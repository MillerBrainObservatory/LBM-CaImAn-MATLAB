function [xx,yy] = circle(tt,varargin)
% circle stimulus function

%% parse inputs
% no additional inputs required
% inputs = scanimage.mroi.util.parseInputs(varargin); %#ok<NASGU>

%% generate output
tt = tt ./ tt(end); %normalize tt
tt = (2*pi) .* tt;
xx = cos(tt);
yy = sin(tt);
end


%--------------------------------------------------------------------------%
% circle.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
