function faceTextures = preload_face_textures(win, cfg)
% PRELOAD_FACE_TEXTURES
% Load all face images and preserve their PNG alpha channel.

    faceTextures = containers.Map();

    fprintf('Loading face textures from %s ...\n', cfg.face_folder_root);

    n_ids = numel(cfg.face_identities);
    n_emotions = numel(cfg.emotion_levels);
    total = n_ids * n_emotions;
    count = 0;

    for idx = 1:n_ids

        id = cfg.face_identities(idx).id;
        gender = cfg.face_identities(idx).gender;

        for e = 1:n_emotions

            emotion = cfg.emotion_levels{e};

            [fpath, ~] = get_face_filename(cfg, id, gender, emotion);

            if ~isfile(fpath)
                error('preload_face_textures:fileNotFound', ...
                    'Expected face file not found: %s', fpath);
            end

            % ---------------------------------------------------------
            % READ RGB + PNG ALPHA
            % ---------------------------------------------------------
            [img, ~, alpha] = imread(fpath);

            % Make grayscale image RGB
            if ndims(img) == 2
                img = repmat(img, [1 1 3]);
            end

            % If no alpha exists, make image fully opaque
            if isempty(alpha)
                alpha = uint8(255 * ones(size(img,1), size(img,2)));
            end

            % Add alpha as fourth channel
            img(:,:,4) = alpha;

            % ---------------------------------------------------------
            % CREATE PSYCHTOOLBOX TEXTURE
            % ---------------------------------------------------------
            tex = Screen('MakeTexture', win, img);

            key = face_texture_key(id, gender, emotion);
            faceTextures(key) = tex;

            count = count + 1;
        end
    end

    fprintf('Loaded %d/%d face textures with alpha channels.\n', ...
        count, total);
end