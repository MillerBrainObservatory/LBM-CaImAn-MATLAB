function [xx,yy] = sinesquare(tt,varargin)
% sinesquare stimulus function

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: numlines (Number of lines)

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
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
