function draw_fixation_cross(win, center_xy, span_px, thick_px, rgb)
% DRAW_FIXATION_CROSS  Draw a plus-shaped cross centered at center_xy.
% span_px = total length of each arm-to-arm span, thick_px = line thickness.
% Does NOT flip. Used by the calibration screen (big cross) and by the
% pre-trial fixation (smaller cross).

    cx = center_xy(1);
    cy = center_xy(2);
    h  = span_px / 2;
    t  = thick_px / 2;

    Screen('FillRect', win, rgb, [cx - h, cy - t, cx + h, cy + t]);
    Screen('FillRect', win, rgb, [cx - t, cy - h, cx + t, cy + h]);
end
