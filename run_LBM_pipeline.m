%% Light Beads Microscopy Pipeline

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
clc
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core/')));

%% Here you can validate that all packages are on the path and accessible 
% from within this pipeline.

result = validateRequirements();
if ischar(result)
    error(result); 
else
    disp('Proceeding with execution...');
end

parentpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
raw_path = [ parentpath 'raw\'];
extract_path = [ parentpath 'extracted2\'];
mkdir(extract_path); mkdir(raw_path);

%% 1a) Pre-Processing

convertScanImageTiffToVolume(raw_path, extract_path, 0,'fix_scan_phase', false);

%% 1b) Motion Correction

mdata = get_metadata(fullfile(metapath, metaname));
mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";

mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';
motionCorrectPlane(extract_path, 23, 1, 30);

%% 2) CNMF Plane-by-plane Segmentation

segmentPlane(extract_path, mdata,'0','1','30','24')
