function cfs_draw_cal_target(win, el, xy)
% CFS_DRAW_CAL_TARGET  Draw an EyeLink calibration / drift-check target in
% BOTH eyes' fusion frames (so the stereoscope shows one fused target).
%
%   cfs_draw_cal_target(win, el, xy)
%
% xy is the target position in the tracker's VIRTUAL screen coordinates (see
% et_make_geom). Called from the patched PsychEyelinkDispatchCallback.m (see
% EYETRACKING_README.md). If no stereoscope geometry has been stored yet it
% falls back to a single normal target at xy.
%
% Does NOT flip -- the callback flips.

    geom = getappdata(0, 'cfs_et_geom');
    outer_deg = 0.6; inner_deg = 0.2;
    c_out = [255 255 255]; c_in = [0 0 0];
    if isappdata(0, 'cfs_et_cfg')
        E = getappdata(0, 'cfs_et_cfg');
        outer_deg = E.cal_target_outer_deg; inner_deg = E.cal_target_inner_deg;
        c_out = E.cal_target_rgb; c_in = E.cal_inner_rgb;
    end

    if isempty(geom)
        pts = xy(:)';
        ppd = 40;
    else
        pts = [geom.centers.left  + (xy(:)' - geom.vc); ...
               geom.centers.right + (xy(:)' - geom.vc)];
        ppd = geom.ppd;
    end

    % The EyeLink callback clears the whole window before every target, which would erase the fusion
    % frames. Redraw them first so the participant keeps seeing (and fusing) both frames.
    if ~isempty(geom) && ~isempty(geom.frameTex) && ~isempty(geom.frameDestRects)
        Screen('DrawTexture', win, geom.frameTex, [], geom.frameDestRects.left, 0, 0);
        Screen('DrawTexture', win, geom.frameTex, [], geom.frameDestRects.right, 0, 0);
    end

    d_out = max(6, round(outer_deg * ppd));
    d_in  = max(2, round(inner_deg * ppd));
    for k = 1:size(pts, 1)
        Screen('FillOval', win, c_out, CenterRectOnPointd([0 0 d_out d_out], pts(k,1), pts(k,2)), d_out);
        Screen('FillOval', win, c_in,  CenterRectOnPointd([0 0 d_in  d_in ], pts(k,1), pts(k,2)), d_in);
    end
end
