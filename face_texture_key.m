function key = face_texture_key(identity_id, gender, emotion)
% FACE_TEXTURE_KEY  Build a consistent lookup key for the face-texture
% map, used both when preloading (preload_face_textures) and when
% looking up which texture to draw for a given trial.
%
%   key = face_texture_key(identity_id, gender, emotion)
%
% e.g. face_texture_key('03','F','angry') -> 'F_03_angry'

    key = sprintf('%s_%s_%s', upper(gender), identity_id, emotion);
end
