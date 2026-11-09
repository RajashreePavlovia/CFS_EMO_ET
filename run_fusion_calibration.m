function [separation_px, offsets, state] = run_fusion_calibration(win, cfg, ppd, block_num, participant_id, prev_state)
% RUN_FUSION_CALIBRATION  Interactive fusion-frame calibration, run before
% every block. Draws both eyes' fusion frames (left/right half of screen)
% with a big fixation cross in the centre of each, and lets the
% experimenter/participant nudge the frames until they fuse.
%
%   [separation_px, offsets, state] = run_fusion_calibration(win, cfg, ppd, block_num, participant_id, prev_state)
%
% INPUTS
%   prev_state - (optional) 'state' returned by the previous call. If given,
%                the frames START at the previous block's fused position and
%                the screen asks "are the frames still fused?" -- Return
%                accepts as-is, or adjust first. If [] / omitted, starts at
%                cfg.calibration_initial_separation_px with no offsets.
%
% OUTPUTS
%   separation_px - symmetric separation (px), as before
%   offsets       - struct .left_dx .left_dy .right_dx .right_dy (px): extra
%                   per-frame shifts (single-frame moves + vertical moves)
%   state         - struct(separation_px, offsets) to pass to the next call
%
% Use with:  centers = compute_frame_centers(winRect, separation_px, offsets);
%
% CONTROLS
%   Left / Right arrow : 1 px  (Right = widen / move outward, Left = shorten)
%   Up / Down arrow    : 5 px  (Down = widen,                 Up   = shorten)
%   W / S              : move frame(s) UP / DOWN (cfg.calibration_vertical_step_px)
%   Tab                : cycle which frame moves: BOTH -> LEFT only -> RIGHT only
%                        (BOTH: horizontal keys change the separation and
%                         W/S shift both frames together. LEFT/RIGHT only:
%                         every key moves just that one frame.)
%   HOLD any movement key: after a short delay it auto-repeats, and speeds
%                        up (x cfg.calibration_hold_accel_mult) if held longer.
%   Return             : accept
%   Escape             : abort

    if nargin < 6
        prev_state = [];
    end

    KbName('UnifyKeyNames');
    keyUp     = KbName('UpArrow');
    keyDown   = KbName('DownArrow');
    keyLeft   = KbName('LeftArrow');
    keyRight  = KbName('RightArrow');
    keyW      = KbName('w');
    keyS      = KbName('s');
    keyTab    = KbName('Tab');
    keyReturn = KbName('Space');
    keyEscape = KbName('ESCAPE');

    stepSmall = cfg.calibration_step_small_px;
    stepLarge = cfg.calibration_step_large_px;
    stepVert  = cfgval(cfg, 'calibration_vertical_step_px', 1);
    holdDelay = cfgval(cfg, 'calibration_hold_delay_s', 0.35);
    holdInt   = cfgval(cfg, 'calibration_hold_interval_s', 0.03);
    accelAft  = cfgval(cfg, 'calibration_hold_accel_after_s', 1.0);
    accelMult = cfgval(cfg, 'calibration_hold_accel_mult', 3);
    crossSpan = cfgval(cfg, 'calibration_cross_deg', 1.5) * ppd;
    crossThk  = max(2, round(cfgval(cfg, 'calibration_cross_thickness_deg', 0.12) * ppd));

    % action table: Up, Down, Left, Right, W, S
    moveKeys = [keyUp keyDown keyLeft keyRight keyW keyS];
    hDelta   = [-stepLarge, +stepLarge, -stepSmall, +stepSmall, 0, 0];
    vDelta   = [0, 0, 0, 0, -stepVert, +stepVert];   % screen y grows downward

    % build the frame texture once (geometry is fixed; only position moves)
    frameImg = build_fusion_frame_texture(cfg, ppd);
    frameTex = Screen('MakeTexture', win, frameImg);
    frameSizePx = size(frameImg, 1);
    screenRect = Screen('Rect', win);

    % starting position: previous block's fused position, or the default
    if isempty(prev_state)
        sep = cfg.calibration_initial_separation_px;
        off = struct('left_dx', 0, 'left_dy', 0, 'right_dx', 0, 'right_dy', 0);
        carried = false;
    else
        sep = prev_state.separation_px;
        off = prev_state.offsets;
        carried = true;
    end

    modeNames = {'BOTH frames', 'LEFT frame only', 'RIGHT frame only'};
    mode = 1;
    heldAct = 0; pressT = 0; lastFireT = 0;
    tabWasDown = false; retWasDown = false;

    HideCursor;
    KbReleaseWait;   % so a Return held from the previous screen can't instantly accept

    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        tNow = GetSecs;

        act = 0;
        if keyIsDown
            if keyCode(keyEscape)
                ShowCursor;
                Screen('Close', frameTex);
                error('run_fusion_calibration:userAbort', 'User pressed Escape -- aborting.');
            end
            for k = 1:numel(moveKeys)
                if keyCode(moveKeys(k))
                    act = k;
                    break;
                end
            end
        end

        % --- one-shot keys (rising edge): Tab = switch frame, Return = accept ---
        tabDown = keyIsDown && keyCode(keyTab);
        retDown = keyIsDown && keyCode(keyReturn);
        if tabDown && ~tabWasDown
            mode = mod(mode, 3) + 1;
        end
        if retDown && ~retWasDown
            break;
        end
        tabWasDown = tabDown;
        retWasDown = retDown;

        % --- movement keys: fire on press, then auto-repeat while held ---
        fire = false;
        mult = 1;
        if act ~= 0
            if act ~= heldAct
                fire = true;               % fresh press
                heldAct = act;
                pressT = tNow;
                lastFireT = tNow;
            else
                held = tNow - pressT;
                if held >= holdDelay && (tNow - lastFireT) >= holdInt
                    fire = true;
                    lastFireT = tNow;
                    if held >= accelAft
                        mult = accelMult;
                    end
                end
            end
        else
            heldAct = 0;
        end

        if fire
            d = hDelta(act) * mult;   % + = widen (outward), - = shorten
            v = vDelta(act) * mult;   % + = down, - = up
            if d ~= 0
                switch mode
                    case 1, sep = sep + d;
                    case 2, off.left_dx  = off.left_dx  - d;   % outward = left
                    case 3, off.right_dx = off.right_dx + d;   % outward = right
                end
            end
            if v ~= 0
                switch mode
                    case 1
                        off.left_dy  = off.left_dy  + v;
                        off.right_dy = off.right_dy + v;
                    case 2, off.left_dy  = off.left_dy  + v;
                    case 3, off.right_dy = off.right_dy + v;
                end
            end
        end

        % --- draw both frames + big central cross in each ---
        centers = compute_frame_centers(screenRect, sep, off);
        leftDestRect  = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.left(1),  centers.left(2));
        rightDestRect = CenterRectOnPoint([0 0 frameSizePx frameSizePx], centers.right(1), centers.right(2));

        Screen('FillRect', win, cfg.background_rgb);
        Screen('DrawTexture', win, frameTex, [], leftDestRect, 0, 0);
        Screen('DrawTexture', win, frameTex, [], rightDestRect, 0, 0);
% fusion aid: concentric circles + one big cross spanning the whole frame area
        half_px = round(cfg.fusion_frame_deg * ppd / 2);   % half the frame's content side
        n_rings = 5;
        for c = {centers.left, centers.right}
            cx = c{1}(1); cy = c{1}(2);
            for r = 1:n_rings
                rad = round(half_px * r / n_rings);
                Screen('FrameOval', win, [255 255 255], [cx-rad cy-rad cx+rad cy+rad], 2);
            end
            Screen('FillRect', win, [255 255 255], [cx-half_px, cy-crossThk/2, cx+half_px, cy+crossThk/2]);
            Screen('FillRect', win, [255 255 255], [cx-crossThk/2, cy-half_px, cx+crossThk/2, cy+half_px]);
        end

        % experimenter-facing text (top of screen)
        effSep = sep + off.right_dx - off.left_dx;
        vertDiff = off.right_dy - off.left_dy;
        if carried
            prompt = 'ARE THE FRAMES STILL FUSED?   YES: press space.   NO: adjust, then press space.';
        else
            prompt = 'Adjust until the two frames fuse, then press space.';
        end
        statusStr = sprintf(['Participant %d | Block %d | separation %d px | vertical offset %d px | MOVING: %s\n' ...
            '%s\n' ...
            'Left/Right = 1 px   Up/Down = 5 px   W/S = up/down   Tab = switch frame   (hold keys to go faster)'], ...
            participant_id, block_num, round(effSep), round(vertDiff), modeNames{mode}, prompt);
        Screen('TextSize', win, 16);
        DrawFormattedText(win, statusStr, 'center', 20, [255 255 255]);

        Screen('Flip', win);
    end

    ShowCursor;
    Screen('Close', frameTex);

    separation_px = sep;
    offsets = off;
    state = struct('separation_px', sep, 'offsets', off);
end


function v = cfgval(cfg, name, default)
    if isfield(cfg, name) && ~isempty(cfg.(name))
        v = cfg.(name);
    else
        v = default;
    end
end
