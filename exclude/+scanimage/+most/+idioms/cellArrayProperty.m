function result=cellArrayProperty(cellArray,propertyName)
    % If you have a cell array of objects, cellArray, get a property from each
    % element, and return them in a cell array of the same size as
    % cellArray.
    result=cellfun(@(element)(element.(propertyName)),cellArray,'UniformOutput',false);
end


%--------------------------------------------------------------------------%
% cellArrayProperty.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
