%% Example script that will run the full pipeline.
clc
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core/')));

result = validateRequirements();
if ischar(result)
    error(result); 
else
    disp('Proceeding with execution...');
end

%% 1) Pre-Processing
% should only contain .tif files from a single session
datapath = 'C:\Users\RBO\Documents\MATLAB\benchmarks\high_res\';
% convertScanImageTiffToVolume(datapath);
% motionCorrectPlane(datapath, 23, 1, 3);
segmentPlane(datapath, '0', '1', '1', '0')