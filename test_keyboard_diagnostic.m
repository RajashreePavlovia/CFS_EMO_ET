function test_keyboard_diagnostic()
% TEST_KEYBOARD_DIAGNOSTIC  Prints exactly what MATLAB/PsychToolbox sees
% for each key you press. No Screen/window needed -- run this directly
% in the MATLAB command window.
%
% HOW TO RUN:
%   test_keyboard_diagnostic
%
% Then press: 1, 2, 3, 4, 5 (top row, NOT numpad if your laptop has one),
% then try Escape to quit. For each keypress, it prints the exact KbName
% string(s) MATLAB detected. Paste the FULL output back -- this will tell
% us exactly what key names to use in cfg.keys, since the current code
% assumes plain '1'-'5' and that assumption may be wrong for your
% keyboard/layout.

    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');

    fprintf('Press keys now (try 1,2,3,4,5, then Escape to quit)...\n');

    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            idx = find(keyCode);
            names = KbName(idx);
            if ~iscell(names)
                names = {names};
            end
            fprintf('Detected key(s): %s\n', strjoin(names, ', '));

            if any(idx == escKey)
                fprintf('Escape detected -- quitting.\n');
                break;
            end
            while KbCheck; end % wait for release before checking again
        end
    end
end
