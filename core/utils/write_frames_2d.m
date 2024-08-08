function write_frames_2d(filename, data, dataset_name, overwrite, append)
    % get the size of the data
    [dim1, dim2] = size(data);
    
    if ~isfile(filename) || overwrite
        % create the dataset with unlimited dimensions for appending
        h5create(filename, dataset_name, [dim1 Inf], 'ChunkSize', [dim1 dim2]);
        h5write(filename, dataset_name, data, [1, 1], [dim1, dim2]);
    else
        % check if the dataset exists
        info = h5info(filename);
        dataset_exists = any(strcmp({info.Datasets.Name}, dataset_name(2:end))); % remove leading '/'
        
        if dataset_exists && append
            % get the current size of the dataset
            dset_info = h5info(filename, dataset_name);
            current_size = dset_info.Dataspace.Size;
            % calculate the start index for appending data
            start_index = current_size(2) + 1;
            % write the data to the extended part
            h5write(filename, dataset_name, data, [1, start_index], [dim1, dim2]);
        elseif ~dataset_exists
            % create a new dataset in the existing file with unlimited dimensions
            h5create(filename, dataset_name, [dim1 Inf], 'ChunkSize', [dim1 dim2]);
            h5write(filename, dataset_name, data, [1, 1], [dim1, dim2]);
        else
            % overwrite the existing dataset
            h5write(filename, dataset_name, data, [1, 1], [dim1, dim2]);
        end
    end
end
