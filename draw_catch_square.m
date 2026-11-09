function draw_catch_square(win, cfg, ppd, frame_center, side)
% DRAW_CATCH_SQUARE  Draw a plain black rectangle in place of the face,
% for catch trials -- same size and position as a real face would use
% (cfg.face_width_deg x cfg.face_height_deg, offset by cfg.face_eccentricity_deg
% to the given side), so catch trials are visually matched to real face
% trials in every way except the actual face content.
%
%   draw_catch_square(win, cfg, ppd, frame_center, side)
%
% INPUTS -- same meaning as draw_face.m's corresponding inputs, minus the
% face-identity ones (no texture needed here).

    deg2px = @(d) round(d * ppd);

    ecc_px = deg2px(cfg.face_eccentricity_deg);
    if strcmpi(side, 'left')
        x_offset = -ecc_px;
    elseif strcmpi(side, 'right')
        x_offset = ecc_px;
    else
        error('draw_catch_square:badSide', 'side must be ''left'' or ''right''.');
    end

    w_px = deg2px(cfg.face_width_deg);
    h_px = deg2px(cfg.face_height_deg);

    destRect = CenterRectOnPoint([0 0 w_px h_px], ...
        frame_center(1) + x_offset, frame_center(2));

    Screen('FillRect', win, [0 0 0], destRect);
end
