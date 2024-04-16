clear;
path = fullfile("/data2/fpo/lbm/0p6mm_0p6mm/input/TMPMH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.mat");
data = matfile(path);
volumeRate = data.volumeRate;
pixelResolution = data.pixelResolution;
vol = data.vol(:, :, :, 1:300);
fullVolumeSize = size(vol);
sizY=size(vol);

output = fullfile("/data2/fpo/lbm/0p6mm_0p6mm/data_full_30_300.mat");
savefast(output,'vol','volumeRate', 'fullVolumeSize', 'sizY','pixelResolution');

square_size = 400;
numPlanes=2;
numFrames=400;

y = fullVolumeSize(1);
x = fullVolumeSize(2);

% Calculate starting points
y_start = round((y - square_size) / 2) + 1;
x_start = round((x - square_size) / 2) + 1;

% Calculate ending points
y_end = y_start + square_size - 1;
x_end = x_start + square_size - 1;

% Slice the array
vol = vol(y_start:y_end, x_start:x_end, 1:numPlanes, 1:numFrames);
fullVolumeSize = size(vol);
sizY=size(vol);

output = fullfile("/data2/fpo/lbm/0p6mm_0p6mm/data_full_30_300.mat");
savefast(output,'vol','volumeRate', 'fullVolumeSize', 'sizY','pixelResolution');