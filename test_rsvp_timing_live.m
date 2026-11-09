% TEST_RSVP_TIMING_LIVE  Standalone script to test frame-accurate RSVP
% presentation on your actual display: opens a window, shows a brief
% fixation, then runs ONE trial's arrow sequence (duplicated in both eye
% frames) and reports how accurate the timing actually was.
%
% This test uses separation_px = 0 (frames centered, no live calibration)
% since the goal here is purely to check RSVP timing, not fusion -- we
% already tested calibration separately in test_fusion_calibration_live.
%
% HOW TO RUN:
%   1. Keep this file in the same folder as all your other .m files.
%   2. cd to that folder in MATLAB.
%   3. Type:  test_rsvp_timing_live
%   4. Watch the arrows flash briefly in both screen halves, then check
%      the printed timing report.
%
% If it gets stuck: Ctrl+C, then type "sca" and Enter.

try
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % dev laptop only -- set to 0 for real data collection

    cfg = config_experiment();

    [win, winRect, ppd, ifi] = open_experiment_window(cfg);

    % --- fusion frame background (aware-style, no face/mask yet) ---
    frameImg = build_fusion_frame_texture(cfg, ppd);
    frameTex = Screen('MakeTexture', win, frameImg);
    frameSizePx = size(frameImg, 1);

    separation_px = 0; % see note above
    centers = compute_frame_centers(winRect, separation_px);
    leftDestRect  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    rightDestRect = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    draw_background_fn = @(w) draw_bg(w, frameTex, leftDestRect, rightDestRect);

    % --- fixation period (500ms), duplicated in both frames ---
    fixSize = 10; % px, simple cross
    draw_background_fn(win);
    Screen('DrawLine', win, [255 255 255], centers.left(1)-fixSize, centers.left(2), centers.left(1)+fixSize, centers.left(2), 2);
    Screen('DrawLine', win, [255 255 255], centers.left(1), centers.left(2)-fixSize, centers.left(1), centers.left(2)+fixSize, 2);
    Screen('DrawLine', win, [255 255 255], centers.right(1)-fixSize, centers.right(2), centers.right(1)+fixSize, centers.right(2), 2);
    Screen('DrawLine', win, [255 255 255], centers.right(1), centers.right(2)-fixSize, centers.right(1), centers.right(2)+fixSize, 2);
    vbl_fix_start = Screen('Flip', win);

    n_fix_frames = round(0.5 / ifi); % 500ms fixation
    vbl_start = Screen('Flip', win, vbl_fix_start + (n_fix_frames - 0.5) * ifi);
    % vbl_start now marks the end of fixation / start of RSVP stream

    % --- generate and run one test trial (low load, 3 targets) ---
    test_seq = generate_rsvp_trial(cfg, 'low', 3);
    fprintf('Test trial: %d items, %d targets requested.\n', numel(test_seq), sum([test_seq.is_target]));

    log = run_rsvp_trial(win, cfg, ifi, test_seq, centers, draw_background_fn, vbl_start);

    % blank screen at the end
    draw_background_fn(win);
    Screen('Flip', win);
    WaitSecs(0.3);

    Screen('CloseAll');
    sca;

    % --- timing report ---
    errors_ms = [log.onset_error_ms];
    fprintf('\n--- RSVP timing report ---\n');
    fprintf('Items shown: %d\n', numel(log));
    fprintf('Mean onset error: %.3f ms\n', mean(errors_ms));
    fprintf('Max abs onset error: %.3f ms\n', max(abs(errors_ms)));
    fprintf('Expected item duration: %.3f ms | measured mean inter-item interval: %.3f ms\n', ...
        cfg.rsvp_item_duration_s*1000, mean(diff([log.actual_onset_s]))*1000);
    for i = 1:numel(log)
        fprintf('  item %2d: %-6s %-4s target=%d  onset_error=%.2fms\n', ...
            i, log(i).color, log(i).orientation, log(i).is_target, log(i).onset_error_ms);
    end

catch ME
    sca;
    rethrow(ME);
end


function draw_bg(w, frameTex, leftDestRect, rightDestRect)
% Local function (supported in MATLAB scripts since R2016b): draws the
% fusion-frame background into both eye regions. Kept as a plain local
% function rather than the earlier deal()-based anonymous trick, since
% Screen('DrawTexture', ...) doesn't return a value to deal with.
    Screen('DrawTexture', w, frameTex, [], leftDestRect, 0, 0);
    Screen('DrawTexture', w, frameTex, [], rightDestRect, 0, 0);
end
