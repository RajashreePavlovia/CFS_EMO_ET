% TEST_PROBE_SEQUENCE_LIVE  Standalone script to test the probe branching
% logic on your real display: run one full probe sequence and see the
% questions/options rendered, then check the printed result struct
% matches what you actually pressed.
%
% HOW TO RUN:
%   1. Keep this file in the same folder as your other .m files.
%   2. cd to that folder in MATLAB.
%   3. Type:  test_probe_sequence_live
%   4. Answer the questions as they appear. Try running it multiple
%      times, picking different Probe-1 answers each time (on-task vs
%      SDT vs something else), to confirm the branching skips/shows the
%      right follow-up questions.
%
% If it gets stuck: Ctrl+C, then type "sca" and Enter.

try
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % dev laptop only

    cfg = config_experiment();

    [win, winRect, ppd, ~] = open_experiment_window(cfg);

    frameImg = build_fusion_frame_texture(cfg, ppd);
    frameTex = Screen('MakeTexture', win, frameImg);
    frameSizePx = size(frameImg, 1);

    separation_px = 0; % no live calibration for this test
    centers = compute_frame_centers(winRect, separation_px);
    frameDestRects = struct();
    frameDestRects.left  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    frameDestRects.right = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    test_participant_id = 1;
    probe1_order = build_probe1_order(cfg, test_participant_id);
    fprintf('This participant''s Probe-1 display order: %s\n', strjoin(probe1_order, ', '));

    result = run_probe_sequence(win, cfg, winRect, frameTex, frameDestRects, ppd, probe1_order);

    Screen('CloseAll');
    sca;

    fprintf('\n--- Probe sequence result ---\n');
    disp(result);

catch ME
    sca;
    rethrow(ME);
end
