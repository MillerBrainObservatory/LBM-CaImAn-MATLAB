function [xx,yy] = hypotrochoid(tt,varargin)
% hypotrochoid stimulus function

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'r1') || isempty(inputs.r1)
   inputs.r1 = 5; % integer number
end

if ~isfield(inputs,'r2') || isempty(inputs.r2)
   inputs.r2 = 3; % integer number
end

if ~isfield(inputs,'d') || isempty(inputs.d)
   inputs.d = 5; % integer number
end

r1 = inputs.r1;
r2 = inputs.r2;
d =  inputs.d;

%% generate output
tt = tt ./ tt(end); %normalize tt
phi = 2*pi*r2/gcd(r1,r2) .* tt;

xx = (r1-r2) .* cos(phi) + d .* cos( ((r1-r2)/r2) .* phi);
yy = (r1-r2) .* sin(phi) - d .* sin( ((r1-r2)/r2) .* phi);

% scale output to fill the interval [-1, 1]
scalefactor = max(abs([min(xx),max(xx),min(yy),max(yy)]));
xx = xx ./ scalefactor;
yy = yy ./ scalefactor;
end


%--------------------------------------------------------------------------%
% hypotrochoid.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
