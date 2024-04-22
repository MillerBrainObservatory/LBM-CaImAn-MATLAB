function minimizeFigure(hFig)
%MINIMIZEFIGURE Minimize figure window
%
%   hFig: A handle-graphics figure object handle
%
% NOTES
%  Use trick given on Yair Altman's Undocumented Matlab site to minimize
%  figure. Amazingly, this functionality is not provided by TMW.

if strcmpi(hFig.Visible,'on');
    hFrame = get(hFig,'JavaFrame');
    hFrame.setMinimized(true);
end


%--------------------------------------------------------------------------%
% minimizeFigure.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
