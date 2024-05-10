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
clc
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core/')));

result = validateRequirements(); % make sure we have dependencies in accessible places
if ischar(result)
    error(result); 
else
    disp('Proceeding with execution...');
end

%% 1a) Pre-Processing

parentpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
raw_path = [ parentpath 'raw\'];
extract_path = [ parentpath 'extracted\'];
mkdir(extract_path); mkdir(raw_path);

raw_files = dir([raw_path '*.tif*']);
metainfo = raw_files(1);
metaname = metainfo.name;
metapath = metainfo.folder;

convertScanImageTiffToVolume(raw_path, extract_path, 'bi_hemisphere');

%% 1b) Motion Correction

mdata = get_metadata(fullfile(metapath, metaname));
mdata.dataset_name = "bi_hemisphere";
mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";

mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';
motionCorrectPlane(extract_path, mdata, 23, 1, 3);

%% 2) CNMF Plane-by-plane Segmentation

segmentPlane(mcpath,mdata,'0','1','30','24')

%% 3) Axial Offset Correction
