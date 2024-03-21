function removedPaths = removePaths(paths)
removedPaths = {};
for i = 1:length(paths)
    pathi = paths{i};
    pathi = fullfile(pathi,''); % ensure correct formatting
    if most.idioms.isOnPath(pathi);
        rmpath(pathi);
        removedPaths{end+1} = {pathi}; %#ok<AGROW>
    end
end
end


%--------------------------------------------------------------------------%
% removePaths.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
