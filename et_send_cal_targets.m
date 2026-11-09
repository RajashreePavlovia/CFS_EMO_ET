function et_send_cal_targets(cfg, geom)
% ET_SEND_CAL_TARGETS  Tell the host PC exactly where its 9 calibration and
% validation points are: a 3x3 grid inside the fusion frame, centred on the
% fused frame centre (geom.vc, in virtual-screen pixels), spanning
% +/- cfg.eyetracking.cal_area_deg/2. Without this the host spreads the points over
% the whole half-screen, mostly outside the frames the participant can see.
% Also used for the drift-correction target, which sits at geom.vc (frame centre).
%
% HV9 order on the host: centre, top, bottom, left, right, top-left, top-right,
% bottom-left, bottom-right.

    S = et_state('get');
    if ~strcmp(S.mode, 'live')
        return;
    end
    E = cfg.eyetracking;
    h = E.cal_area_deg / 2 * geom.ppd;          % half-width in px
    c = geom.vc;
    off = [0 0; 0 -h; 0 h; -h 0; h 0; -h -h; h -h; -h h; h h];
    p = round(off + c);
    str = '';
    for k = 1:size(p, 1)
        str = [str sprintf('%d,%d ', p(k,1), p(k,2))]; %#ok<AGROW>
    end
    str = strtrim(str);
    Eyelink('Command', 'generate_default_targets = NO');
    Eyelink('Command', sprintf('calibration_targets = %s', str));
    Eyelink('Command', sprintf('validation_targets = %s', str));
    et_msg('CAL_TARGETS_PX %s', str);
end
