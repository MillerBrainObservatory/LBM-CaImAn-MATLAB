function [xx,yy] = hypocycloid(tt,varargin)
% hypocycloid stimulus function

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
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
