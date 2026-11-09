function is_pressed = check_pause_key(cfg)
% CHECK_PAUSE_KEY  Non-blocking, single-shot check for whether the pause
% key (cfg.keys.pause_key) is currently down. Call this between trials
% (not mid-stream) to offer a pause opportunity without disrupting
% frame-precise RSVP timing -- checking WITHIN the RSVP stream itself
% would risk stealing time from the tight per-frame draw budget.
%
%   is_pressed = check_pause_key(cfg)

    KbName('UnifyKeyNames');
    pauseKey = KbName(cfg.keys.pause_key);
    [keyIsDown, ~, keyCode] = KbCheck;
    is_pressed = keyIsDown && keyCode(pauseKey);
end
