function [xx,yy,zz] = logspiral(tt,varargin)
% logarithmic spiral stimulus

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: revolutions (Number of revolutions)

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'revolutions') || isempty(inputs.revolutions)
    inputs.revolutions = 5;
end

if ~isfield(inputs,'a') || isempty(inputs.a)
    inputs.a = 0;
end

tt = tt ./ tt(end); %normalize tt

%% generate output
xx = sin(inputs.revolutions .* 2*pi .* tt);
yy = cos(inputs.revolutions .* 2*pi .* tt);
zz = tt;



%--------------------------------------------------------------------------%
% zcoil.m                                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
