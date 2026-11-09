%% ========================================================================
% KDEF FACE PREPROCESSING
% NATURAL GRAYSCALE + MATCHED LUMINANCE + MATCHED RMS CONTRAST
%
% PURPOSE:
% Preserve natural-looking facial structure while minimizing
% low-level luminance and contrast differences between KDEF faces.
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
% D:\CFS\Expt_emo\Stimuli\cfs_bnw\
%       angry\
%       happy\
%       neutral\
%
% Additional output:
%       KDEF_Stimulus_QC.csv
%       KDEF_Category_QC.csv
%       Elliptical_Mask.png
%       Processing_Parameters.txt
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
    'D:\CFS\Expt_emo\Stimuli\cfs_bnw';

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
% 3. OUTPUT IMAGE SIZE
% ========================================================================

outputHeight = 762;
outputWidth  = 562;

%% ========================================================================
% 4. ELLIPTICAL MASK
% ========================================================================

ellipseCenterX = 0.50;
ellipseCenterY = 0.58;

ellipseRadiusX = 0.24;
ellipseRadiusY = 0.22;

% Background outside the face
% 128/255 = approximately 0.502
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
% 7. FIND AND READ ALL IMAGES
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('KDEF GRAYSCALE FACE PREPROCESSING\n');
fprintf('============================================================\n');

fprintf('\nInput folder:\n%s\n',inputRoot);

fprintf('\nOutput folder:\n%s\n',outputRoot);

allImages = {};
allNames = {};
allCategories = {};

imageCounter = 0;

fprintf('\n============================================================\n');
fprintf('READING IMAGES\n');
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

    jpgFiles = [
        dir(fullfile(categoryFolder,'*.jpg'));
        dir(fullfile(categoryFolder,'*.JPG'));
        dir(fullfile(categoryFolder,'*.jpeg'));
        dir(fullfile(categoryFolder,'*.JPEG'))
        ];

    fprintf('\n%s: %d images\n', ...
        category,length(jpgFiles));

    for i = 1:length(jpgFiles)

        filename = jpgFiles(i).name;

        filepath = ...
            fullfile(categoryFolder,filename);

        %% ------------------------------------------------------------
        % Read image
        % -------------------------------------------------------------

        img = imread(filepath);

        %% ------------------------------------------------------------
        % Convert RGB to grayscale
        % -------------------------------------------------------------

        if size(img,3) == 3

            img = rgb2gray(img);

        end

        %% ------------------------------------------------------------
        % Convert to double [0 1]
        % -------------------------------------------------------------

        img = im2double(img);

        %% ------------------------------------------------------------
        % Resize
        % -------------------------------------------------------------

        img = imresize( ...
            img, ...
            [outputHeight outputWidth]);

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
% 8. ORIGINAL IMAGE STATISTICS
% ========================================================================

originalMean = zeros(imageCounter,1);

originalSD = zeros(imageCounter,1);

originalRMSContrast = zeros(imageCounter,1);

originalMin = zeros(imageCounter,1);

originalMax = zeros(imageCounter,1);

fprintf('\n============================================================\n');
fprintf('CALCULATING ORIGINAL IMAGE STATISTICS\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    img = allImages{i};

    pixels = img(ellipseMask);

    originalMean(i) = mean(pixels);

    originalSD(i) = std(pixels);

    originalRMSContrast(i) = ...
        originalSD(i) / originalMean(i);

    originalMin(i) = min(pixels);

    originalMax(i) = max(pixels);

end

%% ========================================================================
% 9. DETERMINE TARGET LUMINANCE
% ========================================================================

targetLuminance = mean(originalMean);

%% ========================================================================
% 10. DETERMINE TARGET RMS CONTRAST
% ========================================================================

targetRMSContrast = mean(originalRMSContrast);

%% ========================================================================
% 11. DISPLAY ORIGINAL TARGETS
% ========================================================================

fprintf('\n============================================================\n');
fprintf('TARGET VALUES\n');
fprintf('============================================================\n');

fprintf('\nTarget mean luminance:\n');
fprintf('%.6f\n',targetLuminance);

fprintf('\nTarget RMS contrast:\n');
fprintf('%.6f\n',targetRMSContrast);

fprintf('\nTarget mean luminance in 0-255 scale:\n');
fprintf('%.2f\n',targetLuminance*255);

%% ========================================================================
% 12. LUMINANCE + CONTRAST NORMALIZATION
% ========================================================================
%
% Each face is transformed according to:
%
%       normalized = ((image - mean) / SD) * targetSD
%                    + targetMean
%
% Since:
%
%       RMS contrast = SD / mean
%
% targetSD is calculated from:
%
%       targetSD = targetRMSContrast * targetLuminance
%
% ========================================================================

targetSD = ...
    targetRMSContrast * targetLuminance;

fprintf('\nTarget SD:\n');
fprintf('%.6f\n',targetSD);

normalizedImages = cell(imageCounter,1);

%% ========================================================================
% 13. FIRST NORMALIZATION PASS
% ========================================================================

fprintf('\n============================================================\n');
fprintf('NORMALIZING LUMINANCE AND CONTRAST\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    img = allImages{i};

    pixels = img(ellipseMask);

    currentMean = mean(pixels);

    currentSD = std(pixels);

    %% ------------------------------------------------------------
    % Standardize luminance
    % -------------------------------------------------------------

    standardized = ...
        (img - currentMean) / currentSD;

    %% ------------------------------------------------------------
    % Apply target SD
    % -------------------------------------------------------------

    normalized = ...
        standardized * targetSD;

    %% ------------------------------------------------------------
    % Apply target mean
    % -------------------------------------------------------------

    normalized = ...
        normalized + targetLuminance;

    %% ------------------------------------------------------------
    % IMPORTANT:
    % Do not modify the face statistics with the mask.
    %
    % We clip only extreme values outside [0 1].
    % -------------------------------------------------------------

    normalized = ...
        max(0,min(1,normalized));

    %% ------------------------------------------------------------
    % Set outside of ellipse to fixed gray
    % -------------------------------------------------------------

    normalized(~ellipseMask) = ...
        maskBackground / 255;

    normalizedImages{i} = normalized;

end

%% ========================================================================
% 14. CHECK FINAL STATISTICS BEFORE SAVING
% ========================================================================

finalMeanBeforeSave = zeros(imageCounter,1);

finalSDBeforeSave = zeros(imageCounter,1);

finalRMSBeforeSave = zeros(imageCounter,1);

finalMinBeforeSave = zeros(imageCounter,1);

finalMaxBeforeSave = zeros(imageCounter,1);

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

    finalMinBeforeSave(i) = ...
        min(pixels);

    finalMaxBeforeSave(i) = ...
        max(pixels);

    %% Count pixels at limits

    clippedLow(i) = ...
        sum(pixels <= 0);

    clippedHigh(i) = ...
        sum(pixels >= 1);

end

%% ========================================================================
% 15. CHECK WHETHER CLIPPING OCCURRED
% ========================================================================

fprintf('\n============================================================\n');
fprintf('CLIPPING CHECK\n');
fprintf('============================================================\n');

fprintf('\nImages with pixels clipped to black:\n');
fprintf('%d / %d\n', ...
    sum(clippedLow > 0), ...
    imageCounter);

fprintf('\nImages with pixels clipped to white:\n');
fprintf('%d / %d\n', ...
    sum(clippedHigh > 0), ...
    imageCounter);

fprintf('\nMaximum number of clipped pixels in any image:\n');
fprintf('%d\n', ...
    max(max(clippedLow),max(clippedHigh)));

%% ========================================================================
% 16. SAVE IMAGES AS LOSSLESS PNG
% ========================================================================

fprintf('\n============================================================\n');
fprintf('SAVING PROCESSED IMAGES\n');
fprintf('============================================================\n');

for i = 1:imageCounter

    category = allCategories{i};

    filename = allNames{i};

    categoryOutputFolder = ...
        fullfile(outputRoot,category);

    [~,name,~] = ...
        fileparts(filename);

    outputFilename = ...
        [name '_processed.png'];

    outputPath = ...
        fullfile(categoryOutputFolder,outputFilename);

    %% Convert to 8-bit grayscale

    saveImage = ...
        uint8(round(normalizedImages{i} * 255));

    %% Save losslessly

    imwrite( ...
        saveImage, ...
        outputPath);

end

fprintf('\nImages saved as PNG.\n');

%% ========================================================================
% 17. RELOAD SAVED IMAGES
% ========================================================================
%
% This is an important QC step.
%
% We calculate the statistics from the ACTUAL SAVED FILES,
% rather than assuming that the in-memory values are identical.
%
% ========================================================================

fprintf('\n============================================================\n');
fprintf('RELOADING SAVED STIMULI FOR FINAL QC\n');
fprintf('============================================================\n');

savedMean = zeros(imageCounter,1);

savedSD = zeros(imageCounter,1);

savedRMSContrast = zeros(imageCounter,1);

savedMin = zeros(imageCounter,1);

savedMax = zeros(imageCounter,1);

for i = 1:imageCounter

    category = allCategories{i};

    filename = allNames{i};

    [~,name,~] = ...
        fileparts(filename);

    savedFilename = ...
        [name '_processed.png'];

    savedPath = ...
        fullfile( ...
        outputRoot, ...
        category, ...
        savedFilename);

    %% Read saved PNG

    savedImg = imread(savedPath);

    %% Convert to double

    savedImg = im2double(savedImg);

    %% Facial pixels only

    pixels = savedImg(ellipseMask);

    %% Statistics

    savedMean(i) = mean(pixels);

    savedSD(i) = std(pixels);

    savedRMSContrast(i) = ...
        savedSD(i) / savedMean(i);

    savedMin(i) = min(pixels);

    savedMax(i) = max(pixels);

end

%% ========================================================================
% 18. FINAL DEVIATION FROM TARGET
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
% 19. OVERALL FINAL QC
% ========================================================================

fprintf('\n============================================================\n');
fprintf('FINAL QC\n');
fprintf('============================================================\n');

fprintf('\nTarget mean luminance:\n');
fprintf('%.6f\n',targetLuminance);

fprintf('\nActual mean across final stimuli:\n');
fprintf('%.6f\n',mean(savedMean));

fprintf('\nSD of final luminance values across stimuli:\n');
fprintf('%.6f\n',std(savedMean));

fprintf('\nMaximum absolute luminance deviation:\n');
fprintf('%.6f\n',max(absoluteLuminanceDeviation));

fprintf('\nTarget RMS contrast:\n');
fprintf('%.6f\n',targetRMSContrast);

fprintf('\nActual mean RMS contrast:\n');
fprintf('%.6f\n',mean(savedRMSContrast));

fprintf('\nSD of final RMS contrast values:\n');
fprintf('%.6f\n',std(savedRMSContrast));

fprintf('\nMaximum absolute RMS contrast deviation:\n');
fprintf('%.6f\n',max(absoluteContrastDeviation));

%% ========================================================================
% 20. CATEGORY-LEVEL QC
% ========================================================================

categoryMeanLuminance = zeros(length(categories),1);

categorySDLuminance = zeros(length(categories),1);

categoryMeanContrast = zeros(length(categories),1);

categorySDContrast = zeros(length(categories),1);

categoryN = zeros(length(categories),1);

for c = 1:length(categories)

    category = categories{c};

    idx = strcmp(allCategories,category);

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

    fprintf('  N = %d\n',categoryN(c));

    fprintf('  Mean luminance = %.6f\n', ...
        categoryMeanLuminance(c));

    fprintf('  SD luminance = %.6f\n', ...
        categorySDLuminance(c));

    fprintf('  Mean RMS contrast = %.6f\n', ...
        categoryMeanContrast(c));

    fprintf('  SD RMS contrast = %.6f\n', ...
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
    'OriginalMeanLuminance', ...
    'OriginalSD', ...
    'OriginalRMSContrast', ...
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
    fullfile(outputRoot,'KDEF_Stimulus_QC.csv');

writetable(QC,qcPath);

fprintf('\nImage-level QC saved:\n%s\n',qcPath);

%% ========================================================================
% 24. CREATE CATEGORY-LEVEL QC TABLE
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

%% ========================================================================
% 25. SAVE CATEGORY QC
% ========================================================================

categoryQCPath = ...
    fullfile(outputRoot,'KDEF_Category_QC.csv');

writetable(CategoryQC,categoryQCPath);

fprintf('\nCategory-level QC saved:\n%s\n',categoryQCPath);

%% ========================================================================
% 26. SAVE ELLIPTICAL MASK
% ========================================================================

maskPath = ...
    fullfile(outputRoot,'Elliptical_Mask.png');

imwrite( ...
    uint8(ellipseMask)*255, ...
    maskPath);

%% ========================================================================
% 27. SAVE PROCESSING PARAMETERS
% ========================================================================

parameterPath = ...
    fullfile(outputRoot,'Processing_Parameters.txt');

fid = fopen(parameterPath,'w');

fprintf(fid,'KDEF NATURAL GRAYSCALE PREPROCESSING\n');
fprintf(fid,'====================================\n\n');

fprintf(fid,'INPUT ROOT\n');
fprintf(fid,'%s\n\n',inputRoot);

fprintf(fid,'OUTPUT ROOT\n');
fprintf(fid,'%s\n\n',outputRoot);

fprintf(fid,'IMAGE SIZE\n');
fprintf(fid,'%d x %d pixels\n\n', ...
    outputHeight,outputWidth);

fprintf(fid,'ELLIPSE PARAMETERS\n');
fprintf(fid,'Center X = %.4f\n',ellipseCenterX);
fprintf(fid,'Center Y = %.4f\n',ellipseCenterY);
fprintf(fid,'Radius X = %.4f\n',ellipseRadiusX);
fprintf(fid,'Radius Y = %.4f\n\n',ellipseRadiusY);

fprintf(fid,'MASK BACKGROUND\n');
fprintf(fid,'RGB = %d\n',maskBackground);
fprintf(fid,'Normalized = %.6f\n\n',maskBackground/255);

fprintf(fid,'TARGET STATISTICS\n');
fprintf(fid,'Target mean luminance = %.8f\n',targetLuminance);
fprintf(fid,'Target RMS contrast = %.8f\n',targetRMSContrast);
fprintf(fid,'Target SD = %.8f\n\n',targetSD);

fprintf(fid,'FINAL SAVED-STIMULUS STATISTICS\n');
fprintf(fid,'Mean luminance = %.8f\n',mean(savedMean));
fprintf(fid,'SD of luminance = %.8f\n',std(savedMean));
fprintf(fid,'Mean RMS contrast = %.8f\n',mean(savedRMSContrast));
fprintf(fid,'SD of RMS contrast = %.8f\n\n',std(savedRMSContrast));

fprintf(fid,'CLIPPING\n');
fprintf(fid,'Images with low clipping = %d\n',sum(clippedLow>0));
fprintf(fid,'Images with high clipping = %d\n',sum(clippedHigh>0));

fclose(fid);

%% ========================================================================
% 28. DISPLAY ORIGINAL VS PROCESSED
% ========================================================================

figure('Name','Original vs Processed');

nCompare = min(6,imageCounter);

for i = 1:nCompare

    subplot(2,3,i);

    imshow(allImages{i});

    title( ...
        ['Original: ' allNames{i}], ...
        'Interpreter','none', ...
        'FontSize',8);

end

figure('Name','Processed Stimuli');

for i = 1:nCompare

    subplot(2,3,i);

    imshow(normalizedImages{i});

    title( ...
        ['Processed: ' allNames{i}], ...
        'Interpreter','none', ...
        'FontSize',8);

end

%% ========================================================================
% 29. LUMINANCE QC PLOT
% ========================================================================

figure('Name','Luminance QC');

plot(savedMean,'o-');

hold on;

yline( ...
    targetLuminance, ...
    '--');

xlabel('Stimulus');

ylabel('Mean luminance');

title('Final Saved-Stimulus Mean Luminance');

grid on;

hold off;

%% ========================================================================
% 30. RMS CONTRAST QC PLOT
% ========================================================================

figure('Name','RMS Contrast QC');

plot(savedRMSContrast,'o-');

hold on;

yline( ...
    targetRMSContrast, ...
    '--');

xlabel('Stimulus');

ylabel('RMS contrast');

title('Final Saved-Stimulus RMS Contrast');

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
    'Original', ...
    'Final', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 32. ORIGINAL VS FINAL RMS CONTRAST
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
    'Original', ...
    'Final', ...
    'Target', ...
    'Location','best');

grid on;

hold off;

%% ========================================================================
% 33. CATEGORY-LEVEL LUMINANCE
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

title('Mean Luminance by Emotion');

grid on;

hold off;

%% ========================================================================
% 34. CATEGORY-LEVEL CONTRAST
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

title('Mean RMS Contrast by Emotion');

grid on;

hold off;

%% ========================================================================
% 35. FINAL SUMMARY
% ========================================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('PROCESSING COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nInput:\n%s\n',inputRoot);

fprintf('\nOutput:\n%s\n',outputRoot);

fprintf('\nImage-level QC:\n%s\n',qcPath);

fprintf('\nCategory-level QC:\n%s\n',categoryQCPath);

fprintf('\nProcessing parameters:\n%s\n',parameterPath);

fprintf('\n------------------------------------------------------------\n');
fprintf('FINAL STIMULUS STATISTICS\n');
fprintf('------------------------------------------------------------\n');

fprintf('\nMean luminance = %.6f\n', ...
    mean(savedMean));

fprintf('SD across images = %.6f\n', ...
    std(savedMean));

fprintf('\nMean RMS contrast = %.6f\n', ...
    mean(savedRMSContrast));

fprintf('SD across images = %.6f\n', ...
    std(savedRMSContrast));

fprintf('\nMaximum luminance deviation = %.6f\n', ...
    max(absoluteLuminanceDeviation));

fprintf('Maximum RMS contrast deviation = %.6f\n', ...
    max(absoluteContrastDeviation));

fprintf('\n------------------------------------------------------------\n');
fprintf('CATEGORY MEANS\n');
fprintf('------------------------------------------------------------\n');

for c = 1:length(categories)

    fprintf('\n%s:\n',categories{c});

    fprintf('  Mean luminance = %.6f\n', ...
        categoryMeanLuminance(c));

    fprintf('  Mean RMS contrast = %.6f\n', ...
        categoryMeanContrast(c));

end

fprintf('\n============================================================\n');
fprintf('DONE\n');
fprintf('============================================================\n');