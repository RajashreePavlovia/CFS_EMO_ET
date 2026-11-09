function [answer, rt_s] = run_probe_temporality(win, cfg, winRect, frameTex, frameDestRects, ppd)
% RUN_PROBE_TEMPORALITY  "Was the thought about (a) the present, (b) the
% past, (c) the future or (d) atemporal?" Number keys 1-4.
%
%   [answer, rt_s] = run_probe_temporality(win, cfg, winRect, frameTex, frameDestRects)
%
% OUTPUT
%   answer - 'present', 'past', 'future', or 'atemporal'
%   rt_s   - response time in seconds

    options = {'present','past','future','atemporal'};
    lines = {'Was the thought about:', '', ...
              '1 - The present', '2 - The past', '3 - The future', '4 - Atemporal (no specific time)'};

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);

    [key, rt_s] = collect_keypress_response({'1','2','3','4'}, win);
    idx = str2double(key);
    answer = options{idx};
end
