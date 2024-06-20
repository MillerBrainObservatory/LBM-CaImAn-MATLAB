function [xx,yy,zz] = zspiral(tt,varargin)
% logarithmic spiral stimulus

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: revolutions (Number of revolutions), zrepeats (Number of times to repeat the spiral as scanner travels through Z)

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'revolutions') || isempty(inputs.revolutions)
    inputs.revolutions = 5;
end

if ~isfield(inputs,'a') || isempty(inputs.a)
    inputs.a = 0;
end

if ~isfield(inputs,'zrepeats') || isempty(inputs.zrepeats)
    inputs.zrepeats = 1;
end

mxn = numel(tt);
zz = tt ./ tt(mxn);

N = ceil(mxn * .5 / inputs.zrepeats);
thtt = linspace(0,2,2*N);
rtt = [1:N N:-1:1] / N;


%% generate output
if inputs.a == 0;
    xx = rtt .* sin(inputs.revolutions .* 2*pi .* thtt);
    yy = rtt .* cos(inputs.revolutions .* 2*pi .* thtt);
else
    rtt = rtt-max(rtt);
    xx = exp(inputs.a .* rtt) .* sin(inputs.revolutions .* 2*pi .* thtt);
    yy = exp(inputs.a .* rtt) .* cos(inputs.revolutions .* 2*pi .* thtt);
end


xx = repmat(xx, 1, inputs.zrepeats);
xx(mxn+1:end) = [];

yy = repmat(yy, 1, inputs.zrepeats);
yy(mxn+1:end) = [];



%--------------------------------------------------------------------------%
% zspiral.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
