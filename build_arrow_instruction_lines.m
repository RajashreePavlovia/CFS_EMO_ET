function lines = build_arrow_instruction_lines(attention, mode)
% BUILD_ARROW_INSTRUCTION_LINES  Build the text lines telling the
% participant which arrows to count, for this block's load condition.
% Used both at block-start ("This block:") and as a reminder right after
% a probe fires (same block, keep counting), so the wording lives in one
% place.
%
%   lines = build_arrow_instruction_lines(attention, mode)
%
% INPUTS
%   attention - 'low' or 'high' (block.attention)
%   mode      - 'start' (block beginning), 'continue' (post-probe reminder)
%               or 'recalibrated' (reminder after a C-key recalibration)
%
% OUTPUT
%   lines - cell array of strings for draw_probe_screen

    if ~any(strcmpi(mode, {'start', 'continue', 'recalibrated'}))
        error('build_arrow_instruction_lines:badMode', 'mode must be ''start'', ''continue'' or ''recalibrated''.');
    end

    if strcmpi(mode, 'start')
        if strcmpi(attention, 'low')
            lines = {'This block:', '', 'Count the RED arrows only.', '', 'Press any key to begin.'};
        else
            lines = {'This block:', '', 'The YELLOW UPRIGHT arrows', ...
                'AND the GREEN DOWNWARD (inverted) arrows.', '', 'Press any key to begin.'};
        end
    elseif strcmpi(mode, 'recalibrated')
        % after a C-key recalibration (no probe): same block carries on
        if strcmpi(attention, 'low')
            lines = {'Frames adjusted - same block continues.', '', ...
                'Continue counting the RED arrows only.', '', 'Press any key to continue.'};
        else
            lines = {'Frames adjusted - same block continues.', '', ...
                'Continue counting the YELLOW UPRIGHT arrows', ...
                'AND the GREEN DOWNWARD (inverted) arrows.', '', 'Press any key to continue.'};
        end
    else
        % post-probe: same block carries on
        if strcmpi(attention, 'low')
            lines = {'Questions finished - same block continues.', '', ...
                'Continue counting the RED arrows only.', '', 'Press any key to continue.'};
        else
            lines = {'Questions finished - same block continues.', '', ...
                'Continue counting the YELLOW UPRIGHT arrows', ...
                'AND the GREEN DOWNWARD (inverted) arrows.', '', 'Press any key to continue.'};
        end
    end
end
