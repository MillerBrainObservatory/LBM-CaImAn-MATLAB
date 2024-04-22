function [xx,yy] = hypocycloid(tt,varargin)
% hypocycloid stimulus function

% the following line will be parsed by the ROI editor to present a list of
% options. should be in the format: parameter1 (comment), parameter2 (comment)
%% parameter options: k

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

if ~isfield(inputs,'k') || isempty(inputs.k)
   inputs.k = 5; % integer number
end

r1 = inputs.k;
r2 = 1;
d  = r2;

%% generate output
[xx,yy] = scanimage.mroi.stimulusfunctions.hypotrochoid(tt,'r1',r1,'r2',r2,'d',d);
end


%--------------------------------------------------------------------------%
% hypocycloid.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
