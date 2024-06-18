function absPos = getAbsolutePixelPositionInFigure(hObj)
assert(isgraphics(hObj),'Input to function getAbsolutePixelPositionInFigure needs to be a valid graphics object');

pos = zeros(0,4);

while ~isa(hObj,'matlab.ui.Figure')
    pos(end+1,:) = getPixelPosition(hObj); %#ok<AGROW>
    hObj = hObj.Parent;
end

absPos = [sum(pos(:,1:2),1),pos(1,3:4)];

    function pos_ = getPixelPosition(hObj_)
        units_ = hObj_.Units;
        hObj_.Units = 'pixel';
        pos_ = hObj_.Position;
        hObj_.Units = units_;
    end
end

%--------------------------------------------------------------------------%
% getAbsolutePixelPositionInFigure.m                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
