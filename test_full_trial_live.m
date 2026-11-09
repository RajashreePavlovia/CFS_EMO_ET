% TEST_FULL_TRIAL_LIVE  Standalone script to run ONE complete trial start
% to finish on your actual display: fixation, RSVP + face + CFS mask
% stream, response collection, and ITI. This is the first test that needs
% your REAL face and mask image files to be present at the paths in
% config_experiment.m, since it loads and draws them for real.
%
% HOW TO RUN:
%   1. Keep this file in the same folder as all your other .m files.
%   2. Make sure cfg.face_folder_root and cfg.mask_folder in
%      config_experiment.m point to real folders with your actual files.
%   3. cd to that folder in MATLAB.
%   4. Type:  test_full_trial_live
%   5. It will ask (in the MATLAB command window, before opening any
%      window) which eye is dominant -- type left or right.
%   6. Watch: fixation cross -> RSVP arrows flashing with a face+mask
%      running alongside -> a response prompt (press 0-5) -> a blank ITI.
%   7. Check the printed trial summary at the end.
%
% If it gets stuck: Ctrl+C, then type "sca" and Enter.

try
    dominant_eye_input = input('Dominant eye for this test (left/right): ', 's');
    if ~ismember(lower(dominant_eye_input), {'left','right'})
        error('test_full_trial_live:badInput', 'Must type left or right.');
    end
    dominant_eye = lower(dominant_eye_input);

    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % dev laptop only -- set to 0 for real data collection

    cfg = config_experiment();

    [win, winRect, ppd, ifi] = open_experiment_window(cfg);

    % --- eye-side mapping for this participant ---
    sides = get_eye_side_mapping(cfg, dominant_eye);
    fprintf('Dominant eye (%s) -> %s screen half (mask). Non-dominant -> %s screen half (face).\n', ...
        dominant_eye, sides.dominant_screen_half, sides.nondominant_screen_half);

    % --- fusion frame texture + calibration (block 1, participant 1 for this test) ---
    frameImg = build_fusion_frame_texture(cfg, ppd);
    frameTex = Screen('MakeTexture', win, frameImg);
    frameSizePx = size(frameImg, 1);

    separation_px = run_fusion_calibration(win, cfg, ppd, 1, 1);
    centers = compute_frame_centers(winRect, separation_px);
    frameDestRects = struct();
    frameDestRects.left  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    frameDestRects.right = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    % --- preload real face + mask textures (needs real files present) ---
    faceTextures = preload_face_textures(win, cfg);
    maskTextures = preload_mask_textures(win, cfg);

    % --- build a schedule and grab one trial to test with ---
    sched = generate_block_schedule(cfg, 1, 42);
    block = sched.blocks(1);
    trial = block.trials(1);
    fprintf('Testing block 1 (attention=%s, awareness=%s, emotion=%s), trial 1 (n_targets=%d).\n', ...
        block.attention, block.awareness, block.emotion, trial.n_targets);

    % --- run the full trial ---
    result = run_full_trial(win, cfg, ifi, ppd, trial, block.awareness, centers, ...
        sides.dominant_screen_half, sides.nondominant_screen_half, ...
        faceTextures, maskTextures, frameTex, frameDestRects);

    Screen('CloseAll');
    sca;

    % --- report ---
    fprintf('\n--- Trial result ---\n');
    fprintf('Targets requested: %d | actual in sequence: %d\n', result.n_targets_requested, result.n_targets_actual);
    if result.timed_out
        fprintf('Response: TIMED OUT (no keypress within %.1fs)\n', cfg.max_response_time_s);
    else
        fprintf('Response: %d | RT: %.3fs | Correct: %d\n', result.response, result.rt_s, result.correct);
    end
    fprintf('RSVP items shown: %d\n', numel(result.item_log));
    fprintf('RSVP stream duration: %.3fs (expected ~%.3fs)\n', ...
        result.trial_rsvp_end_vbl - result.trial_start_vbl, numel(trial.arrow_seq)*cfg.rsvp_item_duration_s);

catch ME
    sca;
    rethrow(ME);
end
