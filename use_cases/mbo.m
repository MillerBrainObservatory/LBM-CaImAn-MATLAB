
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

parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
raw_tiff_path = fullfile(parent_path);
extract_path = fullfile(parent_path);

convertScanImageTiffToVolume( ...
    raw_tiff_path, ...
    extract_path, ...
    'trim_pixels', [6 6 17 0], ...
    'debug', 1, ...
    'overwrite', 1 ...
);

mc_path = fullfile(parent_path, "registration");
motionCorrectPlane( ...
    extract_path, ... % we used this to save extracted data
    mc_path, ... % save registered data here
    'overwrite', 1, ...
    'do_figures', 1 ...
);
