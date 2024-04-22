function mask = computeresscanmask(scanFreq, sampleRate, fillFractionSpatial, pixelsPerLine)
%COMPUTERESSCANMASK Computes the line mask for resonant scanning
%   The mask indicates the number of samples acquired per pixel in a line
%   based on the given parameters    

    assert(fillFractionSpatial>0 && fillFractionSpatial<1,'fillFractionSpatial needs to be smaller than 1');

    pixelBoundaries = linspace(-fillFractionSpatial,fillFractionSpatial,pixelsPerLine+1)';
    pixelBoundariesTime = asin(pixelBoundaries) / (2*pi*scanFreq);
    pixelBoundariesSamples = pixelBoundariesTime * sampleRate;
    pixelBoundariesSamples = round(pixelBoundariesSamples); % quantize
    mask = diff(pixelBoundariesSamples);

%     assert(all(mask>0),'Mask contains zero values, which will result in incorrect FPGA behavior');
end


%--------------------------------------------------------------------------%
% computeresscanmask.m                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
