 function probe_result = run_probe_sequence(win, cfg, winRect, frameTex, frameDestRects, ppd, probe1_order)
% RUN_PROBE_SEQUENCE  Run the full spontaneous-thought probe sequence for
% one probe event, implementing the branching logic:
%
%   Probe 1 (always) -> if SDT: Probe 2
%                     -> if NOT on-task (i.e. SDT/TRI/SIT/blank-mind):
%                          Probe 3 (meta-awareness), Probe 4 (vividness),
%                          Probe temporality, Probe current-concerns
%
%   probe_result = run_probe_sequence(win, cfg, winRect, frameTex, frameDestRects, ppd, probe1_order)
%
% INPUTS
%   win, cfg, winRect, frameTex, ppd - as elsewhere
%   probe1_order                - this participant's counterbalanced
%                                  Probe-1 option order (schedule.probe1_order)
%
% OUTPUT
%   probe_result - struct with all fields below. Fields for probes that
%   were skipped by the branching logic are left as [] (label fields) or
%   NaN (numeric rating fields), NOT zero, so a CSV/analysis script can
%   distinguish "skipped" from "answered 0".
%
%       .probe1_label, .probe1_rt_s
%       .probe2_label, .probe2_rt_s              ([] / NaN if not SDT)
%       .metaawareness, .metaawareness_rt_s       ([] / NaN if on-task)
%       .vividness, .vividness_rt_s               ([] / NaN if on-task)
%       .emotionality, .emotionality_rt_s         ('positive'/'negative'/'neutral'; [] / NaN if on-task)
%       .temporality, .temporality_rt_s           ([] / NaN if on-task)
%       .current_concerns, .current_concerns_rt_s ([] / NaN if on-task)

    probe_result = struct();

    [probe_result.probe1_label, probe_result.probe1_rt_s] = ...
        run_probe1(win, cfg, winRect, frameTex, frameDestRects, ppd, probe1_order);

    % --- Probe 2: only if the thought was stimulus-dependent ---
    if strcmp(probe_result.probe1_label, 'SDT')
        [probe_result.probe2_label, probe_result.probe2_rt_s] = run_probe2(win, cfg, winRect, frameTex, frameDestRects, ppd);
    else
        probe_result.probe2_label = [];
        probe_result.probe2_rt_s = NaN;
    end

    % --- Probes 3-5 ---
    % on-task    : none of them
    % blank-mind : meta-awareness only
    % SDT/TRI/SIT: all four
    label = probe_result.probe1_label;

    % defaults (skipped = [] / NaN, not 0)
    probe_result.metaawareness = [];       probe_result.metaawareness_rt_s = NaN;
    probe_result.emotionality = [];        probe_result.emotionality_rt_s = NaN;
    probe_result.vividness = [];           probe_result.vividness_rt_s = NaN;
    probe_result.temporality = [];         probe_result.temporality_rt_s = NaN;
    probe_result.current_concerns = [];    probe_result.current_concerns_rt_s = NaN;

    % follow-ups: on-task = none; blank-mind = meta-awareness only;
    % SDT/TRI/SIT = meta, vividness, emotionality, concerns in random order,
    % then temporality last (fixed position)
    if strcmp(label, 'on-task')
        queue = {};
    elseif strcmp(label, 'blank-mind')
        queue = {'meta'};
    else
        queue = {'meta','vivid','emotion','temporal','concerns'};
        queue = queue(randperm(numel(queue)));
    end

    for qi = 1:numel(queue)
        switch queue{qi}
            case 'meta'
                [probe_result.metaawareness, probe_result.metaawareness_rt_s] = ...
                    run_probe3_metaawareness(win, cfg, winRect, frameTex, frameDestRects, ppd);
            case 'vivid'
                [probe_result.vividness, probe_result.vividness_rt_s] = ...
                    run_scale_probe(win, cfg, winRect, frameTex, frameDestRects, ppd, 'How vivid was the thought?');
            case 'emotion'
                [probe_result.emotionality, probe_result.emotionality_rt_s] = ...
                    run_probe_emotionality(win, cfg, winRect, frameTex, frameDestRects, ppd);
            case 'temporal'
                [probe_result.temporality, probe_result.temporality_rt_s] = ...
                    run_probe_temporality(win, cfg, winRect, frameTex, frameDestRects, ppd);
            case 'concerns'
                [probe_result.current_concerns, probe_result.current_concerns_rt_s] = ...
                    run_scale_probe(win, cfg, winRect, frameTex, frameDestRects, ppd, ...
                    sprintf('Rate the extent to which your thought was relevant\nto your everyday goals, concerns and worries.'));
        end
    end
