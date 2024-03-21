function [XData,YData] = xformMesh(XData,YData,T,varargin)
shape = size(XData);

XData = reshape(XData,[],1);
YData = reshape(YData,[],1);

pts = [XData YData];
pts = scanimage.mroi.util.xformPoints(pts,T,varargin{:});

XData = reshape(pts(:,1),shape);
YData = reshape(pts(:,2),shape);
end

%--------------------------------------------------------------------------%
% xformMesh.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
