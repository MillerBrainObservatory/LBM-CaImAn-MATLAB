function [xx,yy] = line(tt,varargin)
% sinesquare stimulus function

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'numlines') || isempty(inputs.numlines)
    inputs.numlines = 10;
end

%% generate output
yy = linspace(-1,1,numel(tt));
xx = -yy;
end


%--------------------------------------------------------------------------%
% line.m                                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
