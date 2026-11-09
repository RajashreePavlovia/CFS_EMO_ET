%% ========================================================================
% KDEF FACE PREPROCESSING
% DESATURATION ONLY + MATCHED LUMINANCE + MATCHED RMS CONTRAST
%
% PURPOSE:
% Remove chromatic/saturation information while preserving the natural
% tonal structure and appearance of the original KDEF faces.
%
% INPUT:
%
% D:\CFS\Expt_emo\Stimuli\OG_faces\
%       angry\
%       happy\
%       neutral\
%
% OUTPUT:
%
% D:\CFS\Expt_emo\Stimuli\cfs_desaturated\
%       angry\
%       happy\
%       neutral\
%
% Processing:
%
%   1. Read original RGB KDEF image
%   2. Set saturation to ZERO
%   3. Preserve hue/value structure
%   4. Resize to 762 x 562
%   5. Apply elliptical facial mask
%   6. Match mean luminance
%   7. Match RMS contrast
%   8. Set outside ellipse to gray 128
%   9. Save as lossless PNG
%  10. Reload saved files and perform rigorous QC
%
% ========================================================================

clear;
clc;
close all;

%% ========================================================================
% 1. INPUT / OUTPUT PATHS
% ========================================================================

inputRoot = ...
    'D:\CFS\Expt_emo\Stimuli\OG_faces';

outputRoot = ...
    'D:\CFS\Expt_emo\Stimuli\cfs_desaturated';

if ~exist(outputRoot,'dir')
    mkdir(outputRoot);
end

%% ========================================================================
% 2. STIMULUS CATEGORIES
% ========================================================================

categories = {
    'angry'
    'happy'
    'neutral'
    };

%% ========================================================================
% 3. IMAGE SIZE
% ========================================================================

outputHeight = 762;
outputWidth  = 562;

%% ========================================================================
% 4. ELLIPTICAL MASK PARAMETERS
% ========================================================================

ellipseCenterX = 0.50;
ellipseCenterY = 0.58;

ellipseRadiusX = 0.24;
ellipseRadiusY = 0.22;

% Background outside ellipse
maskBackground = 128;

%% ========================================================================
% 5. CREATE ELLIPTICAL MASK
% ========================================================================

[X,Y] = meshgrid(1:outputWidth,1:outputHeight);

centerX = ellipseCenterX * outputWidth;
centerY = ellipseCenterY * outputHeight;

radiusX = ellipseRadiusX * outputWidth;
radiusY = ellipseRadiusY * outputHeight;

ellipseMask = ...
    ((X-centerX).^2 ./ radiusX^2) + ...
    ((Y-centerY).^2 ./ radiusY^2) <= 1;

%% ========================================================================
% 6. CREATE OUTPUT SUBFOLDERS
% ========================================================================

for c = 1:length(categories)

    outputCategoryFolder = ...
        fullfile(outputRoot,categories{c});

    if ~exist(outputCategoryFolder,'dir')
        mkdir(outputCategoryFolder);
    end

end

%% ========================================================================
% 7. READ ALL RGB IMAGES AND REMOVE SATURATION
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('KDEF DESATURATION + LUMINANCE/CONTRAST NORMALIZATION\n');
fprintf('============================================================\n');

fprintf('\nInput folder:\n%s\n',inputRoot);

fprintf('\nOutput folder:\n%s\n',outputRoot);

allImages = {};
allNames = {};
allCategories = {};

imageCounter = 0;

fprintf('\n============================================================\n');
fprintf('READING AND DESATURATING IMAGES\n');
fprintf('============================================================\n');

for c = 1:length(categories)

    category = categories{c};

    categoryFolder = ...
        fullfile(inputRoot,category);

    if ~exist(categoryFolder,'dir')

        error( ...
            'Input folder does not exist: %s', ...
            categoryFolder);

    end

    %% Find image files

    imageFiles = [
        dir(fullfile(categoryFolder,'*.jpg'));
        dir(fullfile(categoryFolder,'*.JPG'));
        dir(fullfile(categoryFolder,'*.jpeg'));
        dir(fullfile(categoryFolder,'*.JPEG'))
        ];

    fprintf('\n%s: %d images\n', ...
        category,length(imageFiles));

    for i = 1:length(imageFiles)

        filename = imageFiles(i).name;

        filepath = ...
            fullfile(categoryFolder,filename);

        %% ------------------------------------------------------------
        % READ ORIGINAL RGB IMAGE
        % -------------------------------------------------------------

        imgRGB = imread(filepath);

        %% ------------------------------------------------------------
        % CONVERT TO DOUBLE
        % -------------------------------------------------------------

        imgRGB = im2double(imgRGB);

        %% ------------------------------------------------------------
        % RESIZE WHILE STILL RGB
        % -------------------------------------------------------------

        imgRGB = imresize( ...
            imgRGB, ...
            [outputHeight outputWidth]);

        %% ------------------------------------------------------------
        % CONVERT RGB -> HSV
        % -------------------------------------------------------------

        imgHSV = rgb2hsv(imgRGB);

        %% ------------------------------------------------------------
        % SET SATURATION TO ZERO
        %
        % This removes all chromatic information while preserving
        % the value/brightness structure of the original image.
        % -------------------------------------------------------------

        imgHSV(:,:,2) = 0;

        %% ------------------------------------------------------------
        % Convert back to RGB
        % -------------------------------------------------------------

        imgDesaturatedRGB = hsv2rgb(imgHSV);

        %% ------------------------------------------------------------
        % Convert to grayscale representation
        %
        % Since saturation = 0, R = G = B.
        % Taking one channel gives the desaturated luminance image.
        % -------------------------------------------------------------

        img = imgDesaturatedRGB(:,:,1);

        %% ------------------------------------------------------------
        % Store
        % -------------------------------------------------------------

        imageCounter = imageCounter + 1;

        allImages{imageCounter} = img;

        allNames{imageCounter} = filename;

        allCategories{imageCounter} = category;

    end

end

fprintf('\nTotal images: %d\n',imageCounter);

%% ========================================================================
% 8. CALCULATE ORIGINAL DESATURATED STATISTICS
% ========================================================================

originalMean = zeros(imageCounter,1);

originalSD = zeros(imageCounter,1);

originalRMSContrast = zeros(imageCounter,1);

originalMin = zeros(imageCounter,1);

originalMax = zeros(imageCounter,1);

fprintf('\n============================================================\n');
fprintf('CALCULATING DESATURATED IMAGE STATISTICS\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    img = allImages{i};

    %% Facial region only

    pixels = img(ellipseMask);

    %% Mean luminance

    originalMean(i) = ...
        mean(pixels);

    %% SD

    originalSD(i) = ...
        std(pixels);

    %% RMS contrast

    originalRMSContrast(i) = ...
        originalSD(i) / originalMean(i);

    %% Range

    originalMin(i) = ...
        min(pixels);

    originalMax(i) = ...
        max(pixels);

end

%% ========================================================================
% 9. TARGET LUMINANCE
% ========================================================================

targetLuminance = ...
    mean(originalMean);

%% ========================================================================
% 10. TARGET RMS CONTRAST
% ========================================================================

targetRMSContrast = ...
    mean(originalRMSContrast);

%% ========================================================================
% 11. TARGET SD
% ========================================================================

targetSD = ...
    targetRMSContrast * targetLuminance;

%% ========================================================================
% 12. DISPLAY TARGET VALUES
% ========================================================================

fprintf('\n============================================================\n');
fprintf('TARGET VALUES\n');
fprintf('============================================================\n');

fprintf('\nTarget mean luminance = %.6f\n', ...
    targetLuminance);

fprintf('Target mean luminance (0-255) = %.2f\n', ...
    targetLuminance*255);

fprintf('\nTarget RMS contrast = %.6f\n', ...
    targetRMSContrast);

fprintf('\nTarget SD = %.6f\n', ...
    targetSD);

%% ========================================================================
% 13. NORMALIZE LUMINANCE + CONTRAST
% ========================================================================

normalizedImages = ...
    cell(imageCounter,1);

fprintf('\n============================================================\n');
fprintf('NORMALIZING LUMINANCE AND CONTRAST\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    img = allImages{i};

    %% Facial pixels

    pixels = img(ellipseMask);

    %% Current statistics

    currentMean = mean(pixels);

    currentSD = std(pixels);

    %% ------------------------------------------------------------
    % Standardize image
    % -------------------------------------------------------------

    normalized = ...
        (img - currentMean) / currentSD;

    %% ------------------------------------------------------------
    % Apply target SD
    % -------------------------------------------------------------

    normalized = ...
        normalized * targetSD;

    %% ------------------------------------------------------------
    % Apply target mean
    % -------------------------------------------------------------

    normalized = ...
        normalized + targetLuminance;

    %% ------------------------------------------------------------
    % Clip to valid display range
    % -------------------------------------------------------------

    normalized = ...
        max(0,min(1,normalized));

    %% ------------------------------------------------------------
    % Apply uniform gray outside ellipse
    % -------------------------------------------------------------

    normalized(~ellipseMask) = ...
        maskBackground / 255;

    %% Store

    normalizedImages{i} = normalized;

end

%% ========================================================================
% 14. PRE-SAVE QC
% ========================================================================

finalMeanBeforeSave = zeros(imageCounter,1);

finalSDBeforeSave = zeros(imageCounter,1);

finalRMSBeforeSave = zeros(imageCounter,1);

clippedLow = zeros(imageCounter,1);

clippedHigh = zeros(imageCounter,1);

for i = 1:imageCounter

    img = normalizedImages{i};

    pixels = img(ellipseMask);

    finalMeanBeforeSave(i) = ...
        mean(pixels);

    finalSDBeforeSave(i) = ...
        std(pixels);

    finalRMSBeforeSave(i) = ...
        finalSDBeforeSave(i) / ...
        finalMeanBeforeSave(i);

    clippedLow(i) = ...
        sum(pixels <= 0);

    clippedHigh(i) = ...
        sum(pixels >= 1);

end

%% ========================================================================
% 15. CLIPPING REPORT
% ========================================================================

fprintf('\n============================================================\n');
fprintf('CLIPPING CHECK\n');
fprintf('============================================================\n');

fprintf('\nImages with low-end clipping: %d / %d\n', ...
    sum(clippedLow > 0),imageCounter);

fprintf('Images with high-end clipping: %d / %d\n', ...
    sum(clippedHigh > 0),imageCounter);

fprintf('\nMaximum low-clipped pixels in one image: %d\n', ...
    max(clippedLow));

fprintf('Maximum high-clipped pixels in one image: %d\n', ...
    max(clippedHigh));

%% ========================================================================
% 16. SAVE IMAGES AS PNG
% ========================================================================

fprintf('\n============================================================\n');
fprintf('SAVING DESATURATED STIMULI\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    category = ...
        allCategories{i};

    filename = ...
        allNames{i};

    outputCategoryFolder = ...
        fullfile(outputRoot,category);

    [~,name,~] = ...
        fileparts(filename);

    outputFilename = ...
        [name '_desaturated.png'];

    outputPath = ...
        fullfile( ...
        outputCategoryFolder, ...
        outputFilename);

    %% Convert to 8-bit grayscale

    saveImage = ...
        uint8(round(normalizedImages{i} * 255));

    %% Save lossless PNG

    imwrite( ...
        saveImage, ...
        outputPath);

end

fprintf('\nAll stimuli saved as PNG.\n');

%% ========================================================================
% 17. RELOAD SAVED FILES FOR FINAL QC
% ========================================================================

fprintf('\n============================================================\n');
fprintf('RELOADING SAVED STIMULI\n');
fprintf('============================================================\n');

savedMean = zeros(imageCounter,1);

savedSD = zeros(imageCounter,1);

savedRMSContrast = zeros(imageCounter,1);

savedMin = zeros(imageCounter,1);

savedMax = zeros(imageCounter,1);

for i = 1:imageCounter

    category = ...
        allCategories{i};

    filename = ...
        allNames{i};

    [~,name,~] = ...
        fileparts(filename);

    savedFilename = ...
        [name '_desaturated.png'];

    savedPath = ...
        fullfile( ...
        outputRoot, ...
        category, ...
        savedFilename);

    %% Read

    savedImg = imread(savedPath);

    %% Convert to double

    savedImg = im2double(savedImg);

    %% Facial pixels only

    pixels = savedImg(ellipseMask);

    %% Statistics

    savedMean(i) = ...
        mean(pixels);

    savedSD(i) = ...
        std(pixels);

    savedRMSContrast(i) = ...
        savedSD(i) / savedMean(i);

    savedMin(i) = ...
        min(pixels);

    savedMax(i) = ...
        max(pixels);

end

%% ========================================================================
% 18. FINAL DEVIATIONS
% ========================================================================

luminanceDeviation = ...
    savedMean - targetLuminance;

contrastDeviation = ...
    savedRMSContrast - targetRMSContrast;

absoluteLuminanceDeviation = ...
    abs(luminanceDeviation);

absoluteContrastDeviation = ...
    abs(contrastDeviation);

%% ========================================================================
% 19. FINAL QC
% ========================================================================

fprintf('\n============================================================\n');
fprintf('FINAL SAVED-STIMULUS QC\n');
fprintf('============================================================\n');

fprintf('\nTARGET MEAN LUMINANCE\n');
fprintf('%.8f\n',targetLuminance);

fprintf('\nACTUAL MEAN LUMINANCE\n');
fprintf('%.8f\n',mean(savedMean));

fprintf('\nSD ACROSS STIMULI\n');
fprintf('%.8f\n',std(savedMean));

fprintf('\nMAX ABSOLUTE LUMINANCE DEVIATION\n');
fprintf('%.8f\n',max(absoluteLuminanceDeviation));

fprintf('\n\nTARGET RMS CONTRAST\n');
fprintf('%.8f\n',targetRMSContrast);

fprintf('\nACTUAL MEAN RMS CONTRAST\n');
fprintf('%.8f\n',mean(savedRMSContrast));

fprintf('\nSD ACROSS STIMULI\n');
fprintf('%.8f\n',std(savedRMSContrast));

fprintf('\nMAX ABSOLUTE RMS CONTRAST DEVIATION\n');
fprintf('%.8f\n',max(absoluteContrastDeviation));

%% ========================================================================
% 20. CATEGORY-LEVEL QC
% ========================================================================

categoryN = zeros(length(categories),1);

categoryMeanLuminance = zeros(length(categories),1);

categorySDLuminance = zeros(length(categories),1);

categoryMeanContrast = zeros(length(categories),1);

categorySDContrast = zeros(length(categories),1);

for c = 1:length(categories)

    category = categories{c};

    idx = strcmp( ...
        allCategories, ...
        category);

    categoryN(c) = sum(idx);

    categoryMeanLuminance(c) = ...
        mean(savedMean(idx));

    categorySDLuminance(c) = ...
        std(savedMean(idx));

    categoryMeanContrast(c) = ...
        mean(savedRMSContrast(idx));

    categorySDContrast(c) = ...
        std(savedRMSContrast(idx));

end

%% ========================================================================
% 21. PRINT CATEGORY QC
% ========================================================================

fprintf('\n============================================================\n');
fprintf('CATEGORY-LEVEL QC\n');
fprintf('============================================================\n');

for c = 1:length(categories)

    fprintf('\n%s\n',categories{c});

    fprintf('  N = %d\n', ...
        categoryN(c));

    fprintf('  Mean luminance = %.8f\n', ...
        categoryMeanLuminance(c));

    fprintf('  SD luminance = %.8f\n', ...
        categorySDLuminance(c));

    fprintf('  Mean RMS contrast = %.8f\n', ...
        categoryMeanContrast(c));

    fprintf('  SD RMS contrast = %.8f\n', ...
        categorySDContrast(c));

end

%% ========================================================================
% 22. CREATE IMAGE-LEVEL QC TABLE
% ========================================================================

QC = table( ...
    allCategories', ...
    allNames', ...
    originalMean, ...
    originalSD, ...
    originalRMSContrast, ...
    finalMeanBeforeSave, ...
    finalSDBeforeSave, ...
    finalRMSBeforeSave, ...
    savedMean, ...
    savedSD, ...
    savedRMSContrast, ...
    savedMin, ...
    savedMax, ...
    clippedLow, ...
    clippedHigh, ...
    luminanceDeviation, ...
    contrastDeviation, ...
    'VariableNames',{ ...
    'Category', ...
    'Filename', ...
    'OriginalDesaturatedMeanLuminance', ...
    'OriginalDesaturatedSD', ...
    'OriginalDesaturatedRMSContrast', ...
    'FinalMeanBeforeSave', ...
    'FinalSDBeforeSave', ...
    'FinalRMSBeforeSave', ...
    'SavedMeanLuminance', ...
    'SavedSD', ...
    'SavedRMSContrast', ...
    'SavedMin', ...
    'SavedMax', ...
    'ClippedLowPixels', ...
    'ClippedHighPixels', ...
    'LuminanceDeviationFromTarget', ...
    'RMSContrastDeviationFromTarget' ...
    });

%% ========================================================================
% 23. SAVE IMAGE-LEVEL QC
% ========================================================================

qcPath = ...
    fullfile( ...
    outputRoot, ...
    'KDEF_Stimulus_QC.csv');

writetable(QC,qcPath);

%% ========================================================================
% 24. CATEGORY QC TABLE
% ========================================================================

CategoryQC = table( ...
    categories, ...
    categoryN, ...
    categoryMeanLuminance, ...
    categorySDLuminance, ...
    categoryMeanContrast, ...
    categorySDContrast, ...
    'VariableNames',{ ...
    'Category', ...
    'N', ...
    'MeanLuminance', ...
    'SDLuminance', ...
    'MeanRMSContrast', ...
    'SDRMSContrast' ...
    });

categoryQCPath = ...
    fullfile( ...
    outputRoot, ...
    'KDEF_Category_QC.csv');

writetable(CategoryQC,categoryQCPath);

%% ========================================================================
% 25. SAVE ELLIPTICAL MASK
% ========================================================================

maskPath = ...
    fullfile( ...
    outputRoot, ...
    'Elliptical_Mask.png');

imwrite( ...
    uint8(ellipseMask)*255, ...
    maskPath);

%% ========================================================================
% 26. SAVE PROCESSING PARAMETERS
% ========================================================================

parameterPath = ...
    fullfile( ...
    outputRoot, ...
    'Processing_Parameters.txt');

fid = fopen(parameterPath,'w');

fprintf(fid,'KDEF DESATURATED FACE PREPROCESSING\n');
fprintf(fid,'===================================\n\n');

fprintf(fid,'Input root:\n%s\n\n',inputRoot);

fprintf(fid,'Output root:\n%s\n\n',outputRoot);

fprintf(fid,'Image size:\n%d x %d pixels\n\n', ...
    outputHeight,outputWidth);

fprintf(fid,'Ellipse center X: %.4f\n', ...
    ellipseCenterX);

fprintf(fid,'Ellipse center Y: %.4f\n', ...
    ellipseCenterY);

fprintf(fid,'Ellipse radius X: %.4f\n', ...
    ellipseRadiusX);

fprintf(fid,'Ellipse radius Y: %.4f\n\n', ...
    ellipseRadiusY);

fprintf(fid,'Outside-ellipse background:\n');
fprintf(fid,'RGB = %d\n',maskBackground);
fprintf(fid,'Normalized = %.6f\n\n', ...
    maskBackground/255);

fprintf(fid,'Saturation:\n');
fprintf(fid,'Set to ZERO\n\n');

fprintf(fid,'Target mean luminance:\n');
fprintf(fid,'%.8f\n\n',targetLuminance);

fprintf(fid,'Target RMS contrast:\n');
fprintf(fid,'%.8f\n\n',targetRMSContrast);

fprintf(fid,'Target SD:\n');
fprintf(fid,'%.8f\n\n',targetSD);

fprintf(fid,'FINAL SAVED-STIMULUS VALUES\n');
fprintf(fid,'Mean luminance = %.8f\n', ...
    mean(savedMean));

fprintf(fid,'SD luminance = %.8f\n', ...
    std(savedMean));

fprintf(fid,'Mean RMS contrast = %.8f\n', ...
    mean(savedRMSContrast));

fprintf(fid,'SD RMS contrast = %.8f\n\n', ...
    std(savedRMSContrast));

fprintf(fid,'Clipping:\n');
fprintf(fid,'Images with low clipping = %d\n', ...
    sum(clippedLow>0));

fprintf(fid,'Images with high clipping = %d\n', ...
    sum(clippedHigh>0));

fclose(fid);

%% ========================================================================
% 27. DISPLAY MASK
% ========================================================================

figure('Name','Elliptical Mask');

imshow(ellipseMask);

title('Elliptical Facial Mask');

%% ========================================================================
% 28. DISPLAY ORIGINAL COLOR VS DESATURATED
% ========================================================================

nCompare = min(6,imageCounter);

figure('Name','Original Colour Images');

for i = 1:nCompare

    % Reload original image for display

    category = allCategories{i};

    filename = allNames{i};

    originalPath = ...
        fullfile( ...
        inputRoot, ...
        category, ...
        filename);

    originalRGB = imread(originalPath);

    subplot(2,3,i);

    imshow(originalRGB);

    title( ...
        ['Original: ' filename], ...
        'Interpreter','none', ...
        'FontSize',8);

end

figure('Name','Desaturated Images');

for i = 1:nCompare

    subplot(2,3,i);

    imshow(normalizedImages{i});

    title( ...
        ['Desaturated: ' allNames{i}], ...
        'Interpreter','none', ...
        'FontSize',8);

end

%% ========================================================================
% 29. LUMINANCE QC
% ========================================================================

figure('Name','Final Luminance QC');

plot(savedMean,'o-');

hold on;

yline( ...
    targetLuminance, ...
    '--');

xlabel('Stimulus');

ylabel('Mean luminance');

title('Final Saved-Stimulus Mean Luminance');

legend( ...
    'Stimulus', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 30. RMS CONTRAST QC
% ========================================================================

figure('Name','Final RMS Contrast QC');

plot(savedRMSContrast,'o-');

hold on;

yline( ...
    targetRMSContrast, ...
    '--');

xlabel('Stimulus');

ylabel('RMS contrast');

title('Final Saved-Stimulus RMS Contrast');

legend( ...
    'Stimulus', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 31. ORIGINAL VS FINAL LUMINANCE
% ========================================================================

figure('Name','Luminance Before and After');

plot(originalMean,'o-');

hold on;

plot(savedMean,'o-');

yline( ...
    targetLuminance, ...
    '--');

xlabel('Stimulus');

ylabel('Mean luminance');

title('Mean Luminance Before and After Normalization');

legend( ...
    'Original desaturated', ...
    'Final', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 32. ORIGINAL VS FINAL CONTRAST
% ========================================================================

figure('Name','Contrast Before and After');

plot(originalRMSContrast,'o-');

hold on;

plot(savedRMSContrast,'o-');

yline( ...
    targetRMSContrast, ...
    '--');

xlabel('Stimulus');

ylabel('RMS contrast');

title('RMS Contrast Before and After Normalization');

legend( ...
    'Original desaturated', ...
    'Final', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 33. CATEGORY LUMINANCE
% ========================================================================

figure('Name','Category Luminance');

bar(categoryMeanLuminance);

hold on;

yline( ...
    targetLuminance, ...
    '--');

set(gca, ...
    'XTick',1:length(categories), ...
    'XTickLabel',categories);

xlabel('Emotion');

ylabel('Mean luminance');

title('Final Mean Luminance by Emotion');

grid on;

hold off;

%% ========================================================================
% 34. CATEGORY RMS CONTRAST
% ========================================================================

figure('Name','Category RMS Contrast');

bar(categoryMeanContrast);

hold on;

yline( ...
    targetRMSContrast, ...
    '--');

set(gca, ...
    'XTick',1:length(categories), ...
    'XTickLabel',categories);

xlabel('Emotion');

ylabel('RMS contrast');

title('Final RMS Contrast by Emotion');

grid on;

hold off;

%% ========================================================================
% 35. FINISHED
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('PROCESSING COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nInput:\n%s\n',inputRoot);

fprintf('\nOutput:\n%s\n',outputRoot);

fprintf('\nImage QC:\n%s\n',qcPath);

fprintf('\nCategory QC:\n%s\n',categoryQCPath);

fprintf('\nParameters:\n%s\n',parameterPath);

fprintf('\n------------------------------------------------------------\n');
fprintf('FINAL RESULTS\n');
fprintf('------------------------------------------------------------\n');

fprintf('\nMean luminance = %.8f\n', ...
    mean(savedMean));

fprintf('SD luminance across images = %.8f\n', ...
    std(savedMean));

fprintf('\nMean RMS contrast = %.8f\n', ...
    mean(savedRMSContrast));

fprintf('SD RMS contrast across images = %.8f\n', ...
    std(savedRMSContrast));

fprintf('\nMaximum luminance deviation = %.8f\n', ...
    max(absoluteLuminanceDeviation));

fprintf('Maximum RMS contrast deviation = %.8f\n', ...
    max(absoluteContrastDeviation));

fprintf('\n============================================================\n');
fprintf('DONE\n');
fprintf('============================================================\n');