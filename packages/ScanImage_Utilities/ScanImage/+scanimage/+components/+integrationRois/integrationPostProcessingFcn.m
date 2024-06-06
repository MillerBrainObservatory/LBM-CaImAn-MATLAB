function integrationValues = integrationPostProcessingFcn(rois,integrationDone,arrayIndices,integrationValueHistory,integrationTimestampHistory,integrationFrameNumberHistory)
% This function is used to post process integration values
% standard behavior: pass the integration values through without changing the calculated values
integrationValues = integrationValueHistory(arrayIndices);
end

%--------------------------------------------------------------------------%
% integrationPostProcessingFcn.m                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
