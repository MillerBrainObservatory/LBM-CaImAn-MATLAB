function [tf,pt] = isMouseInAxes(hAx,pt)
    if nargin<2 || isempty(pt)
        pt = hAx.CurrentPoint(1,1:2);
    end
    xLim = hAx.XLim;
    yLim = hAx.YLim;
    tf = pt(1)>=xLim(1) && pt(1)<=xLim(2) && ...
         pt(2)>=yLim(1) && pt(2)<=yLim(2);
end

%--------------------------------------------------------------------------%
% isMouseInAxes.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
