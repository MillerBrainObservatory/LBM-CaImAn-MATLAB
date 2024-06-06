
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

log_file_name = sprintf("%s_correction", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
% closeCleanupObj = onCleanup(@() fclose(fid));

%% Pull metadata from attributes attached to this group
num_cores = max(num_cores, 23);
fprintf(fid, '%s : Beginning registration with %d cores...\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), num_cores); tall=tic;
for plane_idx = start_plane:end_plane
    fprintf(fid, '%s : Beginning plane %d\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_idx);

    z_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s/extracted_%s.h5", data_path, z_str);
    plane_name_save = sprintf("%s/motion_corrected_%s.h5", save_path, z_str);
    if isfile(plane_name_save)
        fprintf(fid, '%s : %s already exists.\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        if overwrite
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
            delete(plane_name_save)
        end
    end

    h5_data = h5info(plane_name, dataset_name);
    metadata = struct();
    for k = 1:numel(h5_data.Attributes)
        attr_name = h5_data.Attributes(k).Name;
        attr_value = h5readatt(plane_name, sprintf("/%s",h5_data.Name), attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end

    if isempty(gcp('nocreate')) && num_cores > 1
        parpool(num_cores);
    end

    pixel_resolution = metadata.pixel_resolution;
    max_shift = round(20/pixel_resolution);

    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    Y = h5read(plane_name, dataset_name);
    Y = Y - min(Y(:));
    volume_size = size(Y);
    d1 = volume_size(1);
    d2 = volume_size(2);

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

    % start timer for registration after parpool to avoid inconsistent
    % pool startup times.
    t_rigid=tic;
    [M1,shifts_template,~,~] = normcorre_batch(Y, options_rigid);
    fprintf(fid, "%s : Rigid registration complete. Elapsed time: %.3f minutes\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(t_rigid)/60);

    % create the template using X/Y shift displacements
    shifts_template = squeeze(cat(3,shifts_template(:).shifts));
    shifts_v = movvar(shifts_template, 24, 1);
    [~, minv_idx] = sort(shifts_v, 120);
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
    t_nonrigid=tic;
    fprintf(fid, "%s : Non-rigid registration complete. Elapsed time: %.3f minutes\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(t_nonrigid)/60);
    [M2, shifts_nr, ~, ~] = normcorre_batch(Y, options_nonrigid, template_good);
    shifts_nr = squeeze(cat(3,shifts_nr(:).shifts));
    t_save=tic;

    write_chunk_h5(plane_name_save, M2, size(M2,3), '/mov');
    write_chunk_h5(plane_name_save, shifts_nr, size(shifts_nr,2), '/shifts');
    write_chunk_h5(plane_name_save, shifts_template, size(shifts_template,2), '/template');
    write_metadata_h5(metadata, plane_name_save, '/mov');
    fprintf(fid, "%s : Data saved. Elapsed time: %.2f seconds\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(t_save)/60);

    clear M1 M2 shifts template;
    try
        fprintf(fid, "%s : Motion correction for plane %d complete. Time: %.2f minutes. Beginning next plane...\n", datestr(datetime('now'), 'yyyy_mm_dd HH:MM:SS'), plane_idx, toc(t_rigid)/60);
    catch ME
        warning("File ID, no longer valid: %d", fid);
        return;
    end
fprintf(fid, "%s : Processing complete. Time: %.2f hours\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(tall)/3600);
end