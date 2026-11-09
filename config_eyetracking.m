function E = config_eyetracking()
% CONFIG_EYETRACKING  Settings for the EyeLink 1000 (binocular, tower mount).
% Kept in its own file so config_experiment.m does not need to change.
% run_experiment_session.m stores the result as cfg.eyetracking.

E = struct();
% mode: 'off'   = no eye tracking at all (all et_* functions do nothing)
%       'dummy' = no tracker needed: gaze is simulated with the MOUSE (hover over the
%                 fixation cross in the LEFT half), messages go to a text file instead
%                 of the tracker. Use on the laptop to test the whole flow.
%       'live'  = real EyeLink. Run_experiment_session also asks for this at start.
E.mode = 'off';
E.host_ip = '100.1.1.1';       % only needed if the host is not at the default address
E.sample_rate_hz = 1000;       % binocular maximum on the EyeLink 1000
E.calibration_type = 'HV9';
% The 9 calibration/validation points are placed INSIDE the fusion frame: the 3x3 grid spans +/- cal_area_deg/2
% around the fused frame centre (the frame is cfg.fusion_frame_deg wide, so keep this a bit smaller, and >= about 5.6
% to cover the face region). The host is given these exact pixel positions, so it never asks for points outside the frames.
E.cal_area_deg = 5.0;
E.recalibrate_every_blocks = 6; % extra EyeLink calibration at the start of every 6th block (0 = only once at the start)
% calibration / drift-check targets (drawn in BOTH eyes' fusion frames)
E.cal_target_outer_deg = 0.6;
E.cal_target_inner_deg = 0.2;
E.cal_target_rgb = [255 255 255];
E.cal_inner_rgb  = [0 0 0];
% after EVERY fusion calibration: if the frames moved (in either eye) since the last EyeLink calibration/drift
% correction, the eye calibration no longer matches what the participant fixates.
E.refusion_drift_deg = 0.5;    % moved >= this: EyeLink drift correction (target at the centre of both frames)
E.refusion_recal_deg = 1.5;    % moved >= this: full EyeLink calibration + validation
% per-trial central-fixation check ("gate"): the trial starts only when gaze
% has stayed inside the window for gate_hold_s
% true = ALSO run EyeLink's own drift correction before every trial (the target appears in both frames and the
% host/experimenter accepts it), then the gaze check below. Default false = gaze check only.
E.drift_correct_every_trial = false;
E.gate_radius_deg = 1.5;
E.gate_hold_s     = 0.3;
E.gate_timeout_s  = 10;        % then the experimenter menu appears: D = drift correct, R = recalibrate, Space = start anyway
% interest areas, in degrees, centred on the fused frame centre
E.ia_rsvp_half_deg   = 0.5;    % central square around the arrows: +/- this many degrees
E.ia_face_margin_deg = 0.3;    % face IA = face rectangle grown by this margin on every side

end
