function draw_mask(win, maskTextures, cfg, ppd, frame_center, mask_id)
% DRAW_MASK  Draw one CFS Mondrian mask frame, filling the complete
% fusion frame (cfg.fusion_frame_deg x cfg.fusion_frame_deg), centered on
% the dominant eye's frame center.
%
%   draw_mask(win, maskTextures, cfg, ppd, frame_center, mask_id)
%
% INPUTS
%   win           - PsychToolbox window pointer
%   maskTextures  - vector of texture pointers from preload_mask_textures
%   cfg           - struct from config_experiment()
%   ppd           - pixels-per-degree, from compute_ppd()
%   frame_center  - [x y] pixel center of the dominant eye's fusion frame
%   mask_id       - integer index into maskTextures (1..cfg.mask_n_total)

    deg2px = @(d) round(d * ppd);
    size_px = deg2px(cfg.fusion_frame_deg); % mask spans the full 7.8x7.8 deg frame

    destRect = CenterRectOnPoint([0 0 size_px size_px], frame_center(1), frame_center(2));
    Screen('DrawTexture', win, maskTextures(mask_id), [], destRect);
end
