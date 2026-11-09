function diagnose_face_backgrounds()
% DIAGNOSE_FACE_BACKGROUNDS  Sample the corner/border pixels of every
% face image and report their actual value(s) vs. cfg.background_rgb
% (128,128,128). Handles BOTH grayscale (single-channel) and RGB images
% -- your images turned out to be grayscale, which the first version of
% this script didn't handle.
%
% HOW TO RUN:
%   diagnose_face_backgrounds
%
% No PsychToolbox window needed -- pure image reading.

    cfg = config_experiment();
    target_gray = mean(cfg.background_rgb); % 128, assuming R=G=B as given
    fprintf('Target background: [%d %d %d] (gray value %.1f)\n\n', ...
        cfg.background_rgb(1), cfg.background_rgb(2), cfg.background_rgb(3), target_gray);

    n_ids = numel(cfg.face_identities);
    n_emotions = numel(cfg.emotion_levels);
    mismatches = 0;
    n_grayscale = 0;
    n_rgb = 0;

    for idx = 1:n_ids
        id = cfg.face_identities(idx).id;
        gender = cfg.face_identities(idx).gender;
        for e = 1:n_emotions
            emotion = cfg.emotion_levels{e};
            [fpath, fname] = get_face_filename(cfg, id, gender, emotion);
            if ~isfile(fpath)
                fprintf('MISSING: %s\n', fpath);
                continue;
            end
            img = imread(fpath);
            [h, w, n_channels] = size(img);
            m = min(5, floor(min(h,w)/10));

            if n_channels == 1
                n_grayscale = n_grayscale + 1;
                corners = double([img(m,m); img(m,w-m); img(h-m,m); img(h-m,w-m)]);
                avg_corner = mean(corners);
                diff_from_target = avg_corner - target_gray;
                max_abs_diff = abs(diff_from_target);

                if max_abs_diff > 1
                    mismatches = mismatches + 1;
                    fprintf('%s [grayscale]: corner avg = %.1f  (diff from %d: %.1f)\n', ...
                        fname, avg_corner, target_gray, diff_from_target);
                end
            else
                n_rgb = n_rgb + 1;
                corners = [ ...
                    double(squeeze(img(m, m, 1:3)))'; ...
                    double(squeeze(img(m, w-m, 1:3)))'; ...
                    double(squeeze(img(h-m, m, 1:3)))'; ...
                    double(squeeze(img(h-m, w-m, 1:3)))'];
                avg_corner = mean(corners, 1);
                diff_from_target = avg_corner - double(cfg.background_rgb);
                max_abs_diff = max(abs(diff_from_target));

                if max_abs_diff > 1
                    mismatches = mismatches + 1;
                    fprintf('%s [RGB]: corner RGB avg = [%.1f %.1f %.1f]  (diff from 128: [%.1f %.1f %.1f])\n', ...
                        fname, avg_corner(1), avg_corner(2), avg_corner(3), ...
                        diff_from_target(1), diff_from_target(2), diff_from_target(3));
                end
            end
        end
    end

    fprintf('\nChecked %d grayscale, %d RGB images.\n', n_grayscale, n_rgb);
    if mismatches == 0
        fprintf('All sampled face backgrounds matched target (within 1 unit). No fix needed.\n');
    else
        fprintf('%d image(s) had a background mismatch >1 unit from target.\n', mismatches);
        fprintf('Run fix_face_backgrounds to auto-correct these before your session.\n');
    end
end
