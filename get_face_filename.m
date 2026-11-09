function [full_path, fname] = get_face_filename(cfg, identity_id, gender, emotion)
% GET_FACE_FILENAME  Build the full path + filename for a face stimulus.
%
%   [full_path, fname] = get_face_filename(cfg, identity_id, gender, emotion)
%
% INPUTS
%   cfg         - struct from config_experiment()
%   identity_id - 2-char identity string, e.g. '03' (must be one of
%                 cfg.face_identity_ids)
%   gender      - 'F' or 'M'
%   emotion     - one of cfg.emotion_levels ('happy','angry','neutral')
%
% OUTPUT
%   full_path   - absolute path to the image file
%   fname       - just the filename
%
% Filename pattern (from KDEF-style naming, confirmed with user):
%   A[Gender][ID][EmotionCode]_processed.png
%   e.g. angry, female, identity 03 -> AF03ANS_processed.png
%
% NOTE: this assumes the leading 'A' is a fixed constant across all
% files, as confirmed. If that turns out to vary, update this function.

    if ~isfield(cfg.face_emotion_code, emotion)
        error('get_face_filename:badEmotion', 'Unknown emotion: %s', emotion);
    end
    emo_code = cfg.face_emotion_code.(emotion);
    subfolder = cfg.face_emotion_subfolder.(emotion);

    fname = sprintf('A%s%s%s_processed.png', upper(gender), identity_id, emo_code);
    full_path = fullfile(cfg.face_folder_root, subfolder, fname);
end
