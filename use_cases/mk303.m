%% mk302, 01.30.25

set(groot, 'DefaultFigureVisible', 'on');
clc, clear; % !! Careful, this will clear all variables from memory
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core'))); addpath(genpath(fullfile(fpath, 'packages')));

%% POINT THIS PATH TO WHERE YOUR TIFF FILES LIVE
data_path = fullfile('D:\W2_DATA\kbarber\2025_01_30_GCaMP8s_tdtomato_mk303\mk303_mbo_2umpx_2roi_448umx896um_17p07_green_14planes_00001');
%%
% To preview metadata for this file without assembling it
% metadata = get_metadata(fullfile(data_path, "filename.tif");
% This happens internally in convertScanImageTiffToVolume()
metadata = get_metadata(fullfile(data_path, "mk303_mbo_2umpx_2roi_448umx896um_17p07_green_14planes_00001.tif"));
% disp(metadata);
%%

save_path = fullfile('D:\W2_DATA\2025_01_30_GCaMP8s_tdtomato_mk303\mk303_mbo_2umpx_2roi_448umx896um_17p07_green_14planes_00001\matlab\assembled');
%%
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


%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Motion Correction %%%
%%
t1 = tic;

% We want to fetch the size of the dataset from the first assembled file
filename = fullfile(save_path, "assembled_plane_1.h5");
metadata = read_h5_metadata(filename, '/Y');

% data_size = metadata.data_size;
data_size = h5info(filename, '/Y').ChunkSize(1:2);

options = NoRMCorreSetParms(...
    'd1', data_size(1),...
    'd2', data_size(2),...
    'grid_size', [64,64], ...
    'bin_width', 100,... % number of frames to avg when updating template
    'max_shift', round(20/metadata.pixel_resolution),... % (a little larger than) size of a large neuron mouse cortex
    'correct_bidir', false, ... % defaults to true, this was already done in step 1
    'us_fac', 5, ...
    'init_batch', 200 ... % increasing will add frames to the mean image used as a template
);

motionCorrectPlane( ...
    fullfile(save_path), ... % tiff_path / assembled
    'save_path', fullfile(data_path, "matlab/processed/"), ... % default used internally
    'ds', '/Y', ... 
    'debug_flag', 0, ...
    'overwrite', 1, ...
    'num_cores', 23, ... % "matlab workers" not exactly cpu cores
    'start_plane', 1, ...
    'end_plane', metadata.num_planes,  ...
    'options', options ...
    );

%% 3) CNMF Plane-by-plane Segmentation

% Pull metadata from a single file
filename = fullfile(data_path, 'matlab/processed/', "motion_corrected_plane_1.h5");

% Gather relevnt metadata
metadata = read_h5_metadata(filename, '/Y');
data_size = h5info(filename, '/Y').ChunkSize(1:2);
pixel_resolution = metadata.pixel_resolution;
frame_rate = metadata.frame_rate;
d1=data_size(1);d2=data_size(2);
d = data_size(1)*data_size(2);      % total number of samples
T = metadata.num_frames;

tau = ceil(7.5./pixel_resolution);  % (a little smaller than) half-size of neuron

% USER-SET VARIABLES - CHANGE THESE TO IMPROVE SEGMENTATION

merge_thresh = 0.8;                 % how temporally correlated any two neurons need to be to be merged
min_SNR = 1.4;                      % signal-noise ratio needed to accept this neuron as initialized (1.4 is liberal)
space_thresh = 0.2;                 % how spatially correlated nearby px need to be to be considered for segmentation
sz = 0.1;                           % If masks are too large, increase sz, if too small, decrease. 0.1 lowest.
p = 2;                              % order of dynamics

mx = ceil(pi.*(1.33.*tau).^2);
mn = floor(pi.*(tau.*0.5).^2);     

% patch set up; basing it on the ~600 um strips of the 2pRAM, +50 um overlap between patches
% patch_size = round(650/pixel_resolution).*[1,1];
patch_size = [128, 128];
% overlap = [1,1].*ceil(50./pixel_resolution);
overlap = [32, 32];
patches = construct_patches(data_size,patch_size,overlap);

% number of components based on assumption of 9.2e4 neurons/mm^3
K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2);

% Set caiman parameters
options = CNMFSetParms(...
    'd1',d1,'d2',d2, ...                         % dimensionality of the FOV
    'deconv_method','constrained_foopsi',...    % neural activity deconvolution method
    'temporal_iter',3,...                       % number of block-coordinate descent steps
    'maxIter',15,...                            % number of NMF iterations during initialization
    'spatial_method','regularized',...          % method for updating spatial components
    'df_prctile',20,...                         % take the median of background fluorescence to compute baseline fluorescence
    'p',p,...                                   % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
    'gSig',tau,...                              % half size of neuron
    'merge_thr',merge_thresh,...                % how correlated 2 neurons must be to merge
    'nb',1,...                                  % number of background components (keep at 1 or 2, 2 for more noisy background)
    'gnb',3,...
    'min_SNR',min_SNR,...                       % minimum SNR threshold
    'space_thresh',space_thresh ,...            % space correlation threshold
    'decay_time',0.5,...                        % decay time of transients, GCaMP6s
    'size_thr', sz, ...
    'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
    'max_size', 2*round(tau), ...               % maximum size of ellipse axis (default: 8)
    'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
    'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
    'rolling_length',ceil(frame_rate*5),...
    'fr', frame_rate ...
);   

segmentPlane( ...
    fullfile(data_path, 'matlab/processed/'), ... % we used this to save extracted data
    'save_path', fullfile(data_path, "matlab/processed/"), ... % default used internally
    'ds', '/Y', ... % where we saved the last step in h5 (default)
    'debug_flag', 0, ...
    'overwrite', 1, ...
    'num_cores', 23, ...
    'start_plane', 1, ...
    'end_plane', 30, ...
    'options', options, ...
    'patches', patches, ...
    'K', K ...
);

t2 = toc(t1);
disp(t2);

%% 4) Collate z-planes and merge spatially overlapping highly-correlated neuronss

thresh_options = {'min_SNR', 1.5, 'merge_thr', 0.95};
collatePlanes( ...
    fullfile(data_path, 'matlab/segmented'), ... % data_path = segmentation results
    'save_path', fullfile(data_path, 'matlab/collated'), ... % data_path = segmentation results
    'ds', '/Y', ...
    'debug_flag', 0, ...
    'overwrite', 0, ...
    'start_plane', 1, ...
    'end_plane', metadata.num_planes,  ...
    'num_features', 1, ...
    'motion_corrected_path', fullfile(data_path, 'matlab/processed'), ...
    'options', thresh_options ...
);

%%

col_fpath = "E:\W2_archive\demas_2021\high_resolution\matlab\processed\collated_planes.h5";

T_all = h5read(col_fpath, '/T_all');
% T_all = movmean(T_all./(max(T_all,[],2)*ones(1,size(T_all,2))),5,2);

% C_all = h5read(col_fpath, '/C_all');
% nx = h5read(col_fpath, '/nx');
% ny = h5read(col_fpath, '/ny');
% nz = h5read(col_fpath, '/nz');

% Compute total activity for each neuron (sum across time)
total_activity = sum(T_all, 2);

% Sort neurons by descending activity
[~, sorted_indices] = sort(total_activity, 'descend');
top_100_traces = T_all(sorted_indices(1:100), :);

% Normalize each neuron's activity (row-wise)
top_100_traces = top_100_traces - min(top_100_traces, [], 2);
top_100_traces = top_100_traces ./ max(top_100_traces, [], 2);

% Plot heatmap
figure;
imagesc(top_100_traces);
colormap hot; % Use a heat colormap
colorbar;
xlabel('Frames (Time)');
ylabel('Top 100 Most Active Neurons');
title('Neuronal Activity Heatmap');

%%

save_path = "E:\W2_archive\demas_2021\high_resolution\matlab\processed\figures\traces.png";
plot_traces(T_all, 100, save_path);

