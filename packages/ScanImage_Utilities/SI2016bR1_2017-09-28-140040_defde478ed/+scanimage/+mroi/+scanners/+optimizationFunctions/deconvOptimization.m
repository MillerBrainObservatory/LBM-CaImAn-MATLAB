function [done,nextOutputWaveform,optimizationData] = deconvOptimization(linearScanner,iterationNumber,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData)
err = feedbackWaveform - desiredWaveform;
H = fft(feedbackWaveform)./fft(outputWaveform);
H(abs(H)<0.05) = Inf; % avoid division by zero
err_i = ifft(fft(err)./H);
err_i = err_i-mean(err_i);
nextOutputWaveform = outputWaveform - err_i - mean(err);
done = iterationNumber > 5; 
end

%--------------------------------------------------------------------------%
% deconvOptimization.m                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
