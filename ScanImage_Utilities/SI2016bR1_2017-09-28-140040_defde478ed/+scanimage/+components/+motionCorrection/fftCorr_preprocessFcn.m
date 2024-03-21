function [refDisplayImage,referenceImagePreprocessed] = fftCorr_preprocessFcn(refIm)
% function to pre-process a reference image for use with a
% motion correction algorithm
%
% inputs:
%     refIm: data describing the reference image (usually a 2D numeric matrix)
% outputs:
%     refDisplayImage: image used for visualization in motion display (2D numeric matrix)
%     referenceImagePreProcessed: data that is passed into the motion detection function
%
% this function calculates conj(fft2(refIm))

refDisplayImage = refIm;
referenceImagePreprocessed = conj(fft2(single(refIm)));
end

%--------------------------------------------------------------------------%
% fftCorr_preprocessFcn.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
