function [powers] = beamPowers(tt,powerFracs,varargin)
% powerFracs is a row vector of power fractions where a value of 1
% corresponds to 100% beampower
%
% tt is an evenly spaced, zero based time series in the form of a time, so that
%       dt = 1 / sample frequency
%       min(tt) = 0
%       max(tt) = (numsamples - 1) * dt
%
% implement the parametric function of time, so that
%       length(powers) == length(tt)
%       powers is a row vectors
%
% this function will be called frequently by ScanImage;
% it is advised to optimize for performance

% generate output
powers = repmat(powerFracs,numel(tt),1);
end


%--------------------------------------------------------------------------%
% beamPowers.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
