function h = roiIntegratorDisplay(varargin)
    hDisplay = roiIntegratorDisplayClass();
    
    if nargin >= 1
        hDisplay.hSI = varargin{1};
    end
    if nargin >= 2
        hDisplay.hSICtl = varargin{2};
    end
    
    h = hDisplay.hFig;
    handles = most.util.setHandleStructGuideStyle(h);
    handles.hDisplay = hDisplay; % append hDisplay object to 
    guidata(h,handles);
end

%--------------------------------------------------------------------------%
% roiIntegratorDisplay.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
