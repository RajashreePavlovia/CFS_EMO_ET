function sides = get_eye_side_mapping(cfg, dominant_eye)
% GET_EYE_SIDE_MAPPING  Work out which screen half (left/right) is the
% dominant vs non-dominant eye's region for this participant, so the
% mask (shown to dominant eye) and face (shown to non-dominant eye) land
% on the correct physical side of the display.
%
%   sides = get_eye_side_mapping(cfg, dominant_eye)
%
% INPUT
%   cfg          - struct from config_experiment()
%   dominant_eye - 'left' or 'right' (this participant's dominant eye,
%                  from your separate eye-dominance test)
%
% OUTPUT
%   sides - struct with fields:
%       .dominant_screen_half     ('left' or 'right') -- gets the mask
%       .nondominant_screen_half  ('left' or 'right') -- gets the face
%
% Uses cfg.stereoscope_crossed to decide whether left-half-of-screen maps
% to the left eye (uncrossed, default) or the right eye (crossed mirror
% arrangement). If testing shows stimuli landing in the wrong eye, flip
% cfg.stereoscope_crossed rather than editing this function.

    if ~ismember(lower(dominant_eye), {'left','right'})
        error('get_eye_side_mapping:badEye', 'dominant_eye must be ''left'' or ''right''.');
    end
    dominant_eye = lower(dominant_eye);

    if ~cfg.stereoscope_crossed
        % uncrossed: left eye <-> left screen half, right eye <-> right screen half
        eye_to_half = struct('left','left','right','right');
    else
        % crossed: left eye <-> right screen half, right eye <-> left screen half
        eye_to_half = struct('left','right','right','left');
    end

    sides = struct();
    sides.dominant_screen_half = eye_to_half.(dominant_eye);
    if strcmp(sides.dominant_screen_half, 'left')
        sides.nondominant_screen_half = 'right';
    else
        sides.nondominant_screen_half = 'left';
    end
end
