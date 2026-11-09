function [response, rt_s, timed_out, response_abs_time_s, face_report] = collect_target_count_response(win, cfg, frameTex, frameDestRects, dominant_side, is_unaware, face_report)% COLLECT_TARGET_COUNT_RESPONSE  Show the response prompt and wait for a
% 1-5 keypress reporting how many targets the participant counted, with
% a max_response_time_s timeout.
%
%   [response, rt_s, timed_out, response_abs_time_s, pause_requested] = collect_target_count_response(win, cfg, frameTex, frameDestRects, dominant_side)
%
% INPUTS (new)
%   dominant_side - 'left' or 'right': which frameDestRects field to show
%                    the prompt text in. Only the dominant eye's frame
%                    gets the prompt (not duplicated in both) per request.
%
% OUTPUTS
%   response             - 1-5 (double) if a valid key was pressed, [] if timed out
%   rt_s                 - response time in seconds from prompt onset, NaN if timed out
%   timed_out             - true if no valid key was pressed within cfg.max_response_time_s
%   response_abs_time_s  - GetSecs timestamp of the keypress itself (NaN if timed out),
%                           for logging alongside the other absolute VBL timestamps
%   pause_requested       - true if the pause key was pressed at any point
%                            while waiting for the response (sticky flag;
%                            does not interrupt response collection itself)
%
% NOTE: an earlier version of this function drew the prompt text centered
% on the WHOLE window (DrawFormattedText sx='center' with no per-half
% positioning), which doesn't correctly duplicate per-eye the way every
% other screen in this codebase does -- it would have landed ambiguously
% near the boundary between the two eye regions. Fixed here to draw only
% in the dominant eye's actual frame position, matching the pattern used
% in draw_probe_screen.m.

% SAFETY EXIT: pressing Escape throws 'collect_target_count_response:userAbort'
% instead of hanging -- calling scripts should catch this with sca() (all
% the test_*_live.m scripts already do).

    KbName('UnifyKeyNames');
    validKeys = cfg.keys.target_count_keys; % {'1','2','3','4','5'}
    leftKey  = KbName(cfg.keys.face_report_keys.left);
    rightKey = KbName(cfg.keys.face_report_keys.right);
    pauseKey = KbName(cfg.keys.pause_key);
    calibKey = KbName(cfg.keys.calib_key);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
    Screen('TextSize', win, 14);

    domRect = frameDestRects.(dominant_side);
    textX = domRect(1) + 70;
    DrawFormattedText(win, 'How many targets? (1-5)', textX, 'center', [255 255 255]);
    prompt_vbl = Screen('Flip', win);
    et_msg('COUNT_PROMPT_ON vbl=%.6f', prompt_vbl);

    startTime = GetSecs;
    response = [];
    rt_s = NaN;
    timed_out = false;
    response_abs_time_s = NaN;

    while (GetSecs - startTime) < cfg.max_response_time_s
        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            idx = find(keyCode);
            names = KbName(idx);
            if ~iscell(names)
                names = {names};
            end

            if any(strcmpi(names, 'ESCAPE'))
                error('collect_target_count_response:userAbort', 'User pressed Escape -- aborting.');
            end

            % pause / recalibrate requests are only latched; the trial goes on
            if keyCode(pauseKey)
                key_flag('pause', 'set');
            end
            if keyCode(calibKey)
                key_flag('calib', 'set');
            end

                        if is_unaware && ~face_report.reported
                if keyCode(leftKey)
                    face_report = struct('reported', true, 'side', 'left', 'report_abs_time_s', secs);
                elseif keyCode(rightKey)
                    face_report = struct('reported', true, 'side', 'right', 'report_abs_time_s', secs);
                end
            end

            matched = false;
            for i = 1:numel(names)
                for j = 1:numel(validKeys)
                    if startsWith(names{i}, validKeys{j})
                        response = str2double(validKeys{j});
                        rt_s = secs - startTime;
                        response_abs_time_s = secs;
                        et_msg('COUNT_RESPONSE %d key_time=%.6f', response, secs);
                        matched = true;
                        break;
                    end
                end
                if matched, break; end
            end
            if matched
                while KbCheck; end % debounce release
                return;
            end
        end
    end

    timed_out = true; % no valid key pressed within the time limit
end
