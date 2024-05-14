% function metadata = readH5Metadata(filePath, datasetPath)
%     if ~isfile(filePath)
%         error('File does not exist: %s', filePath);
%     end
%     try
%         datasetInfo = h5info(filePath, datasetPath);
%     catch
%         error('Dataset does not exist at path: %s', datasetPath);
%     end
%     metadata = struct();
%     for k = 1:length(datasetInfo.Attributes)
%         attrName = datasetInfo.Attributes(k).Name;
%         attrValue = h5readatt(filePath, datasetPath, attrName);
%         metadata.(matlab.lang.makeValidName(attrName)) = attrValue;
%     end
% end

function metadata = readH5Metadata(h5FilePath)
    info = h5info(h5FilePath);
    metadata = processGroup(info);
end

function groupData = processGroup(groupInfo)
    groupData = struct('Name', groupInfo.Name, 'Datasets', [], 'Groups', []);
    
    % datasets
    for i = 1:length(groupInfo.Datasets)
        datasetName = groupInfo.Datasets(i).Name;
        groupData.Datasets = [groupData.Datasets; {datasetName}];
    end
    
    % subgroups
    for i = 1:length(groupInfo.Groups)
        subGroup = groupInfo.Groups(i);
        groupData.Groups = [groupData.Groups; processGroup(subGroup)];
    end
end