function [dB,f] = fftTodB(fft_in,Fs,amp0)
% returns single-sided amplitude Spectrum of input signal in units of dB
%
% inputs: 
%       fft_in: raw fft of signal
%       Fs: Sampling frequency of signal
%       amp0: (optional) reference amplitude for dB calculation. default: 1
%
% returns:


if nargin < 3 || isempty(amp0)
    amp0 = 1;
end

L = numel(fft_in);  % Length of signal
P2 = abs(fft_in)/L; % normalize fft

% single sided power spectrum: double and keep only right side
amp = P2(1:floor(L/2)+1); 
amp(2:end-1) = 2*amp(2:end-1);

dB = 20 * log10(amp/amp0); % dB is defined in regards to power (reflected by factor 20)

if nargout > 1
    f = Fs*(0:(L/2))/L;
end

end

%--------------------------------------------------------------------------%
% fftTodB.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
