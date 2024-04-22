function [done,nextOutputWaveform,optimizationData] = proportionalOptimization(linearScanner,iterationNumber,sampleRateHz,desiredWaveform,outputWaveform,feedbackWaveform,optimizationData)

if iterationNumber == 1
    optimizationData = struct();
    
    delay = findDelay(feedbackWaveform,desiredWaveform);
    if isempty(delay)
        delay = 0; % no correlation found. probably because waveform is constant
    end
    
    optimizationData.delay = delay;
    nextOutputWaveform = circshift(outputWaveform,-optimizationData.delay);
else
    err = feedbackWaveform - desiredWaveform;
    err_shift = circshift(err,-optimizationData.delay);

    K = 0.5;
    nextOutputWaveform = outputWaveform - K * err_shift;
end

done = iterationNumber >= 5;
end

function delay = findDelay(waveform1,waveform2)
% calculate waveform autocorrelation
    assert(numel(waveform1)==numel(waveform2));
    len = numel(waveform1);
    r = ifft( fft(waveform1) .* conj(fft(waveform2)) );
    r = [r(end-len+2:end) ; r(1:len)];
    
    peakLoc = scanimage.util.peakFinder(r);
    peakLoc(r(peakLoc)<0.99*max(r(peakLoc))) = []; % filter out peaks to compensate for rounding errors
    delay = min(peakLoc);
end

%--------------------------------------------------------------------------%
% proportionalOptimization.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
