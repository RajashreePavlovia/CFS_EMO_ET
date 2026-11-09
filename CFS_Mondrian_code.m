%% ============================================================
%  MONDRIAN MASK GENERATOR FOR CFS
%  Generates TWO independent sets: grayscale masks + vivid colored masks
%
%  Paper spec (patch geometry):
%    "Randomly generated achromatic Mondrian patterned images
%     made of rectangles drawn in variable size (0.2-1.2 deg
%     in length), luminance, and location within a square
%     aperture of uniform luminance (15 cd/m2). The Mondrian
%     images changed every 100 ms throughout a trial."
%
%  NOTE on luminance: true cd/m2 matching requires photometer
%  calibration of your specific monitor (gamma-corrected LUT).
%  Grayscale and color sets below are brightness-tuned
%  independently of each other (not matched), for a vivid,
%  punchy appearance. If physically calibrated luminance is
%  needed, that step must be done separately (e.g. via a
%  photometer + gamma correction) before/after this script.
%
%  Screen:
%       Resolution: 1920 x 1080 pixels
%       Diagonal:   21.5 inches, assumed 16:9 aspect ratio
%       Viewing distance: 60 cm
%
%  Mask:
%       7.8 x 7.8 degrees visual angle
%       Rectangular Mondrian patches, 0.2-1.2 deg in length
%
%  Output:
%       200 grayscale PNGs + 200 colored PNGs
%       Intended CFS rate: 10 Hz (100 ms per mask)
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

maskSize_cm = 2 * viewingDistance_cm * tand(desiredVisualAngle_deg / 2);

pixelsPerCm_horizontal = screenWidth_px / screenWidth_cm;
pixelsPerCm_vertical   = screenHeight_px / screenHeight_cm;

maskWidth_px  = round(maskSize_cm * pixelsPerCm_horizontal);
maskHeight_px = round(maskSize_cm * pixelsPerCm_vertical);

fprintf('\n============================================\n');
fprintf('SCREEN PARAMETERS\n');
fprintf('============================================\n');
fprintf('Screen width  = %.2f in (%.2f cm)\n', screenWidth_in, screenWidth_cm);
fprintf('Screen height = %.2f in (%.2f cm)\n', screenHeight_in, screenHeight_cm);

fprintf('\nMask size = %d x %d pixels (%.2f deg)\n', ...
    maskWidth_px, maskHeight_px, desiredVisualAngle_deg);

%% ============================================================
% 3. PATCH SIZE (0.2 - 1.2 deg, per paper), converted to pixels
% ============================================================

patchAngle_min_deg = 0.2;
patchAngle_max_deg = 1.2;

patchSize_min_cm = 2 * viewingDistance_cm * tand(patchAngle_min_deg / 2);
patchSize_max_cm = 2 * viewingDistance_cm * tand(patchAngle_max_deg / 2);

patchWidth_min_px  = round(patchSize_min_cm * pixelsPerCm_horizontal);
patchWidth_max_px  = round(patchSize_max_cm * pixelsPerCm_horizontal);

patchHeight_min_px = round(patchSize_min_cm * pixelsPerCm_vertical);
patchHeight_max_px = round(patchSize_max_cm * pixelsPerCm_vertical);

fprintf('\nPatch length range = %.2f - %.2f deg\n', patchAngle_min_deg, patchAngle_max_deg);
fprintf('Patch width  range = %d - %d px\n', patchWidth_min_px, patchWidth_max_px);
fprintf('Patch height range = %d - %d px\n', patchHeight_min_px, patchHeight_max_px);

minPatches = 200;
maxPatches = 300;
edgePatches = 12;

%% ============================================================
% 4. GRAYSCALE LEVELS + COLOR PALETTE (independent brightness)
% ============================================================

% --- Grayscale set: biased brighter, no near-black values ---
grayLevels = [0 32 64 96 128 160 192 224 255];

% --- Color set: vivid, independent from grayscale ---
% Hues spread around the color wheel (in degrees, 0-360)
colorHues = [0 30 60 90 120 150 180 210 240 270 300 330];

% Saturation and brightness (V) ranges for vivid colors.
% Both kept high -> punchy, saturated patches. No forced
% luminance matching to grayscale or across hues.
colorSatRange = [0.85 1.0];
colorValRange = [0.85 1.0];

%% ============================================================
% 5. OUTPUT FOLDERS
% ============================================================

outputFolderGray  = fullfile("D:\CFS\Expt_emo\Stimuli\CFS_Mondrian_Grayscale");
outputFolderColor = fullfile("D:\CFS\Expt_emo\Stimuli\CFS_Mondrian_Colored");

if ~exist(outputFolderGray, 'dir');  mkdir(outputFolderGray);  end
if ~exist(outputFolderColor, 'dir'); mkdir(outputFolderColor); end

fprintf('\nGrayscale output folder:\n%s\n', outputFolderGray);
fprintf('Color output folder:\n%s\n', outputFolderColor);

%% ============================================================
% 6. GENERATE GRAYSCALE MASKS
% ============================================================

fprintf('\nGenerating %d grayscale masks...\n', nMasks);

for maskNum = 1:nMasks

    img = uint8(127 * ones(maskHeight_px, maskWidth_px));

    nPatches = randi([minPatches maxPatches]);

    % Edges
    for p = 1:edgePatches
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        grayValue = grayLevels(randi(length(grayLevels)));

        edge = mod(p-1,4) + 1;
        switch edge
            case 1, x = randi([1 max(1, maskWidth_px-patchWidth+1)]);  y = 1;
            case 2, x = maskWidth_px-patchWidth+1; y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
            case 3, x = randi([1 max(1, maskWidth_px-patchWidth+1)]);  y = maskHeight_px-patchHeight+1;
            case 4, x = 1; y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
        end
        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    % Corners
    for c = 1:4
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        grayValue = grayLevels(randi(length(grayLevels)));

        switch c
            case 1, x = 1; y = 1;
            case 2, x = maskWidth_px-patchWidth+1; y = 1;
            case 3, x = 1; y = maskHeight_px-patchHeight+1;
            case 4, x = maskWidth_px-patchWidth+1; y = maskHeight_px-patchHeight+1;
        end
        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    % Remaining random patches
    remainingPatches = nPatches - edgePatches - 4;
    for p = 1:remainingPatches
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        x = randi([1 max(1, maskWidth_px-patchWidth+1)]);
        y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
        grayValue = grayLevels(randi(length(grayLevels)));
        img(y:y+patchHeight-1, x:x+patchWidth-1) = uint8(grayValue);
    end

    filename = fullfile(outputFolderGray, sprintf('Mondrian_Gray_%03d.png', maskNum));
    imwrite(img, filename);
end

fprintf('Done: %d grayscale masks saved.\n', nMasks);

%% ============================================================
% 7. GENERATE COLORED MASKS
% ============================================================

fprintf('\nGenerating %d colored masks...\n', nMasks);

for maskNum = 1:nMasks

    % Background: neutral mid-gray aperture (uniform luminance),
    % only the patches carry vivid color
    img = uint8(127 * ones(maskHeight_px, maskWidth_px, 3));

    nPatches = randi([minPatches maxPatches]);

    % Edges
    for p = 1:edgePatches
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        rgbValue = getVividColor(colorHues, colorSatRange, colorValRange);

        edge = mod(p-1,4) + 1;
        switch edge
            case 1, x = randi([1 max(1, maskWidth_px-patchWidth+1)]);  y = 1;
            case 2, x = maskWidth_px-patchWidth+1; y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
            case 3, x = randi([1 max(1, maskWidth_px-patchWidth+1)]);  y = maskHeight_px-patchHeight+1;
            case 4, x = 1; y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
        end
        img(y:y+patchHeight-1, x:x+patchWidth-1, 1) = rgbValue(1);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 2) = rgbValue(2);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 3) = rgbValue(3);
    end

    % Corners
    for c = 1:4
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        rgbValue = getVividColor(colorHues, colorSatRange, colorValRange);

        switch c
            case 1, x = 1; y = 1;
            case 2, x = maskWidth_px-patchWidth+1; y = 1;
            case 3, x = 1; y = maskHeight_px-patchHeight+1;
            case 4, x = maskWidth_px-patchWidth+1; y = maskHeight_px-patchHeight+1;
        end
        img(y:y+patchHeight-1, x:x+patchWidth-1, 1) = rgbValue(1);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 2) = rgbValue(2);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 3) = rgbValue(3);
    end

    % Remaining random patches
    remainingPatches = nPatches - edgePatches - 4;
    for p = 1:remainingPatches
        patchWidth  = randi([patchWidth_min_px  patchWidth_max_px]);
        patchHeight = randi([patchHeight_min_px patchHeight_max_px]);
        x = randi([1 max(1, maskWidth_px-patchWidth+1)]);
        y = randi([1 max(1, maskHeight_px-patchHeight+1)]);
        rgbValue = getVividColor(colorHues, colorSatRange, colorValRange);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 1) = rgbValue(1);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 2) = rgbValue(2);
        img(y:y+patchHeight-1, x:x+patchWidth-1, 3) = rgbValue(3);
    end

    filename = fullfile(outputFolderColor, sprintf('Mondrian_%03d.png', maskNum));
    imwrite(img, filename);
end

fprintf('Done: %d colored masks saved.\n', nMasks);

fprintf('\n============================================\n');
fprintf('ALL MASKS GENERATED SUCCESSFULLY\n');
fprintf('Grayscale: %s\n', outputFolderGray);
fprintf('Color:     %s\n', outputFolderColor);
fprintf('============================================\n');

%% ============================================================
% 8. DISPLAY RANDOM EXAMPLES (grayscale + color side by side)
% ============================================================

figure('Name', 'Example CFS Mondrian Masks', 'Color', 'white');

for k = 1:5
    randomNumber = randi(nMasks);
    filename = fullfile(outputFolderGray, sprintf('Mondrian_Gray_%03d.png', randomNumber));
    img = imread(filename);
    subplot(2,5,k);
    imshow(img, 'InitialMagnification', 'fit');
    title(sprintf('Gray %03d', randomNumber));
end

for k = 1:5
    randomNumber = randi(nMasks);
    filename = fullfile(outputFolderColor, sprintf('Mondrian_%03d.png', randomNumber));
    img = imread(filename);
    subplot(2,5,k+5);
    imshow(img, 'InitialMagnification', 'fit');
    title(sprintf('Color %03d', randomNumber));
end

sgtitle('Example Grayscale (top) and Colored (bottom) CFS Mondrian Masks');

%% ============================================================
% LOCAL FUNCTION: vivid color generator
%
% Picks a random hue from the palette and high, independently
% randomized saturation/brightness (HSV) for a punchy, varied
% look. No cross-hue or cross-set luminance matching (by design).
% ============================================================

function rgb255 = getVividColor(hueList, satRange, valRange)

    h = hueList(randi(length(hueList))) / 360;   % normalize to 0-1
    s = satRange(1) + (satRange(2) - satRange(1)) * rand();
    v = valRange(1) + (valRange(2) - valRange(1)) * rand();

    rgb = hsv2rgb([h s v]);   % 0-1 range
    rgb255 = uint8(round(rgb * 255));

end