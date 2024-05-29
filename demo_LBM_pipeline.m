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

%% Here you can validate that all dependencies are on the path and accessible from within this pipeline.
%% This does not check for package access on your path.
result = validateRequirements();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

<<<<<<< HEAD:run_LBM_pipeline.m
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
=======
parent_path = 'C:\Users\<Username>\Documents\data\bi_hemisphere\';
raw_path = [ parent_path 'raw\'];
extraction_path = [ parent_path '\extracted\'];
registration_path = [ parent_path 'registration\'];
segmentation_path = [ parent_path 'traces\'];

%% 1a) Pre-Processing
group_path = "/extraction"; % where data is saved in the h5 file (this is default)
convertScanImageTiffToVolume( ...
    raw_path, ... %% where our .tif files live
    extraction_path, ... %% our output filepath
    'group_path', group_path, ...  %% What we name our output group
    'fix_scan_phase', true, ...
    'trim_pixels', [7 7 29 0], ...
    'overwrite', 1 ...
    );


%% 1b) Motion Correction

% mdata = get_metadata(fullfile(raw_path ,"MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tif"));
% mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";
% mc_path_new = [ parent_path 'registration_test\'];
%
if ~isfolder(registration_path)
    mkdir(registration_path);
end
motionCorrectPlane( ...
    extraction_path, ...
    registration_path, ...
    'data_input_group', '/extraction', ... % from the last step
    'data_output_group', "/registration", ... % "str" or 'char' both work for inputs
    'overwrite', 1, ...
    'num_cores', 23, ...
    'start_plane', 29, ...
    'end_plane', 29 ...
    );

% %% 2) CNMF Plane-by-plane SegmentationS
%
% segmentPlane(mc_path, traces_path, mdata, '0','30','30','23');
%
% %% 3) Axial Offset Correction
% collatePlanes()

function has_mc = has_registration(ih5_path)
    if numel(h5info(ih5_path, '/').Groups) < 2
        has_mc = false;
    else
        has_mc = true;
    end
>>>>>>> benchmarks_improvements:demo_LBM_pipeline.m
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
        'start_plane', 2, ...
        'end_plane', 6  ...
        );
end

%% 3) CNMF Plane-by-plane SegmentationS
segment_path = fullfile(parent_path, 'segmented');
if ~isfolder(segment_path); mkdir(segment_path); end

compute = 1;
if compute
    segmentPlane( ...
        mc_path, ... % we used this to save extracted data
        segment_path, ... % save registered data here
        'dataset_name', '/mov', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 1  ...
        );
end

%% 4) Axial Offset Correction
dpath="D:\Jeffs LBM paper data\Fig4a-c\20191121\MH70\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001\output";
h5_fullfile="../../Documents/data/high_res/extracted/extracted_plane_1.h5";
metadata = read_h5_metadata(h5_fullfile, '/Y');

%%
calculateZOffset(dpath, metadata);