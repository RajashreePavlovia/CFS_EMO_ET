function ctx = show_main_instructions(win, cfg, frameTex, winRect, ctx, ppd)
% SHOW_MAIN_INSTRUCTIONS  Short instruction pages shown once, before the first
% block of the MAIN session (after practice). Covers the face-location report
% that follows every count response, the thought questions, and the pause and
% recalibration keys.
%
%   ctx = show_main_instructions(win, cfg, frameTex, winRect, ctx, ppd)
%
% ctx is the calibration context from make_calib_ctx (it carries the current
% frameDestRects) and is returned, because pressing C on any page runs the
% fusion calibration and the page is then redrawn on the new frame positions.
%
% Any key = next page, Backspace = previous page, C = recalibrate, Escape = abort.
% Pages are kept short because the fusion frame is small (about 285 px wide
% on the 1920x1080 Legion at 60 cm). If a page triggers the
% 'draw_probe_screen:textOutsideFrame' warning, split it into two pages.

    KbName('UnifyKeyNames');
    backKey = KbName('BackSpace');

    leftLbl  = key_label(cfg.keys.face_report_keys.left);
    rightLbl = key_label(cfg.keys.face_report_keys.right);
    noneLbl  = key_label(cfg.keys.quest_none_key);
    pauseLbl = key_label(cfg.keys.pause_key);
    calibLbl = key_label(cfg.keys.calib_key);

    pages = {};

    pages{end+1} = { ...
        'MAIN EXPERIMENT', '', ...
        'The task is the same as in practice: count the target arrows.', '', ...
        'A face may appear beside the arrows. Sometimes flickering patterns hide it.'};

    pages{end+1} = { ...
        'FACE QUESTION', '', ...
        'After you report the number of targets, you will always be asked: "Where was the face?"', '', ...
        sprintf('%s = LEFT', leftLbl), ...
        sprintf('%s = RIGHT', rightLbl), ...
        sprintf('%s = did NOT see a face', noneLbl), '', ...
        'If you did not see a face, do not guess.'};

    pages{end+1} = { ...
        'THOUGHT QUESTIONS', '', ...
        'Now and then, a few questions will appear about what you were just thinking.', '', ...
        'Report what was in your mind at the moment BEFORE the questions appeared.', '', ...
        'There are no right or wrong answers.'};

    pages{end+1} = { ...
        'PAUSE', '', ...
        sprintf('To pause, press %s at any time. The pause starts when the current trial has finished.', pauseLbl), '', ...
        sprintf('If the two frames stop fusing, press %s. The trial finishes first, then you can adjust.', calibLbl), '', ...
        'Press any key to begin.'};

    n_pages = numel(pages);
    i = 1;
    while i <= n_pages
        lines = pages{i};
        if i < n_pages
            lines = [lines, {'', 'Press any key to continue.'}];
        end
        [ctx, ~, keyCode] = wait_key_or_calib(win, cfg, ppd, winRect, ctx, ...
            @(c) flip_probe_screen(win, cfg, frameTex, winRect, c.frameDestRects, ppd, lines));

        if keyCode(backKey)
            i = max(1, i - 1);
        else
            i = i + 1;
        end
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
