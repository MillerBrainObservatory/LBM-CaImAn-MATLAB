function writePlaneH5(frames,folder,filename,metadata,nvargs)
%%
arguments
	frames		{mustBeA(frames,"uint16")}
	folder		(1,1)	string	{mustBeFolder}
	filename	(1,1)	string	% File name
	metadata	(1,1)	struct	% Struct containing metadata values
	nvargs.dataset		(1,1)	string	= "/Y"
	nvargs.chunksize	(1,:)	double	= [height(frames), width(frames), 1]
	nvargs.compression	(1,1)	double	= 0
end
%% Set file paths
filename = regexprep(filename,"(?i)(\.h5)?$",".h5");
temp_path = tempname(folder)+".h5";		% Temporary file
final_path = fullfile(folder,filename);	% Desired final filename
%% Do some extra validation checks
assert(ndims(frames)==3, "Input frames must be 3D array")
% Throw an error if the destination path already exists
assert(~isfile(final_path), compose("File %s already exists",final_path))
%% Create h5 file
h5create(...
	temp_path ...
	, nvargs.dataset ...
	, size(frames) ...
	, datatype	= "int16" ...
	, chunksize	= nvargs.chunksize ...
	, deflate	= nvargs.compression ...
	);
%% write frames
h5write(temp_path, nvargs.dataset, frames);
%% Write metadata
metadata_fields = string(fieldnames(metadata));
for f = metadata_fields(:).'
	h5writeatt(temp_path, nvargs.dataset, f, metadata.(f));
end
%% Now rename the file to the actual desired filename
movefile(temp_path,final_path);
%%
end