function mask_ids = generate_mask_sequence(cfg, n_frames, prev_mask_id)
% GENERATE_MASK_SEQUENCE  Pick a sequence of Mondrian mask indices for CFS
% presentation, with no mask repeating on consecutive frames.
%
%   mask_ids = generate_mask_sequence(cfg, n_frames, prev_mask_id)
%
% INPUTS
%   cfg          - struct from config_experiment() (uses cfg.mask_n_total)
%   n_frames     - number of mask frames needed (e.g. ceil(trial_duration /
%                  cfg.mask_frame_duration_s))
%   prev_mask_id - the mask index used immediately before this sequence
%                  starts (e.g. last mask of the previous trial), so the
%                  no-repeat rule holds across trial boundaries too.
%                  Pass [] if there is no previous mask (start of block).
%
% OUTPUT
%   mask_ids     - 1 x n_frames vector of integers in [1, cfg.mask_n_total],
%                  filenames are [cfg.mask_filename_prefix sprintf('%03d',id) '.png']
%                  e.g. Mondrian_001.png

    if nargin < 3
        prev_mask_id = [];
    end

    n_total = cfg.mask_n_total;
    mask_ids = zeros(1, n_frames);
    prev = prev_mask_id;

    for i = 1:n_frames
        pick = randi(n_total);
        if ~isempty(prev)
            while pick == prev
                pick = randi(n_total);
            end
        end
        mask_ids(i) = pick;
        prev = pick;
    end
end
