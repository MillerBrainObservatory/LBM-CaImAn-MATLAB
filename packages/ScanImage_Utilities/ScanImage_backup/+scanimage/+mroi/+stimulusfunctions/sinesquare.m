function [xx,yy] = sinesquare(tt,varargin)
% sinesquare stimulus function

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'numlines') || isempty(inputs.numlines)
    inputs.numlines = 10;
end

%% generate output
tt = tt ./ tt(end); %normalize tt
phi = 2*pi .* tt * inputs.numlines / 2;
xx = cos(phi);
yy = (tt - 0.5)*2 ; % center around [0,0], fill interval [-1,1]
end


%--------------------------------------------------------------------------%
% sinesquare.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
