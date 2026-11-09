function probe_trials = choose_probe_trials(cfg)
% CHOOSE_PROBE_TRIALS  Pick the trial numbers (after which a thought probe
% fires) for ONE block.
%
%   probe_trials = choose_probe_trials(cfg)      % sorted row vector
%
% cfg.probes_per_block = 1 : one probe, uniform over cfg.probe_trial_range
%                            (default [15 36], as in the original design).
% cfg.probes_per_block >= 2: all probes must be at least cfg.probe_first_min
%                            into the block, consecutive probes at least
%                            cfg.probe_min_gap trials apart, and the last
%                            at or before cfg.trials_per_block. With the
%                            defaults (36 trials, 2 probes, first_min 12,
%                            gap 12) the two 12-trial pre-probe windows can
%                            never overlap. The combination is drawn
%                            uniformly from ALL valid combinations, so the
%                            positions stay unpredictable.

    k = cfg.probes_per_block;
    T = cfg.trials_per_block;

    if k == 1
        probe_trials = randi(cfg.probe_trial_range);
        return;
    end

    first_min = cfg.probe_first_min;
    gap = cfg.probe_min_gap;
    if first_min + (k - 1) * gap > T
        error('choose_probe_trials:infeasible', ...
            ['Cannot fit %d probes into %d trials with first probe >= trial %d and gap >= %d. ' ...
             'Lower cfg.probe_min_gap / cfg.probe_first_min or raise cfg.trials_per_block.'], ...
            k, T, first_min, gap);
    end

    combos = nchoosek(first_min:T, k);
    ok = all(diff(combos, 1, 2) >= gap, 2);
    combos = combos(ok, :);
    probe_trials = combos(randi(size(combos, 1)), :);
end
