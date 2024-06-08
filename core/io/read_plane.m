function Y_out = read_plane(folder, dataset_name, plane_number, frames)
% READ_PLANE Reads the specified frames from a dataset in a folder or file.
%
% Parameters
% ----------
% folder : char (optional)
%     Path to the folder containing the plane files or the file itself.
% dataset_name : char (optional)
%     Name of the dataset to read.
% plane_number : int (optional)
%     The plane number to read.
% frames : array (optional)
%     Frames to read from the dataset (e.g., 1:100).
%
% Returns
% -------
% Y_out : array
%     The requested 3D planar dataset.

% Initialize selection flags
folder_selected = nargin >= 1 && ~isempty(folder);
dataset_name_selected = nargin >= 2 && ~isempty(dataset_name);
plane_selected = nargin >= 3 && ~isempty(plane_number);
frames_selected = nargin >= 4 && ~isempty(frames);

while true
    try
        % Prompt for folder if not provided or invalid
        if ~folder_selected
            folder = uigetdir('', 'Select Folder Containing Plane Files');
            if folder == 0  % User clicked cancel
                error('No folder selected.');
            end
            folder_selected = true;
        end

        % Check if the folder is a directory or a file
        if isfolder(folder)
            files = dir(fullfile(folder, '*_plane_*.h5'));
            if isempty(files)
                error('No plane files found in the given folder: %s', folder);
            end
            if ~plane_selected || plane_number > numel(files)
                plane_number = input('Please enter the plane number: ');
                plane_selected = true;
            end
            plane_file = fullfile(folder, files(plane_number).name);
        elseif isfile(folder)
            plane_file = folder;
        else
            error('Invalid input. Must be a valid folder or file.');
        end

        % Prompt for dataset_name if not provided or invalid
        if ~dataset_name_selected
            dataset_name = input('Please enter the dataset name (e.g. /mov): ', 's');
        end

        % Check if the dataset exists
        try
            data_info = h5info(plane_file, dataset_name);
        catch
            fprintf('Dataset "%s" not found in file "%s".\n', dataset_name, plane_file);
            root_info = h5info(plane_file, '/');
            fprintf('Available datasets at root "/":\n');
            for i = 1:length(root_info.Datasets)
                ds = root_info.Datasets(i);
                fprintf('Name: %s, Size: [%s], Datatype: %s\n', ...
                    ds.Name, num2str(ds.Dataspace.Size), ds.Datatype.Class);
            end
            dataset_name = input('Please enter a valid dataset name: ', 's');
            dataset_name_selected = false;  % Set flag to re-prompt dataset name
            continue;  % Skip remaining checks and retry
        end

        % If dataset exists, continue with processing
        data_size = data_info.Dataspace.Size;
        dataset_name_selected = true;

        % Prompt for frames if not provided or invalid
        if ~frames_selected || max(frames) > data_size(end)
            frames = input('Please enter the frames to read (e.g., 1:100): ');
            frames_selected = true;
        end

        % Read the specified frames
        slice_start = [ones(1, numel(data_size) - 1), frames(1)];
        slice_count = [data_size(1:end-1), length(frames)];

        Y_out = h5read(plane_file, dataset_name, slice_start, slice_count);
        break;

    catch ME
        fprintf('\nError: %s\n', ME.message);

        if strcmp(ME.identifier, 'MATLAB:imagesci:h5info:libraryError')
            fprintf('Dataset "%s" not found in file "%s".\n', dataset_name, plane_file);
            root_info = h5info(plane_file, '/');
            fprintf('Available datasets at root "/":\n');
            for i = 1:length(root_info.Datasets)
                ds = root_info.Datasets(i);
                fprintf('Name: %s, Size: [%s], Datatype: %s\n', ...
                    ds.Name, num2str(ds.Dataspace.Size), ds.Datatype.Class);
            end
            dataset_name_selected = false;
        elseif contains(ME.message, 'No plane files found')
            folder_selected = false;
        elseif contains(ME.message, 'Invalid input')
            folder_selected = false;
        elseif contains(ME.message, 'exceed the available frames')
            frames_selected = false;
        elseif contains(ME.message, 'Invalid plane number')
            plane_selected = false;
        else
            fprintf('Press Ctrl+C to exit or enter new values.\n');
        end
    end
end
end
