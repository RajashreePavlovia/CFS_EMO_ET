% TEST_FUSION_CALIBRATION_LIVE  Standalone script to open a PsychToolbox
% window and run the fusion-frame calibration screen once, so you can see
% it on your actual display and test the arrow-key controls.
%
% HOW TO RUN:
%   1. Make sure this file is in the SAME FOLDER as your other .m files
%      (config_experiment.m, compute_ppd.m, build_fusion_frame_texture.m,
%      run_fusion_calibration.m, etc.)
%   2. In MATLAB, cd to that folder.
%   3. Type:  test_fusion_calibration_live
%   4. A gray window should open showing two fusion frames (one in each
%      screen half). Try the arrow keys to nudge them, then press Return
%      to confirm. The window will close automatically and print the
%      final calibrated separation value.
%
% If anything goes wrong mid-run (error, or the window gets stuck),
% press Ctrl+C in the MATLAB command window, then type "sca" and press
% Enter -- that forces PsychToolbox to close the screen and give control
% back to MATLAB.

try
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % dev laptop is 60Hz, non-critical for this test

    cfg = config_experiment();

    [win, winRect, ppd, ~] = open_experiment_window(cfg);

    test_participant_id = 1;
    test_block_num = 1;

    separation_px = run_fusion_calibration(win, cfg, ppd, test_block_num, test_participant_id);

    Screen('CloseAll');
    sca;

    fprintf('Calibration confirmed. Final separation = %d px.\n', separation_px);

catch ME
    % ALWAYS clean up the screen on error, or MATLAB can get stuck behind
    % the PTB fullscreen window.
    sca;
    rethrow(ME);
end
