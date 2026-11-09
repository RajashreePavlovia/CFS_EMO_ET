function tf = key_flag(name, action)
% KEY_FLAG  Tiny shared "a key was pressed somewhere" flag, so any polling
% loop (RSVP stream, response window, face report, ITI, probe screens) can
% latch a request without its function signature changing, and the session
% script can act on it at the next safe point.
%
%   key_flag('calib', 'set')     latch "C was pressed"
%   tf = key_flag('calib', 'get')  true if latched
%   key_flag('calib', 'clear')   un-latch
%
% name: 'calib' (recalibration requested) or 'pause' (pause requested).
% Stored with setappdata(0, ...), so it survives across function calls but
% not across MATLAB restarts.

    field = ['cfs_flag_' name];
    switch action
        case 'set'
            setappdata(0, field, true);
            tf = true;
        case 'clear'
            setappdata(0, field, false);
            tf = false;
        case 'get'
            tf = isappdata(0, field) && logical(getappdata(0, field));
        otherwise
            error('key_flag:badAction', 'action must be set, get or clear.');
    end
end
