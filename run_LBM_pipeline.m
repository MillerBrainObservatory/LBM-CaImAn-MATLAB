%% Example script that will run the full pipeline.
clc
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core/')));

result = validateRequirements();
if ischar(result)
    error(result);  % Stop execution and display error if not all toolboxes are installed
else
    disp('Proceeding with execution...');  % Continue with your script if all toolboxes are installed
end

%% 1) Pre-Processing


% should only contain .tif files from a single session
datapath = 'C:\Users\RBO\Documents\MATLAB\benchmarks\high_resolution\';

convertScanImageTiffToVolume(datapath);
motionCorrectPlane(datapath, 23, 1, 3);