function [xx,yy] = logspiral(tt,varargin)
% logarithmic spiral stimulus

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'revolutions') || isempty(inputs.revolutions)
    inputs.revolutions = 5;
end

if ~isfield(inputs,'direction') || isempty(inputs.direction)
    inputs.direction = 'outward';
end

if ~isfield(inputs,'a') || isempty(inputs.a)
    inputs.a = 0;
end

tt = tt ./ tt(end); %normalize tt
switch inputs.direction
    case 'outward'
        % Nothing to do
        % tt = tt;
    case 'inward'
        tt = fliplr(tt);
    otherwise
        error('Unknown direction: %s',inputs.direction);
end

%% generate output
if inputs.a == 0;
    xx = tt .* sin(inputs.revolutions .* 2*pi .* tt);
    yy = tt .* cos(inputs.revolutions .* 2*pi .* tt);
else
    tt = tt-max(tt);
    xx = exp(inputs.a .* tt) .* sin(inputs.revolutions .* 2*pi .* tt);
    yy = exp(inputs.a .* tt) .* cos(inputs.revolutions .* 2*pi .* tt);
end


%--------------------------------------------------------------------------%
% logspiral.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
