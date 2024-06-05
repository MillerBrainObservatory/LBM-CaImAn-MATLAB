function [xx,yy] = template(tt,varargin)
% describe type of stimulus here

%% parse inputs
inputs = scanimage.mroi.util.parseInputs(varargin);

% add optional parameters
if ~isfield(inputs,'myparameter1') || isempty(inputs.myparameter1)
   inputs.myparameter1 = 10; % standard value for myparameter1
end

if ~isfield(inputs,'myparameter2') || isempty(inputs.myparameter2)
   inputs.myparameter2 = 20; % standard value for myparameter2
end

%% generate output
% tt is an evenly spaced, zero based time series in the form of a time, so that
%       dt = 1 / sample frequency
%       min(tt) = 0
%       max(tt) = (numsamples - 1) * dt
%
% implement the parametric function of time, so that
%       length(xx) == length(tt)  and  length(yy) == length(tt)
%       xx,yy are row vectors
%
% this function will be called frequently by ScanImage;
% it is advised to optimize for performance

% (optional) if required, normalize tt
tt = tt ./ tt(end);

xx = xfunction_of(tt) * inputs.myparameter1;
yy = yfunction_of(tt) - inputs.myparameter2;

%% (optional) normalize output to interval [-1,1]
% for optimal performance, the output generation should produce values in
% the interval [-1,1] natively, instead of scaling the output in an
% additional step
[xx,yy] = normalize(xx,yy);
end

function normalize(xx,yy)
xxrange = [min(xx) max(xx)];
yyrange = [min(yy) max(yy)];

%center
xx = xx - sum(xxrange)/2;
yy = yy - sum(yyrange)/2;

%scale
factor = 1 / max(abs([xxrange - sum(xxrange)/2 , yyrange - sum(yyrange)/2]));
xx = xx .* factor;
yy = yy .* factor;
end


%--------------------------------------------------------------------------%
% 0template.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
