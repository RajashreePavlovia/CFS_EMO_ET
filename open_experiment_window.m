function [win, winRect, ppd, ifi] = open_experiment_window(cfg)
% OPEN_EXPERIMENT_WINDOW  Open the PTB window (fullscreen or windowed,
% per cfg.debug_windowed_mode) and compute ppd correctly regardless of
% which mode is used.
%
%   [win, winRect, ppd, ifi] = open_experiment_window(cfg)
%
% IMPORTANT: pixels-per-degree depends on the monitor's physical pixel
% density, which does NOT change just because you open a smaller window
% on it. This function always computes ppd from the screen's NATIVE
% resolution (Screen('Resolution', ...)), never from winRect -- using
% winRect's width here would silently shrink every stimulus size whenever
% debug_windowed_mode is on, which would be a nasty, easy-to-miss bug.
%
% OUTPUT
%   win, winRect - as normal
%   ppd          - pixels-per-degree, correct regardless of window size
%   ifi          - measured inter-frame interval, Screen('GetFlipInterval', win)

    screens = Screen('Screens');
    screenNumber = max(screens);

    res = Screen('Resolution', screenNumber);
    native_width_px = res.width;
    
    Screen('Preference', 'DefaultFontName', 'Arial');
    if cfg.debug_windowed_mode
        [win, winRect] = Screen('OpenWindow', screenNumber, cfg.background_rgb, cfg.debug_window_rect);
    else
        [win, winRect] = Screen('OpenWindow', screenNumber, cfg.background_rgb);
    end

    ifi = Screen('GetFlipInterval', win);
    ppd = compute_ppd(native_width_px, cfg.screen_width_cm, cfg.viewing_distance_cm);

    fprintf('Window opened (%s). Native screen width: %dpx. ppd=%.2f. ifi=%.5fs (%.2fHz)\n', ...
        ternary(cfg.debug_windowed_mode, 'WINDOWED - debug only', 'FULLSCREEN'), ...
        native_width_px, ppd, ifi, 1/ifi);
end


function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
