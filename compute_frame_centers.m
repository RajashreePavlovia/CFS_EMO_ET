function centers = compute_frame_centers(winRect, separation_px, offsets)
% COMPUTE_FRAME_CENTERS  Shared geometry helper: given the window rect and
% a calibrated separation (from run_fusion_calibration), return the pixel
% center of each eye's fusion frame region. Used by BOTH the calibration
% screen and the trial-drawing code so the two never drift out of sync
% with each other.
%
%   centers = compute_frame_centers(winRect, separation_px, offsets)
%
% INPUTS
%   winRect       - PsychToolbox window rect, e.g. Screen('Rect', win)
%   separation_px - calibrated symmetric separation in pixels
%   offsets       - (optional) struct with .left_dx .left_dy .right_dx
%                   .right_dy: extra per-frame shifts in pixels (single-frame
%                   and vertical adjustments from run_fusion_calibration).
%                   Omitted / [] = no extra shifts.
%
% OUTPUT
%   centers - struct with .left = [x y] and .right = [x y]

    screenW = winRect(3) - winRect(1);
    screenH = winRect(4) - winRect(2);
    leftHalfCenterX  = winRect(1) + screenW/4;
    rightHalfCenterX = winRect(1) + 3*screenW/4;
    centerY = winRect(2) + screenH/2;

    centers = struct();
    centers.left  = [leftHalfCenterX  - separation_px/2, centerY];
    centers.right = [rightHalfCenterX + separation_px/2, centerY];

    if nargin >= 3 && ~isempty(offsets)
        centers.left  = centers.left  + [offsets.left_dx,  offsets.left_dy];
        centers.right = centers.right + [offsets.right_dx, offsets.right_dy];
    end
end
