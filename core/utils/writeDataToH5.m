function writeDataToH5(data, metadata, filePath, datasetPath, nvargs)
% if the file doesnt exist, we know to create both file + dataset
if ~isfile(filePath)
    fprintf("%s does not exist, Creating the h5 file... \n", filePath)
    h5create(filePath, datasetPath, size(data), 'Datatype', 'uint16', ...
     'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression);  
    h5write(filePath, datasetPath, data);
else
    % file exists, check that the dataset exists
    try
        h5create(filePath, datasetPath, size(data), 'Datatype', 'uint16', ...
            'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression); 
        h5write(filePath, datasetPath, data);
    catch ME  % errors if the file does exist
        if nvargs.overwrite == 1
            fprintf('File: %s \n ...with dataset-path: %s already exists, but user input overwrite = 1, writing over the file...', filePath, datasetPath);

            h5write(filePath, datasetPath, data);  % overwrite the data
        else
            fprintf('File: %s \n ...with dataset-path: %s already exists, skipping this file...', filePath, datasetPath);
        end
    end
end

% Write the data to the specified dataset within the group


% Write metadata attributes to the dataset
fields = string(fieldnames(metadata));
for f = fields'
    h5writeatt(filePath, datasetPath, f, metadata.(f));
end


