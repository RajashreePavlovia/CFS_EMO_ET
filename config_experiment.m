function cfg = config_experiment()
% CONFIG_EXPERIMENT  Central configuration for the CFS / spontaneous-thought
% RSVP experiment. Edit values here rather than scattering constants through
% the codebase. Nothing in this file touches PsychToolbox / the screen --
% it is pure parameters, so it can be loaded and unit-tested without a
% display connected.

cfg = struct();

%% ---- Session / conditions -------------------------------------------
cfg.attention_levels = {'low','high'};      % perceptual load
cfg.awareness_levels = {'aware','unaware'}; % CFS on/off
cfg.emotion_levels   = {'happy','angry','neutral'};

cfg.reps_per_condition   = 2;   % each of the 12 conditions shown twice
cfg.trials_per_block     = 36;
cfg.probe_trial_range    = [15 36]; % used ONLY when probes_per_block = 1: probe occurs after a trial in this range (inclusive)

% --- thought probes per block (see choose_probe_trials.m) ---
% 1 = original design (one probe, trial 15-36).
% 2 = two probes per block: both at least cfg.probe_first_min trials into the
%     block and at least cfg.probe_min_gap trials apart, so the 10-12 trial
%     pre-probe windows of the two probes never share trials.
%     (36 trials, first_min 12, gap 12 -> first probe in 12-24, second in first+12 .. 36)
cfg.probes_per_block = 2;
cfg.probe_first_min  = 12;
cfg.probe_min_gap    = 12;
cfg.n_catch_trials_per_block = 3;   % trials where a black square replaces the face (instead of, not in addition to, 3 of the 36 trials)

% target-count ranges per load (from RSVP perceptual-load task spec)
cfg.low_load_target_counts  = [2 3 4 5];
cfg.high_load_target_counts = [1 2 3 4];

%% ---- RSVP timing -------------------------------------------------------
cfg.rsvp_item_duration_s = 133 / 1000;  % 133ms per item (changed from 166.67ms)
cfg.rsvp_isi_s           = 133 / 1000;  % 133ms blank gap between items (changed from 100ms)
cfg.pretrial_fixation_s  = 0.2;            % 200ms fixation cross at the very start of every trial
cfg.fixation_cross_deg   = 0.5;            % size of that cross
cfg.fixation_cross_thickness_deg = 0.06;
cfg.iti_s                = 1.5;            % inter-trial interval within a block (changed from 1.5s)
cfg.max_response_time_s  = 3.0;            % max time to report target count for a trial

%% ---- RSVP arrow colors (RGB 0-255) -------------------------------------
% Fill these in with your exact calibrated RGB values before running.
cfg.colors = struct( ...
    'red',    [255   0   0], ...
    'yellow', [255 255   0], ...
    'green',  [  0 255   0], ...
    'blue',   [  0   0 255], ...
    'pink',   [255 105 180], ...
    'purple', [160  32 240] );

%% ---- RSVP color/orientation rules by load ------------------------------
% Each definition is a struct with .color (fieldname into cfg.colors) and
% .orientations (cell array of allowed orientations, 'up' and/or 'down').
%
% LOW LOAD
%   targets     : red, either orientation
%   non-targets : yellow/green/blue/pink/purple, either orientation
cfg.low_load.targets = struct('color','red','orientations',{{'up','down'}});
cfg.low_load.nontargets = struct( ...
    'color', {'yellow','green','blue','pink','purple'}, ...
    'orientations', {{'up','down'},{'up','down'},{'up','down'},{'up','down'},{'up','down'}});

% HIGH LOAD
%   targets     : yellow-upright, green-downward (inverted) ONLY
%   non-targets : green-upright, yellow-downward, plus red/pink/blue/purple (either orientation)
cfg.high_load.targets = struct( ...
    'color', {'yellow','green'}, ...
    'orientations', {{'up'},{'down'}});
cfg.high_load.nontargets = [ ...
    struct('color','green',  'orientations',{{'up'}}), ...
    struct('color','yellow', 'orientations',{{'down'}}), ...
    struct('color','red',    'orientations',{{'up','down'}}), ...
    struct('color','pink',   'orientations',{{'up','down'}}), ...
    struct('color','blue',   'orientations',{{'up','down'}}), ...
    struct('color','purple','orientations',{{'up','down'}}) ];  % replaced orange -- see note below

%% ---- Arrow geometry (pixels; convert to degrees once ppd is known) -----
cfg.arrow_height_px = 30;
cfg.arrow_width_px  = 12; % midpoint of your 10-15px suggestion; adjust freely
cfg.arrow_backdrop_padding_px = 8; % extra margin around the arrow for its background patch, so it stays visible against the flickering mask

%% ---- Background --------------------------------------------------------
cfg.background_rgb = [95 95 95];

%% ---- Stereoscope / fusion frame geometry (degrees visual angle) --------
cfg.viewing_distance_cm   = 94;
cfg.fusion_frame_deg      = 6.4;    % side length of each eye's square fusion frame
cfg.contour_band_deg      = 0.2;    % width of black/white contour ring at frame border
cfg.contour_element_deg   = 0.015;   % size of each contour patch
    % CHANGED from the earlier-confirmed 0.015: on real hardware this
    % rendered as invisible flat gray (1px elements are below human
    % visual resolution at these viewing distances, even rendered
    % perfectly). 0.15 gives ~12px elements at typical laptop ppd,
    % clearly visible. Revert to 0.015 only if there's a specific
    % measurement reason for it -- it will likely look blank again.
cfg.red_boundary_line_deg = 0.01;   % thin red reference line just outside contour band

% Physical screen size MUST be measured (ruler/spec sheet) for accurate
% degrees-to-pixels conversion -- do not guess from diagonal+aspect ratio,
% bezels vary. Fill in for EACH display you test on.
cfg.screen_width_cm  = 54.4;  % TODO: measure active display width (HP 14s dev laptop)
cfg.screen_height_cm = 30.4;  % TODO: measure active display height (HP 14s dev laptop)
% NOTE: when you move to the BenQ 240Hz monitor, either add a second cfg
% variant (e.g. config_experiment_benq.m) or overwrite these two fields
% after loading cfg, so pixels-per-degree is recomputed correctly for
% that display.

%% ---- Stereoscope screen-half / eye-dominance mapping --------------------
% Physical arrangement: left half of screen = one eye, right half = other
% eye (confirmed). cfg.stereoscope_crossed says whether the mirror
% stereoscope sends left-half-of-screen to the LEFT eye (uncrossed, the
% typical/default arrangement) or to the RIGHT eye (crossed, some mirror
% configurations invert this). If face/mask sides look swapped from what
% you expect during testing, flip this flag first before changing
% anything else.
cfg.stereoscope_crossed = false;

%% ---- Fusion calibration ---------------------------------------------
cfg.calibration_step_small_px = 1;   % Left/Right arrow: fine adjustment
cfg.calibration_step_large_px = 5;   % Up/Down arrow: coarse adjustment
cfg.calibration_confirm_key   = 'return'; % key to lock in calibration and continue
cfg.calibration_vertical_step_px = 1;     % W/S keys: vertical move per step
cfg.calibration_hold_delay_s = 0.35;      % hold a key this long before auto-repeat starts
cfg.calibration_hold_interval_s = 0.03;   % time between auto-repeat steps
cfg.calibration_hold_accel_after_s = 1.0; % held longer than this -> faster
cfg.calibration_hold_accel_mult = 3;      % step multiplier once accelerated
cfg.calibration_cross_deg = 1.5;          % big central cross on calibration screens
cfg.calibration_cross_thickness_deg = 0.12;
cfg.calibration_initial_separation_px = 0; % starting offset for the FIRST calibration only; later blocks start from the previous block's fused position

%% ---- Face stimuli --------------------------------------------------------
cfg.face_width_deg  = 2.0;
cfg.face_height_deg = 2.8;
cfg.face_eccentricity_deg = 2.1;

% 12 identities total. KDEF-style numbering is unique WITHIN each gender,
% so id '13' and id '33' each denote two different people (one male, one
% female) -- confirmed with user. Female/male grouping inferred from the
% order originally given (first 6 = female, last 6 = male); flag if wrong.
cfg.face_identities = struct( ...
    'id',     {'03','13','15','29','33','35', '01','06','08','13','30','33'}, ...
    'gender', {'F','F','F','F','F','F',       'M','M','M','M','M','M'});

cfg.face_folder_root = 'D:\CFS\Expt_emo_ET\Stimuli\crop_contour_blur';
cfg.face_emotion_subfolder = struct('happy','happy','angry','angry','neutral','neutral');
% filename pattern: A[Gender][ID][EmotionCode]_processed.png
%   Gender code: F or M (leading 'A' is a fixed constant, confirmed)
%   EmotionCode: ANS (angry) / HAS (happy) / NES (neutral)
cfg.face_emotion_code = struct('angry','ANS','happy','HAS','neutral','NES');

%% ---- CFS Mondrian masks --------------------------------------------------
cfg.mask_update_hz = 10;   % ~10 Hz -> ~100 ms per mask frame
cfg.mask_frame_duration_s = 1 / cfg.mask_update_hz;
cfg.mask_folder = 'D:\CFS\Expt_emo_ET\Stimuli\CFS_Mondrian_Colored'; % colored, confirmed
cfg.mask_filename_prefix = 'Mondrian_';
cfg.mask_n_total = 200;   % Mondrian_001 ... Mondrian_200
cfg.mask_no_immediate_repeat = true;

%% ---- Debug / development display mode -----------------------------------
% Windowed mode is useful while developing/debugging (easier to switch
% focus between MATLAB console and the experiment window than with
% exclusive fullscreen). Set false for real data collection -- the
% stereoscope needs genuine fullscreen to correctly cover the two screen
% halves.
cfg.debug_windowed_mode = false;
cfg.debug_window_rect = [50 50 1780 950]; % [left top right bottom], only used if debug_windowed_mode

%% ---- Response keys ---------------------------------------------------
cfg.keys.target_count_keys = {'1','2','3','4','5'}; % RSVP target-count report (changed from 0-5: minimum possible targets in any trial is 1, so 0 was never a valid answer)
cfg.keys.probe1_keys = {'1','2','3','4','5'};           % on-task/SDT/TRI/SIT/blank-mind (order counterbalanced per participant, see build_probe1_order.m)
cfg.keys.probe2_keys = {'1','2','3','4'};               % which stimulus (arrows/masks/faces/other)
cfg.keys.yesno_keys  = struct('yes','LeftArrow','no','RightArrow');
cfg.keys.scale_keys  = {'1','2','3','4','5','6','7'};   % vividness / temporality-as-4pt / current-concerns
cfg.keys.samediff_keys = struct('same','0','different','2');   % colour-screen (same/different arrow task): 0 = same, 2 = different (main row or keypad)
cfg.keys.pause_key = 'p';                               % global pause: latched anywhere in a trial, shown when that trial finishes
cfg.keys.calib_key = 'c';                                % recalibrate fusion frames: works on every screen; during a trial/probe it is latched and the calibration screen appears when the trial (and any probe) has finished
cfg.keys.face_report_keys = struct('left','LeftArrow','right','RightArrow'); % unaware-trial face-location report, checked continuously during the RSVP+mask stream

%% ---- Practice session ---------------------------------------------------
cfg.practice_face_folder_root = 'D:\CFS\Expt_emo_ET\Stimuli\practice_crop_contour_blur'; % PUT YOUR NEW PRACTICE FACE FOLDER HERE
    % expected structure: practice_face_folder_root\happy\*.png (or .jpg),
    % \angry\*.png, \neutral\*.png -- same subfolder-per-emotion layout as
    % the main face set, but files are auto-discovered (any filename), NOT
    % looked up by identity/gender like the main experiment's faces. Any
    % number of images per emotion is fine.
cfg.practice_n_blocks = 4;       % easy-aware, easy-unaware, hard-aware, hard-unaware
cfg.practice_trials_per_block = 12;
cfg.practice_learning_contrast = 1.0;   % faces during learning trials (100%)
cfg.practice_feedback_s = 1.0;
cfg.practice_probes_per_block = 3;      % thought-probe sequences shown inside EACH Phase-1 practice block (to get used to the options)
cfg.practice_pass_easy = 0.80;
cfg.practice_pass_hard = 0.60;
cfg.practice_criterion_last_n = 12;     % accuracy uses the last 12 learning trials of each block
cfg.quest_start_contrast = 1.0;         % start at 100% and go down
cfg.quest_prior_sd = 1.5;               % log10 units
cfg.quest_p_threshold = 0.75;
cfg.quest_beta = 3.5;
cfg.quest_delta = 0.02;
cfg.quest_gamma = 0.05;                 % guess rate is near 0 because "did not see" is an option
cfg.quest_min_trials = 20;
cfg.quest_max_trials = 50;
cfg.quest_sd_stop = 0.15;               % stop early once the estimate is this stable
cfg.quest_min_contrast = 0.01;
cfg.unaware_contrast_fraction = 0.5;    % main-task contrast = this x participant threshold
cfg.keys.quest_none_key = 'DownArrow';  % "did not see a face"

%% ---- Probe 1 options (fixed set; per-participant order is counterbalanced) --
cfg.probe1_options = {'on-task','SDT','TRI','SIT','blank-mind'};
cfg.probe2_options = {'arrows','masks','faces','other'};

% Participant-facing wording for each probe1/probe2 option code (internal
% codes like 'SDT' are for data/analysis, not for display).
cfg.probe1_display_text = containers.Map( ...
    {'on-task','SDT','TRI','SIT','blank-mind'}, ...
    {'On task', ...
     'Stimulus dependent thoughts', ...
     'Task related interference', ...
     'Stimulus independent thoughts', ...
     'Blank mind'});

cfg.probe2_display_text = containers.Map( ...
    {'arrows','masks','faces','other'}, ...
    {'Arrows in the centre', ...
     'Peripheral masks', ...
     'Peripheral faces', ...
     'Something else about the experimental setup'});

end
