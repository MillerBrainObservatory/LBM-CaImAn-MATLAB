function Y_out = read_plane(folder, dataset_name, plane_number, frames)
% READ_PLANE Reads the specified frames from a dataset in a folder or file.
folder_selected = nargin >= 1 && ~isempty(folder);
dataset_name_selected = nargin >= 2 && ~isempty(dataset_name);
plane_selected = nargin >= 3 && ~isempty(plane_number);
frames_selected = nargin >= 4 && ~isempty(frames);

while true
    try
        if ~folder_selected
            folder = uigetdir('', 'Select Folder Containing Plane Files');
            if folder == 0
                error('No folder selected.');
            end
            folder_selected = true;
        end

        if isfolder(folder)
            try
            files = dir(fullfile(folder, '*_plane_*.h5'));
            if isempty(files)
                error('No plane files found in the given folder: %s', folder);
            end
            if ~plane_selected 
                plane_number = input(sprintf('Please enter the plane number (1:%d): ', numel(files)));
                if plane_number < 1 || plane_number > numel(files)
                    error('Invalid plane number.');
                end
                plane_selected = true;
            end
            if ischar(plane_number); plane_number = str2double(plane_number); end
            if plane_number > numel(files)
                error("The given plane (%d) exceeds the number of planes found in this folder: %d\n", plane_number, numel(files));
            end
            plane_file = fullfile(folder, files(plane_number).name);
            catch ME
            end
        elseif isfile(folder)
            plane_file = folder;
        else
            error('Invalid input. Must be a valid folder or file.');
        end

        if ~dataset_name_selected
            dataset_name = input('Please enter the dataset name (e.g. /mov): ', 's');
            dataset_name_selected = true;
        end

        data_info = h5info(plane_file, dataset_name);
        data_size = data_info.Dataspace.Size;

        if ~frames_selected || max(frames) > data_size(end)
            frames = input(sprintf('Please enter the frames to read (1:%d): ', data_size(end)));
            if max(frames) > data_size(end)
                error('Frames exceed the available range.');
            end
            frames_selected = true;
        end

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
        elseif contains(ME.message, 'frames')
            frames_selected = false;
        elseif contains(ME.message, 'plane')
            plane_selected = false;
        elseif contains(ME.message, 'array')
            plane_selected = false;
        elseif contains(ME.message, 'element')
            plane_selected = false;

        else
            fprintf('Press Ctrl+C to exit or enter new values.\n');
        end
    end
end
end
