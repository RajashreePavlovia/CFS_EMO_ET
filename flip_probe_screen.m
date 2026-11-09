function flip_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines)
% FLIP_PROBE_SCREEN  draw_probe_screen + Flip in one call (used as the
% "redraw this screen" callback for wait_key_or_calib).
    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);
end
