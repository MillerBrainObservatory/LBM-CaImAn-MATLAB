function positiveWidth(roigroup,varargin)
    for roi=roigroup.rois
        for s=roi.scanfields
            s.sizeXY(1) = abs(s.sizeXY(1));
        end
    end
end


%--------------------------------------------------------------------------%
% positiveWidth.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
