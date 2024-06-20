function [xx,yy] = cardioid(tt,varargin)
% cardioid stimulus function

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
% from http://mathworld.wolfram.com/HeartCurve.html
tt = 6.5 / tt(end) .* tt;
xx = 16 * sin(tt).^3;
yy = 13*cos(tt) - 5*cos(2*tt) - 2*cos(3*tt) - cos(4*tt);

% scale
xx =  xx/17;
yy = -yy/17;
end


%--------------------------------------------------------------------------%
% cardioid.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
