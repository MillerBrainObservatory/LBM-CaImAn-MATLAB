function writeDataToH5(data, filePath, datasetPath, nvargs, metadata)
    try
        info = h5info(filepath, datasetPath);
    catch
       fprintf("%s doesnt exists, creating...\n", datasetPath);
       h5create(filePath, datasetPath, size(data), 'Datatype', 'uint16', ...
         'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression);
    end
   
    % Write the data to the specified dataset within the group
    h5write(filePath, datasetPath, data);

    % Write metadata attributes to the dataset
    fields = string(fieldnames(metadata));
    for f = fields'
        h5writeatt(filePath, datasetPath, f, metadata.(f));
    end
end

