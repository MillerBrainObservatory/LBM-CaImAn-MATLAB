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
addpath(genpath(fullfile(fpath, 'core/')));

%% Here you can validate that all dependencies are on the path and accessible from within this pipeline.
%% This does not check for package access on your path.
result = validateRequirements();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

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
end

