# Eye tracking (EyeLink 1000, binocular, tower mount) -- setup and use

## 0. What it does
* Per trial: central-fixation check ("gate") -> recording -> trial -> stop. The trial only starts after
  gaze has stayed within `gate_radius_deg` (1.5 deg) of the fused fixation cross for `gate_hold_s` (0.3 s).
  The mean gaze offset during the check is saved as a per-trial **drift estimate**.
* Both eyes, 1000 Hz, gaze + pupil area. Messages (with VBL times) mark: gate on/pass, stimulus onset,
  every arrow, every mask frame, stream end, count prompt/response, face question/response, ITI, probes.
* Interest areas (RSVP centre, FACE, FACE_OPPOSITE = same spot on the other side as a control, FRAME) are
  written into every trial as `!V IAREA` messages.
* EDF is copied from the host PC to `data\` at the end (also after an Esc/error).
* `analyze_eyelink_asc.m` turns an ASC file into per-trial dwell time, entry time, fixation count,
  first-fixation IA, saccades, blinks, gaze stability and pupil measures.

## 1. Is the Eyelink Toolbox installed?
It ships with Psychtoolbox. In MATLAB:
```
which Eyelink
which EyelinkInit
which PsychEyelinkDispatchCallback
```
Each must print a path (the first one ends in `.mex...`). If `which Eyelink` says "not found", install the
EyeLink Developers Kit (SR Research support site) and re-run `DownloadPsychtoolbox`/`UpdatePsychtoolbox`.
You also need the Developers Kit for `edf2asc` (EDF -> ASC converter).

## 2. Try it WITHOUT a tracker (laptop)
`run_experiment_session` -> practice or main -> at "Eye tracking" type `dummy`.
Gaze is the mouse: put the pointer on the fixation cross in the LEFT frame to pass the check. If you do not,
after 10 s the experimenter menu appears (Space = start anyway). Every message that would go to the EDF is
written to `data\p<ID>_eyelink_dummy_messages_<name>.txt`. The trial CSV gets 5 new columns
(`et_gate_status`, `et_gate_wait_s`, `et_gate_offset_x_deg`, `et_gate_offset_y_deg`, `et_gate_menu_count`).
Type `off` for the old behaviour (nothing changes), `live` for the real tracker.

## 3. ONE-TIME PATCH for the real tracker (stereoscope calibration targets)
EyeLink draws calibration/drift targets with a function in Psychtoolbox, one target at one place on the
screen. In the stereoscope each eye sees only its own half, so we must draw the target in BOTH halves.
1. Find the file:  `which PsychEyelinkDispatchCallback`
2. Copy it into this project folder (same name; the project folder is first on the path, so the copy is used).
3. In YOUR COPY, find the code that draws the default (oval) calibration target -- the `otherwise` branch
   of the `switch el.calTargetType` inside `EyelinkDrawCalibrationTarget` (it uses `Screen('FillOval', ...)`
   with `el.calibrationtargetcolour` and `calxy`). Replace the drawing lines of that branch with:
   ```
   cfs_draw_cal_target(eyewin, el, calxy);
   ```
   (variable names may differ slightly between Psychtoolbox versions: use the window variable and the
   target-position variable that the original FillOval line used.)
4. `et_init` checks the copy for `cfs_draw_cal_target` and warns if it is missing.
Keep the camera-image / instruction drawing as it is. If you later update Psychtoolbox, your copy stays old:
that is normally fine, but delete and redo the patch if EyeLink calibration starts to misbehave.

## 4. Real-tracker checklist (first session with the hardware)
* Host PC: EyeLink 1000, tower mount, binocular, sample rate 1000 Hz. Host Offline screen shown. Cable on.
* Optional: `cfg.eyetracking.host_ip` in `config_eyetracking.m` if the host is not 100.1.1.1.
* Order each block: fusion calibration (existing) -> EyeLink calibration (first block, then every 6th) -> trials.
* EyeLink calibration is driven by the experimenter on the display PC keyboard / host: `C` calibrate,
  `V` validate, Enter/Space accept, `Esc` leave. Participant looks at the fused target.
* Check on the host that both eyes are tracked, pupil/CR thresholds are good, and validation error is < ~0.5-1 deg.
* Per-trial "drift check": if gaze does not reach the centre within 10 s, the experimenter menu opens:
  `D` host drift correction, `R` recalibrate, `Space` start anyway (flagged `forced` in the CSV).

## 5. After the session
1. `edf2asc -y data\m0121417.edf`  (or the Visual EDF2ASC tool; keep samples AND events)
2. `[T, pupil_tc] = analyze_eyelink_asc('data\m0121417.asc');`
3. Join `T` to `p<ID>_trials_*.csv` on block/trial (`trial_label` = `main_b05_t12`).

## 6. Things to know
* Coordinates are in a "virtual screen" (one display half, origin top-left) whose centre is the centre of
  the fused frame, so interest areas are the same for every participant (see `et_make_geom.m`).
* The face's inner edge is only ~0.2 deg from the centre (ecc 1.6 deg, width 2.8 deg), i.e. it touches
  the arrow area. IA priority is RSVP > FACE > FACE_OPPOSITE > FRAME, and the RSVP IA is +/-0.5 deg.
  Tracker accuracy (~0.5 deg) cannot separate arrow and face inside that overlap.
* The existing `face_onset` event in the events CSV uses the end-of-fixation flip (`trial_start_vbl`), which is
  one frame BEFORE the stream's first frame. The EyeLink `STIM_ONSET` message uses the true first frame.
* UNTESTED on real hardware: this was written without a tracker or MATLAB available. The first live run
  should be done with the experimenter at the host PC.
