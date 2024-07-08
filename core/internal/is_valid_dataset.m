function valid = is_valid_dataset(filename, location, num_samples)
% Check if the HDF5 dataset contains valid data.
%
% Query random indexes of dataset to ensure it contains valid data.
%
% Parameters
% ----------
% filename : char
%     The path to the HDF5 file.
% location : char
%     The dataset location within the HDF5 file.
% num_samples : int, optional
%     Number of random samples to check from the dataset. Defaults to 5.
%
% Returns
% -------
% valid : logical
%     Returns true if the dataset contains valid (non-zero) data, otherwise false.
%
% Notes
% -----
% The function checks if the dataset has at least 2 rows and 2 columns.
% It then randomly samples data from the dataset to check for non-zero values.
% If any sample contains a non-zero value, the dataset is considered valid.
% Catches any errors during the process and returns false if an error occurs.

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

