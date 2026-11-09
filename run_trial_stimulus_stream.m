function log = run_trial_stimulus_stream(win, cfg, ifi, ppd, trial, awareness, frame_centers, ...
    dominant_side, nondominant_side, faceTextures, maskTextures, frameTex, frameDestRects, vbl_start)
% RUN_TRIAL_STIMULUS_STREAM  Present the RSVP arrow stream, the
% task-irrelevant face, and (if unaware) the flickering CFS mask, all
% simultaneously for the duration of one trial. Flips on EVERY monitor
% frame (not once per RSVP item) because the mask updates on its own
% ~10Hz clock, independent of the ~6Hz RSVP item rate -- these need
% separate frame counters on the same per-frame loop; they can't share a
% single flip-per-item schedule the way the isolated RSVP timing test did.
%
%   log = run_trial_stimulus_stream(win, cfg, ifi, ppd, trial, awareness, ...
%             frame_centers, dominant_side, nondominant_side, ...
%             faceTextures, maskTextures, frameTex, frameDestRects, vbl_start)
%
% INPUTS
%   win, cfg, ifi, ppd - as elsewhere
%   trial             - one trial struct from generate_block_schedule
%                        (.arrow_seq, .mask_ids, .face_identity_id,
%                        .face_gender, .face_side)
%   awareness         - 'aware' or 'unaware' (this block's condition;
%                        controls whether the mask is drawn at all)
%   frame_centers     - struct from compute_frame_centers (.left, .right)
%   dominant_side     - 'left' or 'right': which frame_centers field is
%                        this participant's dominant eye (gets the mask)
%   nondominant_side  - the other one (gets the face)
%   faceTextures      - containers.Map from preload_face_textures
%   maskTextures      - vector from preload_mask_textures
%   frameTex          - fusion-frame texture from build_fusion_frame_texture
%   frameDestRects    - struct with .left, .right destination rects for
%                        drawing frameTex (precomputed once per block from
%                        the calibrated separation, since frame texture
%                        size/position doesn't change trial to trial)
%   vbl_start         - VBL timestamp marking end of fixation / trial onset
%
% OUTPUT
%   log - struct with:
%       .items(1:N)       - one entry per RSVP item actually presented:
%                             .is_target, .color, .orientation,
%                             .actual_onset_s (VBL time of first frame showing this item)
%       .mask_events(1:M) - one entry per DISTINCT mask frame actually
%                            shown (only populated for unaware trials):
%                             .mask_id, .actual_onset_s
%       .trial_end_vbl    - VBL time of the last frame of the RSVP stream
%       .face_report      - struct: .reported (logical), .side ('left'/
%                            'right'/[]), .report_abs_time_s (NaN if not
%                            reported). Only meaningful for unaware
%                            trials -- participant can press Left/Right
%                            AT ANY POINT during the stream to report
%                            seeing the face and which side, without
%                            interrupting the stream. Only the FIRST
%                            press per trial is recorded.
%       .pause_requested  - true if the pause key was pressed at any
%                            point during this stream (sticky flag,
%                            checked continuously; does NOT interrupt the
%                            stream itself -- caller pauses at the next
%                            natural trial boundary instead)
%
% NOTE: this flips every single monitor frame for the whole trial
% (potentially 60+ flips), which is more demanding than the item-level
% test in run_rsvp_trial.m. Watch the missed-deadline count when you test
% this on real hardware -- if it's high, the per-frame draw calls
% (2x fusion frame + 2x arrow + face + mask) may be too much work to
% finish within one 16.67ms (or 4.17ms at 240Hz) frame budget, and we'd
% need to optimize (e.g. pre-render more into static textures).
%
% DRAW ORDER: frame background -> face/catch-square -> mask -> arrow
% backdrop patch -> arrow. The arrow is drawn LAST (on top) specifically
% so it stays visible over the flickering CFS mask in the dominant eye's
% frame -- an earlier version drew the mask after the arrow, which
% covered it. A small background-colored patch is drawn just behind the
% arrow (in BOTH eyes, for consistency) so the arrow reads clearly
% against the mask's moving Mondrian pattern.
%
% SAFETY: Escape is checked every frame during this stream (not just on
% the calibration/probe/response screens) and aborts cleanly via error --
% an earlier version had no abort route during the stimulus stream itself.

    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');
    leftKey = KbName(cfg.keys.face_report_keys.left);
    rightKey = KbName(cfg.keys.face_report_keys.right);
    pauseKey = KbName(cfg.keys.pause_key);
    calibKey = KbName(cfg.keys.calib_key);

    n_frames_per_item = round(cfg.rsvp_item_duration_s / ifi);
    n_frames_isi = round(cfg.rsvp_isi_s / ifi); % blank gap frames between items (0 if rsvp_isi_s is 0)
    cycle_frames = n_frames_per_item + n_frames_isi; % full item+gap cycle length
    n_frames_per_mask = max(1, round(cfg.mask_frame_duration_s / ifi));

    n_items = numel(trial.arrow_seq);
    total_frames = n_items * cycle_frames;

    is_unaware = strcmpi(awareness, 'unaware');
    if is_unaware && isempty(trial.mask_ids)
        error('run_trial_stimulus_stream:missingMask', ...
            'awareness=unaware but trial.mask_ids is empty -- schedule/trial mismatch.');
    end

    is_catch = isfield(trial, 'is_catch') && trial.is_catch;

    dom_center = frame_centers.(dominant_side);
    nondom_center = frame_centers.(nondominant_side);

    backdrop_w = cfg.arrow_width_px  + 2*cfg.arrow_backdrop_padding_px;
    backdrop_h = cfg.arrow_height_px + 2*cfg.arrow_backdrop_padding_px;
    backdrop_rect_left  = CenterRectOnPoint([0 0 backdrop_w backdrop_h], frame_centers.left(1),  frame_centers.left(2));
    backdrop_rect_right = CenterRectOnPoint([0 0 backdrop_w backdrop_h], frame_centers.right(1), frame_centers.right(2));

    % backdrop color: always black now, in every trial (aware and unaware
    % alike), per request -- previously only black in unaware/masked
    % trials, background-gray otherwise.
    backdrop_rgb = [0 0 0];

    log = struct();
    log.items = struct('is_target', {}, 'color', {}, 'orientation', {}, 'actual_onset_s', {});
    log.mask_events = struct('mask_id', {}, 'actual_onset_s', {});
    log.face_report = struct('reported', false, 'side', [], 'report_abs_time_s', NaN);
    log.pause_requested = false; % sticky flag: set true if the pause key is pressed at any point during this stream

    vbl_prev = vbl_start;
    last_item_idx = -1;
    last_mask_frame_idx = -1;

    for f = 1:total_frames
        item_idx = min(n_items, floor((f-1) / cycle_frames) + 1);
        cyc_pos = mod(f-1, cycle_frames);
        show_arrow_this_frame = cyc_pos < n_frames_per_item; % false during the ISI blank portion of the cycle
        item = trial.arrow_seq(item_idx);
        color_rgb = cfg.colors.(item.color);

        % --- draw everything for this frame, in back-to-front order ---
        Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
        Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);

        if is_catch
            draw_catch_square(win, cfg, ppd, nondom_center, trial.face_side);
        else
            draw_face(win, faceTextures, cfg, ppd, nondom_center, ...
                trial.face_identity_id, trial.face_gender, trial.face_emotion, trial.face_side);
        end

        mask_frame_idx = -1;
        if is_unaware
            mask_frame_idx = min(numel(trial.mask_ids), floor((f-1) / n_frames_per_mask) + 1);
            draw_mask(win, maskTextures, cfg, ppd, dom_center, trial.mask_ids(mask_frame_idx));
        end

        if show_arrow_this_frame
            % background patch drawn just behind the arrow so it stays
            % visible against the mask, then the arrow on top of that
            Screen('FillRect', win, backdrop_rgb, backdrop_rect_left);
            Screen('FillRect', win, backdrop_rgb, backdrop_rect_right);
            draw_arrow(win, frame_centers.left,  cfg.arrow_height_px, cfg.arrow_width_px, item.orientation, color_rgb);
            draw_arrow(win, frame_centers.right, cfg.arrow_height_px, cfg.arrow_width_px, item.orientation, color_rgb);
        end
        % NOTE: during the ISI blank portion, no arrow or backdrop patch
        % is drawn, so the mask is fully visible/unobstructed during the gap.

        % --- Escape (always) + pause key (sticky flag) + face-location report (unaware trials only) ---
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_trial_stimulus_stream:userAbort', 'User pressed Escape -- aborting.');
            end
            % pause / recalibrate requests are only LATCHED here (never
            % interrupt the stream); the session acts on them after the trial.
            if keyCode(pauseKey)
                key_flag('pause', 'set');
                log.pause_requested = true;
            end
            if keyCode(calibKey)
                key_flag('calib', 'set');
            end
            if is_unaware && ~log.face_report.reported
                if keyCode(leftKey)
                    log.face_report = struct('reported', true, 'side', 'left', 'report_abs_time_s', secs);
                elseif keyCode(rightKey)
                    log.face_report = struct('reported', true, 'side', 'right', 'report_abs_time_s', secs);
                end
            end
        end

        target_time = vbl_prev + (1 - 0.5) * ifi; % schedule for the very next frame
        vbl = Screen('Flip', win, target_time);
        vbl_prev = vbl;

        if f == 1
            % first frame of the stream = onset of the face, the arrows and (unaware) the mask
            et_msg('STIM_ONSET vbl=%.6f face_side=%s', vbl, trial.face_side);
        end

        if item_idx ~= last_item_idx
            log.items(end+1) = struct('is_target', item.is_target, 'color', item.color, ...
                'orientation', item.orientation, 'actual_onset_s', vbl);
            last_item_idx = item_idx;
            et_msg('ARROW %d %s %s target=%d vbl=%.6f', item_idx, item.color, item.orientation, double(item.is_target), vbl);
        end

        if is_unaware && mask_frame_idx ~= last_mask_frame_idx
            log.mask_events(end+1) = struct('mask_id', trial.mask_ids(mask_frame_idx), 'actual_onset_s', vbl);
            last_mask_frame_idx = mask_frame_idx;
            et_msg('MASK %d id=%d vbl=%.6f', numel(log.mask_events), trial.mask_ids(mask_frame_idx), vbl);
        end
    end

    log.trial_end_vbl = vbl_prev;
end
