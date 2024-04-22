%% Example script that will run the full pipeline.
clc
addpath(fullfile(mfilename('fullpath'), 'pre_processing'));
% where your raw data files live
% should only contain .tif files from a single session
datapath = 'C:\Users\RBO\Documents\MATLAB\benchmarks\high_resolution\';

convertScanImageTiffToVolume(datapath);
motionCorrectPlane(datapath, fileRoot, 23, 1, 3);