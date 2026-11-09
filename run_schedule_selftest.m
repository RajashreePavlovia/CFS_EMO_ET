function run_schedule_selftest()
% RUN_SCHEDULE_SELFTEST  Sanity-check the block/trial generation logic
% with no PsychToolbox / screen dependency at all -- just run this in
% plain MATLAB to verify the design constraints hold before wiring up any
% display code.

    cfg = config_experiment();

    fprintf('Running schedule self-test for a dummy participant...\n');
    sched = generate_block_schedule(cfg, 1, 42);

    assert(numel(sched.blocks) == 24, 'Expected 24 blocks, got %d', numel(sched.blocks));

    % --- 12 identities, 6 male / 6 female
    genders = {cfg.face_identities.gender};
    assert(sum(strcmp(genders,'F')) == 6 && sum(strcmp(genders,'M')) == 6, ...
        'Expected 6 female + 6 male identities.');

    % --- sample filename check (angry female id 03)
    [~, fname] = get_face_filename(cfg, '03', 'F', 'angry');
    assert(strcmp(fname, 'AF03ANS_processed.png'), ...
        'Filename pattern check failed, got %s', fname);

    % --- condition coverage: each of the 12 (attn,aware,emotion) combos exactly twice
    combo_keys = cell(1, 24);
    for b = 1:24
        blk = sched.blocks(b);
        combo_keys{b} = sprintf('%s|%s|%s', blk.attention, blk.awareness, blk.emotion);
    end
    [u, ~, ic] = unique(combo_keys);
    counts = accumarray(ic, 1);
    assert(numel(u) == 12, 'Expected 12 distinct conditions, got %d', numel(u));
    assert(all(counts == 2), 'Every condition should appear exactly twice.');

    % --- no two consecutive blocks share the same condition
    for b = 1:23
        assert(~strcmp(combo_keys{b}, combo_keys{b+1}), ...
            'Blocks %d and %d have identical condition.', b, b+1);
    end

    for b = 1:24
        blk = sched.blocks(b);

        % --- probe trial(s): right count, sorted, in range, far enough apart
        pt = blk.probe_trials;
        assert(numel(pt) == cfg.probes_per_block, ...
            'Block %d has %d probes, expected %d.', b, numel(pt), cfg.probes_per_block);
        assert(all(pt >= 1) && all(pt <= cfg.trials_per_block), ...
            'Block %d probe trial outside the block.', b);
        if cfg.probes_per_block == 1
            assert(pt >= cfg.probe_trial_range(1) && pt <= cfg.probe_trial_range(2), ...
                'Block %d probe_trial out of range.', b);
        else
            assert(pt(1) >= cfg.probe_first_min, ...
                'Block %d first probe (%d) earlier than probe_first_min.', b, pt(1));
            assert(all(diff(pt) >= cfg.probe_min_gap), ...
                'Block %d probes closer than probe_min_gap: %s', b, mat2str(pt));
        end

        assert(numel(blk.trials) == cfg.trials_per_block, ...
            'Block %d does not have %d trials.', b, cfg.trials_per_block);

        if strcmpi(blk.attention, 'low')
            valid_counts = cfg.low_load_target_counts;
        else
            valid_counts = cfg.high_load_target_counts;
        end

        prev_count = NaN;
        for t = 1:numel(blk.trials)
            trial = blk.trials(t);

            % target count in valid range and matches actual sequence
            assert(any(trial.n_targets == valid_counts), ...
                'Block %d trial %d: n_targets %d not valid for %s load.', ...
                b, t, trial.n_targets, blk.attention);
            n_actual = sum([trial.arrow_seq.is_target]);
            assert(n_actual == trial.n_targets, ...
                'Block %d trial %d: sequence has %d targets, expected %d.', ...
                b, t, n_actual, trial.n_targets);

            % target identity rules: high load = yellow-UP and green-DOWN only;
            % low load = red (either orientation). Everything else is a non-target.
            for i = 1:numel(trial.arrow_seq)
                it = trial.arrow_seq(i);
                if strcmpi(blk.attention, 'high')
                    should_be_target = (strcmp(it.color,'yellow') && strcmp(it.orientation,'up')) || ...
                                       (strcmp(it.color,'green')  && strcmp(it.orientation,'down'));
                else
                    should_be_target = strcmp(it.color,'red');
                end
                assert(logical(it.is_target) == should_be_target, ...
                    'Block %d trial %d item %d: %s-%s has is_target=%d but rules say %d.', ...
                    b, t, i, it.color, it.orientation, it.is_target, should_be_target);
            end

            % no adjacent-trial repeat of target count
            assert(trial.n_targets ~= prev_count, ...
                'Block %d trial %d: target count repeats previous trial.', b, t);
            prev_count = trial.n_targets;

            % face side must be 'left' or 'right'
            assert(any(strcmp(trial.face_side, {'left','right'})), ...
                'Block %d trial %d: invalid face_side %s.', b, t, trial.face_side);

            % face emotion must match this block's emotion condition
            assert(strcmp(trial.face_emotion, blk.emotion), ...
                'Block %d trial %d: face_emotion (%s) does not match block emotion (%s).', ...
                b, t, trial.face_emotion, blk.emotion);

            % no more than 2 consecutive non-targets within the sequence
            run = 0;
            for i = 1:numel(trial.arrow_seq)
                if ~trial.arrow_seq(i).is_target
                    run = run + 1;
                    assert(run <= 2, ...
                        'Block %d trial %d: >2 consecutive non-targets.', b, t);
                else
                    run = 0;
                end
            end

            % no two consecutive items share the same color
            colors = {trial.arrow_seq.color};
            for i = 2:numel(colors)
                assert(~strcmp(colors{i}, colors{i-1}), ...
                    'Block %d trial %d: consecutive repeated color at item %d.', b, t, i);
            end

            % no more than 3 consecutive items share the same orientation
            orients = {trial.arrow_seq.orientation};
            orun = 1;
            for i = 2:numel(orients)
                if strcmp(orients{i}, orients{i-1})
                    orun = orun + 1;
                    assert(orun <= 3, ...
                        'Block %d trial %d: >3 consecutive same orientation at item %d.', b, t, i);
                else
                    orun = 1;
                end
            end

            % mask sequence present only for unaware blocks, and no immediate repeats
            if strcmpi(blk.awareness, 'unaware')
                assert(~isempty(trial.mask_ids), ...
                    'Block %d trial %d: unaware block missing mask_ids.', b, t);
                m = trial.mask_ids;
                for i = 1:numel(m)-1
                    assert(m(i) ~= m(i+1), ...
                        'Block %d trial %d: consecutive repeated mask id.', b, t);
                end
            else
                assert(isempty(trial.mask_ids), ...
                    'Block %d trial %d: aware block should have empty mask_ids.', b, t);
            end
        end

        % --- face-side max-run-3 check across this block's 36 trials
        sides = {blk.trials.face_side};
        run = 1;
        for t = 2:numel(sides)
            if strcmp(sides{t}, sides{t-1})
                run = run + 1;
                assert(run <= 3, 'Block %d: face_side runs >3 consecutive at trial %d.', b, t);
            else
                run = 1;
            end
        end

        % --- exactly cfg.n_catch_trials_per_block catch trials per block
        n_catch = sum([blk.trials.is_catch]);
        assert(n_catch == cfg.n_catch_trials_per_block, ...
            'Block %d: expected %d catch trials, got %d.', b, cfg.n_catch_trials_per_block, n_catch);
    end

    fprintf('All self-tests passed: 24 blocks, 12 conditions x2, ');
    fprintf('36 trials/block, target-count + mask constraints all hold.\n');
end