function [answer, rt_s] = run_probe_emotionality(win, cfg, winRect, frameTex, frameDestRects, ppd)
% RUN_PROBE_EMOTIONALITY  "Was the thought: (1) positive, (2) negative,
% or (3) neutral?" Number keys 1-3. Asked after vividness, before temporality.
%
%   [answer, rt_s] = run_probe_emotionality(win, cfg, winRect, frameTex, frameDestRects, ppd)
%
% OUTPUT
%   answer - 'positive', 'negative', or 'neutral'
%   rt_s   - response time in seconds

    options = {'positive','negative','neutral'};
    options = options(randperm(numel(options)));   % new random order every time

    display_text = struct('positive','Positive', 'negative','Negative', 'neutral','Neutral');

    lines = {'How emotional was the thought?', ''};
    for i = 1:numel(options)
        lines{end+1} = sprintf('%d - %s', i, display_text.(options{i})); %#ok<AGROW>
    end

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);

    [key, rt_s] = collect_keypress_response({'1','2','3'}, win);
    idx = str2double(key);
    answer = options{idx};
end
