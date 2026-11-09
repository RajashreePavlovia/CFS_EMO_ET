function seq = generate_rsvp_trial(cfg, load, n_targets)
% GENERATE_RSVP_TRIAL  Build one trial's RSVP arrow sequence.
%
%   seq = generate_rsvp_trial(cfg, load, n_targets)
%
% INPUTS
%   cfg        - struct from config_experiment()
%   load       - 'low' or 'high'
%   n_targets  - number of targets required in this trial (int)
%
% OUTPUT
%   seq        - 1xN struct array: .is_target, .color, .orientation
%
% RULES ENFORCED (all HARD constraints, no exceptions):
%   - each target separated from the next by 1-2 non-targets
%   - no more than 2 consecutive non-targets anywhere in the sequence
%   - a small number (0-2) of non-targets may appear before the first
%     target and after the last target
%   - no two consecutive items share the same color
%   - no more than 3 consecutive items share the same orientation
%
% METHOD: the target/non-target POSITION pattern is built first (as
% before). Colors and orientations are then assigned via backtracking
% search: at each position, candidates are tried in random order; if a
% choice leads to a dead end further down the sequence, the search
% backtracks and tries a different earlier choice instead. This is what
% actually guarantees both hard constraints hold -- an earlier version of
% this function used a greedy single-step-lookahead with a "relax the
% rule if stuck" fallback, which could not actually guarantee the
% max-3-consecutive-orientation rule (relaxing it even once let the run
% length grow past 3, sometimes repeatedly). If no valid assignment
% exists at all for a given position pattern (should be rare given the
% size of the color/orientation pools), this errors clearly rather than
% silently violating a constraint.

    type_seq = build_type_sequence(n_targets);
    N = numel(type_seq);

    if strcmpi(load, 'low')
        target_defs    = cfg.low_load.targets;
        nontarget_defs = cfg.low_load.nontargets;
    elseif strcmpi(load, 'high')
        target_defs    = cfg.high_load.targets;
        nontarget_defs = cfg.high_load.nontargets;
    else
        error('generate_rsvp_trial:badLoad', 'load must be ''low'' or ''high''.');
    end

    target_candidates    = flatten_defs(target_defs);
    nontarget_candidates = flatten_defs(nontarget_defs);

    pools = cell(1, N);
    for i = 1:N
        if type_seq(i)
            pools{i} = target_candidates;
        else
            pools{i} = nontarget_candidates;
        end
    end

    assignment = backtrack_assign(pools, 1, {}, struct('prev_color','', 'prev_orientation','', 'orientation_run_len',0));
    if isempty(assignment)
        error('generate_rsvp_trial:infeasible', ...
            'Could not find any color/orientation assignment satisfying both constraints for this trial''s target pattern.');
    end

    seq = struct('is_target', {}, 'color', {}, 'orientation', {});
    for i = 1:N
        seq(i) = struct('is_target', type_seq(i), 'color', assignment{i}{1}, 'orientation', assignment{i}{2});
    end
end


function type_seq = build_type_sequence(n_targets)
% Build the target/non-target position pattern: 0-2 leading non-targets,
% targets separated by 1-2 non-targets, 0-2 trailing non-targets.
    type_seq = [];
    n_lead = randi([0 2]);
    type_seq = [type_seq, false(1, n_lead)];

    for t = 1:n_targets
        type_seq(end+1) = true; %#ok<AGROW>
        if t < n_targets
            gap = randi([1 2]);
            type_seq = [type_seq, false(1, gap)]; %#ok<AGROW>
        end
    end

    n_trail = randi([0 2]);
    type_seq = [type_seq, false(1, n_trail)];
end


function candidates = flatten_defs(defs)
% Flatten a defs struct array (.color, .orientations cell array) into a
% flat cell array of {color, orientation} pairs.
    candidates = {};
    for d = defs
        for o = d.orientations
            candidates{end+1} = {d.color, o{1}}; %#ok<AGROW>
        end
    end
end


function chosen = backtrack_assign(pools, i, chosen_so_far, state)
% Recursive backtracking search. Returns a cell array of {color,
% orientation} pairs (one per position) if a valid full assignment is
% found from position i onward, or {} if this branch is a dead end.
    N = numel(pools);
    if i > N
        chosen = chosen_so_far;
        return;
    end

    candidates = pools{i};
    order = randperm(numel(candidates)); % randomize search order so results aren't deterministic
    for k = order
        c = candidates{k};

        if ~isempty(state.prev_color) && strcmp(c{1}, state.prev_color)
            continue; % hard color constraint violated
        end

        if ~isempty(state.prev_orientation) && strcmp(c{2}, state.prev_orientation)
            new_run_len = state.orientation_run_len + 1;
            if new_run_len > 3
                continue; % hard orientation-run constraint violated
            end
        else
            new_run_len = 1;
        end

        new_state = struct('prev_color', c{1}, 'prev_orientation', c{2}, 'orientation_run_len', new_run_len);
        result = backtrack_assign(pools, i+1, [chosen_so_far, {c}], new_state);
        if ~isempty(result)
            chosen = result;
            return;
        end
    end

    chosen = {}; % no candidate at this position leads to a full valid sequence -- caller will backtrack
end
