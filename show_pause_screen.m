function show_pause_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, target_lines)
% SHOW_PAUSE_SCREEN  Display a "Paused" screen and block until any key is
% pressed to resume. Called between trials when check_pause_key detects
% the pause key was pressed.
%
%   show_pause_screen(win, cfg, frameTex, winRect, frameDestRects, ppd)

    lines = [{'PAUSED', '', 'Take your time.', '', 'When you continue, please count:', ''}, ...
             target_lines, {'', 'Press any key to resume.'}];    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);
    wait_any_key();
end