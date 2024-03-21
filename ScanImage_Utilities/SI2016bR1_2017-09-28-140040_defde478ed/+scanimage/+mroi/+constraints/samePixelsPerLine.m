function samePixelsPerLine(roigroup,~,scanfield)
if ~isa(scanfield,'scanimage.mroi.scanfield.ImagingField');
    return
end
if nargin < 2 || isempty(scanfield)
    pixelsPerLine = [];
else
    if isprop(scanfield,'pixelResolution')
        pixelsPerLine=scanfield.pixelResolutionXY(1);
    else
        pixelsPerLine = [];
    end
end

for roi=roigroup.rois
    for s=roi.scanfields
        if isprop(s,'pixelResolution')
            if isempty(pixelsPerLine)
                pixelsPerLine = s.pixelResolutionXY(1);
            elseif s.pixelResolutionXY(1)~=pixelsPerLine
                s.pixelResolutionXY(1)=pixelsPerLine;
            end
        end
    end
end

end


%--------------------------------------------------------------------------%
% samePixelsPerLine.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
