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

%% Here you can validate that all dependencies are on the path and accessible from within this pipeline.
% This does not check for package access on your path.

result = validate_toolboxes();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

parent_path = fullfile('C:\Users\RBO\Documents\data\david');
data_path = fullfile(parent_path, "raw");
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
