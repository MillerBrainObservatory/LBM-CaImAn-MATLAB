function [xs,ys] = xformPointsXY(xs,ys,T,varargin)
    % T is a 2D affine
    % x is [m x n] array of x points
    % y is [m x n] array of y points
    
    r=[xs(:),ys(:)];
    r = scanimage.mroi.util.xformPoints(r,T,varargin{:});
    xs=reshape(r(:,1),size(xs));
    ys=reshape(r(:,2),size(ys));
end


%--------------------------------------------------------------------------%
% xformPointsXY.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
