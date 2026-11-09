%% ============================================================
%  GRAYSCALE MONDRIAN MASK GENERATOR FOR CFS
%  (patch size specified in degrees of visual angle, per paper)
%
%  Paper spec:
%    "Randomly generated achromatic Mondrian patterned images
%     made of rectangles drawn in variable size (0.2-1.2 deg
%     in length), luminance, and location within a square
%     aperture of uniform luminance (15 cd/m2). The Mondrian
%     images changed every 100 ms throughout a trial."
%
%  Screen:
%       Resolution: 1920 x 1080 pixels
%       Diagonal:   21.5 inches, assumed 16:9 aspect ratio
%       Viewing distance: 60 cm
%
%  Mask:
%       7.8 x 7.8 degrees visual angle
%       Grayscale, rectangular Mondrian patches
%       Patch length: 0.2 - 1.2 degrees (width & height drawn
%       independently within this range)
%
%  Output:
%       200 PNG masks, changing every 100 ms (10 Hz) in CFS
% =============================================================

clear;
clc;
close all;

%% ============================================================
% 1. BASIC PARAMETERS
% ============================================================

nMasks = 200;

viewingDistance_cm = 60;

% Monitor: 21.5" diagonal, 1920x1080, assumed 16:9 aspect ratio
screenDiagonal_in = 21.5;
aspectW = 16; aspectH = 9;
diagRatio = sqrt(aspectW^2 + aspectH^2);

screenWidth_in  = screenDiagonal_in * aspectW / diagRatio;
screenHeight_in = screenDiagonal_in * aspectH / diagRatio;

screenWidth_cm  = screenWidth_in  * 2.54;
screenHeight_cm = screenHeight_in * 2.54;

screenWidth_px  = 1920;
screenHeight_px = 1080;

desiredVisualAngle_deg = 7.8;

%% ============================================================
% 2. CALCULATE MASK SIZE (7.8 x 7.8 deg)
% ============================================================

maskSize_cm = 2 * viewingDistance_cm * ...
    tand(desiredVisualAngle_deg / 2);

pixelsPerCm_horizontal = screenWidth_px / screenWidth_cm;
pixelsPerCm_vertical   = screenHeight_px / screenHeight_cm;

maskWidth_px  = round(maskSize_cm * pixelsPerCm_horizontal);
maskHeight_px = round(maskSize_cm * pixelsPerCm_vertical);

fprintf('\n============================================\n');
fprintf('SCREEN PARAMETERS\n');
fprintf('============================================\n');
fprintf('Screen width  = %.2f in (%.2f cm)\n', screenWidth_in, screenWidth_cm);
fprintf('Screen height = %.2f in (%.2f cm)\n', screenHeight_in, screenHeight_cm);
fprintf('Pixels/cm (horizontal) = %.2f\n', pixelsPerCm_horizontal);
fprintf('Pixels/cm (vertical)   = %.2f\n', pixelsPerCm_vertical);

fprintf('\n============================================\n');
fprintf('MASK PARAMETERS\n');
fprintf('============================================\n');
fprintf('Desired visual angle = %.2f degrees\n', desiredVisualAngle_deg);
fprintf('Physical mask size = %.2f cm x %.2f cm\n', maskSize_cm, maskSize_cm);
fprintf('Mask size = %d x %d pixels\n', maskWidth_px, maskHeight_px);

%% ============================================================
% 3. PATCH SIZE (0.2 - 1.2 deg, per paper), converted to pixels
% ============================================================

patchAngle_min_deg = 0.2;
patchAngle_max_deg = 1.2;

patchSize_min_cm = 2 * viewingDistance_cm * tand(patchAngle_min_deg / 2);
patchSize_max_cm = 2 * viewingDistance_cm * tand(patchAngle_max_deg / 2);

% Width and height each drawn independently within this deg range
patchWidth_min_px  = round(patchSize_min_cm * pixelsPerCm_horizontal);
patchWidth_max_px  = round(patchSize_max_cm * pixelsPerCm_horizontal);

patchHeight_min_px = round(patchSize_min_cm * pixelsPerCm_vertical);
patchHeight_max_px = round(patchSize_max_cm * pixelsPerCm_vertical);

fprintf('\n============================================\n');
fprintf('PATCH PARAMETERS\n');
fprintf('============================================\n');
fprintf('Patch length range = %.2f - %.2f degrees\n', ...
    patchAngle_min_deg, patchAngle_max_deg);
fprintf('Patch width  range = %d - %d pixels\n', ...
    patchWidth_min_px, patchWidth_max_px);
fprintf('Patch height range = %d - %d pixels\n', ...
    patchHeight_min_px, patchHeight_max_px);

% Number of rectangular patches per mask
minPatches = 200;
maxPatches = 250;

% Grayscale values (approximate luminance steps).
% NOTE: the paper specifies the aperture is normalized to a mean
% luminance of 15 cd/m2 and a calibrated RMS contrast. True cd/m2
% control requires a photometer reading + gamma correction (LUT)
% for your specific monitor - plain 8-bit grayscale values (0-255)
% are NOT linearly related to cd/m2 output. This script uses
% grayscale as a stand-in; if you need photometrically accurate
% luminance, that calibration step has to happen separately
% (e.g., via Psychtoolbox gamma correction) before/after this.
grayLevels = [0 32 64 96 127 159 191 223 255];

%% ============================================================
% 4. OUTPUT FOLDER
% ============================================================

outputFolder = fullfile('D:\CFS\Expt_emo\Stimuli\CFS_Mondrian_Grayscale');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

if ~exist(outputFolder, 'dir')
    error('Could not create output folder: %s', outputFolder);
end

fprintf('\nOutput folder:\n%s\n', outputFolder);

%% ============================================================
% 5. GENERATE MASKS
% ============================================================

for maskNum = 1:nMasks

    % Middle gray background (uniform "aperture" luminance)
    img = uint8(127 * ones(maskHeight_px, maskWidth_px));

    nPatches = randi([minPatches maxPatches]);

    % ------------------------------------------------------
    % Force coverage of the four edges
    % ------------------------------------------------------
    edgePatches = 12;

    for p = 1:edgePatches

        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);

        grayValue = grayLevels(randi(length(grayLevels)));

        edge = mod(p-1,4) + 1;

        switch edge
            case 1 % TOP
                x = randi([1 max(1, maskWidth_px-patchWidth+1)]);
                y = 1;
            case 2 % RIGHT
                x = maskWidth_px-patchWidth+1;
                y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
            case 3 % BOTTOM
                x = randi([1 max(1, maskWidth_px-patchWidth+1)]);
                y = maskHeight_px-patchHeight+1;
            case 4 % LEFT
                x = 1;
                y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
        end

        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    % ------------------------------------------------------
    % Force corner coverage
    % ------------------------------------------------------
    for c = 1:4

        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);

        grayValue = grayLevels(randi(length(grayLevels)));

        switch c
            case 1 % TOP-LEFT
                x = 1; y = 1;
            case 2 % TOP-RIGHT
                x = maskWidth_px-patchWidth+1; y = 1;
            case 3 % BOTTOM-LEFT
                x = 1; y = maskHeight_px-patchHeight+1;
            case 4 % BOTTOM-RIGHT
                x = maskWidth_px-patchWidth+1; y = maskHeight_px-patchHeight+1;
        end

        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    % ------------------------------------------------------
    % Remaining random patches, all drawn from the 0.2-1.2 deg
    % size range (matches the paper - one unified size pool)
    % ------------------------------------------------------
    remainingPatches = nPatches - edgePatches - 4;

    for p = 1:remainingPatches

        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);

        x = randi([1 max(1, maskWidth_px-patchWidth+1)]);
        y = randi([1 max(1, maskHeight_px-patchHeight+1)]);

        grayValue = grayLevels(randi(length(grayLevels)));

        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    % ------------------------------------------------------
    % Save mask
    % ------------------------------------------------------
    filename = fullfile(outputFolder, sprintf('Mondrian_%03d.png', maskNum));
    imwrite(img, filename);

end

fprintf('\n============================================\n');
fprintf('%d Mondrian masks generated successfully.\n', nMasks);
fprintf('Saved to: %s\n', outputFolder);
fprintf('============================================\n');

%% ============================================================
% 6. DISPLAY RANDOM EXAMPLES
% ============================================================

figure('Name', 'Example CFS Mondrian Masks', 'Color', 'white');

for k = 1:9
    randomNumber = randi(nMasks);
    filename = fullfile(outputFolder, sprintf('Mondrian_%03d.png', randomNumber));
    img = imread(filename);
    subplot(3,3,k);
    imshow(img, 'InitialMagnification', 'fit');
    title(sprintf('Mask %03d', randomNumber));
end

sgtitle('Example Grayscale CFS Mondrian Masks');