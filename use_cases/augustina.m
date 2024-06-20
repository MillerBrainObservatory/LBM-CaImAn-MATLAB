% USE_CASE: AUGUSTINA

%% Example script that will run the full pipeline.
% This code block adds all modules inside the "core" directory to the
% matlab path.
% This isn't needed if the path to this package is added to the MATLAB path
% manually by right clicking caiman_matlab folder and "add packages and
% subpackages to path" or via the startup.m file. Both methods described in
% more detail in the README.

%% UPDATE: RUN THIS WITH THE PLAY BUTTON, NOT "RUN SECTION"
% To get eveything added to your path
clc, clear;
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core')));
addpath(genpath(fullfile(fpath, 'core', 'utils')));
addpath(genpath(fullfile(fpath, 'core', 'io')));

%% Here you can validate that all dependencies are on the path and accessible from within this pipeline.
% This does not check for package access on your path.

result = validate_toolboxes();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

parent_path = fullfile('C:/Users/RBO/Documents/data/augustina/');
data_path = fullfile(parent_path, 'raw');
save_path = fullfile(parent_path, sprintf('extracted'));

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Extraction %%%%%%%%

clc; compute = 1;
if compute
    convertScanImageTiffToVolume( ...
        data_path, ...
        save_path, ...
        'dataset_name', '/Y', ... % default
        'debug_flag', 0, ... % default, if 1 will display files and return
        'fix_scan_phase', 1, ... % default, keep to 1
        'trim_pixels', [0 0 0 0], ... % default, num pixels to trim for each roi
        'overwrite', 1 ...
        );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Motion Correction %%%

clc; compute = 1;
if compute

    mc_path = fullfile(parent_path, 'extracted_4px_4px_17px_0px');
    if ~isfolder(mc_path); mkdir(mc_path); end

    filename = fullfile(save_path, "extracted_plane_1.h5");
    metadata = read_h5_metadata(filename, '/Y');
    info = h5info(filename, '/Y');
    data_size = info.Dataspace.Size;

    options_nonrigid = NoRMCorreSetParms(...
        'd1', data_size(1),...
        'd2', data_size(2),...
        'grid_size', [128,128], ...
        'bin_width', 24,... % number of frames to avg when updating template
        'max_shift', round(20/metadata.pixel_resolution),... % 20 microns
        'us_fac', 20,...
        'init_batch', 120,...
        'correct_bidir', false...
        );

    motionCorrectPlane( ...
        save_path, ... % we used this to save extracted data
        mc_path, ... % save registered data here
        'dataset_name', '/Y', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 30,  ...
        'options_nonrigid', options_nonrigid ...
        );
end

%% 3) CNMF Plane-by-plane SegmentationS

clc; compute = 1;
if compute
    mc_path = fullfile(parent_path, 'corrected_trimmed_grid');
    if ~isfolder(mc_path); mkdir(mc_path); end
    segment_path = fullfile(parent_path, 'results');
    if ~isfolder(segment_path); mkdir(segment_path); end

    segmentPlane( ...
        mc_path, ... % we used this to save extracted data
        segment_path, ... % save registered data here
        'dataset_name', '/mov', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 30  ...
        );
end

%% 4) Axial Offset Correction
clc; compute = 0;
if compute
    dpath="D:\Jeffs LBM paper data\Fig4a-c\20191121\MH70\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001\output";
    h5_fullfile="C:/Users/RBO/Documents/data/high_res/corrected_trimmed_grid/motion_corrected_plane_1.h5";
    metadata = read_h5_metadata(h5_fullfile, '/Y');
    data = h5read(h5_fullfile, '/Y');

    calculateZOffset(dpath, metadata);
end
