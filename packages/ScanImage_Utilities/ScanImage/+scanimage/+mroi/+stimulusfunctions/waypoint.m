function [xx,yy] = waypoint(tt,varargin)
% point stimulus

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
xx = nan(size(tt));
yy = nan(size(tt));

t = ceil(numel(xx) / 2);
xx(t) = 0;
yy(t) = 0;

end



%--------------------------------------------------------------------------%
% waypoint.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
