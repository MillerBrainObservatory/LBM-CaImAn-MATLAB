function tf = mouseOnObj(hObj,mousePtPx)

if nargin<2 || isempty(mousePtPx)
    hFig = ancestor(hObj,'figure');
    units_ = hFig.Units;
    hFig.Units = 'pixel';
    mousePtPx = hFig.CurrentPoint(1,1:2);
    hFig.Units = units_;
end

absPixPos = most.util.getAbsolutePixelPositionInFigure(hObj);

tf = mousePtPx(1)>absPixPos(1) && mousePtPx(2)>absPixPos(2) && ...
     mousePtPx(1)<(absPixPos(1)+absPixPos(3)) && mousePtPx(2)<(absPixPos(2)+absPixPos(4));
end

%--------------------------------------------------------------------------%
% mouseOnObj.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
