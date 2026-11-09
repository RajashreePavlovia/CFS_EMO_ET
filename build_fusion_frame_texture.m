function img = build_fusion_frame_texture(cfg, ppd)
% BUILD_FUSION_FRAME_TEXTURE  Build the pixel image (RGB matrix) for ONE
% eye's fusion frame: background fill, a black/white RANDOM NOISE contour
% ring at the border (each 0.15-degree element independently black or
% white, not a regular checkerboard -- matches the "pixel contour"
% description from the literature), and a thin red boundary line just
% outside the ring. This is built once (geometry is fixed) and reused
% every block -- calibration only moves WHERE this texture is drawn, not
% what it looks like.
%
%   img = build_fusion_frame_texture(cfg, ppd)
%
% INPUTS
%   cfg - struct from config_experiment()
%   ppd - pixels-per-degree, from compute_ppd()
%
% OUTPUT
%   img - HxWx3 uint8 RGB image, ready for Screen('MakeTexture', win, img)
%         The square frame content area (inside the ring) is filled with
%         cfg.background_rgb -- draw the actual face/mask/RSVP stimuli
%         for that trial on TOP of this texture afterwards.

    deg2px = @(d) round(d * ppd);

    frame_px      = deg2px(cfg.fusion_frame_deg);
    band_px       = deg2px(cfg.contour_band_deg);
    element_px    = max(1, deg2px(cfg.contour_element_deg)); % floor at 1px, see note below
    red_line_px   = max(1, deg2px(cfg.red_boundary_line_deg));

    if deg2px(cfg.contour_element_deg) < 1
        warning('build_fusion_frame_texture:subpixel', ...
            ['contour_element_deg (%.4f deg) is sub-pixel at this ppd (%.1f) -- ' ...
             'rendered contour ring will be coarser than specified. ' ...
             'Consider 0.15 deg instead of 0.015 deg.'], cfg.contour_element_deg, ppd);
    end

    total_px = frame_px + 2*band_px + 2*red_line_px;
    img = repmat(reshape(uint8(cfg.background_rgb), 1, 1, 3), total_px, total_px, 1);

    % --- red boundary line: a single ring at the VERY outer edge of the
    % whole texture, thickness = red_line_px. (Previous version of this
    % function called paint_ring with degenerate/duplicate coordinates
    % and never actually drew a visible line -- fixed here.)
    red_rgb = uint8([255 0 0]);
    img = paint_ring(img, 1, total_px, red_line_px, red_rgb);

    % --- random noise black/white contour band (NOT a regular checkerboard) ---
    % Each element_px x element_px patch is independently assigned black
    % or white at random (50/50), matching the "pixel contour" description
    % in the literature -- a checkerboard is a regular alternating
    % pattern, which is a different (more structured, less noise-like)
    % visual than what was intended here.
    band_outer_start = red_line_px + 1;
    band_outer_end_coord = total_px - red_line_px;
    content_start = red_line_px + band_px + 1;
    content_end = total_px - red_line_px - band_px;

    [xx, yy] = meshgrid(1:total_px, 1:total_px);
    in_band = (xx >= band_outer_start & xx <= band_outer_end_coord & ...
               yy >= band_outer_start & yy <= band_outer_end_coord) & ...
              ~(xx >= content_start & xx <= content_end & ...
                yy >= content_start & yy <= content_end);

    % build a coarse random grid (one random bit per element_px block),
    % then upsample it to full pixel resolution via nearest-neighbor
    % indexing -- this is what actually makes each block independently
    % random rather than following a fixed alternating pattern.
    n_elements = ceil(total_px / element_px);
    noise_grid = rand(n_elements, n_elements) < 0.5; % true = white, false = black
    element_row = min(n_elements, floor((yy-1)/element_px) + 1);
    element_col = min(n_elements, floor((xx-1)/element_px) + 1);
    element_idx = sub2ind(size(noise_grid), element_row, element_col);
    is_white_full = reshape(noise_grid(element_idx), size(xx));

    is_white = in_band & is_white_full;
    is_black = in_band & ~is_white_full;

    img = set_mask_color(img, is_white, uint8([255 255 255]));
    img = set_mask_color(img, is_black, uint8([0 0 0]));
end


function img = paint_ring(img, from_px, to_px, thickness, rgb)
% Paint a ring of the given THICKNESS around the border of the square box
% spanning from_px to to_px (inclusive). Used for the red boundary line.
% (Earlier version hardcoded thickness=1 regardless of the thickness
% argument, and callers passed degenerate boxes -- both fixed now.)
    sz = size(img,1);
    [xx, yy] = meshgrid(1:sz, 1:sz);
    outer = (xx>=from_px & xx<=to_px & yy>=from_px & yy<=to_px);
    inner = (xx>=from_px+thickness & xx<=to_px-thickness & ...
             yy>=from_px+thickness & yy<=to_px-thickness);
    ring = outer & ~inner;
    img = set_mask_color(img, ring, rgb);
end


function img = set_mask_color(img, mask, rgb)
    for c = 1:3
        ch = img(:,:,c);
        ch(mask) = rgb(c);
        img(:,:,c) = ch;
    end
end
