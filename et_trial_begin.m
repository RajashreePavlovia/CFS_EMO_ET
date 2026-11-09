function gate = et_trial_begin(win, cfg, ppd, trial, awareness, frame_centers, frameTex, frameDestRects)
% ET_TRIAL_BEGIN  Start of every trial: label the trial in the EDF, start
% recording, write the interest-area definitions, and run the central
% fixation check ("gate"). Returns only once the participant has held gaze
% inside the central window for cfg.eyetracking.gate_hold_s (or the
% experimenter chose "start anyway").
%
%   gate = et_trial_begin(win, cfg, ppd, trial, awareness, frame_centers, frameTex, frameDestRects)
%
% OUTPUT gate: .status ('ok' | 'forced' | 'off'), .wait_s (time until the
% check was passed), .offset_x_deg / .offset_y_deg (mean gaze offset from the
% frame centre while fixating = a per-trial DRIFT estimate), .n_menu (how many
% times the experimenter menu was opened this trial).
%
% Recording runs from here to et_trial_end, so the time before the trial
% starts is available as the pupil baseline.
%
% Experimenter menu (after cfg.eyetracking.gate_timeout_s without a pass):
%   D = drift correction on the host (target appears in both frames; accept it on the host / press Space)
%   R = full EyeLink recalibration
%   Space = start the trial anyway (flagged 'forced')

    gate = struct('status', 'off', 'wait_s', NaN, 'offset_x_deg', NaN, 'offset_y_deg', NaN, 'n_menu', 0);
    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    E = cfg.eyetracking;
    C = S.context;

    geom = et_make_geom(win_rect(win), frame_centers, ppd, frameTex, frameDestRects);
    setappdata(0, 'cfs_et_geom', geom);
    et_state('set', struct('geom', geom));
    vc = geom.vc;

    label = sprintf('%s_b%02d_t%02d', C.session, C.block, C.trial);
    et_msg('TRIALID %s', label);
    et_msg('!V TRIAL_VAR session %s', C.session);
    et_msg('!V TRIAL_VAR block %d', C.block);
    et_msg('!V TRIAL_VAR trial %d', C.trial);
    et_msg('!V TRIAL_VAR attention %s', C.attention);
    et_msg('!V TRIAL_VAR awareness %s', awareness);
    et_msg('!V TRIAL_VAR emotion %s', C.emotion);
    et_msg('!V TRIAL_VAR face_side %s', trial.face_side);
    et_msg('!V TRIAL_VAR face_id %s%s', trial.face_gender, trial.face_identity_id);
    et_msg('!V TRIAL_VAR n_targets %d', trial.n_targets);
    et_msg('!V TRIAL_VAR is_catch %d', double(isfield(trial, 'is_catch') && trial.is_catch));

    write_interest_areas(cfg, geom, trial.face_side);

    if isfield(E, 'drift_correct_every_trial') && E.drift_correct_every_trial
        et_msg('DRIFT_CORRECT_START');
        if strcmp(S.mode, 'live')
            % must run while NOT recording; the target is drawn in both frames by the patched callback
            if EyelinkDoDriftCorrection(S.el, round(vc(1)), round(vc(2)), 1, 1) ~= 1
                error('et_trial_begin:driftFailed', 'EyeLink drift correction failed or the tracker disconnected.');
            end
        end
        et_msg('DRIFT_CORRECT_DONE');
    end

    start_recording(S, label);

    r_px = E.gate_radius_deg * ppd;
    t_on = show_gate_screen(win, cfg, ppd, frameTex, frameDestRects, frame_centers);
    et_msg('GATE_ON vbl=%.6f', t_on);

    escKey = KbName('ESCAPE');
    in_since = NaN;
    buf = zeros(0, 2);
    t_wait0 = t_on;
    passed = false;
    forced = false;

    while ~passed
        [gx, gy, ok] = et_get_gaze(win);
        now = GetSecs;
        if ok && hypot(gx - vc(1), gy - vc(2)) <= r_px
            if isnan(in_since)
                in_since = now;
                buf = zeros(0, 2);
            end
            buf(end+1, :) = [gx gy]; %#ok<AGROW>
            if now - in_since >= E.gate_hold_s
                passed = true;
            end
        else
            in_since = NaN;
        end

        [kd, ~, kc] = KbCheck;
        if kd && kc(escKey)
            error('et_trial_begin:userAbort', 'User pressed Escape -- aborting.');
        end

        if ~passed && (now - t_wait0) > E.gate_timeout_s
            gate.n_menu = gate.n_menu + 1;
            choice = experimenter_menu(win, cfg, ppd, frameTex, frameDestRects);
            switch choice
                case 'drift'
                    stop_recording(S);
                    et_msg('DRIFT_CORRECT_START');
                    if strcmp(S.mode, 'live')
                        EyelinkDoDriftCorrection(S.el, round(vc(1)), round(vc(2)), 1, 1);
                    end
                    et_msg('DRIFT_CORRECT_DONE');
                    start_recording(S, label);
                case 'recal'
                    stop_recording(S);
                    et_msg('RECALIBRATION_REQUESTED');
                    ctx_like = struct('centers', frame_centers, 'frameDestRects', frameDestRects, 'block_num', C.block);
                    et_calibrate(win, cfg, ppd, win_rect(win), ctx_like, frameTex);
                    start_recording(S, label);
                case 'force'
                    forced = true;
                    passed = true;
            end
            t_on = show_gate_screen(win, cfg, ppd, frameTex, frameDestRects, frame_centers);
            et_msg('GATE_ON vbl=%.6f', t_on);
            t_wait0 = GetSecs;
            in_since = NaN;
        end
        WaitSecs(0.002);
    end

    gate.wait_s = GetSecs - t_on;
    if forced
        gate.status = 'forced';
    else
        gate.status = 'ok';
        m = mean(buf, 1);
        gate.offset_x_deg = (m(1) - vc(1)) / ppd;
        gate.offset_y_deg = (m(2) - vc(2)) / ppd;
    end
    et_msg('GATE_PASS status=%s wait=%.3f dx_deg=%.3f dy_deg=%.3f', gate.status, gate.wait_s, ...
        gate.offset_x_deg, gate.offset_y_deg);
end


function rect = win_rect(win)
    rect = Screen('Rect', win);
end


function start_recording(S, label)
    if strcmp(S.mode, 'live')
        Eyelink('Command', sprintf('record_status_message "%s"', label));
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.05);
        Eyelink('StartRecording');
        WaitSecs(0.1);
        err = Eyelink('CheckRecording');
        if err ~= 0
            error('et_trial_begin:recordingFailed', 'EyeLink could not start recording (CheckRecording = %d).', err);
        end
    end
end


function stop_recording(S)
    if strcmp(S.mode, 'live')
        WaitSecs(0.05);
        Eyelink('StopRecording');
    end
end


function t = show_gate_screen(win, cfg, ppd, frameTex, frameDestRects, centers)
    Screen('FillRect', win, cfg.background_rgb);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);
    span = cfg.fixation_cross_deg * ppd;
    thk = max(2, round(cfg.fixation_cross_thickness_deg * ppd));
    draw_fixation_cross(win, centers.left,  span, thk, [255 255 255]);
    draw_fixation_cross(win, centers.right, span, thk, [255 255 255]);
    t = Screen('Flip', win);
end


function choice = experimenter_menu(win, cfg, ppd, frameTex, frameDestRects)
    lines = {'EXPERIMENTER', '', 'Gaze not at the centre.', '', ...
        'D = drift correction', 'R = recalibrate', 'Space = start trial anyway'};
    draw_probe_screen(win, cfg, frameTex, [], frameDestRects, ppd, lines);
    Screen('Flip', win);
    KbReleaseWait;
    kD = KbName('d'); kR = KbName('r'); kSp = KbName('space'); kEsc = KbName('ESCAPE');
    choice = '';
    while isempty(choice)
        [kd, ~, kc] = KbCheck;
        if kd
            if kc(kEsc)
                error('et_trial_begin:userAbort', 'User pressed Escape -- aborting.');
            elseif kc(kD)
                choice = 'drift';
            elseif kc(kR)
                choice = 'recal';
            elseif kc(kSp)
                choice = 'force';
            end
        end
        WaitSecs(0.005);
    end
    KbReleaseWait;
end


function write_interest_areas(cfg, geom, face_side)
% Interest areas in virtual-screen pixels, as Data Viewer IAREA messages.
% Priority when they overlap (used by the analysis script): 1 RSVP, 2 FACE, 3 FACE_OPPOSITE, 4 FRAME.
    E = cfg.eyetracking;
    ppd = geom.ppd; vc = geom.vc;
    sgn = 1; if strcmpi(face_side, 'left'), sgn = -1; end
    ecc = cfg.face_eccentricity_deg * ppd;
    fw = (cfg.face_width_deg  + 2 * E.ia_face_margin_deg) * ppd;
    fh = (cfg.face_height_deg + 2 * E.ia_face_margin_deg) * ppd;
    rh = E.ia_rsvp_half_deg * ppd;
    fr = cfg.fusion_frame_deg / 2 * ppd;

    ia_msg(1, vc(1) - rh, vc(2) - rh, vc(1) + rh, vc(2) + rh, 'RSVP');
    ia_msg(2, vc(1) + sgn*ecc - fw/2, vc(2) - fh/2, vc(1) + sgn*ecc + fw/2, vc(2) + fh/2, 'FACE');
    ia_msg(3, vc(1) - sgn*ecc - fw/2, vc(2) - fh/2, vc(1) - sgn*ecc + fw/2, vc(2) + fh/2, 'FACE_OPPOSITE');
    ia_msg(4, vc(1) - fr, vc(2) - fr, vc(1) + fr, vc(2) + fr, 'FRAME');
end


function ia_msg(id, x1, y1, x2, y2, name)
    et_msg('!V IAREA RECTANGLE %d %d %d %d %d %s', id, round(x1), round(y1), round(x2), round(y2), name);
end
