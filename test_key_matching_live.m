% TEST_KEY_MATCHING_LIVE  Minimal isolated test of collect_keypress_response,
% with none of the probe question/branching complexity. Opens a window,
% shows a simple prompt, and asks you to press 1-5 FIVE TIMES IN A ROW,
% printing exactly what was returned after each press. This isolates
% whether the problem is in collect_keypress_response itself, or
% somewhere in the probe screens/branching logic built on top of it.
%
% HOW TO RUN:
%   test_key_matching_live
%
% Press 1, then 2, then 3, then 4, then 5 (one at a time, waiting for the
% "Detected:" printout after each before pressing the next). Paste the
% FULL console output back, including anything unexpected.
%
% Press Escape at any point to quit early.

try
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1);

    cfg = config_experiment();
    [win, winRect, ~, ~] = open_experiment_window(cfg);

    for trial = 1:5
        Screen('FillRect', win, cfg.background_rgb);
        Screen('TextSize', win, 24);
        DrawFormattedText(win, sprintf('Round %d of 5: press any of 1-5', trial), 'center', 'center', [255 255 255]);
        Screen('Flip', win);

        [key, rt_s] = collect_keypress_response({'1','2','3','4','5'}, win);
        fprintf('Round %d: Detected key = ''%s'', RT = %.3fs\n', trial, key, rt_s);
    end

    Screen('CloseAll');
    sca;
    fprintf('Test complete.\n');

catch ME
    sca;
    fprintf('ERROR: %s\n', ME.message);
    rethrow(ME);
end
