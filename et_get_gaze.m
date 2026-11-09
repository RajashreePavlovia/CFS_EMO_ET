function [gx, gy, ok] = et_get_gaze(win)
% ET_GET_GAZE  Newest gaze position in VIRTUAL screen pixels (mean of the
% eyes that currently have valid data). ok = false if there is no valid sample
% (blink, track loss, nothing new yet).
%
% 'live' : newest EyeLink link sample (recording must be running).
% 'dummy': the mouse; hover over the fixation cross in the LEFT frame.

    gx = NaN; gy = NaN; ok = false;
    S = et_state('get');
    switch S.mode
        case 'dummy'
            if isempty(S.geom), return; end
            [mx, my] = GetMouse(win);
            g = S.geom;
            gx = mx - g.centers.left(1) + g.vc(1);
            gy = my - g.centers.left(2) + g.vc(2);
            ok = true;
        case 'live'
            if Eyelink('NewFloatSampleAvailable') <= 0
                return;
            end
            smp = Eyelink('NewestFloatSample');
            eye = Eyelink('EyeAvailable');            % 0 left, 1 right, 2 both
            if eye == 2
                idx = [1 2];
            else
                idx = eye + 1;
            end
            miss = S.el.MISSING_DATA;
            x = smp.gx(idx); y = smp.gy(idx);
            good = x ~= miss & y ~= miss;
            if any(good)
                gx = mean(x(good));
                gy = mean(y(good));
                ok = true;
            end
    end
end
