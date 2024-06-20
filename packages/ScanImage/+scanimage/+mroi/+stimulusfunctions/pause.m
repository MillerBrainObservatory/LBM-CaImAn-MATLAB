function [xx,yy] = pause(tt,varargin)
% pause function:
%  NaN values will be interpolated by ScanImage

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: poweredPause (If true, beam will be enabled to specified power)

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
xx = nan(size(tt));
yy = nan(size(tt));
end


%--------------------------------------------------------------------------%
% pause.m                                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
