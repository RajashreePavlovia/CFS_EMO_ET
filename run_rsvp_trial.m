function log = run_rsvp_trial(win, cfg, ifi, arrow_seq, frame_centers, draw_background_fn, vbl_start)
% RUN_RSVP_TRIAL  Present one trial's RSVP arrow sequence with frame-
% accurate timing, drawing each arrow identically in BOTH eye frames
% (duplicated so it fuses into one central stream through the stereoscope).
%
%   log = run_rsvp_trial(win, cfg, ifi, arrow_seq, frame_centers, draw_background_fn, vbl_start)
%
% INPUTS
%   win            - PsychToolbox window pointer
%   cfg            - struct from config_experiment()
%   ifi            - measured inter-frame interval in seconds, from
%                     Screen('GetFlipInterval', win) -- at 60Hz this is
%                     ~0.01667s (10 frames/item), at 240Hz ~0.004167s
%                     (40 frames/item), since 166.67ms divides evenly
%                     into both
%   arrow_seq      - struct array from generate_rsvp_trial (is_target,
%                     color, orientation per item)
%   frame_centers  - struct from compute_frame_centers (.left, .right),
%                     using this block's calibrated separation
%   draw_background_fn - function handle, draw_background_fn(win), that
%                     draws whatever should appear BEHIND the arrows each
%                     frame (fusion frames, face, CFS mask) but does NOT
%                     call Screen('Flip'). Keeps this function agnostic
%                     to aware/unaware block content.
%   vbl_start      - timestamp (from a prior Screen('Flip')) marking the
%                     end of the fixation period / start of this trial,
%                     so RSVP timing continues seamlessly from it rather
%                     than this function picking its own arbitrary start
%
% OUTPUT
%   log - 1xN struct array, one entry per RSVP item, with fields:
%           .is_target, .color, .orientation  (from arrow_seq)
%           .requested_onset_s  (target VBL time)
%           .actual_onset_s     (actual VBL time PTB reports)
%           .onset_error_ms     (actual - requested, in ms -- watch for
%                                 consistently large values, a sign of
%                                 dropped frames)
%
% TIMING METHOD: frame-counting rather than wall-clock scheduling. Each
% item is shown for exactly n_frames_per_item monitor refreshes, followed
% by a blank gap of n_frames_isi refreshes (cfg.rsvp_isi_s -- 0 frames if
% that's 0), scheduled relative to the PREVIOUS flip's actual VBL time
% (not requested time), which prevents timing drift from accumulating
% across a long trial.

    n_frames_per_item = round(cfg.rsvp_item_duration_s / ifi);
    n_frames_isi = round(cfg.rsvp_isi_s / ifi);
    if abs(n_frames_per_item * ifi - cfg.rsvp_item_duration_s) > ifi/2
        warning('run_rsvp_trial:framesMismatch', ...
            ['cfg.rsvp_item_duration_s (%.4fs) does not divide evenly into ' ...
             'the measured frame interval (%.5fs, %d frames chosen) -- ' ...
             'timing will be approximate.'], cfg.rsvp_item_duration_s, ifi, n_frames_per_item);
    end

    n_items = numel(arrow_seq);
    log = struct('is_target', cell(1,n_items), 'color', cell(1,n_items), ...
                  'orientation', cell(1,n_items), 'requested_onset_s', cell(1,n_items), ...
                  'actual_onset_s', cell(1,n_items), 'onset_error_ms', cell(1,n_items));

    vbl_prev = vbl_start;

    for i = 1:n_items
        item = arrow_seq(i);
        color_rgb = cfg.colors.(item.color);

        draw_background_fn(win);
        draw_arrow(win, frame_centers.left,  cfg.arrow_height_px, cfg.arrow_width_px, item.orientation, color_rgb);
        draw_arrow(win, frame_centers.right, cfg.arrow_height_px, cfg.arrow_width_px, item.orientation, color_rgb);

        target_time = vbl_prev + (n_frames_per_item - 0.5) * ifi;
        vbl = Screen('Flip', win, target_time);

        log(i).is_target = item.is_target;
        log(i).color = item.color;
        log(i).orientation = item.orientation;
        log(i).requested_onset_s = target_time;
        log(i).actual_onset_s = vbl;
        log(i).onset_error_ms = (vbl - target_time) * 1000;

        vbl_prev = vbl;

        % --- ISI: blank gap (background only, no arrow) before the next item ---
        if n_frames_isi > 0
            draw_background_fn(win);
            isi_target_time = vbl_prev + (n_frames_isi - 0.5) * ifi;
            vbl_prev = Screen('Flip', win, isi_target_time);
        end
    end
end
