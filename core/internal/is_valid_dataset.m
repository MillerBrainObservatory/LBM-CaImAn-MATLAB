function valid = is_valid_dataset(filename, location, num_samples)
	% Query random indexes of dataset to ensure it contains valid data.
    if ~exist("n_samples", "var"); num_samples = 5; end
    try
        info = h5info(filename, location);
        dataset_size = info.Dataspace.Size;
        num_dims = numel(dataset_size);

        if dataset_size(1) < 2 || dataset_size(2) < 2
            valid = false;
            return;
        end

        % sample last index
        rng('shuffle');
        sample_indices = randperm(dataset_size(1), num_samples);

        if num_dims == 1
            data = h5read(filename, location, sample_indices, ones(1, num_samples));
        else
            data = h5read(filename, location, [sample_indices(1), ones(1, num_dims - 1)], [num_samples, dataset_size(2:end)]);
        end
        valid = any(data(:) ~= 0);

    catch
        valid = false;
    end
end

