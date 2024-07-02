
%%%%%%%%%%%%%%%%%%%%%
%%%%%% Setup %%%%%%%%
clc, clear;
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, '../core')));
addpath(genpath(fullfile(fpath, '../core', 'utils')));
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

parent_path = fullfile(sprintf('%s/Desktop', homedir));
raw_tiff_path = fullfile(parent_path);
extract_path = fullfile(parent_path, 'pipeline/extracted');
registered_path = fullfile(parent_path, 'registered');
segment_path = fullfile(parent_path, 'segmented');
collate_path = fullfile(parent_path, 'collated');

do_extraction = 1;
do_registration = 0;

[img, lab] = convertScanImageTiffToVolume( ...
    raw_tiff_path, ...
    extract_path, ...
    'trim_pixels', [0 0 0 0], ...
    'overwrite', 1 ...
);
