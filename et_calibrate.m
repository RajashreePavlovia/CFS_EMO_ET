function et_calibrate(win, cfg, ppd, winRect, ctx, frameTex)
% ET_CALIBRATE  EyeLink calibration + validation, with the targets shown in
% BOTH eyes' fusion frames. Run it AFTER the fusion calibration (ctx holds the
% fused frame positions). The experimenter drives it exactly like the normal
% EyeLink set-up: C = calibrate, V = validate, Enter/Space = accept, Esc = exit.
% The participant just looks at the fused target.
%
%   et_calibrate(win, cfg, ppd, winRect, ctx)
%
% In 'dummy' mode this only prints a note.

    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    if nargin < 6 || isempty(frameTex)
        % make (once) a fusion-frame texture of our own so the frames stay visible during calibration
        frameTex = et_get_frame_tex(win, cfg, ppd);
    end
    geom = et_make_geom(winRect, ctx.centers, ppd, frameTex, ctx.frameDestRects);
    setappdata(0, 'cfs_et_geom', geom);
    et_state('set', struct('geom', geom));

    if strcmp(S.mode, 'dummy')
        fprintf('Eye tracking (dummy): EyeLink calibration would run here.\n');
        et_state('set', struct('calibrated', true, 'cal_ref_centers', ctx.centers, 'last_cal_block', ctx.block_num));
        return;
    end

    et_send_cal_targets(cfg, geom);   % 9 points inside the fusion frame
    KbReleaseWait;
    EyelinkDoTrackerSetup(S.el);
    Eyelink('Message', sprintf('CALIBRATION_DONE block=%d', ctx.block_num));
    et_state('set', struct('calibrated', true, 'cal_ref_centers', ctx.centers, 'last_cal_block', ctx.block_num));
    KbReleaseWait;
end
