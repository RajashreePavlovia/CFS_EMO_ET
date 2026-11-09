function maskTextures = preload_mask_textures(win, cfg)
% PRELOAD_MASK_TEXTURES  Load all Mondrian CFS mask images into PTB
% textures ONCE at the start of a session, rather than reading from disk
% every trial. With 200 masks at ~10Hz update, loading on-the-fly during
% a trial would risk dropped frames -- pre-loading avoids that.
%
%   maskTextures = preload_mask_textures(win, cfg)
%
% INPUTS
%   win - PsychToolbox window pointer
%   cfg - struct from config_experiment() (uses cfg.mask_folder,
%         cfg.mask_filename_prefix, cfg.mask_n_total)
%
% OUTPUT
%   maskTextures - 1 x cfg.mask_n_total vector of PTB texture pointers.
%                  maskTextures(id) corresponds to the mask file
%                  [prefix sprintf('%03d',id) '.png'], matching the
%                  indices produced by generate_mask_sequence.
%
% NOTE: this reads real files from cfg.mask_folder and has not been
% tested against your actual mask files/folder -- if filenames don't
% match exactly (e.g. zero-padding, extension), this will error with a
% clear "file not found" message telling you which file it expected.

    n = cfg.mask_n_total;
    maskTextures = zeros(1, n);

    fprintf('Loading %d mask textures from %s ...\n', n, cfg.mask_folder);
    for i = 1:n
        fname = sprintf('%s%03d.png', cfg.mask_filename_prefix, i);
        fpath = fullfile(cfg.mask_folder, fname);
        if ~isfile(fpath)
            error('preload_mask_textures:fileNotFound', ...
                'Expected mask file not found: %s', fpath);
        end
        img = imread(fpath);
        maskTextures(i) = Screen('MakeTexture', win, img);
    end
    fprintf('Done loading mask textures.\n');
end
