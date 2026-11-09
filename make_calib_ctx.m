function ctx = make_calib_ctx(winRect, frameSizePx, participant_id)
% MAKE_CALIB_CTX  Build the "calibration context" struct that carries the
% CURRENT fusion geometry through the whole session. Every screen draws from
% ctx.frameDestRects / ctx.centers, so after a recalibration (scheduled or
% by pressing C) all later screens automatically use the new positions.
%
% Fields:
%   .calib_state        state returned by run_fusion_calibration ([] at first)
%   .separation_px, .frame_offsets, .eff_separation_px
%   .centers            .left / .right [x y]
%   .frameDestRects     .left / .right destination rects for frameTex
%   .frameSizePx, .participant_id
%   .block_num          shown on the calibration screen
%   .n_recalibrations   how many times C-triggered recalibration has run
%   .last_calib_time    GetSecs at the end of the latest calibration
%   .log_path           events CSV path; if non-empty, recalibrate_now appends
%                       one row per calibration ('calibration_scheduled' or
%                       'calibration_manual') -- '' = no logging
%   .trial_num          trial number written into those rows (0 = before the block's first trial)

    ctx = struct();
    ctx.calib_state = [];
    ctx.frameSizePx = frameSizePx;
    ctx.participant_id = participant_id;
    ctx.block_num = 0;
    ctx.n_recalibrations = 0;
    ctx.last_calib_time = NaN;
    ctx.log_path = '';
    ctx.trial_num = 0;
    off0 = struct('left_dx', 0, 'left_dy', 0, 'right_dx', 0, 'right_dy', 0);
    ctx = set_ctx_geometry(ctx, winRect, 0, off0, []);
end
