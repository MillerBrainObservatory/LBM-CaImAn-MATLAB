function [xx,yy] = pause(tt,varargin)
% pause function:
%  NaN values will be interpolated by ScanImage

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
xx = nan(size(tt));
yy = nan(size(tt));
end


%--------------------------------------------------------------------------%
% pause.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
