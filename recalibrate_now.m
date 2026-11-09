function ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, is_manual)
% RECALIBRATE_NOW  Run the fusion calibration screen and update ctx.
%
%   ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, is_manual)
%
% Starts from the previous fused position (ctx.calib_state), so the screen
% asks "ARE THE FRAMES STILL FUSED?" -- Return accepts as-is, or adjust
% first. Always clears any pending "C was pressed" request, so a scheduled
% calibration also satisfies an earlier C press.
%
% is_manual (optional, default false): true when triggered by the C key;
% only those are counted in ctx.n_recalibrations.

    if nargin < 6
        is_manual = false;
    end
    key_flag('calib', 'clear');

    [sep, off, st] = run_fusion_calibration(win, cfg, ppd, ctx.block_num, ctx.participant_id, ctx.calib_state);
    ctx = set_ctx_geometry(ctx, winRect, sep, off, st);
    ctx.last_calib_time = GetSecs;
    if is_manual
        ctx.n_recalibrations = ctx.n_recalibrations + 1;
        event_type = 'calibration_manual';
    else
        event_type = 'calibration_scheduled';
    end

    % one events-CSV row per calibration (time = when the screen was accepted)
    if isfield(ctx, 'log_path') && ~isempty(ctx.log_path)
        value = sprintf('sep=%.1f;left_dy=%.1f;right_dy=%.1f', ctx.eff_separation_px, ...
            ctx.frame_offsets.left_dy, ctx.frame_offsets.right_dy);
        append_csv_row(ctx.log_path, {ctx.participant_id, ctx.block_num, ctx.trial_num, ...
            event_type, ctx.n_recalibrations, '', value, ctx.last_calib_time});
    end
    et_check_fusion_shift(win, cfg, ppd, winRect, ctx);   % eye tracking: drift-correct / recalibrate if the frames moved
    KbReleaseWait;   % a Return held from the calibration screen must not skip the next screen
end
