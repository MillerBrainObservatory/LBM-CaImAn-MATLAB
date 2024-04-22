function maxHeight(roigroup,scannerset,sf)
    if isempty(sf)
        for roi=roigroup.rois
            for s=roi.scanfields
                constr(s);
            end
        end
    else
        constr(sf);
    end

    function constr(sc)
        if (abs(sc.sizeXY(2)) - abs(scannerset.angularRange(2))) > 1e-8
            sc.sizeXY(2) = scannerset.angularRange(2);
        end
    end
end


%--------------------------------------------------------------------------%
% maxHeight.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
