%% ================================================================
% LAPTOP DISPLAY CALIBRATION — STEP 1
% ================================================================

clear;
clc;
sca;

PsychDefaultSetup(2);

% For development only
Screen('Preference', 'SkipSyncTests', 1);

% ------------------------------------------------
% SELECT DISPLAY
% ------------------------------------------------

screens = Screen('Screens');

disp('Available screens:');
disp(screens);

screenNumber = 2;

% ------------------------------------------------
% OPEN WINDOW
% ------------------------------------------------

backgroundGray = 128 / 255;

windowRect = [100 100 1820 980];

[window, rect] = PsychImaging('OpenWindow', ...
    screenNumber, ...
    backgroundGray, ...
    windowRect);

% ------------------------------------------------
% DISPLAY
% ------------------------------------------------

Screen('Flip', window);

fprintf('\n');
fprintf('============================================\n');
fprintf('LAPTOP CALIBRATION WINDOW\n');
fprintf('============================================\n');
fprintf('\n');
fprintf('Screen number: %d\n', screenNumber);
fprintf('Window size: %.0f x %.0f pixels\n', ...
    RectWidth(rect), RectHeight(rect));
fprintf('\n');
fprintf('Press ENTER to close.\n');

KbStrokeWait;

sca;


%% ================================================================
% STEP 2 — GRAY-LEVEL CALIBRATION PATCHES
% ================================================================

clear;
clc;
sca;

PsychDefaultSetup(2);

% Development only
Screen('Preference', 'SkipSyncTests', 1);

% ------------------------------------------------
% SELECT MONITOR
% ------------------------------------------------

screenNumber = 2;

% ------------------------------------------------
% OPEN WINDOW
% ------------------------------------------------

backgroundGray = 128 / 255;

windowRect = [100 100 1820 980];

[window, rect] = PsychImaging('OpenWindow', ...
    screenNumber, ...
    backgroundGray, ...
    windowRect);

% ------------------------------------------------
% GRAY LEVELS TO TEST
% ------------------------------------------------

grayLevels = [0 32 64 96 128 160 192 224 255];

% ------------------------------------------------
% DISPLAY EACH GRAY LEVEL
% ------------------------------------------------

for i = 1:length(grayLevels)

    gray = grayLevels(i) / 255;

    Screen('FillRect', window, [gray gray gray]);

    Screen('Flip', window);

    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('Patch %d of %d\n', i, length(grayLevels));
    fprintf('RGB value = %d\n', grayLevels(i));
    fprintf('Normalized value = %.4f\n', gray);
    fprintf('--------------------------------------------\n');
    fprintf('Press ENTER for next patch...\n');

    KbStrokeWait;

end

sca;

fprintf('\nCalibration patch sequence finished.\n');