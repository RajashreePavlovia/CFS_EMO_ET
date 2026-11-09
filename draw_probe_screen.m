function draw_probe_screen(win, cfg, frameTex, winRect, frameDestRects, ppd, question_lines)
% DRAW_PROBE_SCREEN  Draw fusion frames (both halves) plus a block of text
% CENTERED (horizontally and vertically) inside the fusion frame, with no
% background fill. Font size automatically shrinks for longer passages so
% the text never overflows the frame. Uses the classic DrawFormattedText
% (works with any Psychtoolbox text renderer -- does NOT require the FTGL
% plugin that DrawFormattedText2 needs). If cfg.text_only_side is set
% ('left' or 'right'), text appears only in that frame; otherwise in both.
% Does NOT call Screen('Flip') -- caller flips after this draws.

    Screen('FillRect', win, cfg.background_rgb);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.left, 0, 0);
    Screen('DrawTexture', win, frameTex, [], frameDestRects.right, 0, 0);

    spacingMult = 1.4;                        % <-- ADJUST: line spacing
    vertical_offset_px = 0.1;                   % <-- ADJUST: shift block up(-)/down(+) from center
    marginY_px = 0.2 * ppd;                   % <-- ADJUST: top/bottom margin inside the frame
    marginX_px = 0.2 * ppd;                   % <-- ADJUST: left/right margin inside the frame
    maxFontSize = max(9, round(0.25 * ppd));  % <-- ADJUST: starting (largest) font size
    minFontSize = max(9, round(0.2 * ppd));  % <-- ADJUST: smallest the text is allowed to shrink to

    draw_left = true;  draw_right = true;
    if isfield(cfg, 'text_only_side')
        draw_left  = strcmpi(cfg.text_only_side, 'left');
        draw_right = strcmpi(cfg.text_only_side, 'right');
    end

    frame_w_px = frameDestRects.left(3) - frameDestRects.left(1);
    frame_h_px = frameDestRects.left(4) - frameDestRects.left(2);
    usable_w_px = frame_w_px - 2 * marginX_px;
    usable_h_px = frame_h_px - 2 * marginY_px;

    text = strjoin(question_lines, '\n');

    Screen('TextBackgroundColor', win, []);

    % --- shrink font size until the MEASURED text block fits the frame ---
    % Measured on a throwaway offscreen window, so this is exact (not an
    % estimate) and works regardless of text renderer.
    fontSize = maxFontSize;
    wrapat_chars = 10;
    tb = [];
    while true
        Screen('TextSize', win, fontSize);
        sample_bounds = Screen('TextBounds', win, 'The quick brown fox jumps over the lazy dog 0123456789');
        avg_char_width_px = sample_bounds(3) / 56;
        wrapat_chars = max(10, floor(0.9 * usable_w_px / avg_char_width_px));

        scratch = Screen('OpenOffscreenWindow', win, [], [0 0 usable_w_px usable_h_px*4]);
        Screen('TextSize', scratch, fontSize);
        [~, ~, tb] = DrawFormattedText(scratch, text, 0, 0, [0 0 0], wrapat_chars, [], [], spacingMult);
        Screen('Close', scratch);

        block_h_px = tb(4) - tb(2);
        if block_h_px <= usable_h_px || fontSize <= minFontSize
            break;
        end
        fontSize = fontSize - 1;
    end
    Screen('TextSize', win, fontSize);
    block_w_px = tb(3) - tb(1);
    block_h_px = tb(4) - tb(2);

    if draw_left
        draw_text_in_frame(win, text, frameDestRects.left, wrapat_chars, spacingMult, ...
            vertical_offset_px, block_w_px, block_h_px, frame_w_px, frame_h_px);
    end
    if draw_right
        draw_text_in_frame(win, text, frameDestRects.right, wrapat_chars, spacingMult, ...
            vertical_offset_px, block_w_px, block_h_px, frame_w_px, frame_h_px);
    end
end


function draw_text_in_frame(win, text, frameRect, wrapat_chars, spacingMult, ...
    vertical_offset_px, block_w_px, block_h_px, frame_w_px, frame_h_px)

    x = frameRect(1) + (frame_w_px - block_w_px) / 2;
    y = frameRect(2) + (frame_h_px - block_h_px) / 2 + vertical_offset_px;

    [~, ~, tb] = DrawFormattedText(win, text, x, y, [0 0 0], wrapat_chars, [], [], spacingMult);

    if tb(1) < frameRect(1) || tb(3) > frameRect(3) || tb(2) < frameRect(2) || tb(4) > frameRect(4)
        msg = sprintf(['Text extends outside the fusion frame (text box [%d %d %d %d], ' ...
            'frame [%d %d %d %d]). Shorten the text or lower the font size.'], ...
            round(tb), round(frameRect));
        warning('draw_probe_screen:textOutsideFrame', '%s', msg);
    end
end