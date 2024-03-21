function positiveWidth(roigroup,varargin)
    for roi=roigroup.rois
        for s=roi.scanfields
            s.sizeXY(1) = abs(s.sizeXY(1));
        end
    end
end


%--------------------------------------------------------------------------%
% positiveWidth.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
