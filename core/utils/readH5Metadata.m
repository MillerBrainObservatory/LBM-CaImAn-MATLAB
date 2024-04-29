function metadata = readH5Metadata(filePath, datasetPath)
    if ~isfile(filePath)
        error('File does not exist: %s', filePath);
    end
    try
        datasetInfo = h5info(filePath, datasetPath);
    catch
        error('Dataset does not exist at path: %s', datasetPath);
    end
    metadata = struct();
    for k = 1:length(datasetInfo.Attributes)
        attrName = datasetInfo.Attributes(k).Name;
        attrValue = h5readatt(filePath, datasetPath, attrName);
        metadata.(matlab.lang.makeValidName(attrName)) = attrValue;
    end
end