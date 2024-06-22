function C = xcorr2circ(A,B)
%circular cross correlation
C = fftshift(ifftn(fftn(A).*conj(fftn(B))));
end



%--------------------------------------------------------------------------%
% xcorr2circ.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
