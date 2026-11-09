function [key_pressed, rt_s] = collect_keypress_response(valid_key_names, win)
% COLLECT_KEYPRESS_RESPONSE  Wait (indefinitely, no timeout) for one of a
% specified set of keys to be pressed. Used by all the probe screens.
%
%   [key_pressed, rt_s] = collect_keypress_response(valid_key_names, win)
%
% INPUT
%   valid_key_names - cell array of key labels, e.g. {'1','2','3','4','5'}
%                      or {'LeftArrow','RightArrow'}. Matched against
%                      whatever KbName reports for the physically pressed
%                      key using STARTSWITH, not exact equality -- on
%                      some systems/keyboards, KbName reports number keys
%                      with their shifted symbol attached (e.g. '1!'
%                      instead of plain '1'). startsWith('1!','1') is
%                      true, so this matches correctly either way without
%                      needing to hardcode a system-specific key name.
%   win              - PsychToolbox window pointer. NOT currently used for
%                       drawing/flipping (see note below) -- kept as a
%                       parameter so call sites don't need to change again
%                       if it's needed later.
%
% OUTPUT
%   key_pressed - the matched label from valid_key_names (e.g. '1', not '1!')
%   rt_s        - response time in seconds from when this function was called
%
% NOTE: untimed by design -- probes should not feel rushed.
% SAFETY EXIT: pressing Escape throws 'collect_keypress_response:userAbort'.
%
% HISTORY NOTE: an earlier version of this function called
% Screen('Flip', win, [], 1) repeatedly in the wait loop, based on a
% (mistaken) guess that periodic flipping was needed for reliable input
% polling. The actual cause of that earlier "no input" symptom was the
% '1!' vs '1' key-name mismatch fixed above via startsWith -- the
% repeated flipping was unnecessary and caused visible on-screen
% flickering (likely interacting with this system's known VBL sync
% issues). Removed: this is now a plain, silent KbCheck spin, so the
% screen stays completely static while waiting.

    KbName('UnifyKeyNames');
    startTime = GetSecs;

    while KbCheck; end % release any held-over key first

    while true
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            idx = find(keyCode);
            names = KbName(idx);
            if ~iscell(names)
                names = {names};
            end

            if any(strcmpi(names, 'ESCAPE'))
                error('collect_keypress_response:userAbort', 'User pressed Escape -- aborting.');
            end

            % C during a thought probe: never interrupt the question, just
            % latch it -- the session recalibrates after the probe finishes.
            if keyCode(KbName('c'))
                key_flag('calib', 'set');
            end

            for i = 1:numel(names)
                for j = 1:numel(valid_key_names)
                    if startsWith(names{i}, valid_key_names{j})
                        key_pressed = valid_key_names{j};
                        rt_s = secs - startTime;
                        while KbCheck; end
                        return;
                    end
                end
            end
        end
    end
end
