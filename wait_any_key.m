function wait_any_key()
% WAIT_ANY_KEY  Block until any key is pressed (used for "press any key
% to continue" screens between blocks). Escape still aborts cleanly.
    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');
    while KbCheck; end
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('wait_any_key:userAbort', 'User pressed Escape -- aborting.');
            end
            while KbCheck; end
            return;
        end
    end
end
