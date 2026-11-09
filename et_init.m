function et_init(win, winRect, cfg, ppd, participant_id, session_type, data_dir)
% ET_INIT  Start eye tracking for this session (call once, right after the
% PTB window is open). Does nothing if cfg.eyetracking.mode is 'off'.
%
%   et_init(win, winRect, cfg, ppd, participant_id, session_type, data_dir)
%
% 'live'  : connects to the EyeLink host, configures it for BINOCULAR
%           recording at cfg.eyetracking.sample_rate_hz, tells it that its
%           screen is the VIRTUAL single-eye screen (one display half, see
%           et_make_geom), and opens the EDF file on the host.
% 'dummy' : no tracker; gaze = mouse, messages go to a text file.
%
% EDF file name (host allows max 8 characters): <session letter><id 3 digits><HHMM>,
% e.g. participant 12, main session, started 14:17 -> m0121417.

    E = cfg.eyetracking;
    S = struct();
    S.mode = lower(E.mode);
    S.data_dir = data_dir;
    S.calibrated = false;

    if strcmp(S.mode, 'off')
        et_state('set', S);
        return;
    end
    if ~ismember(S.mode, {'dummy', 'live'})
        error('et_init:badMode', 'cfg.eyetracking.mode must be off, dummy or live (got %s).', S.mode);
    end

    W = winRect(3) - winRect(1);
    H = winRect(4) - winRect(2);
    S.virtual = struct('W', W/2, 'H', H, 'c', [W/4, H/2]);

    letters = struct('practice', 'p', 'main', 'm', 'eyedom', 'e', 'samediff', 's');
    if isfield(letters, session_type)
        sl = letters.(session_type);
    else
        sl = 'x';
    end
    S.edf_name = sprintf('%s%03d%s', sl, mod(participant_id, 1000), datestr(now, 'HHMM'));

    setappdata(0, 'cfs_et_cfg', E);      % read by cfs_draw_cal_target
    setappdata(0, 'cfs_et_geom', []);

    if strcmp(S.mode, 'dummy')
        S.dummy_log = fullfile(data_dir, sprintf('p%d_eyelink_dummy_messages_%s.txt', participant_id, S.edf_name));
        fid = fopen(S.dummy_log, 'w');
        if fid > 0, fclose(fid); end
        et_state('set', S);
        fprintf('Eye tracking: DUMMY mode (gaze = mouse; hover over the fixation cross in the LEFT half).\n');
        fprintf('  Messages that would go to the EDF are written to %s\n', S.dummy_log);
        return;
    end

    %% ---- live ----
    if exist('Eyelink', 'file') ~= 3 && exist('Eyelink', 'file') ~= 2
        error('et_init:noToolbox', ['The Eyelink toolbox is not on the MATLAB path. It ships with Psychtoolbox; ' ...
            'type  which Eyelink  in the command window to check. See EYETRACKING_README.md.']);
    end
    if ~strcmp(E.host_ip, '100.1.1.1')
        Eyelink('SetAddress', E.host_ip);
    end
    if EyelinkInit(0, 1) ~= 1
        error('et_init:connectFailed', 'Could not connect to the EyeLink host (check the cable, the host IP and that the host is in the Offline screen).');
    end

    % the calibration targets are drawn by PsychEyelinkDispatchCallback.m; the project
    % copy must contain our one-line patch or only ONE eye would see each target
    cb = which('PsychEyelinkDispatchCallback');
    patched = false;
    if ~isempty(cb)
        try
            patched = contains(fileread(cb), 'cfs_draw_cal_target');
        catch
        end
    end
    if ~patched
        warning('et_init:callbackNotPatched', ['PsychEyelinkDispatchCallback.m (%s) is NOT patched for the stereoscope: ' ...
            'calibration targets will appear in only one eye''s half. See EYETRACKING_README.md, step 3.'], cb);
    end

    el = EyelinkInitDefaults(win);
    el.backgroundcolour = cfg.background_rgb;
    el.foregroundcolour = [0 0 0];
    el.msgfontcolour = [0 0 0];
    el.imgtitlecolour = [0 0 0];
    el.calibrationtargetcolour = E.cal_target_rgb;
    EyelinkUpdateDefaults(el);
    S.el = el;

    et_state('set', S);   % from here on et_shutdown (also called by the error handler) can close the connection

    [~, vs] = Eyelink('GetTrackerVersion');
    fprintf('Eye tracking: LIVE, connected to %s\n', vs);

    % virtual single-eye screen: one display half, at the optical viewing distance
    Wv = W / 2;
    half_w_mm = 10 * cfg.screen_width_cm / 2;      % physical width of ONE half of the screen
    half_h_mm = 10 * cfg.screen_height_cm;
    % NOTE: the Eyelink() mex only accepts WHOLE numbers as extra arguments (a fractional one such as
    % ppd = 57.91 gives "Supplied value was either fractional or outside of allowed range"), so every
    % command/message is formatted with sprintf in MATLAB first and passed as one finished string.
    Eyelink('Command', sprintf('screen_pixel_coords = %d %d %d %d', 0, 0, round(Wv) - 1, round(H) - 1));
    Eyelink('Message', sprintf('DISPLAY_COORDS %d %d %d %d', 0, 0, round(Wv) - 1, round(H) - 1));
    Eyelink('Command', sprintf('screen_phys_coords = %d %d %d %d', ...
        round(-half_w_mm/2), round(half_h_mm/2), round(half_w_mm/2), round(-half_h_mm/2)));
    Eyelink('Command', sprintf('screen_distance = %d', round(10 * cfg.viewing_distance_cm)));

    et_send_cal_targets(cfg, struct('vc', [Wv/2, H/2], 'ppd', ppd));   % calibration/validation points inside the fusion frame

    % recording set-up: both eyes, gaze + pupil area, full event detection
    Eyelink('Command', 'binocular_enabled = YES');
    Eyelink('Command', sprintf('sample_rate = %d', E.sample_rate_hz));
    Eyelink('Command', sprintf('calibration_type = %s', E.calibration_type));
    Eyelink('Command', 'pupil_size_diameter = NO');   % pupil AREA (arbitrary units)
    Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,AREA,GAZERES,STATUS,INPUT');
    Eyelink('Command', 'file_event_data   = GAZE,GAZERES,AREA,VELOCITY');
    Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,INPUT');
    Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
    Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE');

    status = Eyelink('OpenFile', [S.edf_name '.edf']);   % with extension, as in the working IIT-Bombay value-learning script
    if status ~= 0
        error('et_init:openFile', 'Could not open EDF file %s on the host (status %d).', S.edf_name, status);
    end
    Eyelink('Command', sprintf('add_file_preamble_text "CFS emotion experiment, participant %d, %s session"', participant_id, session_type));
    Eyelink('Message', sprintf('SESSION_START participant=%d session=%s ppd=%.4f', participant_id, session_type, ppd));

    et_state('set', S);
    fprintf('  EDF file on host: %s.edf\n', S.edf_name);
end
