% RUN_EXPERIMENT_SESSION  The full experiment: 24 blocks x 36 trials,
% fusion calibration before every block, RSVP+face+CFS mask on every
% trial, spontaneous-thought probes firing at their randomized positions
% within each block (cfg.probes_per_block, default 2), and CSV logging of
% every trial, probe and calibration.
%
% HOW TO RUN:
%   1. Make sure ALL project .m files are in the same folder.
%   2. Make sure cfg.screen_width_cm / screen_height_cm in
%      config_experiment.m are your real measured values (not NaN).
%   3. Make sure cfg.face_folder_root and cfg.mask_folder point to real,
%      existing folders with your actual files.
%   4. cd to that folder in MATLAB.
%   5. Type:  run_experiment_session
%   6. Enter participant ID, dominant eye and session type (practice/main)
%      when prompted (in the command window, before any window opens).
%   7. Fusion calibration runs before EVERY block (arrow keys + Return).
%   8. Each trial: fixation -> RSVP+face+mask -> press 1-5 for target count
%      -> face-location report.
%   9. At each of the block's randomized probe trials, the probe sequence
%      fires automatically after that trial's responses.
%  10. Between blocks: a break screen, press any key to continue.
%  11. PAUSE KEY (cfg.keys.pause_key, default 'p'): press it AT ANY POINT
%      during a trial (RSVP stream, response, face report or ITI). The trial
%      is never interrupted; a "PAUSED" screen appears as soon as it has
%      finished. Press any key to resume.
%  12. CALIBRATION KEY (cfg.keys.calib_key, default 'c'): works on EVERY
%      screen, from the first instruction page to the thank-you page.
%        - On instruction / break / reminder screens it opens the fusion
%          calibration screen straight away, then shows the same screen again.
%        - During a trial it is only latched: the trial runs to the end with
%          all responses recorded (and the block's probe, if one follows),
%          then the calibration screen appears, then the next trial starts.
%        - Pressed in the LAST trial of a block (not the last block), the
%          next block's normal calibration screen covers it.
%      The calibration screen starts from the current fused position and asks
%      "ARE THE FRAMES STILL FUSED?" (Return = yes, or adjust first).
%      Every calibration is written to the events CSV
%      (calibration_scheduled / calibration_manual).
%  13. Press Escape at ANY point to abort cleanly (data already written is
%      preserved on disk -- see the note on CSV logging below).
%
% THIS HAS NOT BEEN TESTED AS A FULL 24-BLOCK RUN. Please do NOT run this
% with a real participant before running it yourself end to end, possibly
% with a shortened schedule (e.g. cfg.trials_per_block = 14 and fewer
% blocks), and confirm it holds up before real data collection.
%
% DATA SAFETY: each trial/probe/calibration result is written to its CSV
% file immediately after it happens (not buffered), so if the script crashes
% or you hit Escape partway through, everything completed so far is already
% safely saved to disk in the data folder.

try
    %% ---- participant setup (before any window opens) ----
    participant_id = input('Participant ID (integer): ');
    if isempty(participant_id) || ~isnumeric(participant_id)
        error('run_experiment_session:badInput', 'Participant ID must be a number.');
    end

    dominant_eye_input = input('Dominant eye (left/right): ', 's');
    if ~ismember(lower(dominant_eye_input), {'left','right'})
        error('run_experiment_session:badInput', 'Must type left or right.');
    end
    dominant_eye = lower(dominant_eye_input);

    session_type_input = input('Session type (practice/main): ', 's');
    if ~ismember(lower(session_type_input), {'practice','main','eyedom','samediff'})
    error('run_experiment_session:badInput', 'Must type practice, main, eyedom, or samediff.');
end
    session_type = lower(session_type_input);

    et_mode_input = '';
    if ismember(session_type, {'practice','main'})
        et_mode_input = lower(strtrim(input('Eye tracking (off/dummy/live, Enter = default from config_eyetracking.m): ', 's')));
        if ~isempty(et_mode_input) && ~ismember(et_mode_input, {'off','dummy','live'})
            error('run_experiment_session:badInput', 'Eye tracking must be off, dummy or live.');
        end
    end

    %% ---- output files ----
    data_dir = fullfile(pwd, 'data');
    if ~isfolder(data_dir)
        mkdir(data_dir);
    end
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    trial_log_path = fullfile(data_dir, sprintf('p%d_trials_%s.csv', participant_id, timestamp));
    probe_log_path = fullfile(data_dir, sprintf('p%d_probes_%s.csv', participant_id, timestamp));
    events_log_path = fullfile(data_dir, sprintf('p%d_events_%s.csv', participant_id, timestamp));

    if strcmp(session_type, 'main')
        trial_header = {'participant_id','block_num','attention','awareness','emotion', ...
            'trial_num','dominant_eye','calibration_separation_px','left_frame_dy_px','right_frame_dy_px', ...
            'n_targets_requested','n_targets_actual','n_items_total','n_nontargets', ...
            'response','rt_s','timed_out','correct','is_catch', ...
            'face_identity_id','face_gender','face_side', ...
            'face_reported','face_report_side','face_report_rt_s', ...
            'face_report_correct','exclude_aware_leak','face_contrast', ...
            'trial_start_vbl','trial_rsvp_end_vbl'};
        MAX_RSVP_ITEMS = 20; % generous upper bound on sequence length; unused columns for shorter trials are left blank
        for i = 1:MAX_RSVP_ITEMS
            trial_header{end+1} = sprintf('arrow%d_color', i); %#ok<AGROW>
            trial_header{end+1} = sprintf('arrow%d_orientation', i); %#ok<AGROW>
        end
        % new column, placed LAST so all earlier column positions are unchanged:
        % how many times C-triggered recalibration had run when this trial started
        trial_header{end+1} = 'recalib_count';
        % eye-tracking central-fixation check (status 'off' when not tracking)
        trial_header = [trial_header, {'et_gate_status','et_gate_wait_s','et_gate_offset_x_deg','et_gate_offset_y_deg','et_gate_menu_count'}];
        append_csv_row(trial_log_path, trial_header);

        probe_header = {'participant_id','block_num','trial_num', ...
            'probe1_label','probe1_rt_s','probe2_label','probe2_rt_s', ...
            'metaawareness','metaawareness_rt_s','vividness','vividness_rt_s','emotionality','emotionality_rt_s', ...
            'temporality','temporality_rt_s','current_concerns','current_concerns_rt_s', ...
            'probe_index'};   % probe_index = 1st, 2nd, ... probe within the block (new column, last)
        append_csv_row(probe_log_path, probe_header);

        events_header = {'participant_id','block_num','trial_num','event_type', ...
            'event_seq_num','color','value','onset_abs_time_s'};
        append_csv_row(events_log_path, events_header);

        fprintf('Trial log: %s\nProbe log: %s\nEvents log: %s\n', trial_log_path, probe_log_path, events_log_path);
    end

    %% ---- PTB / display setup ----
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % TODO: set to 0 for real data collection on final hardware

    cfg = config_experiment();
    cfg.eyetracking = config_eyetracking();
    if ~isempty(et_mode_input)
        cfg.eyetracking.mode = et_mode_input;
    end
    [win, winRect, ppd, ifi] = open_experiment_window(cfg);
    if ismember(session_type, {'practice','main'})
        et_init(win, winRect, cfg, ppd, participant_id, session_type, data_dir);
    end

    key_flag('calib', 'clear');   % start with no pending C / P requests
    key_flag('pause', 'clear');

    sides = get_eye_side_mapping(cfg, dominant_eye);
    calib_state = [];   % carried from block to block (and from practice, see below)
    cfg.text_only_side = sides.dominant_screen_half;
    if strcmp(session_type, 'main')
        practice_file = fullfile(data_dir, sprintf('p%d_practice.mat', participant_id));
        if ~isfile(practice_file)
            error('run_experiment_session:noPractice', ...
                'No practice file for participant %d. Run the practice session first.', participant_id);
        end
        P = load(practice_file);
        if isfield(P.practice, 'calib_state')
            calib_state = P.practice.calib_state;   % start block 1 where practice ended
        end
        cfg.face_contrast = cfg.unaware_contrast_fraction * P.practice.contrast_base;
        cfg.forced_face_report_mode = 'all';   % 'all' | 'unaware_only' | 'none'
        fprintf('Face contrast for ALL trials: %.3f\n', cfg.face_contrast);
        if ~P.practice.passed
            warning('This participant did not meet the practice criteria.');
        end
    end
    fprintf('Dominant eye (%s) -> %s screen half (mask). Non-dominant -> %s screen half (face).\n', ...
        dominant_eye, sides.dominant_screen_half, sides.nondominant_screen_half);

    frameImg = build_fusion_frame_texture(cfg, ppd);
    frameTex = Screen('MakeTexture', win, frameImg);
    frameSizePx = size(frameImg, 1);

    fprintf('Preloading textures...\n');
    faceTextures = preload_face_textures(win, cfg);
    maskTextures = preload_mask_textures(win, cfg);

    if strcmp(session_type, 'practice')
        run_practice_session(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, sides, ...
            maskTextures, participant_id, dominant_eye, data_dir, timestamp);
        et_shutdown();
        Screen('CloseAll');
        sca;
        fprintf('\nPractice session finished.\n');
        return;
    end
    if strcmp(session_type, 'eyedom')
    dominant_eye_result = run_eye_dominance_test(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, ...
        maskTextures, participant_id, data_dir, timestamp);
    Screen('CloseAll');
    sca;
    fprintf('\nEye dominance test finished. Dominant eye: %s\n', dominant_eye_result);
    return;
end
    if strcmp(session_type, 'samediff')
    run_arrow_samediff_task(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, ...
        participant_id, data_dir, timestamp);
    Screen('CloseAll');
    sca;
    fprintf('\nSame/different arrow task finished.\n');
    return;
end
    
    % calibration context: carries the CURRENT fusion geometry (centres,
    % frame rects, offsets) through the whole session; every screen draws
    % from it, so a recalibration anywhere updates everything after it.
    ctx = make_calib_ctx(winRect, frameSizePx, participant_id);
    ctx.calib_state = calib_state;
    ctx.log_path = events_log_path;   % every calibration is written to the events CSV

    %% ---- schedule ----
    schedule = generate_block_schedule(cfg, participant_id);
    n_blocks = numel(schedule.blocks);

    %% ---- main block loop ----
    for b = 1:n_blocks
        block = schedule.blocks(b);
        fprintf('\n=== Block %d/%d: attention=%s, awareness=%s, emotion=%s, probes after trials %s ===\n', ...
            b, n_blocks, block.attention, block.awareness, block.emotion, mat2str(block.probe_trials));

        % --- scheduled fusion calibration for this block ---
        ctx.block_num = b;
        ctx.trial_num = 0;
        ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, false);
        et_ensure_calibrated(win, cfg, ppd, winRect, ctx, b);   % EyeLink calibration (first block, then every N blocks)

        if b == 1
            ctx = show_main_instructions(win, cfg, frameTex, winRect, ctx, ppd);
        end

        % --- block-start instructions: which arrows to count this block ---
        if strcmpi(block.attention, 'low')
            target_lines = {'Count the RED arrows only.'};
        else
            target_lines = {'Count the YELLOW UPRIGHT arrows', 'AND the GREEN DOWNWARD (inverted) arrows.'};
        end
        instruction_lines = build_arrow_instruction_lines(block.attention, 'start');
        ctx = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
            @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, instruction_lines));

        n_trials = numel(block.trials);
        for t = 1:n_trials
            trial = block.trials(t);
            ctx.trial_num = t;

            et_set_context('main', b, t, block.attention, block.awareness, block.emotion);
            result = run_full_trial(win, cfg, ifi, ppd, trial, block.awareness, ctx.centers, ...
                sides.dominant_screen_half, sides.nondominant_screen_half, ...
                faceTextures, maskTextures, frameTex, ctx.frameDestRects);

            % geometry this trial was actually run with (a recalibration after
            % this trial must not change what is logged for it)
            trial_eff_sep    = ctx.eff_separation_px;
            trial_left_dy    = ctx.frame_offsets.left_dy;
            trial_right_dy   = ctx.frame_offsets.right_dy;
            trial_recalib_ct = ctx.n_recalibrations;

            % --- pause: latched anywhere in the trial, shown now ---
            if result.pause_requested
                pause_lines = [{'PAUSED', '', 'Take your time.', '', 'When you continue, please count:', ''}, ...
                    target_lines, {'', 'Press any key to resume.'}];
                ctx = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
                    @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, pause_lines));
                key_flag('pause', 'clear');
            end

            if result.is_catch
                catch_suffix = ' [CATCH]';
            else
                catch_suffix = '';
            end

            % face-report relative RT (time from RSVP+face onset to the report, if any)
            if isfield(result, 'face_report_rt_prompt_s') && ~isnan(result.face_report_rt_prompt_s)
                face_report_rt_s = result.face_report_rt_prompt_s;
            elseif result.face_report.reported
                face_report_rt_s = result.face_report.report_abs_time_s - result.trial_start_vbl;
            else
                face_report_rt_s = NaN;
            end

            face_report_correct = result.face_report.reported && strcmp(result.face_report.side, trial.face_side);
            exclude_aware_leak = strcmpi(block.awareness, 'unaware') && ~result.is_catch && face_report_correct;

            append_csv_row(trial_log_path, [{ ...
                participant_id, b, block.attention, block.awareness, block.emotion, t, ...
                dominant_eye, trial_eff_sep, trial_left_dy, trial_right_dy, ...
                result.n_targets_requested, result.n_targets_actual, ...
                numel(trial.arrow_seq), numel(trial.arrow_seq) - result.n_targets_actual, ...
                result.response, result.rt_s, result.timed_out, result.correct, result.is_catch, ...
                trial.face_identity_id, trial.face_gender, trial.face_side, ...
                result.face_report.reported, result.face_report.side, face_report_rt_s, ...
                face_report_correct, exclude_aware_leak, cfg.face_contrast, ...
                result.trial_start_vbl, result.trial_rsvp_end_vbl}, ...
                arrow_seq_to_csv_cells(trial.arrow_seq, MAX_RSVP_ITEMS), ...
                {trial_recalib_ct}, ...
                {result.et_gate.status, result.et_gate.wait_s, result.et_gate.offset_x_deg, ...
                 result.et_gate.offset_y_deg, result.et_gate.n_menu}]);

            fprintf('  Trial %d/%d: targets=%d/%d, response=%s, correct=%d%s\n', ...
                t, n_trials, result.n_targets_actual, result.n_targets_requested, ...
                mat2str(result.response), result.correct, catch_suffix);

            log_trial_events(events_log_path, participant_id, b, t, result);

            % --- probe fires after this trial if it is one of the block's probe trials ---
            probe_idx = find(block.probe_trials == t, 1);
            probe_fired = ~isempty(probe_idx);
            if probe_fired
                fprintf('  -- Probe %d of %d --\n', probe_idx, numel(block.probe_trials));
                probe_cfg = cfg;
                probe_cfg.text_only_side = sides.dominant_screen_half;
                et_msg('PROBE_START block=%d trial=%d probe=%d', b, t, probe_idx);
                probe_result = run_probe_sequence(win, probe_cfg, winRect, frameTex, ctx.frameDestRects, ppd, schedule.probe1_order);
                et_msg('PROBE_END block=%d trial=%d probe=%d', b, t, probe_idx);
                append_csv_row(probe_log_path, { ...
                    participant_id, b, t, ...
                    probe_result.probe1_label, probe_result.probe1_rt_s, ...
                    probe_result.probe2_label, probe_result.probe2_rt_s, ...
                    probe_result.metaawareness, probe_result.metaawareness_rt_s, ...
                    probe_result.vividness, probe_result.vividness_rt_s, ...
                    probe_result.emotionality, probe_result.emotionality_rt_s, ...
                    probe_result.temporality, probe_result.temporality_rt_s, ...
                    probe_result.current_concerns, probe_result.current_concerns_rt_s, ...
                    probe_idx});

                fprintf('  Probe1: %s\n', probe_result.probe1_label);
            end

            % --- C pressed during this trial (or its probe): recalibrate now,
            % AFTER the trial's responses and any probe are fully recorded,
            % BEFORE the next trial ---
            calibrated_now = false;
            if key_flag('calib', 'get')
                if t == n_trials && b < n_blocks
                    % last trial of a block: the next block opens with the
                    % scheduled calibration screen, which covers this request
                    key_flag('calib', 'clear');
                    fprintf('  C pressed: the next block starts with the calibration screen anyway.\n');
                else
                    fprintf('  C pressed: recalibrating before the next trial.\n');
                    ctx = recalibrate_now(win, cfg, ppd, winRect, ctx, true);
                    calibrated_now = true;
                end
            end

            % --- same block continues: remind which arrows to count ---
            if (probe_fired || calibrated_now) && t < n_trials
                if probe_fired
                    reminder_lines = build_arrow_instruction_lines(block.attention, 'continue');
                else
                    reminder_lines = build_arrow_instruction_lines(block.attention, 'recalibrated');
                end
                ctx = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
                    @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, reminder_lines));
            end
        end

        % --- break between blocks (skip after the last block) ---
        if b < n_blocks
            break_msg = sprintf('Block %d of %d complete.\nTake a short break.\nPress any key to continue.', b, n_blocks);
            ctx = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
                @(c) draw_break_screen(win, cfg, frameTex, c, break_msg));
        end
    end

    % --- thank-you screen (C still works here) ---
    thanks_lines = {'Thank you for your participation', 'in our experiment!', '', 'Press any key to exit.'};
    ctx = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
        @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, thanks_lines));

    et_shutdown();   % close the EDF and copy it from the host PC into the data folder
    Screen('CloseAll');
    sca;
    fprintf('\nSession complete. %d blocks run, %d C-key recalibrations.\n', n_blocks, ctx.n_recalibrations);
    fprintf('Trial log: %s\nProbe log: %s\nEvents log: %s\n', trial_log_path, probe_log_path, events_log_path);

catch ME
    try, et_shutdown(); catch, end   % still rescue the EDF after an abort / error
    sca;
    fprintf('\nSession stopped: %s\n', ME.message);
    fprintf('Data written so far is saved in: %s\n', data_dir);
    rethrow(ME);
end


function draw_break_screen(win, cfg, frameTex, ctx, msg)
% Between-block break screen (text in both eyes' frames), drawn and flipped.
% Takes ctx so it follows the frames after a C-key recalibration.
    Screen('FillRect', win, cfg.background_rgb);
    Screen('DrawTexture', win, frameTex, [], ctx.frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], ctx.frameDestRects.right, 0, 0);
    Screen('TextSize', win, 16);
    DrawFormattedText(win, msg, ctx.frameDestRects.left(1)+70, 'center', [255 255 255]);
    DrawFormattedText(win, msg, ctx.frameDestRects.right(1)+70, 'center', [255 255 255]);
    Screen('Flip', win);
end


function cells = arrow_seq_to_csv_cells(arrow_seq, max_items)
% ARROW_SEQ_TO_CSV_CELLS  Flatten one trial's arrow sequence into a flat
% {color1, orientation1, color2, orientation2, ...} cell array padded
% with empty cells out to max_items, so every trial row in the CSV has
% the same number of columns regardless of that trial's actual sequence
% length. Order is chronological (item 1 = first arrow shown).
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
            'Trial had %d items, exceeding MAX_RSVP_ITEMS=%d -- extra items not logged. Increase MAX_RSVP_ITEMS in run_experiment_session.m.', ...
            n, max_items);
    end
end


function log_trial_events(events_log_path, participant_id, block_num, trial_num, result)
% LOG_TRIAL_EVENTS  Write one row per individual on-screen stimulus event
% for this trial to the events CSV, in chronological order: fixation
% onset, face onset, each arrow (in sequence), each mask frame (in
% sequence, unaware trials only), the response, and ITI onset.
    rows = {};

    if ~isnan(result.pretrial_fixation_onset_vbl)
        rows{end+1} = {participant_id, block_num, trial_num, 'pretrial_fixation_onset', 1, '', '', result.pretrial_fixation_onset_vbl};
    end
    rows{end+1} = {participant_id, block_num, trial_num, 'fixation_onset', 1, '', '', result.fixation_onset_vbl};
    rows{end+1} = {participant_id, block_num, trial_num, 'face_onset', 1, '', '', result.trial_start_vbl};

    for i = 1:numel(result.item_log)
        it = result.item_log(i);
        rows{end+1} = {participant_id, block_num, trial_num, 'arrow', i, it.color, it.orientation, it.actual_onset_s}; %#ok<AGROW>
    end

    for i = 1:numel(result.mask_event_log)
        mv = result.mask_event_log(i);
        rows{end+1} = {participant_id, block_num, trial_num, 'mask', i, '', mv.mask_id, mv.actual_onset_s}; %#ok<AGROW>
    end

    response_value = result.response;
    if isempty(response_value)
        response_value = '';
    end
    rows{end+1} = {participant_id, block_num, trial_num, 'response', 1, '', response_value, result.response_abs_time_s};

    if result.face_report.reported
        rows{end+1} = {participant_id, block_num, trial_num, 'face_report', 1, '', result.face_report.side, result.face_report.report_abs_time_s};
    end

    rows{end+1} = {participant_id, block_num, trial_num, 'iti_onset', 1, '', '', result.iti_onset_vbl};

    for i = 1:numel(rows)
        append_csv_row(events_log_path, rows{i});
    end
end
