function C = xcorrcirc(A,B,varargin)
% circular cross correlation accross dimension dim
C = fftshift(ifft(fft(A,varargin{:}).*conj(fft(B,varargin{:})),varargin{:}));
end



%--------------------------------------------------------------------------%
% xcorrcirc.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
