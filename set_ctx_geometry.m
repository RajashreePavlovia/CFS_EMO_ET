function ctx = set_ctx_geometry(ctx, winRect, separation_px, frame_offsets, calib_state)
% SET_CTX_GEOMETRY  Store a calibration result in ctx and recompute the
% frame centres and destination rects from it (same maths the session used
% to do inline after every run_fusion_calibration call).

    ctx.separation_px = separation_px;
    ctx.frame_offsets = frame_offsets;
    ctx.calib_state = calib_state;
    ctx.eff_separation_px = separation_px + frame_offsets.right_dx - frame_offsets.left_dx;
    ctx.centers = compute_frame_centers(winRect, separation_px, frame_offsets);
    sz = ctx.frameSizePx;
    ctx.frameDestRects = struct();
    ctx.frameDestRects.left  = CenterRectOnPoint([0 0 sz sz], ctx.centers.left(1),  ctx.centers.left(2));
    ctx.frameDestRects.right = CenterRectOnPoint([0 0 sz sz], ctx.centers.right(1), ctx.centers.right(2));
end
