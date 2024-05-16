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
