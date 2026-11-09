function ppd = compute_ppd(screen_width_px, screen_width_cm, viewing_distance_cm)
% COMPUTE_PPD  Convert screen geometry into pixels-per-degree of visual
% angle, for converting all the cfg.*_deg sizes into pixels at runtime.
%
%   ppd = compute_ppd(screen_width_px, screen_width_cm, viewing_distance_cm)
%
% INPUTS
%   screen_width_px    - horizontal resolution in pixels (e.g. from
%                         Screen('Rect', windowPtr))
%   screen_width_cm    - physical ACTIVE display width in cm (measured,
%                         not the diagonal spec -- bezels and aspect
%                         ratio make diagonal-based estimates unreliable)
%   viewing_distance_cm- eye-to-screen distance in cm
%
% OUTPUT
%   ppd - pixels per degree of visual angle (small-angle approximation,
%         accurate for the sizes used in this experiment, all well under
%         15 degrees)
%
% Formula: 1 degree of visual angle subtends
%   S = viewing_distance_cm * tan(pi/180) cm of physical screen space
% so pixels-per-degree = (pixels per cm) * that S.

    if isnan(screen_width_cm)
        error('compute_ppd:missingMeasurement', ...
            ['screen_width_cm is NaN -- measure your display''s active width ' ...
             'and set cfg.screen_width_cm in config_experiment.m before running.']);
    end

    pixels_per_cm = screen_width_px / screen_width_cm;
    ppd = pixels_per_cm * viewing_distance_cm * tan(pi/180);
end
