function h5save(file, dataset, value, useCreate)

if nargin < 4
    useCreate = false;
end

if ischar(file)
    if useCreate
        fileID = H5F.create(file, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
    else
        fileID = H5F.open(file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    end
    c = onCleanup(@()H5F.close(fileID));
else
    fileID = file;
end

if isstruct(value)
    most.fileutil.h5savestruct(fileID, dataset, value);
elseif isnumeric(value)
    if  most.idioms.isenum(value)
        value = double(value);
    end
    most.fileutil.h5savedouble(fileID, dataset, value);
elseif islogical(value)
    most.fileutil.h5savedouble(fileID, dataset, double(value));
elseif ischar(value)
    most.fileutil.h5savestr(fileID, dataset, value);
elseif iscellstr(value)
    most.fileutil.h5savestr(fileID, dataset, char(value));
elseif isobject(value) && ismethod(value,'h5save') ,
    % If it's an object that knows how to save itself to HDF5, use the
    % method
    value.h5save(fileID, dataset);    
else
    %With stack traces turned off, finding this was non-trivial, so make sure to identify the code throwing the warning. - TO022114A
    most.mimics.warning('most:h5:unsuporteddatatype', 'h5save - Unsupported data type: %s', class(value));
end

end  % function


%--------------------------------------------------------------------------%
% h5save.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
