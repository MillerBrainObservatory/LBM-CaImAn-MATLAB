function result=cellArrayPropertyAsArray(cellArray,propertyName)
    % If you have a cell array of objects, cellArray, get a property from each
    % element, and return them in a non-cell array of the same size as
    % cellArray.  This only works if the property values are thie kind of
    % thing you can stick into a regular array.
    result=cellfun(@(element)(element.(propertyName)),cellArray);
end


%--------------------------------------------------------------------------%
% cellArrayPropertyAsArray.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
