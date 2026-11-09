function [label, rt_s] = run_probe1(win, cfg, winRect, frameTex, frameDestRects, ppd, probe1_order)
% RUN_PROBE1  "What were you just thinking about, right before this
% question appeared?" -- 5 options (on-task/SDT/TRI/SIT/blank-mind),
% displayed in THIS PARTICIPANT'S counterbalanced order (probe1_order,
% from build_probe1_order / schedule.probe1_order), keys 1-5 selecting
% by DISPLAY POSITION (not a fixed key-to-meaning mapping).
%
%   [label, rt_s] = run_probe1(win, cfg, winRect, frameTex, frameDestRects, probe1_order)
%
% OUTPUT
%   label - the internal code of the option chosen ('on-task','SDT',
%           'TRI','SIT', or 'blank-mind'), regardless of which key/
%           position it was displayed at for this participant
%   rt_s  - response time in seconds

    lines = {'What were you just thinking about,', ...
              'right before this question appeared?', ''};
    for i = 1:numel(probe1_order)
        lines{end+1} = sprintf('%d - %s', i, cfg.probe1_display_text(probe1_order{i})); %#ok<AGROW>
    end

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, lines);
    Screen('Flip', win);

    [key, rt_s] = collect_keypress_response(cfg.keys.probe1_keys, win);
    idx = str2double(key);
    label = probe1_order{idx};
end
