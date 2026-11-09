function detect_face_background_gray()
% DETECT_FACE_BACKGROUND_GRAY  Sample the corner pixels of every face
% image and report the detected background value(s), so you can set
% cfg.background_rgb in config_experiment.m to match your actual face
% images instead of correcting the images themselves.
%
% HOW TO RUN:
%   detect_face_background_gray
%
% No PsychToolbox window needed -- pure image reading.
%
% WHAT TO DO WITH THE RESULT: if the detected value is consistent across
% all images (recommended value near-identical to the min/max), copy the
% printed RECOMMENDED line into config_experiment.m, replacing
% cfg.background_rgb = [128 128 128] with the detected value. If images
% are grayscale, use [G G G] with G = the detected gray value. If
% inconsistent across images, see the warning at the end -- a single
% fixed experiment background can't perfectly match every image in that
% case, and you may want to reconsider fixing the images instead.

    cfg = config_experiment();

    n_ids = numel(cfg.face_identities);
    n_emotions = numel(cfg.emotion_levels);
    detected_values = []; % one row per image: either [G] (grayscale) or [R G B]
    is_grayscale_set = [];

    for idx = 1:n_ids
        id = cfg.face_identities(idx).id;
        gender = cfg.face_identities(idx).gender;
        for e = 1:n_emotions
            emotion = cfg.emotion_levels{e};
            [fpath, ~] = get_face_filename(cfg, id, gender, emotion);
            if ~isfile(fpath)
                continue;
            end
            img = imread(fpath);
            [h, w, n_channels] = size(img);
            m = min(5, floor(min(h,w)/10));

            if n_channels == 1
                corners = double([img(m,m); img(m,w-m); img(h-m,m); img(h-m,w-m)]);
                detected_values(end+1, :) = [mean(corners), mean(corners), mean(corners)]; %#ok<AGROW>
                is_grayscale_set(end+1) = true; %#ok<AGROW>
            else
                corners = [ ...
                    double(squeeze(img(m, m, 1:3)))'; ...
                    double(squeeze(img(m, w-m, 1:3)))'; ...
                    double(squeeze(img(h-m, m, 1:3)))'; ...
                    double(squeeze(img(h-m, w-m, 1:3)))'];
                detected_values(end+1, :) = mean(corners, 1); %#ok<AGROW>
                is_grayscale_set(end+1) = false; %#ok<AGROW>
            end
        end
    end

    if isempty(detected_values)
        error('detect_face_background_gray:noImages', 'No face images found/read -- check cfg.face_folder_root.');
    end

    all_grayscale = all(is_grayscale_set);
    if all_grayscale
        type_str = 'all grayscale';
    else
        type_str = 'mixed grayscale/RGB';
    end
    fprintf('Sampled %d images (%s).\n\n', size(detected_values,1), type_str);

    mean_val = mean(detected_values, 1);
    min_val = min(detected_values, [], 1);
    max_val = max(detected_values, [], 1);
    spread = max_val - min_val;

    fprintf('Mean detected background: [%.1f %.1f %.1f]\n', mean_val(1), mean_val(2), mean_val(3));
    fprintf('Range across images:      [%.1f-%.1f, %.1f-%.1f, %.1f-%.1f]\n', ...
        min_val(1), max_val(1), min_val(2), max_val(2), min_val(3), max_val(3));

    recommended = round(mean_val);
    fprintf('\nRECOMMENDED: cfg.background_rgb = [%d %d %d];\n', recommended(1), recommended(2), recommended(3));

    if max(spread) > 3
        fprintf(['\nWARNING: background value varies by up to %.1f units across your images -- ' ...
            'a single fixed cfg.background_rgb can''t match every image exactly in that case. ' ...
            'This spread might be worth a quick visual check of the highest/lowest outlier images.\n'], max(spread));
    else
        fprintf('\nBackground is consistent across images (spread < 3 units) -- the recommended value should match all of them well.\n');
    end
end
