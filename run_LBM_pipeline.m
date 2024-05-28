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

parent_path = fullfile('C:\Users\RBO\Documents\data\high_res');
data_path = fullfile(parent_path, 'raw');
save_path = fullfile(parent_path, 'extracted');

%% 1a) Pre-Processing
clc;
compute = 1;
if compute
    convertScanImageTiffToVolume( ...
        data_path, ...
        save_path, ...
        'dataset_name', '/Y', ... % default
        'debug_flag', 0, ... % default, if 1 will display files and return
        'fix_scan_phase', 1, ... % default, keep to 1
        'trim_pixels', [6 6 17 0], ... % default, num pixels to trim for each roi
        'overwrite', 1 ...
        );
end

%% 2) Motion Correction
mc_path = fullfile(parent_path, 'corrected');
if ~isfolder(mc_path); mkdir(mc_path); end

compute = 1;
if compute
    motionCorrectPlane( ...
        save_path, ... % we used this to save extracted data
        mc_path, ... % save registered data here
        'dataset_name', '/Y', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 1  ...
        );
end

%% 3) CNMF Plane-by-plane SegmentationS
segment_path = fullfile(parent_path, 'segmented');
if ~isfolder(segment_path); mkdir(segment_path); end

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

%% 4) Axial Offset Correction
collatePlanes()