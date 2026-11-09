function run_fusion_texture_selftest()
% RUN_FUSION_TEXTURE_SELFTEST  Sanity-check the fusion-frame texture
% geometry WITHOUT needing PsychToolbox or a display -- build_fusion_frame_texture
% only does pixel-matrix math, so this can run in plain MATLAB to catch
% sizing/geometry bugs before you ever open a Screen() window.
%
% NOTE: this does NOT test run_fusion_calibration.m itself, since that
% file makes real Screen()/KbCheck calls that need PsychToolbox and an
% actual display. Test that one directly on your machine.

    cfg = config_experiment();
    cfg.screen_width_cm = 30.5; % placeholder for test only -- replace with your MEASURED value
    ppd = compute_ppd(1366, cfg.screen_width_cm, cfg.viewing_distance_cm);
    fprintf('Test ppd = %.2f px/deg (placeholder screen width, replace before real use)\n', ppd);

    img = build_fusion_frame_texture(cfg, ppd);

    assert(size(img,1) == size(img,2), 'Frame texture should be square.');
    assert(size(img,3) == 3, 'Frame texture should be RGB.');
    assert(isa(img, 'uint8'), 'Frame texture should be uint8.');

    % center pixel should be background color (content area, stimuli drawn later)
    c = round(size(img,1)/2);
    bg = squeeze(img(c, c, :))';
    assert(isequal(bg, uint8(cfg.background_rgb)), 'Center of frame should be background color.');

    % corner-most pixel should be red boundary line
    corner = squeeze(img(1,1,:))';
    assert(isequal(corner, uint8([255 0 0])), 'Outer edge should be red boundary line.');

    fprintf('Fusion frame texture is %dx%d px. Geometry self-test passed.\n', size(img,1), size(img,2));
    fprintf('NOTE: replace the placeholder screen_width_cm with your MEASURED value before real use.\n');
end
