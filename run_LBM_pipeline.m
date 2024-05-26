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
if ~isfolder(save_path)
    mkdir(save_path)
end

%% 1a) Pre-Processing
group_path = "/extraction"; % where data is saved in the h5 file (this is default)
compute = 1;
if compute
    convertScanImageTiffToVolume( ...
        data_path, ...
        save_path, ...
        'dataset_name', group_path, ...
        'debug_flag', 0, ...
        'fix_scan_phase', 0, ...
        'trim_pixels', [6 6 17 0], ...
        'overwrite', 1 ...
        );
end

%% quick vis
plane = 1;
frame_start = 10;
frame_end = 220;

h5files = dir([save_path '*.h5']);
h5name = fullfile(save_path, h5files(1).name);
dataset_path = sprintf('/mov/plane_%d', plane);
data_path = sprintf("%s/Y", dataset_path);
info = h5info(h5name, data_path);

% data = h5read( ...
%     h5name, ... % filename
%     dataset_path, ... % dataset location
%     [1, 1, frame_start], ... % start index for each dimension [X,Y,T]
%     [Inf, Inf,  frame_end - frame_start + 1] ... % count for each dimension [X,Y,T]
%     );

% 
% figure;
% for x = 1:size(data, 3)
%     imshow(data(236:408, 210:377, x), []);
%     title(sprintf('Frame %d', start_frame + x - 1));
% end

%% 1b) Motion Correction

% mdata = get_metadata(fullfile(raw_path ,"MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tif"));
% mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";
% mc_path_new = [ parent_path 'registration_test\'];
compute = 0;
if compute
    motionCorrectPlane( ...
        save_path, ...
        save_path, ...
        'data_input_group', '/extraction', ... % from the last step
        'data_output_group', "/registration", ... % "str" or 'char' both work for inputs
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 2, ...
        'end_plane', 30  ...
        );
end

% 
% % 
%% 2) CNMF Plane-by-plane SegmentationS
% % 
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

% % 
% % %% 3) Axial Offset Correction
% % collatePlanes()
% 
% function has_mc = has_registration(ih5_path)
%     if numel(h5info(ih5_path, '/').Groups) < 2
%         has_mc = false;
%     else
%         has_mc = true;
%     end
% end

