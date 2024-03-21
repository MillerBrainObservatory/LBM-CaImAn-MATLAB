function addedPaths = addPaths(paths)
assert(iscell(paths),'Input needs to be a cell array of strings');

addedPaths = {};
for i = 1:length(paths)
    pathi = paths{i};
    pathi = fullfile(pathi,''); % ensure correct formatting
    if ~most.idioms.isOnPath(pathi)
        addpath(pathi);
        addedPaths{end+1} = pathi; %#ok<AGROW>
    end
end

end


%--------------------------------------------------------------------------%
% addPaths.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
