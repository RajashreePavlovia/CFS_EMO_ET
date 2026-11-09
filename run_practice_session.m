function run_practice_session(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, sides, ...
    maskTextures, participant_id, dominant_eye, data_dir, timestamp)
% RUN_PRACTICE_SESSION  Practice for the CFS/RSVP experiment, in two phases.
%
% PHASE 1 - RSVP learning (single task): 4 blocks, one per condition
%   (low-aware, low-unaware, high-aware, high-unaware), order randomized
%   per participant. Faces and CFS masks appear exactly as they will in
%   the main task, and after every count response the participant also
%   answers the face question ("Where was the face?", Left / Right / did
%   not see), as in the main task. Each block also contains
%   cfg.practice_probes_per_block (default 3) thought-probe sequences at
%   random trials, so the options become familiar. Counting accuracy over the last
%   cfg.practice_criterion_last_n trials of each load level (pooled across
%   its aware+unaware block) is checked against cfg.practice_pass_easy /
%   cfg.practice_pass_hard.
%
%   REPEATS ONLY WHAT IS NOT LEARNED: if the participant reaches criterion
%   for one load level but not the other, pressing R repeats ONLY the two
%   blocks (aware + unaware) of the load level that has not been learned.
%   A level that has been passed stays passed (its accuracy from the attempt
%   where it passed is kept). On that screen ONLY R (repeat) and Escape (end
%   the session early: not ready for Phase 2 / main task) do anything; every
%   other key is ignored.
%
% PHASE 2 - QUEST (dual task): 2 blocks, easy-unaware and hard-unaware,
%   order randomized. Only run once Phase 1 has passed. The face-report
%   keys (Left/Right/"did not see") are already known from Phase 1. Each trial is RSVP counting
%   plus a forced face-location report; QUEST adapts face contrast to find
%   the 75%-correct threshold for each load level.
%
% The participant's single face contrast for the main task is the LOWER
% of the two QUEST thresholds (easy-unaware, hard-unaware), saved to
% data\p<ID>_practice.mat (variable 'practice'). The main session loads
% this and shows every face at cfg.unaware_contrast_fraction * contrast_base,
% in every condition (aware blocks just have no mask).
%
% A per-trial log is written to data\p<ID>_practice_trials_<timestamp>.csv.
% Pause key is NOT active during practice. Escape aborts.
%
% CALIBRATION KEY (cfg.keys.calib_key, 'c'): works on every practice screen
% and during trials, exactly as in the main session. On a screen it opens the
% fusion calibration at once and then shows the same screen again. During a
% trial it is latched: the trial (and its feedback) finishes, then the
% calibration screen appears, then the next trial starts. In the last trial
% of a block, the next block's scheduled calibration covers it.

    KbName('UnifyKeyNames');
    key_flag('calib', 'clear');
    key_flag('pause', 'clear');

    % calibration context: carries the CURRENT fusion geometry; every screen
    % draws from it, so a recalibration anywhere updates everything after it
    ctx = make_calib_ctx(winRect, frameSizePx, participant_id);

    [faceTextures, identities] = load_practice_faces(win, cfg);

    MAX_RSVP_ITEMS = 20; % same generous upper bound used in run_experiment_session.m
    log_path = fullfile(data_dir, sprintf('p%d_practice_trials_%s.csv', participant_id, timestamp));
    practice_header = {'participant_id','attempt','block_num','attention','awareness','phase','trial_num', ...
        'n_targets_actual','response','rt_s','timed_out','correct', ...
        'face_identity_id','face_gender','face_emotion','face_side','face_contrast', ...
        'spont_face_reported','spont_face_side','quest_report','quest_success'};
    for i = 1:MAX_RSVP_ITEMS
        practice_header{end+1} = sprintf('arrow%d_color', i); %#ok<AGROW>
        practice_header{end+1} = sprintf('arrow%d_orientation', i); %#ok<AGROW>
    end
    append_csv_row(log_path, practice_header);

    % practice thought-probe log (one row per practice probe)
    probe_log_path = fullfile(data_dir, sprintf('p%d_practice_probes_%s.csv', participant_id, timestamp));
    append_csv_row(probe_log_path, {'participant_id','practice_block','probe1_label','probe1_rt_s', ...
        'probe2_label','probe2_rt_s','metaawareness','metaawareness_rt_s','vividness','vividness_rt_s', ...
        'emotionality','emotionality_rt_s','temporality','temporality_rt_s', ...
        'current_concerns','current_concerns_rt_s'});
    n_practice_probes = 0;

    %% ================= PHASE 1: RSVP learning (single task) =================
    learn_conditions = struct('attention', {'low','low','high','high'}, ...
                               'awareness', {'aware','unaware','aware','unaware'});

    phase1_attempt = 0;
    passed = false;
    % per-load-level status, carried ACROSS attempts so a level that has been
    % learned is not practised again
    passed_easy = false;   acc_easy = NaN;
    passed_hard = false;   acc_hard = NaN;

    while ~passed
        phase1_attempt = phase1_attempt + 1;

        % blocks to run this attempt: only the load level(s) not yet passed
        % (attempt 1: all four blocks)
        lvl  = {learn_conditions.attention};
        todo = find((strcmp(lvl, 'low') & ~passed_easy) | (strcmp(lvl, 'high') & ~passed_hard));
        order = todo(randperm(numel(todo)));
        n_p1_blocks = numel(order);

        fprintf('\n=== PRACTICE Phase 1 (RSVP learning), attempt %d: %d block(s) ===\n', phase1_attempt, n_p1_blocks);
        if phase1_attempt > 1
            if passed_easy
                fprintf('    Easy load already learned -- only HARD load blocks are repeated.\n');
            elseif passed_hard
                fprintf('    Hard load already learned -- only EASY load blocks are repeated.\n');
            end
        end

        lastN_hits = struct('low', [], 'high', []);

        for bi = 1:n_p1_blocks
            b = order(bi);
            attn = learn_conditions(b).attention;
            awr  = learn_conditions(b).awareness;
            fprintf('\n--- Phase 1 block %d/%d: attention=%s, awareness=%s ---\n', bi, n_p1_blocks, attn, awr);

            ctx.block_num = bi;
            ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, false);
            et_ensure_calibrated(win, cfg, ppd, winRect, ctx, 0);   % EyeLink calibration (first practice block only)

            if phase1_attempt == 1 && bi == 1
                ctx = show_instructions(win, cfg, frameTex, winRect, ctx, ppd);
                ctx = show_face_question_intro(win, cfg, frameTex, winRect, ctx, ppd);
            end

            target_lines = get_target_lines(attn);
            note = 'Other visual patterns may appear on screen. Ignore them and keep counting.';
            intro = [{sprintf('PRACTICE %d of %d', bi, n_p1_blocks), ''}, target_lines, {'', note, '', 'Press any key to begin.'}];
            ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, intro);

            trials = build_learning_trials(cfg, attn, awr, identities, cfg.practice_trials_per_block);
            cfg_l = cfg;
            cfg_l.face_contrast = cfg.practice_learning_contrast;
            cfg_l.forced_face_report_mode = 'all';   % face question after every count response (run_full_trial)
            hits = zeros(1, numel(trials));
            probe_trials = choose_practice_probe_trials(numel(trials), cfg.practice_probes_per_block);
            fprintf('  Practice probes after trials %s\n', mat2str(probe_trials));
            for t = 1:numel(trials)
                trial = trials(t);
                et_set_context('practice', bi, t, attn, awr, trial.face_emotion);
                res = run_full_trial(win, cfg_l, ifi, ppd, trial, awr, ctx.centers, ...
                    sides.dominant_screen_half, sides.nondominant_screen_half, ...
                    faceTextures, maskTextures, frameTex, ctx.frameDestRects);
                hits(t) = double(res.correct);
                log_practice_trial(log_path, participant_id, phase1_attempt, bi, attn, awr, 'learning', t, ...
                    trial, res, cfg_l.face_contrast, '', NaN, MAX_RSVP_ITEMS);
                fprintf('  Learning %d/%d: targets=%d, response=%s, correct=%d\n', ...
                    t, numel(trials), res.n_targets_actual, mat2str(res.response), res.correct);
                show_count_feedback(win, cfg, frameTex, winRect, ctx.frameDestRects, ppd, res);

                % thought probes at this block's randomly chosen trials
                probe_fired = ismember(t, probe_trials);
                if probe_fired
                    ctx = run_practice_probe(win, cfg, winRect, frameTex, ctx, ppd, participant_id, ...
                        probe_log_path, sprintf('phase1_attempt%d_block%d_probe%d', phase1_attempt, bi, find(probe_trials == t)), ...
                        n_practice_probes == 0, ...
                        t < numel(trials) && ~key_flag('calib', 'get'), build_arrow_instruction_lines(attn, 'continue'));
                    n_practice_probes = n_practice_probes + 1;
                end

                % C pressed during this trial: recalibrate now -- AFTER the trial
                % finished, was logged and its feedback was shown, BEFORE the
                % next trial. (After a block's last trial the next scheduled
                % calibration covers it.)
                if key_flag('calib', 'get')
                    if t < numel(trials)
                        fprintf('  C pressed: recalibrating before the next trial.\n');
                        ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, true);
                        ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, ...
                            [{'Frames adjusted.', ''}, target_lines, {'', 'Press any key to continue.'}]);
                    else
                        key_flag('calib', 'clear');
                    end
                end
            end
            n_last = min(cfg.practice_criterion_last_n, numel(hits));
            lastN_hits.(attn) = [lastN_hits.(attn), hits(end-n_last+1:end)];
        end

        % Update ONLY the load level(s) that were practised this attempt; a
        % level that already passed keeps its status and its accuracy.
        ran_easy = ~isempty(lastN_hits.low);
        ran_hard = ~isempty(lastN_hits.high);
        if ran_easy
            acc_easy = mean(lastN_hits.low);
            passed_easy = acc_easy >= cfg.practice_pass_easy;
        end
        if ran_hard
            acc_hard = mean(lastN_hits.high);
            passed_hard = acc_hard >= cfg.practice_pass_hard;
        end
        passed = passed_easy && passed_hard;

        fprintf('\n-- Phase 1 results (attempt %d) --\n', phase1_attempt);
        fprintf('Easy accuracy: %.0f%% (needs %.0f%%) -> %s%s\n', 100*acc_easy, 100*cfg.practice_pass_easy, ...
            pass_text(passed_easy), ternary(ran_easy, '', '  [kept from an earlier attempt]'));
        fprintf('Hard accuracy: %.0f%% (needs %.0f%%) -> %s%s\n', 100*acc_hard, 100*cfg.practice_pass_hard, ...
            pass_text(passed_hard), ternary(ran_hard, '', '  [kept from an earlier attempt]'));

        if ~passed
            repeat_easy_txt = ternary(passed_easy, 'OK', 'REPEAT');
            repeat_hard_txt = ternary(passed_hard, 'OK', 'REPEAT');
            repeat_lines = {'RSVP practice not yet at criterion.', '', ...
                 sprintf('Easy: %.0f%% (need %.0f%%) %s', 100*acc_easy, 100*cfg.practice_pass_easy, repeat_easy_txt), ...
                 sprintf('Hard: %.0f%% (need %.0f%%) %s', 100*acc_hard, 100*cfg.practice_pass_hard, repeat_hard_txt), ...
                 '', 'Experimenter: press R to repeat only the level(s) marked REPEAT. (Esc = end the session)'};
            fprintf('Criteria NOT met. Press R to repeat only the level(s) not passed, or Esc to end the session. All other keys are ignored.\n');
            [ctx, key] = wait_r_or_esc(win, cfg, ppd, winRect, frameTex, ctx, repeat_lines);
            if ~strcmpi(key, 'r')
                practice = struct('participant_id', participant_id, 'dominant_eye', dominant_eye, ...
                    'phase1_attempt', phase1_attempt, 'accuracy_easy', acc_easy, 'accuracy_hard', acc_hard, ...
                    'passed_easy', passed_easy, 'passed_hard', passed_hard, 'passed', false, ...
                    'stopped_at_phase1', true, 'timestamp', timestamp);
                save(fullfile(data_dir, sprintf('p%d_practice.mat', participant_id)), 'practice');
                fprintf('Session ended after Phase 1 (not ready for QUEST / main task).\n');
                return;
            end
            % otherwise: loop repeats Phase 1 (only the unpassed level), window stays open
        end
    end

    %% ================= PHASE 2: QUEST (dual task) =================
    fprintf('\n=== PRACTICE Phase 2 (face-detection threshold) ===\n');
    quest_loads = {'low', 'high'};
    quest_order = randperm(2);
    quest_thr  = struct('low', NaN, 'high', NaN);
    quest_hist = struct('low', [], 'high', []);

    for qi = 1:2
        attn = quest_loads{quest_order(qi)};
        block_num = 4 + qi;

        ctx.block_num = block_num;
        ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, false);

        target_lines = get_target_lines(attn);
        intro = [{sprintf('PRACTICE %d of 2 (final part)', qi), ''}, target_lines, ...
            {'', 'Keep counting as before.', '', 'Press any key to begin.'}];
        ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, intro);

        [thr, qh, ctx] = run_quest_phase(win, cfg, ifi, ppd, attn, sides, ...
            faceTextures, maskTextures, frameTex, winRect, identities, ...
            log_path, participant_id, phase1_attempt, block_num, MAX_RSVP_ITEMS, ctx);
        quest_thr.(attn)  = thr;
        quest_hist.(attn) = qh;
    end

    % C pressed in the very last QUEST trial: honour it now, so the
    % calibration saved for the main session is the latest one
    if key_flag('calib', 'get')
        fprintf('  C pressed in the last practice trial: recalibrating now.\n');
        ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, true);
    end

    contrast_base = min([quest_thr.low, quest_thr.high]);

    practice = struct( ...
        'participant_id', participant_id, 'dominant_eye', dominant_eye, 'phase1_attempt', phase1_attempt, ...
        'threshold_easy', quest_thr.low, 'threshold_hard', quest_thr.high, ...
        'contrast_base', contrast_base, ...
        'accuracy_easy', acc_easy, 'accuracy_hard', acc_hard, ...
        'passed_easy', passed_easy, 'passed_hard', passed_hard, 'passed', true, ...
        'quest_easy', quest_hist.low, 'quest_hard', quest_hist.high, ...
        'calib_state', ctx.calib_state, ...
        'timestamp', timestamp);
    save(fullfile(data_dir, sprintf('p%d_practice.mat', participant_id)), 'practice');

    fprintf('\n================ PRACTICE COMPLETE ================\n');
    fprintf('Easy accuracy: %.0f%%, Hard accuracy: %.0f%%\n', 100*acc_easy, 100*acc_hard);
    fprintf('QUEST thresholds: easy-unaware %.3f, hard-unaware %.3f\n', quest_thr.low, quest_thr.high);
    fprintf('Participant base contrast (lower of the two): %.3f\n', contrast_base);
    fprintf('Main-task face contrast will be: %.3f  (= %.2f x base)\n', ...
        cfg.unaware_contrast_fraction * contrast_base, cfg.unaware_contrast_fraction);

    fprintf('Press any key to finish. Then run run_experiment_session again and type "main" for this participant.\n');
    pwait(win, cfg, ppd, winRect, frameTex, ctx, {'Practice complete.', '', 'Please wait for the experimenter.'});
end


%% ====================== helpers ======================

function [ctx, name] = pwait(win, cfg, ppd, winRect, frameTex, ctx, lines)
% Show a text screen (in both eyes' frames) and wait for a key. C does not
% count as "continue": it recalibrates and the same screen is redrawn on the
% new frames (see wait_key_or_calib). Escape aborts. Returns the pressed
% key's name.
    [ctx, name] = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
        @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, lines));
end


function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end


function ctx = run_practice_probe(win, cfg, winRect, frameTex, ctx, ppd, participant_id, probe_log_path, tag, full_intro, show_reminder, reminder_lines)
% Run one full thought-probe sequence in the middle of a practice block, so
% participants get used to the questions and options of the main task.
% Answers are logged to the practice probes CSV but have no effect on the
% practice criteria. The explanation screen is shown only before the very
% first practice probe; later ones appear straight away (as in the main task).
% If show_reminder is true, a "same block continues" screen follows.
    probe1_order = build_probe1_order(cfg, participant_id);

    if full_intro
        intro = {'THOUGHT QUESTIONS', '', ...
            'In the real experiment, a few questions will sometimes appear about what was going through your mind.', '', ...
            'You will see them several times in each practice block. Report what was in your mind just BEFORE the questions appeared.', '', ...
            'There are no right or wrong answers.', '', 'Press any key to continue.'};
        ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, intro);
    end

    pr = run_probe_sequence(win, cfg, winRect, frameTex, ctx.frameDestRects, ppd, probe1_order);

    append_csv_row(probe_log_path, {participant_id, tag, ...
        pr.probe1_label, pr.probe1_rt_s, pr.probe2_label, pr.probe2_rt_s, ...
        pr.metaawareness, pr.metaawareness_rt_s, pr.vividness, pr.vividness_rt_s, ...
        pr.emotionality, pr.emotionality_rt_s, pr.temporality, pr.temporality_rt_s, ...
        pr.current_concerns, pr.current_concerns_rt_s});
    fprintf('  Practice probe (%s): %s\n', tag, pr.probe1_label);

    if show_reminder
        ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, reminder_lines);
    end
end


function probe_trials = choose_practice_probe_trials(n_trials, k)
% k probe positions inside one practice block: the block is split into k equal
% segments and one trial is drawn at random from each segment, never the very
% first trial of the block. Positions are strictly increasing.
    probe_trials = zeros(1, k);
    for i = 1:k
        lo = max(2, floor((i-1) * n_trials / k) + 1);
        hi = max(lo, floor(i * n_trials / k));
        probe_trials(i) = lo + randi(hi - lo + 1) - 1;
    end
end


function ctx = show_face_question_intro(win, cfg, frameTex, winRect, ctx, ppd)
% Explains the face question once, before the first practice block (the face
% question is asked after every count response in all of practice and main).
    intro = {'FACE QUESTION', '', ...
        'A face may appear beside the arrows. Sometimes flickering patterns hide it.', '', ...
        'After you report the number of targets, you will be asked: "Where was the face?"', '', ...
        sprintf('%s = LEFT', key_label_local(cfg.keys.face_report_keys.left)), ...
        sprintf('%s = RIGHT', key_label_local(cfg.keys.face_report_keys.right)), ...
        sprintf('%s = did NOT see a face', key_label_local(cfg.keys.quest_none_key)), '', ...
        'If you did not see a face, do not guess.', '', 'Press any key to continue.'};
    ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, intro);
end


function [ctx, name] = wait_r_or_esc(win, cfg, ppd, winRect, frameTex, ctx, lines)
% Experimenter screen: ONLY R (name = 'r') or Escape (name = 'esc') ends it.
% Every other key (including C) is ignored, so a stray key press can no
% longer end the session or close the window. Escape returns 'esc' so the
% caller can save the practice status and end cleanly.
    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');
    rKey   = KbName('r');
    flip_probe_screen(win, cfg, frameTex, winRect, ctx.frameDestRects, ppd, lines);
    KbReleaseWait;
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                name = 'esc';
                break;
            elseif keyCode(rKey)
                name = 'r';
                break;
            end
        end
        WaitSecs(0.001);
    end
    KbReleaseWait;
end


function s = pass_text(tf)
    if tf
        s = 'PASS';
    else
        s = 'FAIL';
    end
end


function lines = get_target_lines(attn)
    if strcmpi(attn, 'low')
        lines = {'Count the RED arrows only.'};
    else
        lines = {'Count the YELLOW UPRIGHT arrows', 'AND the GREEN DOWNWARD (inverted) arrows.'};
    end
end


function trials = build_learning_trials(cfg, attn, awr, identities, n_trials)
% One block of learning trials, built the same way as in generate_block_schedule.
    if strcmpi(attn, 'low')
        pool = cfg.low_load_target_counts;
    else
        pool = cfg.high_load_target_counts;
    end
    counts = balanced_no_repeat_sequence(pool, n_trials);
    face_sides = generate_max_run_sequence({'left','right'}, n_trials, 3);

    n_ids = numel(identities);
    id_order = [];
    while numel(id_order) < n_trials
        id_order = [id_order, randperm(n_ids)]; %#ok<AGROW>
    end
    id_order = id_order(1:n_trials);

    trials = struct([]);
    last_mask_id = [];
    for t = 1:n_trials
        emo = cfg.emotion_levels{randi(numel(cfg.emotion_levels))};
        [trial, last_mask_id] = make_practice_trial(cfg, attn, awr, identities(id_order(t)), ...
            face_sides{t}, emo, counts(t), last_mask_id);
        trials = [trials, trial]; %#ok<AGROW>
    end
end


function [trial, last_mask_id] = make_practice_trial(cfg, attn, awr, identity, face_side, emotion, n_targets, last_mask_id)
% One trial struct with exactly the fields run_full_trial expects.
    trial = struct();
    trial.n_targets = n_targets;
    trial.arrow_seq = generate_rsvp_trial(cfg, attn, n_targets);
    trial.is_catch = false;
    trial.face_identity_id = identity.id;
    trial.face_gender = identity.gender;
    trial.face_side = face_side;
    trial.face_emotion = emotion;

    if strcmpi(awr, 'unaware')
        trial_duration_s = numel(trial.arrow_seq) * (cfg.rsvp_item_duration_s + cfg.rsvp_isi_s);
        n_frames = ceil(trial_duration_s / cfg.mask_frame_duration_s);
        trial.mask_ids = generate_mask_sequence(cfg, n_frames, last_mask_id);
        last_mask_id = trial.mask_ids(end);
    else
        trial.mask_ids = [];
    end
end


function [thr_alpha, qh, ctx] = run_quest_phase(win, cfg, ifi, ppd, attn, sides, ...
    faceTextures, maskTextures, frameTex, winRect, identities, log_path, participant_id, attempt, b, MAX_RSVP_ITEMS, ctx)
% QUEST on log10(face contrast). Success = correct side reported.
% Takes and returns the calibration context so a C-key recalibration between
% trials carries on into the following trials.

    leftLbl  = key_label_local(cfg.keys.face_report_keys.left);
    rightLbl = key_label_local(cfg.keys.face_report_keys.right);
    noneLbl  = key_label_local(cfg.keys.quest_none_key);

    intro = {'NEXT PART', '', 'The counting task and the face question continue as before.', '', ...
        'In this part the face may be very faint or hidden by the flickering patterns.', ...
        'After each trial you will again be asked where the face was:', ...
        sprintf('%s = face on the LEFT', leftLbl), ...
        sprintf('%s = face on the RIGHT', rightLbl), ...
        sprintf('%s = I did NOT see a face', noneLbl), ...
        '', 'Answer honestly. If you did not see a face, do not guess.', '', 'Press any key to begin.'};
    ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, intro);

    q = QuestCreate(log10(cfg.quest_start_contrast), cfg.quest_prior_sd, cfg.quest_p_threshold, ...
        cfg.quest_beta, cfg.quest_delta, cfg.quest_gamma, 0.01, 4);
    q.normalizePdf = 1;

    if strcmpi(attn, 'low')
        pool = cfg.low_load_target_counts;
    else
        pool = cfg.high_load_target_counts;
    end
    target_lines = get_target_lines(attn);
    n_ids = numel(identities);
    id_queue = [];
    last_mask_id = [];
    face_sides = {};
    contrasts = [];
    successes = [];
    n = 0;

    while true
        n = n + 1;

        t_log = QuestQuantile(q);
        t_log = min(0, max(t_log, log10(cfg.quest_min_contrast)));   % 1% .. 100% contrast
        alpha = 10 ^ t_log;

        if isempty(id_queue)
            id_queue = randperm(n_ids);
        end
        identity = identities(id_queue(1));
        id_queue(1) = [];

        face_side = pick_face_side(face_sides);
        face_sides{end+1} = face_side; %#ok<AGROW>
        emotion = cfg.emotion_levels{randi(numel(cfg.emotion_levels))};
        n_targets = pool(randi(numel(pool)));

        [trial, last_mask_id] = make_practice_trial(cfg, attn, 'unaware', identity, face_side, ...
            emotion, n_targets, last_mask_id);

        cfg_t = cfg;
        cfg_t.face_contrast = alpha;
        et_set_context('quest', b, n, attn, 'unaware', emotion);
        res = run_full_trial(win, cfg_t, ifi, ppd, trial, 'unaware', ctx.centers, ...
            sides.dominant_screen_half, sides.nondominant_screen_half, ...
            faceTextures, maskTextures, frameTex, ctx.frameDestRects);

        % forced face-location report (standalone ask_face_side.m; it also
        % latches a C press, like every other screen)
        report  = ask_face_side(win, cfg, frameTex, winRect, ctx.frameDestRects, ppd);
        success = strcmp(report, face_side);
        q = QuestUpdate(q, t_log, double(success));

        contrasts(end+1) = alpha;            %#ok<AGROW>
        successes(end+1) = double(success);  %#ok<AGROW>
        log_practice_trial(log_path, participant_id, attempt, b, attn, 'unaware', 'quest', n, ...
            trial, res, alpha, report, double(success), MAX_RSVP_ITEMS);
        fprintf('  QUEST %d: contrast=%.3f, face=%s, report=%s, success=%d\n', ...
            n, alpha, face_side, report, success);

        done = n >= cfg.quest_max_trials || (n >= cfg.quest_min_trials && QuestSd(q) <= cfg.quest_sd_stop);

        % C pressed during this trial (or its face report): recalibrate now,
        % after everything for this trial is recorded and before the next one.
        % If this was the block's last trial the flag stays latched; the next
        % scheduled calibration (or the end-of-practice check) handles it.
        if ~done && key_flag('calib', 'get')
            fprintf('  C pressed: recalibrating before the next trial.\n');
            ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, true);
            ctx = pwait(win, cfg, ppd, winRect, frameTex, ctx, ...
                [{'Frames adjusted.', ''}, target_lines, {'', 'Press any key to continue.'}]);
        end

        if done
            break;
        end
    end

    t_est = QuestMean(q);
    if t_est >= 0
        warning('run_practice_session:questCeiling', ...
            'QUEST estimate is at or above 100%% contrast (%s load) - this participant may not reach the criterion even at full contrast.', attn);
    end
    thr_alpha = min(1, 10 ^ t_est);
    fprintf('  QUEST (%s load): threshold = %.3f (log10 %.3f), SD = %.3f, %d trials\n', ...
        attn, thr_alpha, t_est, QuestSd(q), n);
    qh = struct('contrast', contrasts, 'success', successes, 'log10_estimate', t_est, 'sd', QuestSd(q));
end


function s = pick_face_side(hist)
% Random left/right, but never more than 3 in a row.
    opts = {'left', 'right'};
    n = numel(hist);
    if n >= 3 && strcmp(hist{n}, hist{n-1}) && strcmp(hist{n}, hist{n-2})
        if strcmp(hist{n}, 'left')
            s = 'right';
        else
            s = 'left';
        end
    else
        s = opts{randi(2)};
    end
end


function show_count_feedback(win, cfg, frameTex, winRect, frameDestRects, ppd, res)
    if res.timed_out
        msg = {'Too slow.', '', sprintf('The correct number was %d.', res.n_targets_actual)};
    elseif res.correct
        msg = {'Correct!'};
    else
        msg = {'Incorrect.', '', sprintf('The correct number was %d.', res.n_targets_actual)};
    end
    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, msg);
    Screen('Flip', win);
    % poll for C during the feedback screen (latch only; Escape aborts)
    KbName('UnifyKeyNames');
    calibKey = KbName(cfg.keys.calib_key);
    escKey   = KbName('ESCAPE');
    t_end = GetSecs + cfg.practice_feedback_s;
    while GetSecs < t_end
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_practice_session:userAbort', 'User pressed Escape -- aborting.');
            end
            if keyCode(calibKey)
                key_flag('calib', 'set');
            end
        end
        WaitSecs(0.001);
    end
end


function log_practice_trial(log_path, participant_id, attempt, b, attn, awr, phase, t, trial, res, alpha, quest_report, quest_success, max_items)
    append_csv_row(log_path, [{participant_id, attempt, b, attn, awr, phase, t, ...
        res.n_targets_actual, res.response, res.rt_s, res.timed_out, res.correct, ...
        trial.face_identity_id, trial.face_gender, trial.face_emotion, trial.face_side, alpha, ...
        res.face_report.reported, res.face_report.side, quest_report, quest_success}, ...
        arrow_seq_to_csv_cells(trial.arrow_seq, max_items)]);
end


function [faceTextures, identities] = load_practice_faces(win, cfg)
% Auto-discover practice faces named like AF01ANS...(any suffix/extension),
% anywhere under cfg.practice_face_folder_root (subfolders are searched too).
% Textures are keyed with face_texture_key(), so draw_face works unchanged.
    root = cfg.practice_face_folder_root;
    if ~isfolder(root)
        error('run_practice_session:noPracticeFaces', ...
            'Practice face folder not found: %s (set cfg.practice_face_folder_root)', root);
    end
    fprintf('Loading practice faces from %s ...\n', root);

    emo_names = fieldnames(cfg.face_emotion_code);   % angry / happy / neutral
    files = dir(fullfile(root, '**', '*.*'));
    files = files(~[files.isdir]);

    faceTextures = containers.Map();
    identities = struct('id', {}, 'gender', {});
    seen = {};
    n_loaded = 0;

    for i = 1:numel(files)
        [~, base, ext] = fileparts(files(i).name);
        if ~ismember(lower(ext), {'.jpg', '.jpeg', '.png'})
            continue;
        end
        tok = regexp(base, '^A([FMfm])(\d+)([A-Za-z]{3})', 'tokens', 'once');
        if isempty(tok)
            continue;
        end
        gender = upper(tok{1});
        id     = tok{2};
        code   = upper(tok{3});

        emotion = '';
        for k = 1:numel(emo_names)
            if strcmp(cfg.face_emotion_code.(emo_names{k}), code)
                emotion = emo_names{k};
            end
        end
        if isempty(emotion)
            continue;
        end

        % Read image AND PNG alpha channel
        [img, ~, alpha] = imread(fullfile(files(i).folder, files(i).name));

        % Make grayscale image RGB
        if ndims(img) == 2
            img = repmat(img, [1 1 3]);
        end

        % If there is no alpha channel, treat image as fully opaque
        if isempty(alpha)
            alpha = uint8(255 * ones(size(img,1), size(img,2)));
        end

        % Add alpha as fourth channel
        img(:,:,4) = alpha;

        % Create PTB texture with transparency preserved
        tex = Screen('MakeTexture', win, img);

        faceTextures(face_texture_key(id, gender, emotion)) = tex;
        n_loaded = n_loaded + 1;

        idkey = [gender '_' id];
        if ~ismember(idkey, seen)
            seen{end+1} = idkey; %#ok<AGROW>
            identities(end+1) = struct('id', id, 'gender', gender); %#ok<AGROW>
        end
    end

    if isempty(identities)
        error('run_practice_session:noPracticeFaces', ...
            'No practice faces matching the pattern A[F/M][id][ANS/HAS/NES] found under %s', root);
    end

    % keep only identities that have all 3 emotions -- warn instead of erroring
    complete = true(1, numel(identities));
    for i = 1:numel(identities)
        for e = 1:numel(cfg.emotion_levels)
            key = face_texture_key(identities(i).id, identities(i).gender, cfg.emotion_levels{e});
            if ~isKey(faceTextures, key)
                warning('run_practice_session:missingPracticeFace', ...
                    'Practice face missing for %s (identity %s%s, emotion %s) -- excluding this identity.', ...
                    key, identities(i).gender, identities(i).id, cfg.emotion_levels{e});
                complete(i) = false;
            end
        end
    end
    identities = identities(complete);

    fprintf('Loaded %d practice face images, %d complete identities.\n', n_loaded, numel(identities));
    if numel(identities) < 8
        warning('run_practice_session:identityCount', ...
            'Only %d complete practice identities found (expected around 12). Consider adding more before running real participants.', numel(identities));
    end
end


function s = key_label_local(k)
% 'z' -> 'Z', 'LeftArrow' -> 'Left Arrow'
    if isnumeric(k)
        k = KbName(k);
    end
    if iscell(k)
        k = k{1};
    end
    if numel(k) == 1
        s = upper(k);
    else
        s = regexprep(k, '([a-z])([A-Z])', '$1 $2');
    end
end

function cells = arrow_seq_to_csv_cells(arrow_seq, max_items)
    cells = cell(1, max_items*2);
    n = numel(arrow_seq);
    for i = 1:max_items
        if i <= n
            cells{2*i-1} = arrow_seq(i).color;
            cells{2*i}   = arrow_seq(i).orientation;
        else
            cells{2*i-1} = [];
            cells{2*i}   = [];
        end
    end
    if n > max_items
        warning('arrow_seq_to_csv_cells:truncated', ...
            'Trial had %d items, exceeding max_items=%d -- extra items not logged.', n, max_items);
    end
end
