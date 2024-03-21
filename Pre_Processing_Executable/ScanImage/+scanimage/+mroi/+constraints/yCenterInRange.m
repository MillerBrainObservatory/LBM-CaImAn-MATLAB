function yCenterInRange(roigroup,scannerset,sf)
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
        ySorted = sort(scannerset.fovCornerPoints(:,2));
        ssTop = mean(ySorted(1:2));
        ssBot = mean(ySorted(3:4));
        
        if isa(sc, 'scanimage.mroi.scanfield.fields.StimulusField') && sc.isPoint
            hsz = 0;
        else
            hsz = sc.sizeXY(2)/2;
        end
        
        top = sc.centerXY(2)-hsz;
        bot = sc.centerXY(2)+hsz;
        
        if min([top bot]) < ssTop
            sc.centerXY(2) = ssTop + hsz;
        elseif max([top bot]) > ssBot
            sc.centerXY(2) = ssBot - hsz;
        end
    end
end


%--------------------------------------------------------------------------%
% yCenterInRange.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
