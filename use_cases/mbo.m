
%%%%%%%%%%%%%%%%%%%%%
%%%%%% Setup %%%%%%%%
clc, clear;
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, '../core')));
addpath(genpath(fullfile(fpath, '../core', 'utils')));
addpath(genpath(fullfile(fpath, '../core', 'io')));
addpath(genpath(fullfile(fpath, '../core', 'internal')));

result = validate_toolboxes();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

homedir = getenv('HOMEPATH'); % will autofill /home/<username> (linux) or C:/Users/Username (windows)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% User Parameters %%%%%%%%

parent_path = fullfile(sprintf('%s/Documents/data/high_res/v1.6', homedir));
raw_tiff_path = fullfile(parent_path, 'raw');
extract_path = fullfile(parent_path, 'extracted');
registered_path = fullfile(parent_path, 'registered');
segment_path = fullfile(parent_path, 'segmented');
collate_path = fullfile(parent_path, 'collated');

do_extraction = 1;
do_registration = 1;
do_segmentation = 1;
do_axial_correction = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Extraction %%%%%%%%
%%

if do_extraction
    convertScanImageTiffToVolume( ...
        raw_tiff_path, ...
        extract_path, ...
        'dataset_name', '/Y', ... % default
        'debug_flag', 0, ... % default, if 1 will display files and return
        'fix_scan_phase', 1, ... % default, keep to 1
        'trim_pixels', [6 6 17 0], ... % default, num pixels to trim for each roi
        'overwrite', 1 ...
        );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Motion Correction %%%
%%

if do_registration
    motionCorrectPlane( ...
        extract_path, ... % we used this to save extracted data
        registered_path, ... % save registered data here
        'dataset_name', '/Y', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 30 ...
        );  %...
       % 'options_nonrigid', options_nonrigid ...
end

order = fliplr([1 5:10 2 11:17 3 18:23 4 24:30]);
rename_planes(registered_path, order);
%% 3) CNMF Plane-by-plane SegmentationS

if do_segmentation
    segmentPlane( ...
        registered_path, ... % we used this to save extracted data
        segment_path, ... % save registered data here
        'dataset_name', '/Y', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 30  ...
        );
end

%% 4) Axial Offset Correction

if do_axial_correction
    axial_save_path = fullfile(parent_path, 'axial_offset/');
    calculateZOffset( ...
        registered_path, ...
        segment_path, ...
        axial_save_path, ...
        'start_plane',1, ...
        'end_plane',8, ...
        'base_name', 'motion_corrected', ...
        'dataset_name','/mov' ...
        );
end
