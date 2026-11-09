function geom = et_make_geom(winRect, frame_centers, ppd, frameTex, frameDestRects)
% ET_MAKE_GEOM  Geometry shared by calibration targets, gaze conversion and
% interest areas.
%
% THE "VIRTUAL SCREEN": the tracker is told its screen is ONE half of the
% display (W/2 x H pixels). Every eye-tracking coordinate (calibration
% targets, gaze samples, interest areas) lives in that virtual screen, whose
% centre is the centre of the FUSED frame. A virtual point v is drawn at
%     frame_centers.left  + (v - vc)   in the left half, and
%     frame_centers.right + (v - vc)   in the right half,
% so both eyes always see the same fused point, whatever fusion calibration
% this participant ended up with, and gaze (0,0)-offsets are directly
% comparable across participants.

    W = winRect(3) - winRect(1);
    H = winRect(4) - winRect(2);
    geom = struct();
    geom.Wv = W / 2;
    geom.Hv = H;
    geom.vc = [geom.Wv / 2, H / 2];
    geom.centers = frame_centers;
    geom.ppd = ppd;
    geom.frameTex = [];
    geom.frameDestRects = [];
    if nargin >= 5
        geom.frameTex = frameTex;            % fusion-frame texture + rects, redrawn under every calibration target
        geom.frameDestRects = frameDestRects;
    end
end
