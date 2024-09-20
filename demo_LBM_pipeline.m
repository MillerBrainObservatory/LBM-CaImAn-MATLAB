%% Example script that will run the full pipeline.
% This code block adds all modules inside the "core" directory to the
% matlab path.
% This isn't needed if the path to this package is added to the MATLAB path
% manually by right clicking caiman_matlab folder and "add packages and
% subpackages to path" or via the startup.m file. Both methods described in
% more detail in the README.
%% Two %'s lets you run code section-by-section via the Run Section button or pressing cntl+enter

% Make sure figures will show
set(groot, 'DefaultFigureVisible', 'on');


%% RUN THIS WITH THE PLAY BUTTON, NOT "RUN SECTION"
% When ran as a script (the "Run" button), this will automatically add the
% core and packages folders to your MATLAB path
% Not needed if the project code is stored in the Documents/MATLAB folder
clc, clear; % !! Careful, this will clear all variables from memory
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core'))); addpath(genpath(fullfile(fpath, 'packages')));

% To preview metadata for this file without assembling it
% metadata = get_metadata(fullfile(data_path, "filename.tif");
% This happens internally in convertScanImageTiffToVolume()
metadata = get_metadata(fullfile(data_path, "MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif"));
disp(metadata);

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Assembly %%%%%%%%%%
%%


%% POINT THIS PATH TO WHERE YOUR TIFF FILES LIVE
data_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01');

% by default, results are saved in the parent directory /function_step
% directory
save_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\assembled\');
convertScanImageTiffToVolume( ...
    data_path, ...
    'save_path', save_path, ... 
    'ds', '/Y', ... 
    'debug_flag', 0, ...
    'do_figures', 1, ...
    'overwrite', 0, ...
    'fix_scan_phase', 1, ...
    'trim_roi', [0 0 0 0], ... % num pixels to trim for each roi
    'trim_image', [0 0 0 0], ... % num pixels to trim for each roi
    'z_plane_order', [] ... % reshape the planes according to this vector.
    ...                     % num values should match num planes
);


%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Motion Correction %%%
%%

% We want to fetch the size of the dataset from the first assembled file
filename = fullfile(save_path, "assembled_plane_1.h5");
metadata = read_h5_metadata(filename, '/Y');

data_size = metadata.data_size;

options = NoRMCorreSetParms(...
    'd1', data_size(1),...
    'd2', data_size(2),...
    'grid_size', [64,64], ...
    'bin_width', 100,... % number of frames to avg when updating template
    'max_shift', round(20/metadata.pixel_resolution),... % Size of a large neuron mouse cortex
    'correct_bidir', false... % defaults to true, this was already done in step 1
);

motionCorrectPlane( ...
    fullfile(data_path, "assembled"), ... % we used this to save extracted data
    'save_path', fullfile(data_path, "corrected/"), ... % save registered data here
    'ds', '/Y', ... % where we saved the last step in h5
    'debug_flag', 0, ...
    'overwrite', 0, ...
    'num_cores', 23, ...
    'start_plane', 1, ...
    'end_plane', metadata.num_planes,  ...
    'options', options ...
    );

%% 3) CNMF Plane-by-plane Segmentation

segmentPlane( ...
    mc_path, ... % we used this to save extracted data
    'dataset_name', '/Y', ... % where we saved the last step in h5 (default)
    'debug_flag', 0, ...
    'overwrite', 0, ...
    'num_cores', 23, ...
    'start_plane', 1, ...
    'end_plane', metadata.num_planes  ...
);

%% 4) Collate z-planes and merge spatially overlapping highly-correlated neurons

collatePlanes( ...
    'C:/Users/RBO/caiman_data/animal_01/session_01/segmented', ... % data_path
    'ds', '/Y', ... % where we saved the last step in h5
    'debug_flag', 0, ...
    'overwrite', 0, ...
    'start_plane', 1, ...
    'end_plane', 2,  ...
    'num_features', 1 ...
);


