function [period,numPeriods] = findWaveformPeriodicity(xx)
    assert(isvector(xx),'Expect vector as input');
    xx = xx(:); % ensure input is a column vector
    len = numel(xx);
    
    if all(xx==xx(1))
        period = 1;
        numPeriods = len;
        return
    end

    % calculate waveform autocorrelation
    xx_fft = fft(xx);
    r = ifft( xx_fft .* conj(xx_fft) );
    r = [r(end-len+2:end) ; r(1:len)];

    % find peaks in autocorrelation
    peak = max(r);
    tolerance = 1e-7;
    r(r<(peak-tolerance)|r>(peak+tolerance)) = 0;
    foundPeriod = find(r,1,'first'); % we want to find the smallest period, which corresponds to the first peak

    period = len;
    numPeriods = 1;
    if ~isempty(foundPeriod) && foundPeriod~=len && mod(len,foundPeriod)==0
        % ensure that periodicity is perfect
        xx_ = reshape(xx,foundPeriod,[]);
        xx_max = max(xx_,[],2);
        xx_min = min(xx_,[],2);
        dd = abs(xx_max - xx_min);

        tolerance = 1e-6;
        if all(all(dd < tolerance))
            % all repetitions within tolerance
            period = foundPeriod;
            numPeriods = len/period;
        end
    end
end


%--------------------------------------------------------------------------%
% findWaveformPeriodicity.m                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
