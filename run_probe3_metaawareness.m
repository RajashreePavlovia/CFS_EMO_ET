function [answer, rt_s] = run_probe3_metaawareness(win, cfg, winRect, frameTex, frameDestRects, ppd)
% RUN_PROBE3_METAAWARENESS  "Were you aware of having the thought before
% the thought probe appeared?" Left arrow = yes, Right arrow = no
% (as specified).
%
%   [answer, rt_s] = run_probe3_metaawareness(win, cfg, winRect, frameTex, frameDestRects)
%
% OUTPUT
%   answer - 'yes' or 'no'
%   rt_s   - response time in seconds

    lines = {'Were you aware of having the thought', ...
              'before the thought probe appeared?', '', ...
              sprintf('%s = Yes        %s = No', cfg.keys.yesno_keys.yes, cfg.keys.yesno_keys.no)};

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);

    [key, rt_s] = collect_keypress_response({cfg.keys.yesno_keys.yes, cfg.keys.yesno_keys.no}, win);
    if strcmp(key, cfg.keys.yesno_keys.yes)
        answer = 'yes';
    else
        answer = 'no';
    end
end
