function [accuracy, passed] = run_arrow_samediff_task(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, ...
    participant_id, data_dir, timestamp)
% RUN_ARROW_SAMEDIFF_TASK  Sequential same/different arrow-color
% discrimination task. Used as a quick color-vision screen: a participant
% who cannot reliably tell these 6 colors apart will score near chance.
%
%   [accuracy, passed] = run_arrow_samediff_task(win, winRect, cfg, ifi, ppd, frameTex, ...
%       frameSizePx, participant_id, data_dir, timestamp)
%
% OUTPUTS
%   accuracy - proportion correct over non-timeout trials
%   passed   - accuracy >= cfg.samediff_pass_threshold (default 0.90)
%
% On each trial, two arrows are shown one after another (both upright,
% centered in the fusion frame, identical in both eyes -- no CFS/mask
% involved). The participant reports whether the two arrows were the SAME
% color or DIFFERENT colors.
%
% TRIAL SET: every ordered pair of the 6 arrow colors (6x6 = 36 pairs),
% each repeated 3 times = 108 trials, fully shuffled. This gives only 6
% "same"-color pairs (the diagonal) vs. 30 "different" pairs per
% repetition set -- i.e. same:different trials run about 1:5, NOT
% balanced 50/50. [DECISION NEEDED: oversample the 6 same pairs if a
% balanced same/different split is wanted for accuracy analysis.]
%
% Both arrows are drawn upright (orientation is not part of the judgment
% here). [DECISION NEEDED if orientation should also vary/matter.]
%
% RESPONSE KEYS: cfg.keys.samediff_keys.same / .different if defined in
% config_experiment.m, else defaults to '0' (same) and '2' (different). Digit keys
% work on both the main number row and the numeric keypad.
% Escape aborts.
%
% Saves data\p<ID>_samediff_trials_<timestamp>.csv and a .mat summary.

    KbName('UnifyKeyNames');
    escKey = KbName('ESCAPE');

    sameKeyName = cfg_val(cfg, 'samediff_key_same', '0');
    diffKeyName = cfg_val(cfg, 'samediff_key_different', '2');
    if isfield(cfg, 'keys') && isfield(cfg.keys, 'samediff_keys')
        sameKeyName = cfg.keys.samediff_keys.same;
        diffKeyName = cfg.keys.samediff_keys.different;
    end
    sameKey = response_key_codes(sameKeyName);   % may be several codes (main-row AND keypad digit)
    diffKey = response_key_codes(diffKeyName);

    arrow1_dur_s = cfg_val(cfg, 'samediff_arrow1_duration_s', 0.5);
    isi_s        = cfg_val(cfg, 'samediff_isi_s', 0.3);
    arrow2_dur_s = cfg_val(cfg, 'samediff_arrow2_duration_s', 0.5);
    max_resp_s   = cfg_val(cfg, 'samediff_max_response_s', 3.0);
    reps         = cfg_val(cfg, 'samediff_reps', 3);
    n_break_every = cfg_val(cfg, 'samediff_break_every', 27);
    pass_threshold = cfg_val(cfg, 'samediff_pass_threshold', 0.90);   % <-- ADJUST: pass/fail cutoff

    % --- fusion calibration ---
    separation_px = run_fusion_calibration(win, cfg, ppd, 0, participant_id);
    centers = compute_frame_centers(winRect, separation_px);
    frameDestRects = struct();
    frameDestRects.left  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    frameDestRects.right = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    intro = {'ARROW TASK', '', ...
        'Two arrows will appear one after another at the centre.', '', ...
        sprintf('Press %s if they were the SAME color.', key_label(sameKeyName)), ...
        sprintf('Press %s if they were DIFFERENT colors.', key_label(diffKeyName)), ...
        '', 'Press any key to begin.'};
    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, intro);
    Screen('Flip', win);
    wait_any_key_local(escKey);

    % --- build trial list: every ordered color pair, x reps, shuffled ---
    colorNames = fieldnames(cfg.colors);
    pairs = {};
    for i = 1:numel(colorNames)
        for j = 1:numel(colorNames)
            pairs{end+1} = {colorNames{i}, colorNames{j}}; %#ok<AGROW>
        end
    end
    trial_list = repmat(pairs, 1, reps);
    trial_list = trial_list(randperm(numel(trial_list)));
    n_trials = numel(trial_list);

    log_path = fullfile(data_dir, sprintf('p%d_samediff_trials_%s.csv', participant_id, timestamp));
    append_csv_row(log_path, {'participant_id','trial_num','color1','color2','is_same_actual', ...
        'response','correct','rt_s','timed_out'});

    n_hits = 0;
    n_valid = 0;

    for t = 1:n_trials
        color1 = trial_list{t}{1};
        color2 = trial_list{t}{2};
        is_same_actual = strcmp(color1, color2);

        % --- arrow 1 ---
        draw_centered_arrows(win, cfg, frameTex, frameDestRects, cfg.colors.(color1));
        Screen('Flip', win);
        WaitSecs(arrow1_dur_s);

        % --- ISI (blank frames) ---
        Screen('FillRect', win, cfg.background_rgb);
        Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
        Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
        Screen('Flip', win);
        WaitSecs(isi_s);

        % --- arrow 2 + response window ---
        % The response window opens at the ONSET of arrow 2: a key press
        % during the arrow counts, and RT is measured from the arrow-2 flip.
        % The arrow stays up for arrow2_dur_s, then the "Same or different?"
        % prompt replaces it; the window closes max_resp_s after arrow-2 onset.
        while KbCheck; end   % ignore a key still held from before
        draw_centered_arrows(win, cfg, frameTex, frameDestRects, cfg.colors.(color2));
        onset = Screen('Flip', win);   % arrow-2 onset = response-window onset

        response = '';
        rt_s = NaN;
        timed_out = false;
        prompt_shown = false;
        while (GetSecs - onset) < max_resp_s
            if ~prompt_shown && (GetSecs - onset) >= arrow2_dur_s
                draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, {'Same or different?'});
                Screen('Flip', win);
                prompt_shown = true;
                if ~isempty(response)
                    break;   % answered during the arrow; arrow has now run its full duration
                end
            end
            if isempty(response)
                [keyIsDown, secs, keyCode] = KbCheck;
                if keyIsDown
                    if keyCode(escKey)
                        error('run_arrow_samediff_task:userAbort', 'User pressed Escape -- aborting.');
                    end
                    if any(keyCode(sameKey))
                        response = 'same';
                        rt_s = secs - onset;
                        if prompt_shown, break; end
                    elseif any(keyCode(diffKey))
                        response = 'different';
                        rt_s = secs - onset;
                        if prompt_shown, break; end
                    end
                end
            end
            WaitSecs(0.001);
        end
        while KbCheck; end

        if isempty(response)
            timed_out = true;
            correct = false;
        else
            correct = (strcmp(response, 'same') == is_same_actual);
            n_valid = n_valid + 1;
            n_hits = n_hits + double(correct);
        end

        append_csv_row(log_path, {participant_id, t, color1, color2, is_same_actual, ...
            response, correct, rt_s, timed_out});

        fprintf('  Trial %d/%d: %s vs %s (actual=%s), response=%s, correct=%d%s\n', ...
            t, n_trials, color1, color2, ternary(is_same_actual,'same','diff'), response, correct, ...
            ternary(timed_out, ' [TIMEOUT]', ''));

        if mod(t, n_break_every) == 0 && t < n_trials
            draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, ...
                {'Short break.', '', sprintf('%d of %d trials done.', t, n_trials), '', 'Press any key to continue.'});
            Screen('Flip', win);
            wait_any_key_local(escKey);
        end
    end

    accuracy = n_hits / max(1, n_valid);
    passed = accuracy >= pass_threshold;

    fprintf('\n================ SAME/DIFFERENT (COLOR SCREEN) COMPLETE ================\n');
    fprintf('Accuracy (non-timeout trials): %.0f%% (%d/%d)\n', 100*accuracy, n_hits, n_valid);
    fprintf('Pass threshold: %.0f%% --> %s\n', 100*pass_threshold, ternary(passed, 'PASS', 'FAIL'));

    samediff = struct('participant_id', participant_id, 'n_trials', n_trials, ...
        'accuracy', accuracy, 'pass_threshold', pass_threshold, 'passed', passed, 'timestamp', timestamp);
    save(fullfile(data_dir, sprintf('p%d_samediff.mat', participant_id)), 'samediff');

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, ...
        {'Task complete.', '', 'Please wait for the experimenter.'});
    Screen('Flip', win);
end


function draw_centered_arrows(win, cfg, frameTex, frameDestRects, color_rgb)
    Screen('FillRect', win, cfg.background_rgb);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);

    leftCenter = [(frameDestRects.left(1)+frameDestRects.left(3))/2, (frameDestRects.left(2)+frameDestRects.left(4))/2];
    rightCenter = [(frameDestRects.right(1)+frameDestRects.right(3))/2, (frameDestRects.right(2)+frameDestRects.right(4))/2];

    draw_arrow(win, leftCenter,  cfg.arrow_height_px, cfg.arrow_width_px, 'up', color_rgb);
    draw_arrow(win, rightCenter, cfg.arrow_height_px, cfg.arrow_width_px, 'up', color_rgb);
end


function codes = response_key_codes(name)
% Key code(s) for a response key. For a digit ('0'-'9') this returns the codes
% of BOTH the main-row key (KbName '0)') and the keypad key (KbName '0'), so
% either works. For any other name it is just KbName(name).
    KbName('UnifyKeyNames');
    if ischar(name) && numel(name) == 1 && isstrprop(name, 'digit')
        all_names = KbName('KeyNames');
        codes = [];
        for k = 1:numel(all_names)
            nm = all_names{k};
            if ~isempty(nm) && ischar(nm) && numel(nm) <= 2 && nm(1) == name
                codes(end+1) = k; %#ok<AGROW>
            end
        end
        if isempty(codes)
            codes = KbName(name);
        end
    else
        codes = KbName(name);
    end
end


function wait_any_key_local(escKey)
    while KbCheck; end
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_arrow_samediff_task:userAbort', 'User pressed Escape -- aborting.');
            end
            while KbCheck; end
            return;
        end
        WaitSecs(0.001);
    end
end


function s = key_label(k)
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


function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end


function v = cfg_val(cfg, field, default)
    if isfield(cfg, field) && ~isempty(cfg.(field))
        v = cfg.(field);
    else
        v = default;
    end
end
