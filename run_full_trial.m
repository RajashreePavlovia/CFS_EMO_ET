function trial_result = run_full_trial(win, cfg, ifi, ppd, trial, awareness, frame_centers, ...
    dominant_side, nondominant_side, faceTextures, maskTextures, frameTex, frameDestRects)
% RUN_FULL_TRIAL  Run one complete trial start to finish: fixation (500ms,
% no face/mask) -> RSVP + face + (if unaware) CFS mask stream -> target-
% count response collection -> inter-trial interval.
%
%   trial_result = run_full_trial(win, cfg, ifi, ppd, trial, awareness, ...
%       frame_centers, dominant_side, nondominant_side, faceTextures, ...
%       maskTextures, frameTex, frameDestRects)
%
% INPUTS - see run_trial_stimulus_stream.m for most of these; same
%          meanings here.
%
% OUTPUT
%   trial_result - struct ready to feed into a CSV logger, with fields:
%       .n_targets_requested   (trial.n_targets)
%       .n_targets_actual      (counted from trial.arrow_seq)
%       .response              (0-5, or [] if timed out)
%       .rt_s                  (response time, NaN if timed out)
%       .response_abs_time_s   (GetSecs timestamp of the keypress itself, NaN if timed out)
%       .timed_out             (logical)
%       .correct               (logical; response == n_targets_actual)
%       .item_log              (per-RSVP-item onset log, from run_trial_stimulus_stream)
%       .mask_event_log        (per-mask-frame onset log, from run_trial_stimulus_stream;
%                                 empty struct array for aware trials)
%       .fixation_onset_vbl    (VBL time the fixation cross first appeared)
%       .trial_start_vbl       (VBL time fixation ended / RSVP+face(+mask) began)
%       .trial_rsvp_end_vbl    (VBL time RSVP stream ended)
%       .iti_onset_vbl         (VBL time the post-response blank ITI began)
%       .is_catch              (logical; true if a black square replaced the face this trial)
%       .face_report           (struct from run_trial_stimulus_stream: .reported,
%                                 .side, .report_abs_time_s -- only meaningful
%                                 for unaware trials, see that function's docs)
%       .pause_requested       (logical; true if the pause key was pressed
%                                 anywhere during this trial's RSVP stream
%                                 or response window)
%       .calib_requested       (logical; true if C was pressed anywhere during
%                                 this trial -- the trial itself always runs
%                                 to completion; the session recalibrates after)
%
% NOTE: makes real Screen()/KbCheck calls, untested on real hardware as
% of writing -- test this on your setup and report back exactly what
% happens (including any missed-deadline counts PTB reports).

    % P (pause) is consumed once per trial, so start each trial with it clear.
    % The C (recalibrate) latch is deliberately NOT cleared here: the session
    % clears it when it actually recalibrates.
    key_flag('pause', 'clear');

    % --- eye tracking: label the trial, start recording, central-fixation check ---
    % (does nothing unless cfg.eyetracking.mode is 'dummy' or 'live')
    et_gate = et_trial_begin(win, cfg, ppd, trial, awareness, frame_centers, frameTex, frameDestRects);

    % --- pre-trial fixation cross (cfg.pretrial_fixation_s, default 200 ms) ---
    pre_fix_s = 0;
    if isfield(cfg, 'pretrial_fixation_s') && ~isempty(cfg.pretrial_fixation_s)
        pre_fix_s = cfg.pretrial_fixation_s;
    end
    pre_fix_vbl = NaN;
    if pre_fix_s > 0
        Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
        Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
        cross_span = cfg.fixation_cross_deg * ppd;
        cross_thk  = max(2, round(cfg.fixation_cross_thickness_deg * ppd));
        draw_fixation_cross(win, frame_centers.left,  cross_span, cross_thk, [255 255 255]);
        draw_fixation_cross(win, frame_centers.right, cross_span, cross_thk, [255 255 255]);
        pre_fix_vbl = Screen('Flip', win);
    end

    % --- fixation period: fusion frames only, no face/mask (per methodology) ---
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
    if pre_fix_s > 0
        n_pre_frames = round(pre_fix_s / ifi);
        fixation_onset_vbl = Screen('Flip', win, pre_fix_vbl + (n_pre_frames - 0.5) * ifi);
    else
        fixation_onset_vbl = Screen('Flip', win);
    end

    n_fix_frames = round(cfg.pretrial_fixation_s / ifi);
    trial_start_vbl = Screen('Flip', win, fixation_onset_vbl + (n_fix_frames - 0.5) * ifi);
    % NOTE: this flip still shows the same fixation content (nothing new
    % drawn since the last Flip call) -- it exists purely to mark the
    % precise end-of-fixation timestamp that the RSVP stream continues
    % from. This matches the frame-counting pattern used elsewhere.
    % trial_start_vbl also marks the face's onset, since the face begins
    % simultaneously with the RSVP stream (not during fixation).

    % --- RSVP + face + mask stream ---
    stream_log = run_trial_stimulus_stream(win, cfg, ifi, ppd, trial, awareness, frame_centers, ...
        dominant_side, nondominant_side, faceTextures, maskTextures, frameTex, frameDestRects, trial_start_vbl);
    et_msg('STREAM_END vbl=%.6f', stream_log.trial_end_vbl);

        % --- forced face report? (set by cfg.forced_face_report_mode) ---
    forced_mode = 'none';
    if isfield(cfg, 'forced_face_report_mode')
        forced_mode = cfg.forced_face_report_mode;   % 'none' | 'unaware_only' | 'all'
    end
    ask_now = strcmpi(forced_mode, 'all') || ...
        (strcmpi(forced_mode, 'unaware_only') && strcmpi(awareness, 'unaware'));

    % --- response collection ---
    [response, rt_s, timed_out, response_abs_time_s, stream_log.face_report] = ...
        collect_target_count_response(win, cfg, frameTex, frameDestRects, dominant_side, ...
        strcmpi(awareness, 'unaware') && ~ask_now, stream_log.face_report);

    % --- forced face-location report ---
    face_rt_prompt = NaN;
    if ask_now
        [fr, fr_secs, face_rt_prompt] = ask_face_side(win, cfg, frameTex, [], frameDestRects, ppd);
        if strcmp(fr, 'none')
            stream_log.face_report = struct('reported', false, 'side', [], 'report_abs_time_s', fr_secs);
        else
            stream_log.face_report = struct('reported', true, 'side', fr, 'report_abs_time_s', fr_secs);
        end
    end

        % --- inter-trial interval (blank frames, no face/mask) ---
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
    iti_onset_vbl = Screen('Flip', win);
    et_msg('ITI_ON vbl=%.6f', iti_onset_vbl);

    escKey   = KbName('ESCAPE');
    pauseKey = KbName(cfg.keys.pause_key);
    calibKey = KbName(cfg.keys.calib_key);
    leftKey  = KbName(cfg.keys.face_report_keys.left);
    rightKey = KbName(cfg.keys.face_report_keys.right);
    is_unaware = strcmpi(awareness, 'unaware') && ~ask_now;

    iti_pause_requested = false;
    face_report = stream_log.face_report;   % carries over any report already made

    iti_end = iti_onset_vbl + cfg.iti_s;
    while GetSecs < iti_end
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_full_trial:userAbort', 'User pressed Escape -- aborting.');
            end
            if keyCode(pauseKey)
                iti_pause_requested = true;
                key_flag('pause', 'set');
            end
            if keyCode(calibKey)
                key_flag('calib', 'set');   % latched; session recalibrates after this trial
            end
            if is_unaware && ~face_report.reported
                if keyCode(leftKey)
                    face_report = struct('reported', true, 'side', 'left', 'report_abs_time_s', secs);
                elseif keyCode(rightKey)
                    face_report = struct('reported', true, 'side', 'right', 'report_abs_time_s', secs);
                end
            end
        end
        WaitSecs(0.001);
    end

    et_trial_end();   % stop EyeLink recording (no-op when eye tracking is off)

    % --- assemble result ---
    n_targets_actual = sum([trial.arrow_seq.is_target]);
    trial_result = struct();
    trial_result.n_targets_requested = trial.n_targets;
    trial_result.n_targets_actual = n_targets_actual;
    trial_result.response = response;
    trial_result.rt_s = rt_s;
    trial_result.response_abs_time_s = response_abs_time_s;
    trial_result.timed_out = timed_out;
    trial_result.correct = ~timed_out && ~isempty(response) && (response == n_targets_actual);
    trial_result.item_log = stream_log.items;
    trial_result.mask_event_log = stream_log.mask_events;
    trial_result.pretrial_fixation_onset_vbl = pre_fix_vbl;
    trial_result.fixation_onset_vbl = fixation_onset_vbl;
    trial_result.trial_start_vbl = trial_start_vbl;
    trial_result.trial_rsvp_end_vbl = stream_log.trial_end_vbl;
    trial_result.iti_onset_vbl = iti_onset_vbl;
    trial_result.is_catch = isfield(trial, 'is_catch') && trial.is_catch;
    trial_result.face_report = face_report;
    trial_result.face_report_rt_prompt_s = face_rt_prompt;
    % pause: pressed at ANY point in the trial (stream, response, face report
    % or ITI) -- the stream/response/face-report loops latch it via key_flag.
    trial_result.pause_requested = iti_pause_requested || key_flag('pause', 'get');
    % recalibration requested (C) at any point in the trial; the session acts
    % on it only after the trial's responses are fully recorded.
    trial_result.calib_requested = key_flag('calib', 'get');
    trial_result.et_gate = et_gate;   % eye-tracking central-fixation check (status 'off' when not tracking)
end
