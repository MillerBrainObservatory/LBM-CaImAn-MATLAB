function xCenterInRange(roigroup,scannerset,sf)
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
        if isa(scannerset, 'scanimage.mroi.scannerset.ResonantGalvoGalvo')
            xGalvoRg = scannerset.scanners{2}.travelRange + scannerset.fovCenterPoint(1);
            
            if sc.centerXY(1) - xGalvoRg(2) > 0.000001
                sc.centerXY(1) = xGalvoRg(2);
            elseif sc.centerXY(1) - xGalvoRg(1) < 0.000001
                sc.centerXY(1) = xGalvoRg(1);
            end
        end
        
        xSorted = sort(scannerset.fovCornerPoints(:,1));
        ssLeft = mean(xSorted(1:2));
        ssRight = mean(xSorted(3:4));
        
        if isa(sc, 'scanimage.mroi.scanfield.fields.StimulusField') && sc.isPoint
            hsz = 0;
        else
            hsz = sc.sizeXY(1)/2;
        end
        
        lft = sc.centerXY(1)-hsz;
        rgt = sc.centerXY(1)+hsz;
        
        if min([lft rgt]) < ssLeft
            sc.centerXY(1) = ssLeft + hsz;
        elseif max([lft rgt]) > ssRight
            sc.centerXY(1) = ssRight - hsz;
        end
    end
end



%--------------------------------------------------------------------------%
% xCenterInRange.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
