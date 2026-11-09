function draw_face_texture(win, cfg, ppd, frame_center, tex, side)
% DRAW_FACE_TEXTURE  Draw one face texture offset left/right of frame_center.
%
% The face texture contains an alpha channel generated during preprocessing.
% Alpha blending is therefore enabled for every face draw so that the
% transparent region outside the feathered face boundary reveals the
% experiment background.

    ecc_px = cfg.face_eccentricity_deg * ppd;
    w_px   = cfg.face_width_deg  * ppd;
    h_px   = cfg.face_height_deg * ppd;

    switch lower(side)
        case 'left'
            x = frame_center(1) - ecc_px;

        case 'right'
            x = frame_center(1) + ecc_px;

        otherwise
            error('draw_face_texture:badSide', ...
                'side must be ''left'' or ''right'', got: %s', string(side));
    end

    y = frame_center(2);

    dstRect = CenterRectOnPointd([0 0 w_px h_px], x, y);

    % -------------------------------------------------------------
    % FACE CONTRAST
    % -------------------------------------------------------------
    contrast = 1;

    if isfield(cfg, 'face_contrast') && ~isempty(cfg.face_contrast)
        contrast = cfg.face_contrast;
    end

    % -------------------------------------------------------------
    % ENABLE ALPHA BLENDING
    % -------------------------------------------------------------
    [srcOld, dstOld] = Screen('BlendFunction', win, ...
        GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % Draw face.
    %
    % The PNG's own alpha channel controls the feather/transparency.
    % 'contrast' is applied as an additional global modulation.
    Screen('DrawTexture', win, tex, [], dstRect, 0, [], contrast);

    % Restore previous blending state
    Screen('BlendFunction', win, srcOld, dstOld);

end