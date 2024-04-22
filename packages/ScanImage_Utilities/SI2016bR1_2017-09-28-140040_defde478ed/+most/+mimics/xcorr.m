function c = xcorr(a,b)
% http://stackoverflow.com/questions/7396814/cross-correlation-in-matlab-without-using-the-inbuilt-function
    
corrLength=length(a)+length(b)-1;
c=fftshift(ifft(fft(a,corrLength).*conj(fft(b,corrLength))));
end

%--------------------------------------------------------------------------%
% xcorr.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
