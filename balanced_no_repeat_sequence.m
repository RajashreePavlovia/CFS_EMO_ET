function seq = balanced_no_repeat_sequence(values, n_trials)
% BALANCED_NO_REPEAT_SEQUENCE  Distribute n_trials slots across the given
% values as evenly as possible, with no identical value on two
% consecutive trials.
%
%   seq = balanced_no_repeat_sequence(values, n_trials)
%
% INPUTS
%   values    - vector or cell array of distinct values to balance across
%               (e.g. [2 3 4 5] for low-load target counts)
%   n_trials  - total number of slots to fill (e.g. 36)
%
% OUTPUT
%   seq       - 1 x n_trials vector/cell array, each value appearing as
%               close to n_trials/numel(values) times as possible, with
%               no two consecutive entries equal.
%
% METHOD: greedy max-heap-style ("reorganize string") construction, which
% succeeds whenever a valid no-adjacent-repeat arrangement exists (i.e.
% whenever no single value needs to occupy more than ceil(n_trials/2)
% slots), then randomizes the specific order via random tie-breaking.
% This is deterministic-safe (unlike shuffle-and-reject), so it will not
% silently loop forever or fail on an otherwise-solvable input.

    is_cell = iscell(values);
    n_vals = numel(values);

    base = floor(n_trials / n_vals);
    rem  = mod(n_trials, n_vals);
    reps = base + (1:n_vals <= rem); % first `rem` values get one extra

    if max(reps) > ceil(n_trials / 2)
        error('balanced_no_repeat_sequence:infeasible', ...
            'No valid no-adjacent-repeat arrangement exists for this split.');
    end

    % counts(i) = remaining instances of values(i) left to place
    counts = reps;
    seq = cell(1, n_trials);
    prev_idx = -1;

    for slot = 1:n_trials
        % candidate indices: those with remaining count > 0 and != prev
        cand = find(counts > 0);
        cand(cand == prev_idx) = [];

        if isempty(cand)
            % Only the same value as prev remains -- should not happen if
            % the feasibility check above passed, but guard anyway.
            error('balanced_no_repeat_sequence:stuck', ...
                'Ran out of valid options; check input frequencies.');
        end

        % among candidates, prefer the one(s) with the highest remaining
        % count (keeps the arrangement balanced), break ties randomly
        max_count = max(counts(cand));
        best = cand(counts(cand) == max_count);
        pick = best(randi(numel(best)));

        seq{slot} = values_get(values, pick, is_cell);
        counts(pick) = counts(pick) - 1;
        prev_idx = pick;
    end

    if ~is_cell
        seq = cell2mat(seq);
    end
end


function v = values_get(values, idx, is_cell)
    if is_cell
        v = values{idx};
    else
        v = values(idx);
    end
end
