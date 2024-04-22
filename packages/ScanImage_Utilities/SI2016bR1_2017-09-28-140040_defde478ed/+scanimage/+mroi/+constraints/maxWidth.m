function maxWidth(roigroup,scannerset,sf)
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
        if isa(scannerset, 'scanimage.mroi.scannerset.ResonantGalvoGalvo') && ~scannerset.resonantLimitedFovMode
            resW = scannerset.scanners{1}.fullAngleDegrees * scannerset.fillFractionSpatial;
            if (sc.sizeXY(1) - resW) > 0.00000001;
                sc.sizeXY(1) = resW;
            end
        else
            mW = scannerset.fillFractionSpatial * scannerset.angularRange(1);
            if sc.sizeXY(1) > (1.00000001 * mW)
                sc.sizeXY(1) = mW;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% maxWidth.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
