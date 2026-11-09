function frameTex = et_get_frame_tex(win, cfg, ppd)
% ET_GET_FRAME_TEX  Fusion-frame texture used to keep the frames on screen during
% EyeLink calibration / drift correction (made once, then cached in the et state).
    S = et_state('get');
    if isfield(S, 'cal_frameTex') && ~isempty(S.cal_frameTex)
        frameTex = S.cal_frameTex;
    else
        frameTex = Screen('MakeTexture', win, build_fusion_frame_texture(cfg, ppd));
        et_state('set', struct('cal_frameTex', frameTex));
    end
end
