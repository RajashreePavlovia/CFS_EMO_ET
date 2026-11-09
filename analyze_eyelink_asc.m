function [T, pupil_tc] = analyze_eyelink_asc(asc_path, varargin)
% ANALYZE_EYELINK_ASC  Per-trial eye-movement and pupil measures from an
% EyeLink ASC file (convert the EDF first:  edf2asc -y  m0121417.edf , or
% drag the EDF onto the EyeLink "Visual EDF2ASC" converter; the output must
% contain samples AND events).
%
%   [T, pupil_tc] = analyze_eyelink_asc('m0121417.asc')
%   [T, pupil_tc] = analyze_eyelink_asc(path, 'Eye', 'auto', 'PupilBaselineMs', 200)
%
% Writes <asc_path>_trials.csv (one row per trial) and returns it as a table.
%
% MEASURES (window = from STIM_ONSET, the first frame of arrows+face(+mask),
% to STREAM_END, the last frame of the arrow stream)
%   For each interest area  IA in RSVP, FACE, FACE_OPPOSITE, FRAME:
%     dwell_ms_<IA>        total duration of fixations whose mean position is in the IA
%                          (clipped to the window)
%     fixcount_<IA>        number of such fixations
%     entry_ms_<IA>        time from stimulus onset to the first SAMPLE inside the IA
%                          (NaN = never entered)
%     samples_ms_<IA>      time spent with gaze inside the IA, from the samples
%   first_fix_ia           IA of the first fixation that STARTS after stimulus onset
%                          ('' = none). first_fix_is_face = 1/0: average it over trials
%                          for "probability of first fixation on the face".
%   n_saccades, n_blinks, mean_fix_dur_ms, gaze_sd_deg, gaze_dist_deg (mean distance from fixation point)
%   pupil_base            mean pupil area in the PupilBaselineMs before stimulus onset
%                         (the central-fixation check period), both eyes averaged, blinks removed
%   pupil_mean            mean pupil area in the window;  pupil_change = pupil_mean - pupil_base
%   pupil_change_pct      same, in percent of baseline
%   gate_*                the per-trial central-fixation check: status, wait, drift offset (deg)
% Interest areas overlap; each fixation/sample is assigned by priority RSVP > FACE > FACE_OPPOSITE > FRAME.
%
% pupil_tc: trials x bins matrix of baseline-corrected pupil area (100 ms bins,
% from stimulus onset to +6 s), for pupil time-course plots.
%
% CAUTION (pupil): pupil size follows LUMINANCE. The arrows change colour/brightness,
% and the CFS mask flickers in one eye in 'unaware' blocks, so raw aware-vs-unaware or
% colour differences in pupil size are not interpretable on their own. Compare like with
% like (same awareness / same load) or model luminance.

    p = inputParser;
    addParameter(p, 'Eye', 'auto');            % 'auto' | 'L' | 'R' : eye used for fixation/saccade EVENTS
    addParameter(p, 'PupilBaselineMs', 200);
    addParameter(p, 'PupilBlinkPadMs', 100);   % samples within this many ms of a blink are dropped from pupil
    parse(p, varargin{:});
    opt = p.Results;

    fid = fopen(asc_path, 'r');
    if fid < 0, error('analyze_eyelink_asc:open', 'Cannot open %s', asc_path); end
    cleaner = onCleanup(@() fclose(fid));

    ppd = NaN;
    rows = {};
    tc = {};
    tr = new_trial();
    active = false;

    while true
        line = fgetl(fid);
        if ~ischar(line), break; end
        if isempty(line), continue; end
        c = line(1);
        if c >= '0' && c <= '9'
            if active, tr.samples{end+1} = line; end %#ok<AGROW>
        elseif strncmp(line, 'MSG', 3)
            tok = regexp(line, '^MSG\s+(\d+)\s+(.*)$', 'tokens', 'once');
            if isempty(tok), continue; end
            t = str2double(tok{1}); txt = strtrim(tok{2});
            if startsWith(txt, 'SESSION_START')
                m = regexp(txt, 'ppd=([\d.]+)', 'tokens', 'once');
                if ~isempty(m), ppd = str2double(m{1}); end
            elseif startsWith(txt, 'TRIALID')
                tr = new_trial();
                tr.label = strtrim(txt(8:end));
                active = true;
            elseif active
                tr.msgs(end+1, :) = {t, txt}; %#ok<AGROW>
                if startsWith(txt, 'TRIAL_RESULT')
                    [row, pt] = process_trial(tr, ppd, opt);
                    rows{end+1} = row; %#ok<AGROW>
                    tc{end+1} = pt; %#ok<AGROW>
                    active = false;
                end
            end
        elseif active && strncmp(line, 'EFIX', 4)
            v = sscanf(line(6:end), '%c %f %f %f %f %f %f', 7);
            if numel(v) >= 7, tr.fix(end+1, :) = [v(1) v(2:7)']; end %#ok<AGROW>
        elseif active && strncmp(line, 'ESACC', 5)
            v = sscanf(line(7:end), '%c %f %f %f', 4);
            if numel(v) >= 4, tr.sacc(end+1, :) = [v(1) v(2:4)']; end %#ok<AGROW>
        elseif active && strncmp(line, 'EBLINK', 6)
            v = sscanf(line(8:end), '%c %f %f %f', 4);
            if numel(v) >= 4, tr.blink(end+1, :) = [v(1) v(2:4)']; end %#ok<AGROW>
        end
    end

    rows = rows(~cellfun(@isempty, rows));
    rows = unify_fields(rows);
    T = struct2table([rows{:}]);
    pupil_tc = vertcat(tc{:});
    out_csv = [asc_path '_trials.csv'];
    writetable(T, out_csv);
    fprintf('%d trials analysed -> %s\n', height(T), out_csv);
end


function rows = unify_fields(rows)
% give every row the same fields (a trial with a problem has fewer): numeric NaN or '' for text
    allf = {};
    for i = 1:numel(rows), allf = [allf; fieldnames(rows{i})]; end %#ok<AGROW>
    allf = unique(allf, 'stable');
    is_text = false(size(allf));
    for i = 1:numel(rows)
        for k = 1:numel(allf)
            if isfield(rows{i}, allf{k}) && ischar(rows{i}.(allf{k})), is_text(k) = true; end
        end
    end
    for i = 1:numel(rows)
        r = struct();
        for k = 1:numel(allf)
            if isfield(rows{i}, allf{k})
                r.(allf{k}) = rows{i}.(allf{k});
            elseif is_text(k)
                r.(allf{k}) = '';
            else
                r.(allf{k}) = NaN;
            end
        end
        rows{i} = r;
    end
end


function tr = new_trial()
    tr = struct('label', '', 'msgs', {cell(0, 2)}, 'samples', {{}}, ...
        'fix', zeros(0, 7), 'sacc', zeros(0, 4), 'blink', zeros(0, 4));
end


function [row, pt] = process_trial(tr, ppd, opt)
    nb = 61;                      % pupil time-course bins: 100 ms from onset to +6 s
    pt = nan(1, nb);
    row = struct();
    row.trial_label = tr.label;

    % ---- trial variables, interest areas, gate, event times ----
    ia = struct('name', {}, 'rect', {});
    for i = 1:size(tr.msgs, 1)
        txt = tr.msgs{i, 2};
        if startsWith(txt, '!V TRIAL_VAR')
            m = regexp(txt, '^!V TRIAL_VAR (\S+) (.*)$', 'tokens', 'once');
            if ~isempty(m), row.(matlab.lang.makeValidName(m{1})) = m{2}; end
        elseif startsWith(txt, '!V IAREA')
            m = regexp(txt, '^!V IAREA RECTANGLE (\d+) (-?\d+) (-?\d+) (-?\d+) (-?\d+) (\S+)', 'tokens', 'once');
            if ~isempty(m)
                ia(str2double(m{1})).name = m{6};
                ia(str2double(m{1})).rect = str2double(m(2:5));
            end
        elseif startsWith(txt, 'GATE_PASS')
            m = regexp(txt, 'status=(\S+) wait=([\d.-]+) dx_deg=(\S+) dy_deg=(\S+)', 'tokens', 'once');
            if ~isempty(m)
                row.gate_status = m{1};
                row.gate_wait_s = str2double(m{2});
                row.gate_dx_deg = str2double(m{3});
                row.gate_dy_deg = str2double(m{4});
            end
        end
    end
    t0 = msg_time(tr.msgs, 'STIM_ONSET');
    t1 = msg_time(tr.msgs, 'STREAM_END');
    row.t_stim_onset = t0; row.t_stream_end = t1;
    row.window_ms = t1 - t0;
    names = {'RSVP', 'FACE', 'FACE_OPPOSITE', 'FRAME'};
    if isnan(t0) || isnan(t1) || isempty(tr.samples) || numel(ia) < 4 || isnan(ppd)
        row.problem = 'missing onset/offset, samples, interest areas or ppd';
        return;
    end
    vc = [mean(ia(4).rect([1 3])), mean(ia(4).rect([2 4]))];   % FRAME IA centre = fixation point

    % ---- samples: time x1 y1 p1 x2 y2 p2 ----
    S = textscan(strjoin(tr.samples, newline), '%f %f %f %f %f %f %f %*[^\n]', ...
        'TreatAsEmpty', '.', 'CollectOutput', true);
    S = S{1};
    S(S(:, 1) < t0 - 1000 | S(:, 1) > t1 + 100, :) = [];
    ts = S(:, 1);
    xl = S(:, 2); yl = S(:, 3); pl = S(:, 4); xr = S(:, 5); yr = S(:, 6); pr = S(:, 7);
    % invalid gaze / pupil -> NaN
    bad_l = pl <= 0 | isnan(pl); bad_r = pr <= 0 | isnan(pr);
    xl(bad_l) = NaN; yl(bad_l) = NaN; pl(bad_l) = NaN;
    xr(bad_r) = NaN; yr(bad_r) = NaN; pr(bad_r) = NaN;
    gx = mean([xl xr], 2, 'omitnan'); gy = mean([yl yr], 2, 'omitnan');
    pup = mean([pl pr], 2, 'omitnan');

    % remove pupil samples around blinks
    for k = 1:size(tr.blink, 1)
        pup(ts >= tr.blink(k, 2) - opt.PupilBlinkPadMs & ts <= tr.blink(k, 3) + opt.PupilBlinkPadMs) = NaN;
    end

    % which eye's EVENTS to use
    if strcmpi(opt.Eye, 'auto')
        if sum(~isnan(xl)) >= sum(~isnan(xr)), eyeEv = 'L'; else, eyeEv = 'R'; end
    else
        eyeEv = upper(opt.Eye);
    end
    row.event_eye = eyeEv;

    inwin = ts >= t0 & ts <= t1;
    assign = @(x, y) assign_ia(x, y, ia);

    % ---- fixations (clipped to window) ----
    fx = tr.fix(tr.fix(:, 1) == double(eyeEv), :);          % cols: eye start end dur x y pupil
    first_ia = '';
    n_fix = 0; fixdur = [];
    for k = 1:numel(names), row.(['dwell_ms_' names{k}]) = 0; row.(['fixcount_' names{k}]) = 0; end
    for k = 1:size(fx, 1)
        s = max(fx(k, 2), t0); e = min(fx(k, 3), t1);
        if e <= s, continue; end
        a = assign(fx(k, 5), fx(k, 6));
        if a > 0
            row.(['dwell_ms_' names{a}]) = row.(['dwell_ms_' names{a}]) + (e - s);
            row.(['fixcount_' names{a}]) = row.(['fixcount_' names{a}]) + 1;
        end
        n_fix = n_fix + 1; fixdur(end+1) = e - s; %#ok<AGROW>
        if isempty(first_ia) && fx(k, 2) >= t0      % first fixation that STARTS after onset
            if a > 0, first_ia = names{a}; else, first_ia = 'OUTSIDE'; end
        end
    end
    row.first_fix_ia = first_ia;
    row.first_fix_is_face = double(strcmp(first_ia, 'FACE'));
    row.n_fixations = n_fix;
    row.mean_fix_dur_ms = mean(fixdur);

    % ---- sample-based entry time and time-in-IA ----
    ids = arrayfun(@(i) assign(gx(i), gy(i)), find(inwin));
    tw = ts(inwin);
    for k = 1:numel(names)
        hit = ids == k;
        if any(hit), row.(['entry_ms_' names{k}]) = tw(find(hit, 1)) - t0;
        else, row.(['entry_ms_' names{k}]) = NaN; end
        row.(['samples_ms_' names{k}]) = sum(hit);            % 1 sample = 1 ms at 1000 Hz
    end

    % ---- saccades, blinks, gaze stability ----
    sc = tr.sacc(tr.sacc(:, 1) == double(eyeEv) & tr.sacc(:, 2) >= t0 & tr.sacc(:, 2) <= t1, :);
    bl = tr.blink(tr.blink(:, 1) == double(eyeEv) & tr.blink(:, 2) >= t0 & tr.blink(:, 2) <= t1, :);
    row.n_saccades = size(sc, 1);
    row.n_blinks = size(bl, 1);
    row.gaze_sd_deg = sqrt(var(gx(inwin), 'omitnan') + var(gy(inwin), 'omitnan')) / ppd;
    row.gaze_dist_deg = mean(hypot(gx(inwin) - vc(1), gy(inwin) - vc(2)), 'omitnan') / ppd;

    % ---- pupil ----
    base = mean(pup(ts >= t0 - opt.PupilBaselineMs & ts < t0), 'omitnan');
    pm = mean(pup(inwin), 'omitnan');
    row.pupil_base = base;
    row.pupil_mean = pm;
    row.pupil_change = pm - base;
    row.pupil_change_pct = 100 * (pm - base) / base;
    for b = 1:nb
        sel = ts >= t0 + (b-1)*100 & ts < t0 + b*100;
        pt(b) = mean(pup(sel), 'omitnan') - base;
    end
    row.problem = '';
end


function t = msg_time(msgs, prefix)
    t = NaN;
    for i = 1:size(msgs, 1)
        if startsWith(msgs{i, 2}, prefix)
            t = msgs{i, 1};
            return;
        end
    end
end


function k = assign_ia(x, y, ia)
% IA index (1 RSVP, 2 FACE, 3 FACE_OPPOSITE, 4 FRAME) by priority, 0 = outside all
    k = 0;
    if isnan(x) || isnan(y), return; end
    for i = 1:numel(ia)
        r = ia(i).rect;
        if x >= r(1) && x <= r(3) && y >= r(2) && y <= r(4)
            k = i;
            return;
        end
    end
end
