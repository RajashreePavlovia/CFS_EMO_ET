function et_check_fusion_shift(win, cfg, ppd, winRect, ctx)
% ET_CHECK_FUSION_SHIFT  Call right after every fusion calibration (done inside
% recalibrate_now). The EyeLink calibration was made with the fusion frames at
% certain positions; if the participant has since re-fused and the frames moved,
% each eye's gaze reading is shifted by about that much. So:
%   moved < cfg.eyetracking.refusion_drift_deg  -> nothing
%   moved >= refusion_drift_deg                 -> EyeLink drift correction (target at the
%                                                  centre of both frames)
%   moved >= refusion_recal_deg                 -> full EyeLink calibration + validation
% 'moved' = largest displacement (deg) of either eye's frame since the last
% EyeLink calibration or drift correction. Does nothing before the first
% EyeLink calibration (et_ensure_calibrated does that) or when eye tracking is off.

    S = et_state('get');
    if strcmp(S.mode, 'off') || ~S.calibrated || ~isfield(S, 'cal_ref_centers') || isempty(S.cal_ref_centers)
        return;
    end
    E = cfg.eyetracking;
    ref = S.cal_ref_centers;
    moved_px = max(norm(ctx.centers.left - ref.left), norm(ctx.centers.right - ref.right));
    moved_deg = moved_px / ppd;
    if moved_deg < E.refusion_drift_deg
        et_msg('FUSION_SHIFT deg=%.3f action=none', moved_deg);
        return;
    end

    if moved_deg >= E.refusion_recal_deg
        action = 'recalibrate';
        et_msg('FUSION_SHIFT deg=%.3f action=%s', moved_deg, action);
        fprintf('Eye tracking: fusion frames moved %.2f deg -> full EyeLink calibration.\n', moved_deg);
        et_calibrate(win, cfg, ppd, winRect, ctx);
    else
        action = 'drift_correct';
        et_msg('FUSION_SHIFT deg=%.3f action=%s', moved_deg, action);
        fprintf('Eye tracking: fusion frames moved %.2f deg -> EyeLink drift correction.\n', moved_deg);
        frameTex = et_get_frame_tex(win, cfg, ppd);
        geom = et_make_geom(winRect, ctx.centers, ppd, frameTex, ctx.frameDestRects);
        setappdata(0, 'cfs_et_geom', geom);
        et_state('set', struct('geom', geom));
        if strcmp(S.mode, 'live')
            KbReleaseWait;
            et_msg('DRIFT_CORRECT_START (after refusion)');
            if EyelinkDoDriftCorrection(S.el, round(geom.vc(1)), round(geom.vc(2)), 1, 1) ~= 1
                error('et_check_fusion_shift:driftFailed', 'EyeLink drift correction failed or the tracker disconnected.');
            end
            et_msg('DRIFT_CORRECT_DONE (after refusion)');
            KbReleaseWait;
        else
            fprintf('Eye tracking (dummy): drift correction would run here.\n');
        end
        et_state('set', struct('cal_ref_centers', ctx.centers));
    end
end
