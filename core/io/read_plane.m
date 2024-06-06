function Y_out = read_plane(folder, dataset_name, plane_number, frames)
    % READ_PLANE Reads the specified frames from a dataset in a folder or file.
    %
    % Parameters
    % ----------
    % folder : char
    %     Path to the folder containing the plane files or the file itself.
    % dataset_name : char
    %     Name of the dataset to read.
    % plane_number : int
    %     The plane number to read.
    % frames : array
    %     Frames to read from the dataset (e.g., 1:100).
    %
    % Returns
    % -------
    % Y_out : array
    %     The requested 3D planar dataset.
    
    if isfolder(folder)
        files = dir(fullfile(folder, '*_plane_*.h5'));
        if isempty(files)
            error('No plane files found in the given folder: %s', folder);
        end
        plane_file = fullfile(folder, files(plane_number).name);
    elseif isfile(folder)
        plane_file = folder;
    else
        error('Invalid input. Must be a valid folder or file.');
    end

    data_info = h5info(plane_file, dataset_name);
    data_size = data_info.Dataspace.Size;
    
    if length(frames) > data_size(end)
        error('Requested frames exceed the available frames in the dataset.');
    end
    
    slice_start = [ones(1, numel(data_size) - 1), frames(1)];
    slice_count = [data_size(1:end-1), length(frames)];

    Y_out = h5read(plane_file, dataset_name, slice_start, slice_count);
end
