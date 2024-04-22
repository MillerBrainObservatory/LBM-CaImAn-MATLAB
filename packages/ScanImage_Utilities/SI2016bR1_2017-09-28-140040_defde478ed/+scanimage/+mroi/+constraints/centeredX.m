function centeredX(roigroup,scannerset,sf)
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
        if abs(sc.centerXY(1) - scannerset.fovCenterPoint(1)) > 1e-8
            sc.centerXY(1) = scannerset.fovCenterPoint(1); 
        end
    end
end


%--------------------------------------------------------------------------%
% centeredX.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
