function h5savevalue(fileID, dataset, fileType, value, dataspaceID, memtype)
%H5SAVEVALUE Create an H5 dataset and write the value.

if nargin < 5 || isempty(dataspaceID)
    if isempty(value)
        dims = [1 1];
    else
        dims = size(value);
    end
    
    dataspaceID = H5S.create_simple(2, fliplr(dims), []);
end

datasetID = H5D.create(fileID, dataset, fileType, dataspaceID, 'H5P_DEFAULT');

if ~isempty(value)
    if nargin < 6
        memtype = 'H5ML_DEFAULT';
    end
    H5D.write(datasetID, memtype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', value);
end

H5D.close(datasetID);
H5S.close(dataspaceID);


%--------------------------------------------------------------------------%
% h5savevalue.m                                                            %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
