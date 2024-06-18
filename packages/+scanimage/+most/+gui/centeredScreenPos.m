function pos = centeredScreenPos(sz,units)
%CENTEREDSCREENPOS calculates a position (x y width height) for a screen
%centered figure with the desired width and height.
    if nargin < 2
        units = 'pixels';
    end

    u = get(0,'units');
    set(0,'units',units);
    scrsz = get(0,'ScreenSize');
    set(0,'units',u);
    pos = [(scrsz(3)-sz(1))/2 (scrsz(4)-sz(2))/2 sz(1) sz(2)];
end



%--------------------------------------------------------------------------%
% centeredScreenPos.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
