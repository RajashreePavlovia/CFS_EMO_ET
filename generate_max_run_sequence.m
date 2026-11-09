function seq = generate_max_run_sequence(labels, n, max_run)
% GENERATE_MAX_RUN_SEQUENCE  Generate a random sequence over a small set
% of labels such that no label repeats more than max_run times in a row.
% Used here for face-side assignment (left/right, max 3 consecutive) but
% written generically.
%
%   seq = generate_max_run_sequence(labels, n, max_run)
%
% INPUTS
%   labels   - cell array of possible labels, e.g. {'left','right'}
%   n        - number of trials/slots to generate
%   max_run  - maximum allowed consecutive repeats of the same label
%
% OUTPUT
%   seq      - 1xn cell array of labels, no run longer than max_run
%
% METHOD: at each step, if the current run has already reached max_run,
% force a switch to a different label (chosen randomly among the
% others); otherwise pick freely at random from all labels. This
% guarantees the constraint holds by construction (no rejection
% sampling needed).

    seq = cell(1, n);
    run_label = '';
    run_len = 0;

    for i = 1:n
        if run_len >= max_run
            others = labels(~strcmp(labels, run_label));
            pick = others{randi(numel(others))};
        else
            pick = labels{randi(numel(labels))};
        end

        if strcmp(pick, run_label)
            run_len = run_len + 1;
        else
            run_label = pick;
            run_len = 1;
        end
        seq{i} = pick;
    end
end
