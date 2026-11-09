function et_ensure_calibrated(win, cfg, ppd, winRect, ctx, block_num)
% ET_ENSURE_CALIBRATED  Run the EyeLink calibration the first time it is
% called in a session, and again at the start of every
% cfg.eyetracking.recalibrate_every_blocks-th block (0 = only once).
% Call right after the block's fusion calibration.

    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    n = cfg.eyetracking.recalibrate_every_blocks;
    again = n > 0 && block_num > 1 && mod(block_num - 1, n) == 0 && ...
        ~(isfield(S, 'last_cal_block') && isequal(S.last_cal_block, ctx.block_num));   % not twice in one block
    if ~S.calibrated || again
        et_calibrate(win, cfg, ppd, winRect, ctx);
    end
end
