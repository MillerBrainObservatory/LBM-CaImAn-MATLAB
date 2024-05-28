
function motionCorrectPlane(data_path, save_path, varargin)
% MOTIONCORRECTPLANE Perform rigid and non-rigid motion correction on imaging data.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% dataset_name : string, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is 'registration'.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 1).
% num_cores : double, integer, positive
%     Number of cores to use for computation. The value is limited to a maximum
%     of 24 cores.
% start_plane : double, integer, positive
%     The starting plane index for processing.
% end_plane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     start_plane.
%
% Returns
% -------
% shifts : array
%     2D motion vectors as single precision.
%
% Notes
% -----
% - Each motion-corrected plane is saved as a .h5 group containing the 2D
%   shift vectors in x and y
% - Only .h5 files containing processed volumes should be in the file_path.

p = inputParser;
addRequired(p, 'data_path', @ischar);
addRequired(p, 'save_path', @ischar);
addParameter(p, 'dataset_name', "/extraction", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
dataset_name = p.Results.dataset_name;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", data_path); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", data_path);
    save_path = data_path;
end

fig_save_path = fullfile(save_path, "figures");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir(fullfile(data_path, '*.h*'));
if isempty(files)
    error('No suitable data files found in: \n  %s', data_path);
end

log_file_name = sprintf("%s_extraction", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
closeCleanupObj = onCleanup(@() fclose(fid));

%% Pull metadata from attributes attached to this group
num_cores = max(num_cores, 23);
fprintf(fid, '%s Beginning processing routine with %d cores...\n', datetime, num_cores);
for plane_idx = start_plane:end_plane

    fprintf(fid,'%s : BEGINNING PLANE %u\n', datetime("now"), plane_idx);

    z_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s/extracted_%s.h5", data_path, z_str);
    if isfile(plane_name)
        if overwrite
            delete(plane_name)
        end
    end

    h5_data = h5info(plane_name, dataset_name);
    metadata = struct();
    for k = 1:numel(h5_data.Attributes)
        attr_name = h5_data.Attributes(k).Name;
        attr_value = h5readatt(plane_name, sprintf("/%s",h5_data.Name), attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end

    pixel_resolution = metadata.pixel_resolution;
    max_shift = round(20/pixel_resolution);

    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    fprintf(fid, 'Loading plane  %d with %d workers/cores.\n', plane_idx, num_cores);

    Y = h5read(plane_name, dataset_name);
    Y = Y - min(Y(:));
    volume_size = size(Y);
    d1 = volume_size(1);
    d2 = volume_size(2);

    fprintf(fid, '%s Beginning processing for plane %d with %d matlab workers.\n', datetime, plane_idx, num_cores);
    if isempty(gcp('nocreate')) && num_cores > 1
        parpool(num_cores);
    end

    %% Motion correction: Create Template
    options_rigid = NoRMCorreSetParms(...
        'd1',d1,...
        'd2',d2,...
        'bin_width',200,...       % Bin width for motion correction
        'max_shift', max_shift,...        % Max shift in px
        'us_fac',20,...
        'init_batch',200,...     % Initial batch size
        'correct_bidir',false... % Correct bidirectional scanning
        );

    [M1,shifts1,~,~] = normcorre_batch(Y, options_rigid);
    date = datetime("now");
    format_spec = '%s Rigid MC Complete, beginning non-rigid MC...\n';
    fprintf(fid, format_spec, date);

    % create the template using X/Y shift displacements
    shifts_r = squeeze(cat(3,shifts1(:).shifts));
    shifts_v = movvar(shifts_r, 24, 1);
    [srt, minv_idx] = sort(shifts_v, 120);
    best_idx = unique(reshape(minv_idx, 1, []));
    template_good = mean(M1(:,:,best_idx), 3);

    % % Non-rigid motion correction using the good template from the rigid
    options_nonrigid = NoRMCorreSetParms(...
        'd1', d1,...
        'd2', d2,...
        'bin_width', 24,...
        'max_shift', max_shift,...
        'us_fac', 20,...
        'init_batch', 120,...
        'correct_bidir', false...
        );

    % DFT subpixel registration - results used in CNMF
    [M2, shifts2, ~, ~] = normcorre_batch(Y, options_nonrigid, template_good);
    shifts2 = squeeze(cat(3,shifts2(:).shifts));
    shifts_template = squeeze(cat(3,shifts1(:).shifts));

    write_chunk_h5(plane_name, M2, size(z_timeseries,3), '/mov');
    write_chunk_h5(plane_name, shifts2, size(shifts2,2), '/shifts');
    write_chunk_h5(plane_name, shifts_template, size(shifts_template, 2), '/template');

    clear M* c* shifts* template*;

    disp('Data saved, beginning next plane...');
    date = datetime("now");
    format_spec = '%s Motion Correction Complete. Beginning next plane...\n';
    fprintf(fid, format_spec, date);
end

disp('All planes processed...');
t = toc;
disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.']);
date = datetime("now");
format_spec = '%s Routine complete.\n';
fprintf(fid, format_spec, date);
end

function write_dataset(filename, location, data, fid)
try
    h5create(filename, location, size(data), 'DatatypeS', 'single')
catch ME
    if strcmp(ME.identifier, 'MATLAB:imagesci:h5create:datasetAlreadyExists')
        fprintf(fid, "%s : Skipping dataset creation.\n", location);
    else
        rethrow(ME);
    end
end
try
    h5write(filename, location, data);
    fprintf(fid, "%s : Dataset written\n", location);
catch ME
    disp(ME)
end
end
