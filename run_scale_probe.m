function [rating, rt_s] = run_scale_probe(win, cfg, winRect, frameTex, frameDestRects, ppd, question_text)
% RUN_SCALE_PROBE  Generic 1-7 rating scale probe (used for both the
% vividness index and the current-concerns index -- same response format,
% different question text).
%
%   [rating, rt_s] = run_scale_probe(win, cfg, winRect, frameTex, frameDestRects, question_text)
%
% INPUT
%   question_text - the question to display (a single string; pass
%                    multiple lines pre-joined with \n if needed)
%
% OUTPUT
%   rating - integer 1-7
%   rt_s   - response time in seconds

    lines = {question_text, '', '1 = low/not at all ... 7 = high/very much'};

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);

    [key, rt_s] = collect_keypress_response(cfg.keys.scale_keys, win);
    rating = str2double(key);
end
