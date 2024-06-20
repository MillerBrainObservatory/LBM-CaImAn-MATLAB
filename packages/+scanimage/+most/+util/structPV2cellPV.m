function cellpv = structPV2cellPV(structpv)

flds = fieldnames(structpv);
vals = struct2cell(structpv);

cellpv = [flds(:)'; vals(:)'];
cellpv = cellpv(:);

end


%--------------------------------------------------------------------------%
% structPV2cellPV.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
