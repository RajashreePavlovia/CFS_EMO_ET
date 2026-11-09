function [ctx, key_name, key_code] = wait_key_or_calib(win, cfg, ppd, winRect, ctx, draw_fn)
% WAIT_KEY_OR_CALIB  Show a screen and wait for a key. Behaves like
% wait_any_key, EXCEPT that the calibration key (cfg.keys.calib_key, 'c')
% does not count as "continue": it opens the fusion calibration screen
% instead, and then the SAME screen is redrawn on the new frame positions.
%
%   [ctx, key_name, key_code] = wait_key_or_calib(win, cfg, ppd, winRect, ctx, draw_fn)
%
% draw_fn is a function handle  @(ctx) ...  that draws AND flips the screen
% using ctx.frameDestRects (it is called again after every recalibration so
% the screen follows the new geometry). Example:
%
%   lines = {'Take a break.', '', 'Press any key to continue.'};
%   [ctx, ~] = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
%       @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, lines));
%
% Escape aborts. key_name / key_code describe the key that ended the wait
% (key_code is the full KbCheck vector, handy for comparing against e.g.
% KbName('BackSpace')).

    KbName('UnifyKeyNames');
    escKey   = KbName('ESCAPE');
    calibKey = KbName(cfg.keys.calib_key);

    while true
        draw_fn(ctx);
        KbReleaseWait;   % a key still held from the previous screen can't skip this one

        got_calib = false;
        while true
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(escKey)
                    error('wait_key_or_calib:userAbort', 'User pressed Escape -- aborting.');
                end
                if keyCode(calibKey)
                    got_calib = true;
                    break;
                end
                key_code = keyCode;
                n = KbName(find(keyCode, 1));
                if iscell(n)
                    n = n{1};
                end
                key_name = n;
                KbReleaseWait;
                return;
            end
            WaitSecs(0.001);
        end

        KbReleaseWait;
        if got_calib
            ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, true);
        end
        % loop: redraw the same screen on the (possibly new) frame positions
    end
end
