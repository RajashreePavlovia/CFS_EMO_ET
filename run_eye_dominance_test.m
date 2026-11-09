function dominant_eye = run_eye_dominance_test(win, winRect, cfg, ifi, ppd, frameTex, frameSizePx, ...
    maskTextures, participant_id, data_dir, timestamp)
% RUN_EYE_DOMINANCE_TEST  Sensory (CFS-based) eye-dominance screening.
%
%   dominant_eye = run_eye_dominance_test(win, winRect, cfg, ifi, ppd, frameTex, ...
%       frameSizePx, maskTextures, participant_id, data_dir, timestamp)
%
% CHANGES IN THIS VERSION vs. the first draft:
%   - All three emotions (happy/angry/neutral) are loaded and one is
%     picked at random per trial (logged), not neutral-only.
%   - Faces are loaded with a computed alpha channel (corner-seeded flood
%     fill, feathered) so any flat background baked into the practice
%     images -- black or otherwise -- renders transparent instead of as a
%     solid box. If a file already has a real alpha channel, that is used
%     instead of the computed one.
%   - Face size for THIS task only is 2.8 x 4.0 deg (width x height),
%     overriding cfg.face_width_deg/face_height_deg locally -- the main
%     task and practice are untouched.
%
% Mask-eye assignment and face side are independently randomized and
% balanced across 60 trials, interleaved (not blocked), max 3 consecutive
% repeats of either. A CFS mask ramps 100%->0% in one eye while a face
% ramps 0%->100% in the other over 5 s; participant reports the face's
% side (Left/Right) as soon as detected, or within 10 s. The eye in which
% the mask produced the LONGER average response time is the dominant eye.
%
% Uses the SQUARE fusion frame from the main task, not the circular frame
% described in the cited procedure. [DECISION NEEDED if strict fidelity matters]
%
% OUTPUT
%   dominant_eye - 'left' or 'right'
%
% Saves data\p<ID>_eyedom.mat and data\p<ID>_eyedom_trials_<timestamp>.csv.

    KbName('UnifyKeyNames');
    escKey   = KbName('ESCAPE');
    leftKey  = KbName(cfg.keys.face_report_keys.left);
    rightKey = KbName(cfg.keys.face_report_keys.right);

    n_trials = 60;
    ramp_s = 5.0;
    max_duration_s = 10.0;
    mask_hz = cfg.mask_update_hz;
    n_frames_per_mask = max(1, round(1/mask_hz / ifi));

    EYEDOM_FACE_WIDTH_DEG  = 2.8;   % <-- ADJUST: this task's face width (local override)
    EYEDOM_FACE_HEIGHT_DEG = 4.0;   % <-- ADJUST: this task's face height (local override)

    [faceTextures, identities] = load_eyedom_faces(win, cfg);

    screenRect = winRect;
    centers = compute_frame_centers(screenRect, cfg.calibration_initial_separation_px);
    frameDestRects = struct();
    frameDestRects.left  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    frameDestRects.right = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    % --- fusion check / calibration, same control scheme as the main task ---
    separation_px = run_fusion_calibration(win, cfg, ppd, 0, participant_id);
    centers = compute_frame_centers(screenRect, separation_px);
    frameDestRects.left  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
    frameDestRects.right = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

    intro = {'EYE DOMINANCE TEST', '', ...
        'A flickering pattern will appear in one eye while a face slowly', ...
        'fades in on the other side.', '', ...
        sprintf('As soon as you see the face, press %s if it is on the LEFT,', ...
            key_label(cfg.keys.face_report_keys.left)), ...
        sprintf('or %s if it is on the RIGHT.', key_label(cfg.keys.face_report_keys.right)), ...
        '', 'Press any key to begin.'};
    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, intro);
    Screen('Flip', win);
    wait_any_key_local();

    mask_eye_seq = generate_max_run_sequence({'left','right'}, n_trials, 3);
    face_side_seq = generate_max_run_sequence({'left','right'}, n_trials, 3);

    log_path = fullfile(data_dir, sprintf('p%d_eyedom_trials_%s.csv', participant_id, timestamp));
    append_csv_row(log_path, {'participant_id','trial_num','mask_eye','target_eye','face_side', ...
        'face_identity_id','face_gender','face_emotion','response_side','correct','rt_s','timed_out'});

    results = struct('mask_eye', {}, 'face_side', {}, 'response_side', {}, 'correct', {}, 'rt_s', {}, 'timed_out', {});

    n_ids = numel(identities);
    id_queue = [];
    mask_id = 0;
    emo_list = {'happy','angry','neutral'};

    for t = 1:n_trials
        mask_eye = mask_eye_seq{t};
        if strcmpi(mask_eye, 'left')
            target_eye = 'right';
        else
            target_eye = 'left';
        end
        face_side = face_side_seq{t};

        if isempty(id_queue)
            id_queue = randperm(n_ids);
        end
        identity = identities(id_queue(1));
        id_queue(1) = [];
        emotion = emo_list{randi(3)};

        [response_side, correct, rt_s, timed_out, mask_id] = run_eyedom_trial(win, cfg, ifi, ppd, ...
            frameTex, frameDestRects, centers, mask_eye, target_eye, face_side, ...
            identity, emotion, faceTextures, maskTextures, ramp_s, max_duration_s, n_frames_per_mask, mask_id, ...
            escKey, leftKey, rightKey, EYEDOM_FACE_WIDTH_DEG, EYEDOM_FACE_HEIGHT_DEG);

        results(end+1) = struct('mask_eye', mask_eye, 'face_side', face_side, ...
            'response_side', response_side, 'correct', correct, 'rt_s', rt_s, 'timed_out', timed_out); %#ok<AGROW>

        append_csv_row(log_path, {participant_id, t, mask_eye, target_eye, face_side, ...
            identity.id, identity.gender, emotion, response_side, correct, rt_s, timed_out});

        fprintf('  Trial %d/%d: mask=%s eye, face=%s side (%s), response=%s, correct=%d, rt=%.2fs%s\n', ...
            t, n_trials, mask_eye, face_side, emotion, response_side, correct, rt_s, ternary(timed_out, ' [TIMEOUT]', ''));

        if mod(t, 15) == 0 && t < n_trials
            draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, ...
                {'Short break.', '', sprintf('%d of %d trials done.', t, n_trials), '', 'Press any key to continue.'});
            Screen('Flip', win);
            wait_any_key_local();
        end
    end

    mask_eyes = {results.mask_eye};
    rts = [results.rt_s];
    timed_out_flags = [results.timed_out];
    correct_flags = [results.correct];
    valid = ~timed_out_flags & correct_flags;   % RT means use CORRECT, non-timeout trials only

    n_incorrect_excluded = sum(~timed_out_flags & ~correct_flags);

    rt_mask_left  = mean(rts(valid & strcmp(mask_eyes, 'left')));
    rt_mask_right = mean(rts(valid & strcmp(mask_eyes, 'right')));
    rt_ratio_left_over_right = rt_mask_left / rt_mask_right;   % >1 = left-eye masking suppressed longer (left dominant); <1 = right dominant
    n_timeouts = sum(timed_out_flags);
    acc_overall = mean([results(valid).correct]);

    if rt_ratio_left_over_right > 1
        dominant_eye = 'left';
    else
        dominant_eye = 'right';
    end

    fprintf('\n================ EYE DOMINANCE RESULTS ================\n');
    fprintf('Mean RT with mask in LEFT eye  (target in right): %.3f s\n', rt_mask_left);
    fprintf('Mean RT with mask in RIGHT eye (target in left):  %.3f s\n', rt_mask_right);
    fprintf('RT ratio (left-mask mean RT / right-mask mean RT): %.3f\n', rt_ratio_left_over_right);
    fprintf('Timeouts (excluded from means): %d / %d\n', n_timeouts, n_trials);
    fprintf('Overall accuracy (non-timeout trials): %.0f%%\n', 100*acc_overall);
    fprintf('--> Dominant eye (longer suppression when masked): %s\n', upper(dominant_eye));

    eyedom = struct('participant_id', participant_id, 'dominant_eye', dominant_eye, ...
        'rt_mask_left', rt_mask_left, 'rt_mask_right', rt_mask_right, ...
        'rt_ratio_left_over_right', rt_ratio_left_over_right, ...
        'n_timeouts', n_timeouts, 'accuracy', acc_overall, 'results', results, 'timestamp', timestamp);
    save(fullfile(data_dir, sprintf('p%d_eyedom.mat', participant_id)), 'eyedom');

    draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, ...
        {'Eye dominance test complete.', '', 'Please wait for the experimenter.'});
    Screen('Flip', win);
end


%% ====================== trial logic ======================

function [response_side, correct, rt_s, timed_out, mask_id] = run_eyedom_trial(win, cfg, ifi, ppd, ...
    frameTex, frameDestRects, centers, mask_eye, target_eye, face_side, identity, emotion, ...
    faceTextures, maskTextures, ramp_s, max_duration_s, n_frames_per_mask, mask_id, ...
    escKey, leftKey, rightKey, face_w_deg, face_h_deg)

    maskCenter = centers.(mask_eye);
    targetCenter = centers.(target_eye);

    key = face_texture_key(identity.id, identity.gender, emotion);
    tex = faceTextures(key);

    total_frames = round(max_duration_s / ifi);

    onset = GetSecs;
    response_side = '';
    rt_s = NaN;
    timed_out = false;
    last_mask_frame_idx = -1;

    for f = 1:total_frames
        t_elapsed = (f-1) * ifi;
        if t_elapsed >= ramp_s
            faceContrast = 1.0;
            maskContrast = 0.0;
        else
            frac = t_elapsed / ramp_s;
            faceContrast = frac;
            maskContrast = 1 - frac;
        end

        Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
        Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);

        mask_frame_idx = floor((f-1) / n_frames_per_mask) + 1;
        if mask_frame_idx ~= last_mask_frame_idx
            mask_id = mod(mask_id, numel(maskTextures)) + 1;
            last_mask_frame_idx = mask_frame_idx;
        end
        if maskContrast > 0
            draw_mask_scaled(win, maskTextures, cfg, ppd, maskCenter, mask_id, maskContrast);
        end

        cfg_t = cfg;
        cfg_t.face_contrast = faceContrast;
        cfg_t.face_width_deg = face_w_deg;
        cfg_t.face_height_deg = face_h_deg;
        draw_face_texture(win, cfg_t, ppd, targetCenter, tex, face_side);

        [keyIsDown, secs, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_eye_dominance_test:userAbort', 'User pressed Escape -- aborting.');
            end
            if isempty(response_side) && keyCode(leftKey)
                response_side = 'left';
                rt_s = secs - onset;
            elseif isempty(response_side) && keyCode(rightKey)
                response_side = 'right';
                rt_s = secs - onset;
            end
        end

        Screen('Flip', win);

        if ~isempty(response_side)
            break;
        end
    end

    if isempty(response_side)
        timed_out = true;
        correct = false;
    else
        correct = strcmp(response_side, face_side);
    end
    while KbCheck; end
end


function draw_mask_scaled(win, maskTextures, cfg, ppd, center, mask_id, contrast)
    mask_w_px = cfg.fusion_frame_deg * ppd;
    dstRect = CenterRectOnPointd([0 0 mask_w_px mask_w_px], center(1), center(2));

    [srcOld, dstOld] = Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    Screen('DrawTexture', win, maskTextures(mask_id), [], dstRect, 0, [], contrast);
    Screen('BlendFunction', win, srcOld, dstOld);
end


%% ====================== helpers ======================

function [faceTextures, identities] = load_eyedom_faces(win, cfg)
% Loads ALL THREE emotions for each practice identity. Builds a
% transparent background: if the file has a real alpha channel, that is
% used; otherwise one is computed via corner-seeded flood fill (works for
% black, gray, or any other flat fill, without a global brightness
% threshold that could eat into dark hair).
    root = cfg.practice_face_folder_root;
    files = dir(fullfile(root, '**', '*.*'));
    files = files(~[files.isdir]);

    faceTextures = containers.Map();
    identities = struct('id', {}, 'gender', {});
    seen = {};
    emo_names = fieldnames(cfg.face_emotion_code);
    featherPx = 6;    % <-- ADJUST: feather width (px) for the computed alpha edge
    bgTol = 0.06;     % <-- ADJUST: color-matching tolerance for the flood fill (0-1)

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

        fpath = fullfile(files(i).folder, files(i).name);
        [imgRaw, ~, alphaRaw] = imread(fpath);

        if size(imgRaw, 3) == 3
            imgGray = rgb2gray(imgRaw);
        else
            imgGray = imgRaw;
        end
        imgGray = im2double(imgGray);

        if ~isempty(alphaRaw)
            alphaMap = im2double(alphaRaw);
        else
            alphaMap = compute_bg_alpha(imgGray, bgTol, featherPx);
        end

        rgba = cat(3, uint8(imgGray*255), uint8(alphaMap*255));
        tex = Screen('MakeTexture', win, rgba);
        faceTextures(face_texture_key(id, gender, emotion)) = tex;

        idkey = [gender '_' id];
        if ~ismember(idkey, seen)
            seen{end+1} = idkey; %#ok<AGROW>
            identities(end+1) = struct('id', id, 'gender', gender); %#ok<AGROW>
        end
    end

    if isempty(identities)
        error('run_eye_dominance_test:noFaces', 'No practice faces found under %s', root);
    end

    for i = 1:numel(identities)
        for e = 1:numel(emo_names)
            key = face_texture_key(identities(i).id, identities(i).gender, emo_names{e});
            if ~isKey(faceTextures, key)
                warning('run_eye_dominance_test:missingEmotion', ...
                    'Missing %s for identity %s%s -- that identity/emotion will error if drawn.', ...
                    emo_names{e}, identities(i).gender, identities(i).id);
            end
        end
    end
end


function alphaMap = compute_bg_alpha(imgGray, tol, featherPx)
% Flood-fill from the image border (corners + edge midpoints) to find the
% connected background region within color tolerance `tol`, then feather
% its boundary. Requires Image Processing Toolbox (grayconnected, bwdist).
    [h, w] = size(imgGray);
    seeds = [1 1; 1 w; h 1; h w; ...
        1 max(1,round(w/2)); h max(1,round(w/2)); ...
        max(1,round(h/2)) 1; max(1,round(h/2)) w];

    bgMask = false(h, w);
    for s = 1:size(seeds, 1)
        r = seeds(s,1); c = seeds(s,2);
        bgMask = bgMask | grayconnected(imgGray, r, c, tol);
    end

    faceMask = ~bgMask;
    dist = bwdist(~faceMask);
    alphaMap = min(dist/featherPx, 1);
    alphaMap(~faceMask) = 0;
end


function wait_any_key_local()
    escKey = KbName('ESCAPE');
    while KbCheck; end
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(escKey)
                error('run_eye_dominance_test:userAbort', 'User pressed Escape -- aborting.');
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
