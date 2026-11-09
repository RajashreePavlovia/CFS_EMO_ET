function draw_face(win, faceTextures, cfg, ppd, frame_center, identity_id, gender, emotion, side)
% DRAW_FACE  Draw a face stimulus, offset left or right from the frame
% center by cfg.face_eccentricity_deg (converted to pixels), sized
% cfg.face_width_deg x cfg.face_height_deg.
%
%   draw_face(win, faceTextures, cfg, ppd, frame_center, identity_id, gender, emotion, side)
%
% INPUTS
%   win           - PsychToolbox window pointer
%   faceTextures  - containers.Map from preload_face_textures
%   cfg           - struct from config_experiment()
%   ppd           - pixels-per-degree, from compute_ppd()
%   frame_center  - [x y] pixel center of the (non-dominant) eye's fusion
%                   frame, from compute_frame_centers
%   identity_id, gender, emotion - identify which face texture to use
%   side          - 'left' or 'right': which side of frame-center to
%                   offset the face to (this trial's face_side)
%
% Looks up the texture from the identity-keyed map, then delegates the
% actual position/size drawing to draw_face_texture.m (shared with the
% practice session, which picks textures directly rather than by identity).

    key = face_texture_key(identity_id, gender, emotion);
    if ~isKey(faceTextures, key)
        error('draw_face:missingTexture', 'No preloaded texture for key %s', key);
    end
    draw_face_texture(win, cfg, ppd, frame_center, faceTextures(key), side);
end
