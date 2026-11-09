function [report, secs, rt_s] = ask_face_side(win, cfg, frameTex, winRect, frameDestRects, ppd)
% ASK_FACE_SIDE  Forced face-location report after the count response.
%
%   [report, secs, rt_s] = ask_face_side(win, cfg, frameTex, winRect, frameDestRects, ppd)
%
% Shows "Where was the face?" in the dominant-eye frame and waits for:
%     face_report_keys.left  -> report = 'left'
%     face_report_keys.right -> report = 'right'
%     cfg.keys.quest_none_key -> report = 'none'   (did not see a face)
%
% OUTPUTS
%   report - 'left' | 'right' | 'none'
%   secs   - GetSecs timestamp of the key press
%   rt_s   - reaction time from the onset (Flip) of the report screen
%
% winRect is not used (kept so the call matches draw_probe_screen); pass [].
% Escape aborts.

    KbName('UnifyKeyNames');
    escKey   = KbName('ESCAPE');
    leftKey  = KbName(cfg.keys.face_report_keys.left);
    rightKey = KbName(cfg.keys.face_report_keys.right);
    noneKey  = KbName(cfg.keys.quest_none_key);
    pauseKey = KbName(cfg.keys.pause_key);
    calibKey = KbName(cfg.keys.calib_key);

    lines = {'Where was the face?', '', ...
        sprintf('%s = LEFT', key_label(cfg.keys.face_report_keys.left)), ...
        sprintf('%s = RIGHT', key_label(cfg.keys.face_report_keys.right)), ...
        sprintf('%s = did NOT see a face', key_label(cfg.keys.quest_none_key))};
    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    onset = Screen('Flip', win);
    et_msg('FACE_QUESTION_ON vbl=%.6f', onset);

    while KbCheck; end   % wait until any held key is released
    while true
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('ask_face_side:userAbort', 'User pressed Escape -- aborting.');
            end
            % pause / recalibrate requests are only latched (acted on after the trial)
            if keyCode(pauseKey)
                key_flag('pause', 'set');
            end
            if keyCode(calibKey)
                key_flag('calib', 'set');
            end
            if keyCode(leftKey)
                report = 'left';
                break;
            elseif keyCode(rightKey)
                report = 'right';
                break;
            elseif keyCode(noneKey)
                report = 'none';
                break;
            end
        end
        WaitSecs(0.001);
    end
    rt_s = secs - onset;
    et_msg('FACE_RESPONSE %s key_time=%.6f', report, secs);
    while KbCheck; end
end


function s = key_label(k)
% 'z' -> 'Z', 'LeftArrow' -> 'Left Arrow'
    if isnumeric(k)
        k = KbName(k);
    end
    if iscell(k)
        k = k{1};
    end
    if numel(k) == 1
        s = upper(k);
    else
        s = regexprep(k, '([a-z])([A-Z])', '$1 $2');
    end
end
