%% ================================================================
% KDEF FACE PREPROCESSING
% Folder structure:
%
% faces/
%   angry/
%   happy/
%   neutral/
%
% Each folder contains .jpg images
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
%% INPUT AND OUTPUT FOLDERS
inputFolder = 'D:\CFS\Expt_emo\Stimuli\OG_faces';
outputFolder = 'D:\CFS\Expt_emo\Stimuli\processed_faces';
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end
%% IMAGE SIZE
outputHeight = 254;
outputWidth  = 174;
%% ================================================================
% ELLIPTICAL MASK
% ================================================================
ellipseCenterX = 0.50;
ellipseCenterY = 0.58;
ellipseRadiusX = 0.24;
ellipseRadiusY = 0.22;
% Pixels outside the ellipse will be gray
maskBackground = 95;
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
% FIND SUBFOLDERS
% ================================================================
folders = dir(inputFolder);
folders = folders([folders.isdir]);
% Remove "." and ".."
folders = folders(~ismember({folders.name},{'.','..'}));
fprintf('\nFound %d stimulus folders:\n',length(folders));
for f = 1:length(folders)
    fprintf('   %s\n',folders(f).name);
end
%% ================================================================
% FIRST PASS
% READ ALL IMAGES AND CALCULATE LUMINANCE / CONTRAST
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
    % Create corresponding output folder
    categoryOutputFolder = fullfile(outputFolder,category);
    if ~exist(categoryOutputFolder,'dir')
        mkdir(categoryOutputFolder);
    end
    % Find JPG files
    jpgFiles = [
        dir(fullfile(categoryFolder,'*.jpg'));
        dir(fullfile(categoryFolder, '*.JPG'))
    ];
    fprintf('\n%s: %d images\n',category,length(jpgFiles));
    for i = 1:length(jpgFiles)
        filename = jpgFiles(i).name;
        filepath = fullfile(categoryFolder,filename);
        %% Read image
        img = imread(filepath);
        %% Convert to grayscale
        if size(img,3) == 3
            img = rgb2gray(img);
        end
        %% Convert to double
        img = im2double(img);
        %% Resize
        img = imresize(img,[outputHeight outputWidth]);
        %% Apply elliptical mask
        img(~ellipseMask) = maskBackground/255;
        %% Pixels inside facial region
        pixels = img(ellipseMask);
        %% Mean luminance
        currentMean = mean(pixels);
        %% RMS contrast
        currentContrast = std(pixels)/currentMean;
        %% Store
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
    %% Pixels inside mask
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
    % Clip values to valid grayscale range
    % ------------------------------------------------------------
    img = max(0,min(1,img));
    %% Reapply mask
    img(~ellipseMask) = maskBackground/255;
    %% Store final image
    allImages{i} = img;
    %% ------------------------------------------------------------
    % Calculate final statistics
    % ------------------------------------------------------------
    finalPixels = img(ellipseMask);
    finalMeanLum(i) = mean(finalPixels);
    finalRMSContrast(i) = ...
        std(finalPixels)/mean(finalPixels);
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
    outputFilename = [name '.jpg'];
    outputPath = ...
        fullfile(categoryOutputFolder,outputFilename);
    imwrite(allImages{i},outputPath,'Quality',100);
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
% SAVE QC TABLE
% ================================================================
writetable(QC, ...
    fullfile(outputFolder,'KDEF_Stimulus_QC.csv'));
%% ================================================================
% SAVE MASK
% ================================================================
imwrite(uint8(ellipseMask)*255, ...
    fullfile(outputFolder,'Elliptical_Mask.jpg'));
%% ================================================================
% DISPLAY MASK
% ================================================================
figure;
imshow(ellipseMask);
title('Elliptical Facial Mask');
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
fprintf('\nTarget mean luminance = %.5f\n',targetLuminance);
fprintf('Target RMS contrast   = %.5f\n',targetContrast);
fprintf('\nDone!\n');