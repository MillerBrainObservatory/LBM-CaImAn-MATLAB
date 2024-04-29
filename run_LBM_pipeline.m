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
datapath = 'C:\Users\RBO\Documents\data\high_speed\';
savepath = 'C:\Users\RBO\Documents\data\high_speed\preprocess';
metapath = "C:\Users\RBO\Documents\data\high_speed\MH70_0p9mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif";

% convertScanImageTiffToVolume(datapath, savepath, 'high_speed');
mdata = get_metadata(metapath);
mdata.dataset_name = "high_speed";
mdata.base_filename = "MH70_0p9mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001";
% motionCorrectPlane(savepath, mdata, 23, 1, 3);
segmentPlane(datapath, '0', '1', '1', '0')
%%
