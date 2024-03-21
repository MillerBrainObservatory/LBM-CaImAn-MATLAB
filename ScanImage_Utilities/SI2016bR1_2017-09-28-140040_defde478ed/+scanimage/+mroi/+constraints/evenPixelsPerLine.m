function evenPixelsPerLine(roigroup,~,~)

for roi=roigroup.rois
    for s=roi.scanfields
        if ~isa(s,'scanimage.mroi.scanfield.ImagingField');
            return
        end
        if isprop(s,'pixelResolution')
            res = s.pixelResolutionXY;
            mds = logical(mod(res,2));
            if any(mds)
                s.pixelResolutionXY(mds) = res(mds) + 1;
            end
        end
    end
end

end


%--------------------------------------------------------------------------%
% evenPixelsPerLine.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
