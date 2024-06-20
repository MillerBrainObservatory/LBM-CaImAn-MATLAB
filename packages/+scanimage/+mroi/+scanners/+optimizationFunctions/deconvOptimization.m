function [done,nextOutputWaveform,optimizationData] = deconvOptimization(linearScanner,iterationNumber,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData)
err = feedbackWaveform - desiredWaveform;

if numel(unique(desiredWaveform))==1
    % Handle Constant Output
    nextOutputWaveform = desiredWaveform - mean(err);
    done = true;
    return
end

H = fft(feedbackWaveform)./fft(outputWaveform);
H(abs(H)<0.05) = Inf; % avoid division by zero + primitive low pass filter
err_i = ifft(fft(err)./H);
err_i = err_i-mean(err_i);
nextOutputWaveform = outputWaveform - err_i - mean(err);
done = iterationNumber >= 6; 
end

%--------------------------------------------------------------------------%
% deconvOptimization.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
