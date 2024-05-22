
function motionCorrectPlane(data_path, save_path, varargin)
% MOTIONCORRECTPLANE Perform rigid and non-rigid motion correction on imaging data.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% data_input_group : string, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is 'registration'.
% data_output_group : string, optional
%     Group path within the hdf5 file to save the registered data.
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
% - Each motion-corrected plane is saved as a .hdf5 group containing the 2D
%   shift vectors in x and y
% - Only .h5 files containing processed volumes should be in the file_path.

p = inputParser;
addRequired(p, 'data_path', @ischar);
addRequired(p, 'save_path', @ischar);
addParameter(p, 'data_input_group', "/extraction", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addParameter(p, 'data_output_group', "/registration", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x) && x > 0 && x <= 24);
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
data_input_group = p.Results.data_input_group;
data_output_group = p.Results.data_output_group;

debug_flag = p.Results.debug_flag;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
overwrite = p.Results.overwrite;

clck = clock; % Generate a timestamp for the log file name.
log_file_name = sprintf('registration_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
log_full_path = fullfile(data_path, log_file_name);
fid = fopen(log_full_path, 'w');
close_cleanup_obj = onCleanup(@() fclose(fid));

if isempty(save_path)
    save_path = data_path;
end

data_path = fullfile(data_path);
if ~isfolder(data_path)
    error("Filepath %s does not exist", data_path);
end

if ~isfolder(save_path)
    fprintf('Given savepath %s does not exist. Creating this directory...\n', save_path);
    mkdir(save_path);
end

fig_save_path = fullfile(save_path, 'metrics');
if ~isfolder(fig_save_path)
    mkdir(fig_save_path);
end

if debug_flag == 1
    dir([data_path, '*.tif']);
    return;
end

files = dir(fullfile(data_path, '*.h5'));
if isempty(files)
    error('No suitable h5 files found in: \n  %s', data_path);
end

h5_fullfile = fullfile(files(1).folder, files(1).name);

%% Pull metadata from attributes attached to this group
h5_data = h5info(h5_fullfile, data_input_group);
metadata = struct();
for k = 1:numel(h5_data.Attributes)
    attr_name = h5_data.Attributes(k).Name;
    attr_value = h5readatt(h5_fullfile, h5_data.Name, attr_name);
    metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
end

dataset_paths = {'shifts2', 'Y', 'shifts1'};

% keep track of dataset paths and their corresponding names
dataset_map = containers.Map();
dataset_map('shifts2') = 'shifts2';
dataset_map('Y') = 'Y';
dataset_map('shifts1') = 'shifts1';

% poolobj = gcp('nocreate');
% if ~isempty(poolobj)
%     disp('Removing existing parallel pool.');
%     delete(poolobj);
% end
num_cores = max(num_cores, 23);
fprintf(fid, '%s Beginning processing routine with %d cores...\n', datetime, num_cores);
plane_map = dictionary; tic; 
for plane_idx = 1:metadata.num_planes
    pst = sprintf('plane_%d', plane_idx);
    input_path = sprintf('%s/%s', data_input_group, pst);
    registration_path = sprintf('%s/%s', data_output_group, pst);
    skip_plane = false;
    for i = 1:length(dataset_paths)
        dataset_name = dataset_paths{i};
        dataset_path = sprintf('%s/%s', registration_path, dataset_name);
        if check_dataloc_exists(h5_fullfile, dataset_path)
            if overwrite == 0
                fprintf(fid, 'Dataset %s for plane %d already exists. Skipping.\n', dataset_name, plane_idx);
                skip_plane = true;
                break; % Exit the dataset loop
            else
                fprintf(fid, 'Dataset %s for plane %d already exists. Proceeding...\n', dataset_name, plane_idx);
            end
        else
            fprintf(fid, 'Creating dataset %s for plane %d.\n', dataset_name, plane_idx);
            % Create the dataset with the correct size
            % Assuming h5_data.Datasets(i).Dataspace.Size contains the size
            h5create(h5_fullfile, dataset_path, h5_data.Datasets(i).Dataspace.Size, 'Datatype', 'single');
        end
    end
    if skip_plane
        continue; % skip to next iteration of plane_idx loop
    end
    
    shifts_path =  sprintf('%s/shifts2', registration_path);
    movie_path =  sprintf('%s/Y', registration_path);
    template_shifts_path =  sprintf('%s/shifts1', registration_path);
   
    pixel_resolution = metadata.pixel_resolution;
    max_shift = round(20/pixel_resolution);

    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    fprintf(fid, 'Loading plane  %d with %d workers/cores.\n', plane_idx, num_cores);

    Y = h5read(h5_fullfile, input_path);
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
    date = datetime(now,'ConvertFrom','datenum');
    format_spec = '%s Rigid MC Complete, beginning non-rigid MC...\n';
    fprintf(fid, format_spec, date);

    % create the template using X/Y shift displacements
    shifts_r = squeeze(cat(3,shifts1(:).shifts));
    shifts_v = movvar(shifts_r, 24, 1);
    [srt, minv_idx] = sort(shifts_v, 120);
    best_idx = unique(reshape(minv_idx, 1, []));
    template_good = mean(M1(:,:,best_idx), 3);
    % 
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
    % 
    % % DFT subpixel registration - results used in CNMF
    [M2, shifts2, ~, ~] = normcorre_batch(Y, options_nonrigid, template_good);
    % 
    % save_name = sprintf('registered_%s.mat', pst);
    % metrics_save_name = sprintf('metrics_%s.fig', pst);
    % 
    % full_save_path = fullfile(save_path, save_name);
    % full_metrics_save_path = fullfile(fig_save_path, metrics_save_name);
    % 
    % fprintf('Saving registration results in directory: \n \n %s \n', full_save_path);
    % 
    

    % disp('Calculating motion correction metrics...');
    % 
    % shifts_r = squeeze(cat(3,shifts1(:).shifts));
    % [cY, aa, bb] = motion_metrics(Y, 10);
    % [cM1, cc, dd] = motion_metrics(M1, 10);
    % [cM2, rr, oo] = motion_metrics(M2, 10);
    
    % motion_correction_figure = figure;
    % T = size(Y, 3);
    % 
    % ax1 = subplot(311); plot(1:T, cY, 1:T, cM1, 1:T, cM2); legend('raw data', 'rigid', 'non-rigid'); title('correlation coefficients', 'fontsize', 14, 'fontweight', 'bold')
    % set(gca, 'Xtick', [])
    % ax2 = subplot(312); %plot(shifts_x); hold on; 
    % plot(shifts_r(:,1), '--k', 'linewidth', 2); title('displacements along x', 'fontsize', 14, 'fontweight', 'bold')
    % set(gca, 'Xtick', [])
    % ax3 = subplot(313); 
    % plot(shifts_r(:,2), '--k', 'linewidth', 2); title('displacements along y', 'fontsize', 14, 'fontweight', 'bold')
    % xlabel('timestep', 'fontsize', 14, 'fontweight', 'bold')
    % linkaxes([ax1, ax2, ax3], 'x')

    % Ym = mean(Y, 3);
    % save(full_save_path, 'Y', 'Ym', 'shifts_r', 'M1', 'shifts1', "-v7.3");
    write_dataset(h5_fullfile, [registration_path, '/Y'], Y, fid);
    write_dataset(h5_fullfile, [registration_path, '/shifts1'], shifts1, fid);
    write_dataset(h5_fullfile, [registration_path, '/shifts2'], shifts2, fid);

    % saveas(motion_correction_figure, full_metrics_save_path);
    % close(motion_correction_figure);
    clear M* c* template_good shifts*;

    disp('Data saved, beginning next plane...');
    date = datetime(now,'ConvertFrom','datenum');
    format_spec = '%s Motion Correction Complete. Beginning next plane...\n';
    fprintf(fid, format_spec, date);
end

disp('All planes processed...');
t = toc;
disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.']);
date = datetime(now,'ConvertFrom','datenum');
format_spec = '%s Routine complete.\n';
fprintf(fid, format_spec, date);
end

function close_log_file(fid)
    fclose(fid);
end

% Custom function to validate and adjust group_path
function valid = isValidGroupPath(x)
    if startsWith(x, '/')
        x = char(x);
        if endsWith(x, '/')
            x = x(1:end-1);
        end
        valid = true;
        % Adjust the group_path in the input parser
        p.Results.group_path = string(x);
    else
        error('group_path must start with a leading /.');
    end
end

function write_dataset(filename, location, data, fid)
    try
        h5create(filename, location, size(data), 'Datatype', 'single')
    catch ME
        if strcmp(ME.identifier, 'MATLAB:imagesci:h5create:datasetAlreadyExists')
            fprintf(fid, 'Dataset %s already exists. Skipping creation.\n', location);
        else
            rethrow(ME);
        end
    end
    try
        h5write(filename, location, data);
    catch ME
        disp(ME)
    end
end
function exists = check_dataloc_exists(filename, location)
    try
        h5info(filename, location);
        exists = true;
    catch
        exists = false;
    end
end
