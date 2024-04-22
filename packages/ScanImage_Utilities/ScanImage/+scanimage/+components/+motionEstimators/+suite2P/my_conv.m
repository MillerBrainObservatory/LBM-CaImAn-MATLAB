% this code was developed by Marius Pachitariu and Carsen Stringer as part of the software package Suite2p

function S1 = my_conv(S1, sig)

dsnew = size(S1);

S1 = reshape(S1, size(S1,1), []);
dsnew2 = size(S1);

tmax = ceil(4*sig);
dt = -tmax:1:tmax;
gaus = exp( - dt.^2/(2*sig^2));
gaus = gaus'/sum(gaus);

cNorm = filter(gaus, 1, cat(1, ones(dsnew2(1), 1), zeros(tmax,1)));
cNorm = cNorm(1+tmax:end, :);

S1 = filter(gaus, 1, cat(1, S1, zeros([tmax, dsnew2(2)])));
S1(1:tmax, :) = [];
S1 = reshape(S1, dsnew);

S1 = bsxfun(@rdivide, S1, cNorm);

%--------------------------------------------------------------------------%
% my_conv.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
