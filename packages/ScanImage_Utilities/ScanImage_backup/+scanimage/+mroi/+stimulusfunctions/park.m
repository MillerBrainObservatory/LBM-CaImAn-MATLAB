function [xx,yy] = park(tt,varargin)
% park function:
%  NaNs will be interpolated
%  +inf values will be translated by ScanImage to the park position

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
xx = NaN(size(tt));
yy = NaN(size(tt));

% set last two points of park function to inf so that the slope at the park
% position is zero
assert(length(tt) >= 2);
xx(end-1:end) = inf;
yy(end-1:end) = inf;
end


%--------------------------------------------------------------------------%
% park.m                                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
