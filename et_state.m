function out = et_state(action, varargin)
% ET_STATE  Tiny shared store for the eye-tracking module (persistent
% variable), so no function signature in the experiment has to change.
%
%   S = et_state('get')              whole state struct
%   et_state('set', structOfFields)  merge fields into the state
%   et_state('reset')                back to mode 'off'
%
% Fields: mode ('off'|'dummy'|'live'), el (EyeLink defaults struct), edf_name,
% data_dir, virtual (struct: .W .H .c), geom (frame_centers/ppd of the latest
% trial), calibrated (logical), context (block/trial labels), dummy_log (path).

    persistent S
    if isempty(S)
        S = default_state();
    end

    switch action
        case 'get'
            out = S;
        case 'set'
            f = fieldnames(varargin{1});
            for i = 1:numel(f)
                S.(f{i}) = varargin{1}.(f{i});
            end
            out = S;
        case 'reset'
            S = default_state();
            out = S;
        otherwise
            error('et_state:badAction', 'action must be get, set or reset.');
    end
end


function S = default_state()
    S = struct('mode', 'off', 'el', [], 'edf_name', '', 'data_dir', '', ...
        'virtual', [], 'geom', [], 'calibrated', false, ...
        'context', struct('session', 'x', 'block', 0, 'trial', 0, 'attention', '', ...
                          'awareness', '', 'emotion', ''), ...
        'dummy_log', '');
end
