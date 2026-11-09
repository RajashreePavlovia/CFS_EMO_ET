function schedule = generate_block_schedule(cfg, participant_id, rng_seed)
% GENERATE_BLOCK_SCHEDULE  Build the full 24-block trial schedule for one
% participant: condition order, per-block probe position, per-trial arrow
% sequences, target counts, and (placeholder) face/mask assignments.
%
%   schedule = generate_block_schedule(cfg, participant_id, rng_seed)
%
% INPUTS
%   cfg            - struct from config_experiment()
%   participant_id - positive integer, used to counterbalance probe-1
%                    option order across participants
%   rng_seed       - (optional) seed for reproducibility; if omitted, a
%                    seed is generated and stored in the schedule so the
%                    exact session can be regenerated later if needed
%
% OUTPUT
%   schedule - struct with fields:
%     .participant_id
%     .rng_seed
%     .probe1_order        - this participant's Probe-1 option order
%     .blocks(1:24)         - struct array, each with:
%         .attention        ('low'/'high')
%         .awareness        ('aware'/'unaware')
%         .emotion          ('happy'/'angry'/'neutral')
%         .probe_trials     - row vector: trial number(s) after which a probe fires
%                             (cfg.probes_per_block of them, sorted)
%         .probe_trial      - the first of those (kept for older scripts)
%         .trials(1:36)     - struct array, each with:
%             .n_targets
%             .arrow_seq    - output of generate_rsvp_trial
%             .face_identity_id
%             .face_gender
%             .mask_ids     - [] if aware block, else vector from generate_mask_sequence
%                             (length depends on this trial's total RSVP
%                              duration -- see notes below)
%
% IMPORTANT OPEN ITEM (flagged, not silently assumed):
%   Face-identity assignment WITHIN a block: the methodology specifies
%   identities must not be systematically tied to any one condition, but
%   does not specify whether the identity should change every trial or
%   stay fixed for a whole block. This function currently picks a fresh
%   identity per TRIAL (with no immediate repeat within a block).
%   Confirm this is the intended design before running real participants.

    if nargin < 3 || isempty(rng_seed)
        rng_seed = randi(2^31 - 1);
    end
    rng(rng_seed);

    %% Build the 12 conditions and order 24 blocks (2 reps each, no immediate repeat)
    conditions = struct('attention',{},'awareness',{},'emotion',{});
    for a = 1:numel(cfg.attention_levels)
        for w = 1:numel(cfg.awareness_levels)
            for e = 1:numel(cfg.emotion_levels)
                conditions(end+1) = struct( ...
                    'attention', cfg.attention_levels{a}, ...
                    'awareness', cfg.awareness_levels{w}, ...
                    'emotion',   cfg.emotion_levels{e}); %#ok<AGROW>
            end
        end
    end
    n_conditions = numel(conditions); % should be 12

    cond_idx_order = balanced_no_repeat_sequence(1:n_conditions, ...
        n_conditions * cfg.reps_per_condition); % 24 entries, each 1-12, no adjacent repeat

    schedule = struct();
    schedule.participant_id = participant_id;
    schedule.rng_seed = rng_seed;
    schedule.probe1_order = build_probe1_order(cfg, participant_id);
    schedule.blocks = struct([]);

    n_blocks = numel(cond_idx_order);
    for b = 1:n_blocks
        cond = conditions(cond_idx_order(b));

        block = struct();
        block.attention = cond.attention;
        block.awareness = cond.awareness;
        block.emotion   = cond.emotion;
        % trial number(s) after which a thought probe fires (1 or more per
        % block, see cfg.probes_per_block and choose_probe_trials.m)
        block.probe_trials = choose_probe_trials(cfg);
        block.probe_trial  = block.probe_trials(1);   % kept for older scripts: the FIRST probe

        % target-count list for this block's 36 trials, balanced + no adjacent repeat
        if strcmpi(cond.attention, 'low')
            counts_pool = cfg.low_load_target_counts;
        else
            counts_pool = cfg.high_load_target_counts;
        end
        target_counts = balanced_no_repeat_sequence(counts_pool, cfg.trials_per_block);

        % face left/right side per trial: random, max 3 consecutive same side
        face_sides = generate_max_run_sequence({'left','right'}, cfg.trials_per_block, 3);

        % catch trials: cfg.n_catch_trials_per_block trials (out of the 36)
        % get a plain black square instead of the face image. Chosen
        % randomly, independent of probe_trial position.
        catch_trial_idx = randperm(cfg.trials_per_block, cfg.n_catch_trials_per_block);

        % identity pool for face assignment (same 12 identities used across
        % all emotions -- each identity has happy/angry/neutral versions)
        n_ids = numel(cfg.face_identities);

        trials = struct([]);
        last_face_idx = -1;
        last_mask_id = [];
        for t = 1:cfg.trials_per_block
            trial = struct();
            trial.n_targets = target_counts(t);
            trial.arrow_seq = generate_rsvp_trial(cfg, cond.attention, trial.n_targets);
            trial.is_catch = ismember(t, catch_trial_idx);

            % pick a face identity, avoiding immediate repeat within the block
            % (still assigned even on catch trials, for logging purposes --
            % just not actually drawn on screen for those trials)
            face_idx = randi(n_ids);
            while face_idx == last_face_idx && n_ids > 1
                face_idx = randi(n_ids);
            end
            last_face_idx = face_idx;
            trial.face_identity_id = cfg.face_identities(face_idx).id;
            trial.face_gender = cfg.face_identities(face_idx).gender;
            trial.face_side = face_sides{t};
            trial.face_emotion = cond.emotion; % convenience copy of this block's emotion condition

            % mask sequence only needed for unaware (CFS) blocks
            if strcmpi(cond.awareness, 'unaware')
                % NOTE: must include the ISI gap in each item's total
                % duration, not just the item's own on-screen time --
                % missing this previously caused the mask sequence to run
                % out before the (now longer, with ISI added) RSVP stream
                % actually finished, freezing on the last mask frame.
                trial_duration_s = numel(trial.arrow_seq) * (cfg.rsvp_item_duration_s + cfg.rsvp_isi_s);
                n_frames = ceil(trial_duration_s / cfg.mask_frame_duration_s);
                trial.mask_ids = generate_mask_sequence(cfg, n_frames, last_mask_id);
                last_mask_id = trial.mask_ids(end);
            else
                trial.mask_ids = [];
            end

            trials = [trials, trial]; %#ok<AGROW>
        end
        block.trials = trials;

        schedule.blocks = [schedule.blocks, block]; %#ok<AGROW>
    end
end
