function fix_face_backgrounds()
% FIX_FACE_BACKGROUNDS  For every face image, detect background-colored
% pixels (near-uniform region matching the image's own corners) and
% replace them with EXACTLY cfg.background_rgb (or its grayscale
% equivalent), leaving the face itself untouched. Saves corrected copies
% to a new subfolder so your original files are never overwritten.
% Handles BOTH grayscale (single-channel) and RGB images.
%
% HOW TO RUN:
%   fix_face_backgrounds
%
% Then update cfg.face_folder_root in config_experiment.m to point to the
% new '..._bgfixed' folder (printed at the end) before running the real
% experiment.
%
% METHOD: for each image, the four corners are sampled to detect the
% image's actual background value (which may differ slightly from
% exactly 128 due to compression or export settings). Any pixel within a
% small tolerance of that detected value is replaced with EXACTLY the
% target. This is a simple color-key correction, not sophisticated
% segmentation -- it works well for a clean, near-uniform background but
% could bleed into the face if the face itself contains tones very close
% to the background gray (unlikely for a photo, but inspect a few
% corrected images visually before trusting all of them).

    cfg = config_experiment();
    tolerance = 8; % max distance from detected background to be considered "background"
    target_gray = mean(cfg.background_rgb);

    src_root = cfg.face_folder_root;
    dst_root = [src_root '_bgfixed'];

    n_ids = numel(cfg.face_identities);
    n_emotions = numel(cfg.emotion_levels);
    n_fixed = 0;
    n_total = 0;

    for idx = 1:n_ids
        id = cfg.face_identities(idx).id;
        gender = cfg.face_identities(idx).gender;
        for e = 1:n_emotions
            emotion = cfg.emotion_levels{e};
            [src_path, fname] = get_face_filename(cfg, id, gender, emotion);
            if ~isfile(src_path)
                fprintf('MISSING (skipped): %s\n', src_path);
                continue;
            end
            n_total = n_total + 1;

            img = imread(src_path);
            [h, w, n_channels] = size(img);
            m = min(5, floor(min(h,w)/10));

            if n_channels == 1
                corners = double([img(m,m); img(m,w-m); img(h-m,m); img(h-m,w-m)]);
                detected_bg = mean(corners);

                img_d = double(img);
                dist = abs(img_d - detected_bg);
                bg_mask = dist <= tolerance;

                corrected = img;
                corrected(bg_mask) = uint8(target_gray);

            else
                corners = [ ...
                    double(squeeze(img(m, m, 1:3)))'; ...
                    double(squeeze(img(m, w-m, 1:3)))'; ...
                    double(squeeze(img(h-m, m, 1:3)))'; ...
                    double(squeeze(img(h-m, w-m, 1:3)))'];
                detected_bg = mean(corners, 1);

                img_d = double(img(:,:,1:3));
                dist = sqrt(sum((img_d - reshape(detected_bg, 1, 1, 3)).^2, 3));
                bg_mask = dist <= tolerance;

                corrected = img;
                for c = 1:3
                    ch = corrected(:,:,c);
                    ch(bg_mask) = cfg.background_rgb(c);
                    corrected(:,:,c) = ch;
                end
            end

            subfolder = cfg.face_emotion_subfolder.(emotion);
            dst_dir = fullfile(dst_root, subfolder);
            if ~isfolder(dst_dir)
                mkdir(dst_dir);
            end
            imwrite(corrected, fullfile(dst_dir, fname));
            n_fixed = n_fixed + 1;
        end
    end

    fprintf('\nCorrected %d/%d images.\n', n_fixed, n_total);
    fprintf('Saved to: %s\n', dst_root);
    fprintf('Set cfg.face_folder_root = ''%s''; in config_experiment.m to use these.\n', dst_root);
    fprintf('IMPORTANT: spot-check a few corrected images visually before trusting all of them -- the correction can bleed into the face if it contains near-background-gray tones.\n');
end
