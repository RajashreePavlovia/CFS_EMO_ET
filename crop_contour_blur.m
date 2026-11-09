%% ================================================================
% KDEF FACE PREPROCESSING
%
% Folder structure:
%
% faces/
%   angry/
%       *.jpg / *.JPG
%   happy/
%       *.jpg / *.JPG
%   neutral/
%       *.jpg / *.JPG
%
% Output:
%
% processed_faces/
%   angry/
%   happy/
%   neutral/
%
% ================================================================

clear;
clc;
close all;
%% ================================================================
% INPUT AND OUTPUT FOLDERS
% ================================================================

inputFolder = 'D:\CFS\Expt_emo\Stimuli\practice_faces';

outputFolder = 'D:\CFS\Expt_emo\Stimuli\practice_crop_contour_blur';

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% ================================================================
% IMAGE SIZE
% ================================================================

outputHeight = 254;
outputWidth  = 174;

%% ================================================================
% ELLIPTICAL MASK
% ================================================================

ellipseCenterX = 0.50;
ellipseCenterY = 0.58;

ellipseRadiusX = 0.25;
ellipseRadiusY = 0.22;

%% ================================================================
% FEATHERING
% ================================================================
% Number of pixels over which the face gradually blends
% into the gray background.

featherPixels = 10;

%% ================================================================
% CREATE ELLIPTICAL MASK
% ================================================================

[X,Y] = meshgrid(1:outputWidth,1:outputHeight);

centerX = ellipseCenterX * outputWidth;
centerY = ellipseCenterY * outputHeight;

radiusX = ellipseRadiusX * outputWidth;
radiusY = ellipseRadiusY * outputHeight;

ellipseMask = ...
    ((X-centerX).^2 ./ radiusX^2) + ...
    ((Y-centerY).^2 ./ radiusY^2) <= 1;

%% ================================================================
% CREATE DISTANCE MAP FOR FEATHERING
% ================================================================

% Distance of every pixel INSIDE the ellipse from its boundary

distanceInside = bwdist(~ellipseMask);

% Alpha:
% 1 = completely face
% 0 = completely background

alpha = min(distanceInside / featherPixels, 1);

% Pixels outside the ellipse
alpha(~ellipseMask) = 0;

%% ================================================================
% FIND SUBFOLDERS
% ================================================================

folders = dir(inputFolder);

folders = folders([folders.isdir]);

folders = folders(~ismember({folders.name},{'.','..'}));

fprintf('\nFound %d stimulus folders:\n',length(folders));

for f = 1:length(folders)
    fprintf('   %s\n',folders(f).name);
end

%% ================================================================
% FIRST PASS
% READ ALL IMAGES
% ================================================================

allImages = {};
allNames = {};
allCategories = {};

meanLum = [];
rmsContrast = [];

imageCounter = 0;

fprintf('\n============================================\n');
fprintf('READING IMAGES\n');
fprintf('============================================\n');

for f = 1:length(folders)

    category = folders(f).name;

    categoryFolder = fullfile(inputFolder,category);

    categoryOutputFolder = ...
        fullfile(outputFolder,category);

    if ~exist(categoryOutputFolder,'dir')
        mkdir(categoryOutputFolder);
    end

    %% Find both .jpg and .JPG

    jpgFiles = [
        dir(fullfile(categoryFolder,'*.png'));
        dir(fullfile(categoryFolder,'*.JPG'))
    ];

    fprintf('\n%s: %d images\n', ...
        category,length(jpgFiles));

    for i = 1:length(jpgFiles)

        filename = jpgFiles(i).name;

        filepath = fullfile(categoryFolder,filename);

        %% --------------------------------------------------------
        % Read image
        % --------------------------------------------------------

        img = imread(filepath);

        %% --------------------------------------------------------
        % Convert to grayscale
        % --------------------------------------------------------

        if size(img,3) == 3
            img = rgb2gray(img);
        end

        %% --------------------------------------------------------
        % Convert to double [0 1]
        % --------------------------------------------------------

        img = im2double(img);

        %% --------------------------------------------------------
        % Resize
        % --------------------------------------------------------

        img = imresize(img,[outputHeight outputWidth]);

        %% --------------------------------------------------------
        % Hard ellipse for measuring facial region
        % --------------------------------------------------------

        pixels = img(ellipseMask);

        %% --------------------------------------------------------
        % Mean luminance
        % --------------------------------------------------------

        currentMean = mean(pixels);

        %% --------------------------------------------------------
        % RMS contrast
        % --------------------------------------------------------

        currentContrast = std(pixels) / currentMean;

        %% --------------------------------------------------------
        % Store
        % --------------------------------------------------------

        imageCounter = imageCounter + 1;

        allImages{imageCounter} = img;

        allNames{imageCounter} = filename;

        allCategories{imageCounter} = category;

        meanLum(imageCounter) = currentMean;

        rmsContrast(imageCounter) = currentContrast;

    end
end

fprintf('\nTotal images: %d\n',imageCounter);

%% ================================================================
% TARGET LUMINANCE AND CONTRAST
% ================================================================

targetLuminance = mean(meanLum);

targetContrast = mean(rmsContrast);

fprintf('\n============================================\n');
fprintf('TARGET VALUES\n');
fprintf('============================================\n');

fprintf('Target luminance : %.5f\n',targetLuminance);

fprintf('Target contrast  : %.5f\n',targetContrast);

%% ================================================================
% SECOND PASS
% MATCH LUMINANCE AND CONTRAST
% ================================================================

finalMeanLum = zeros(imageCounter,1);

finalRMSContrast = zeros(imageCounter,1);

fprintf('\n============================================\n');
fprintf('NORMALIZING IMAGES\n');
fprintf('============================================\n');

for i = 1:imageCounter

    img = allImages{i};

    %% Pixels within facial ellipse

    pixels = img(ellipseMask);

    currentMean = mean(pixels);

    currentSD = std(pixels);

    %% ------------------------------------------------------------
    % Standardize contrast
    % ------------------------------------------------------------

    img = ((img-currentMean)/currentSD) * ...
        (targetContrast*targetLuminance);

    %% ------------------------------------------------------------
    % Standardize luminance
    % ------------------------------------------------------------

    img = img + targetLuminance;

    %% ------------------------------------------------------------
    % Clip to valid grayscale range
    % ------------------------------------------------------------

    img = max(0,min(1,img));

    %% ------------------------------------------------------------
    % Store temporarily
    % ------------------------------------------------------------

    allImages{i} = img;

    %% ------------------------------------------------------------
    % Final facial-region statistics
    % ------------------------------------------------------------

    finalPixels = img(ellipseMask);

    finalMeanLum(i) = mean(finalPixels);

    finalRMSContrast(i) = ...
        std(finalPixels) / mean(finalPixels);

end

%% ================================================================
% DETERMINE COMMON BACKGROUND GRAY
%
% IMPORTANT:
% Instead of arbitrarily choosing 127.5, calculate the mean
% luminance around the boundary of the ellipse across ALL faces.
% ================================================================

fprintf('\n============================================\n');
fprintf('CALCULATING FACIAL EDGE GRAY\n');
fprintf('============================================\n');

%% Define a 10-pixel-wide ring immediately inside the ellipse

edgeRing = ellipseMask & ...
           (distanceInside <= featherPixels);

edgeValuesAll = [];

for i = 1:imageCounter

    img = allImages{i};

    edgePixels = img(edgeRing);

    edgeValuesAll = [edgeValuesAll; edgePixels]; %#ok<AGROW>

end

% FIXED to match the experiment's screen background exactly
% (cfg.background_rgb = [95 95 95] in the task), instead of being
% computed from the images -- this guarantees the feathered corners are
% pixel-identical to the on-screen background, with zero visible seam.
maskBackground = 95/255;

fprintf('Common background gray (FIXED to match experiment) = %.5f\n', maskBackground);
fprintf('Equivalent 8-bit gray = %.2f\n', maskBackground*255);
fprintf('(For reference, the images'' own measured edge gray was %.5f)\n', mean(edgeValuesAll));

%% ================================================================
% THIRD PASS
% APPLY GRAY BACKGROUND + FEATHERED EDGE
% ================================================================

fprintf('\n============================================\n');
fprintf('APPLYING GRAY BACKGROUND AND FEATHERING\n');
fprintf('============================================\n');

for i = 1:imageCounter

    img = allImages{i};

    % Blend image with experiment background
    finalImg = alpha .* img + ...
               (1-alpha) .* maskBackground;

    % Store final image
    allImages{i} = finalImg;

end

%% ================================================================
% SAVE PROCESSED IMAGES
% ================================================================

fprintf('\n============================================\n');
fprintf('SAVING IMAGES\n');
fprintf('============================================\n');

for i = 1:imageCounter

    category = allCategories{i};

    filename = allNames{i};

    categoryOutputFolder = ...
        fullfile(outputFolder,category);

    [~,name,~] = fileparts(filename);

    %% Use PNG rather than JPEG
    %
    % PNG is lossless and therefore preferable for experimental
    % stimuli.

    outputFilename = [name '_processed.png'];

    outputPath = ...
        fullfile(categoryOutputFolder,outputFilename);

    imwrite(allImages{i},outputPath, ...
        'Alpha',uint8(alpha*255));
end

%% ================================================================
% CREATE QUALITY CONTROL TABLE
% ================================================================

QC = table( ...
    allCategories', ...
    allNames', ...
    meanLum', ...
    rmsContrast', ...
    finalMeanLum, ...
    finalRMSContrast, ...
    'VariableNames',{ ...
    'Category', ...
    'Filename', ...
    'OriginalMeanLuminance', ...
    'OriginalRMSContrast', ...
    'FinalMeanLuminance', ...
    'FinalRMSContrast'});

%% ================================================================
% ADD BACKGROUND VALUE TO QC TABLE
% ================================================================

QC.BackgroundGray = ...
    repmat(maskBackground,imageCounter,1);

%% ================================================================
% SAVE QC TABLE
% ================================================================

writetable(QC, ...
    fullfile(outputFolder,'KDEF_Stimulus_QC.csv'));

%% ================================================================
% SAVE MASK
% ================================================================

imwrite(uint8(ellipseMask)*255, ...
    fullfile(outputFolder,'Elliptical_Mask.png'));

%% ================================================================
% SAVE ALPHA MASK
% ================================================================

imwrite(alpha, ...
    fullfile(outputFolder,'Feathered_Alpha_Mask.png'));

%% ================================================================
% DISPLAY MASK
% ================================================================

figure;

imshow(ellipseMask);

title('Elliptical Facial Mask');

%% ================================================================
% DISPLAY FEATHERED MASK
% ================================================================

figure;

imshow(alpha);

title('Feathered Facial Mask');

%% ================================================================
% DISPLAY SAMPLE PROCESSED IMAGES
% ================================================================

figure;

nShow = min(9,imageCounter);

for i = 1:nShow

    subplot(3,3,i);

    imshow(allImages{i});

    title(allNames{i}, ...
        'Interpreter','none', ...
        'FontSize',8);

end

sgtitle('Processed KDEF Images');

%% ================================================================
% LUMINANCE QC
% ================================================================

figure;

subplot(2,1,1);

plot(meanLum,'o-');

yline(targetLuminance,'--');

xlabel('Image');

ylabel('Mean luminance');

title('Before luminance normalization');

subplot(2,1,2);

plot(finalMeanLum,'o-');

yline(targetLuminance,'--');

xlabel('Image');

ylabel('Mean luminance');

title('After luminance normalization');

%% ================================================================
% CONTRAST QC
% ================================================================

figure;

subplot(2,1,1);

plot(rmsContrast,'o-');

yline(targetContrast,'--');

xlabel('Image');

ylabel('RMS contrast');

title('Before contrast normalization');

subplot(2,1,2);

plot(finalRMSContrast,'o-');

yline(targetContrast,'--');

xlabel('Image');

ylabel('RMS contrast');

title('After contrast normalization');

%% ================================================================
% FINISHED
% ================================================================

fprintf('\n============================================\n');
fprintf('PROCESSING COMPLETE\n');
fprintf('============================================\n');

fprintf('\nOriginal folder:\n%s\n',inputFolder);

fprintf('\nProcessed images:\n%s\n',outputFolder);

fprintf('\nQC file:\n%s\n', ...
    fullfile(outputFolder,'KDEF_Stimulus_QC.csv'));

fprintf('\nTarget mean luminance = %.5f\n', ...
    targetLuminance);

fprintf('Target RMS contrast   = %.5f\n', ...
    targetContrast);

fprintf('Common background gray = %.5f\n', ...
    maskBackground);

fprintf('Common background 8-bit value = %.2f\n', ...
    maskBackground*255);

fprintf('\nFeather width = %d pixels\n', ...
    featherPixels);

fprintf('\nDone!\n');

%%% ================================================================
% CROP EACH IMAGE TO THE OUTER EDGE OF THE FEATHER
% ================================================================

% Crop to the outer edge of the 10-pixel feather.
% This keeps the entire feathered transition.

xMin = floor(centerX - radiusX) - featherPixels;
xMax = ceil(centerX + radiusX) + featherPixels;

yMin = floor(centerY - radiusY) - featherPixels;
yMax = ceil(centerY + radiusY) + featherPixels;

% Make sure coordinates stay inside image
xMin = max(1,xMin);
xMax = min(outputWidth,xMax);

yMin = max(1,yMin);
yMax = min(outputHeight,yMax);

fprintf('\nFeather-edge bounding box:\n');
fprintf('Width  = %d pixels\n',xMax-xMin+1);
fprintf('Height = %d pixels\n',yMax-yMin+1);

%% ================================================================
% SAVE CROPPED IMAGES
% ================================================================

for i = 1:imageCounter

    category = allCategories{i};

    filename = allNames{i};

    categoryOutputFolder = ...
        fullfile(outputFolder,category);

    [~,name,~] = fileparts(filename);

    %% Crop exactly to ellipse boundary

    croppedImg = allImages{i}(yMin:yMax,xMin:xMax);
    croppedAlpha = alpha(yMin:yMax,xMin:xMax);

    %% Save as PNG

    outputFilename = [name '_processed.png'];

    outputPath = ...
        fullfile(categoryOutputFolder,outputFilename);

    imwrite(croppedImg,outputPath, ...
      'Alpha',uint8(croppedAlpha*255));
end