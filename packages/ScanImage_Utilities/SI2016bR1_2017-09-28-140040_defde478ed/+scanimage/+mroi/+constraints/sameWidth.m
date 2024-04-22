function sameWidth(roigroup,~,scanfield)
    if nargin < 2 || isempty(scanfield)
        sizeX = [];
    else
        sizeX=scanfield.sizeXY(1);
    end

    for roi=roigroup.rois
        for s=roi.scanfields
            if isempty(sizeX)
                sizeX = s.sizeXY(1);
            elseif abs(s.sizeXY(1) - sizeX) > 1e-8
                s.sizeXY(1) = sizeX;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% sameWidth.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
