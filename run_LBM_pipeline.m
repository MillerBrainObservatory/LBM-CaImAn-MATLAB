% folder heirarchy
% -| Parent
% --| raw  <--scanimage .tiff files live here
% ----| basename.h5
% --| extraction
% ----| basename_shifts.h5
% --| registration
% ----| shift_vectors_plane_N.h5
% --| segmentation
% ----| caiman_output_plane_N.h5
% ----| caiman_output_collated_min1.4snr.h5

%% Example script that will run the full pipeline.
% This code block adds all modules inside the "core" directory to the
% matlab path.
% This isn't needed if the path to this package is added to the MATLAB path
% manually by right clicking caiman_matlab folder and "add packages and
% subpackages to path" or via the startup.m file. Both methods described in
% more detail in the README.
clc, clear;
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core')));
addpath(genpath(fullfile(fpath, 'core', 'utils')));
addpath(genpath(fullfile(fpath, 'core', 'io')));

%% Here you can validate that all packages are on the path and accessible
% from within this pipeline.

result = validateRequirements();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\extracted\');
data_path = fullfile(parent_path, 'raw');
save_path = fullfile(parent_path, 'results');
if ~isfolder(save_path)
    mkdir(save_path)
end

%% 1a) Pre-Processing
clc;
compute = 1;
if compute
    convertScanImageTiffToVolume( ...
        data_path, ...
        save_path, ...
        'dataset_name', '/extracted', ... % default
        'debug_flag', 0, ... % default, if 1 will display files and return
        'fix_scan_phase', 1, ... % default, keep to 1
        'trim_pixels', [6 6 17 0], ... % default, num pixels to trim for each roi
        'overwrite', 1 ...
        );
end

%% quick vis
clc;
h5file = 'C:\Users\RBO\Documents\data\high_res\extracted\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.h5';
metadata = read_h5_metadata(h5file, '/extracted');

plane = 1;
frame_start = 10;
frame_end = 100;
xs=(236:408);
ys=(210:377);
ts=(2:202);
dataset_path = sprintf('/extracted/plane_%d', plane);
info = h5info(h5file, dataset_path);

count_x = length(xs);
count_y = length(ys);
count_t = frame_end - frame_start + 1;

data = h5read( ...
    h5file, ... % filename
    dataset_path, ... % dataset location
    [xs(1), ys(1), frame_start], ... % start index for each dimension [X,Y,T]
    [count_x, count_y, count_t] ... % count for each dimension [X,Y,T]
    );

%% 1b) Motion Correction

compute = 0;
if compute
    motionCorrectPlane( ...
        save_path, ...
        save_path, ...
        'data_input_group', '/extracted', ... % from the last step
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 2, ...
        'end_plane', 30  ...
        );
end

%% 2) CNMF Plane-by-plane SegmentationS

compute = 1;
if compute
    segmentPlane( ...
        save_path, ...
        save_path, ...
        'data_input_group', '/registration', ... % from the last step
        'data_output_group', "/segmentation", ... % "str" or 'char' both work for inputs
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 1  ...
        );
end

%% 3) Axial Offset Correction
collatePlanes()