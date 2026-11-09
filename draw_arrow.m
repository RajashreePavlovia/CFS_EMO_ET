function draw_arrow(win, center_xy, height_px, width_px, orientation, color_rgb)
% DRAW_ARROW  Draw a single procedural triangular arrow (isosceles
% triangle) centered at a given screen position.
%
%   draw_arrow(win, center_xy, height_px, width_px, orientation, color_rgb)
%
% INPUTS
%   win          - PsychToolbox window pointer
%   center_xy    - [x y] pixel coordinates of the arrow's center
%   height_px    - arrow height in pixels (cfg.arrow_height_px)
%   width_px     - arrow width in pixels (cfg.arrow_width_px)
%   orientation  - 'up' (apex at top) or 'down' (apex at bottom, i.e.
%                  the inverted/downward arrows used in the high-load
%                  RSVP task)
%   color_rgb    - [R G B] 0-255, e.g. cfg.colors.red
%
% Draws a simple filled isosceles triangle. Does NOT flip the screen --
% call Screen('Flip', win) after drawing all of a frame's content.

    cx = center_xy(1);
    cy = center_xy(2);
    h  = height_px;
    w  = width_px;

    % NOTE: PsychToolbox screen y grows DOWNWARD, so "apex at the top" means
    % the apex has the SMALLER y value (cy - h/2). An earlier version had
    % these two cases swapped, so 'up' arrows were drawn pointing down.
    if strcmpi(orientation, 'up')
        pts = [cx,       cy - h/2; ...
               cx - w/2, cy + h/2; ...
               cx + w/2, cy + h/2];
    elseif strcmpi(orientation, 'down')
        pts = [cx,       cy + h/2; ...
               cx - w/2, cy - h/2; ...
               cx + w/2, cy - h/2];
    else
        error('draw_arrow:badOrientation', 'orientation must be ''up'' or ''down''.');
    end

    Screen('FillPoly', win, color_rgb, pts, 1);
end
