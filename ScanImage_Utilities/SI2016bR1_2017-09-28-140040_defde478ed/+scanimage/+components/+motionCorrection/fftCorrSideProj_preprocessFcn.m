function [refDisplayImage,referenceImagePreprocessed] = fftCorrSideProj_preprocessFcn(refIm)
% function to pre-process a reference image for use with a
% motion correction algorithm
%
% inputs:
%     refIm: data describing the reference image (usually a 2D numeric matrix)
% outputs:
%     refDisplayImage: image used for visualization in motion display (2D numeric matrix)
%     referenceImagePreProcessed: data that is passed into the motion detection function
%
% this function calculates conj(fft(referencImageSideProjection))

refDisplayImage = refIm;
referenceImagePreprocessed = struct();
refImSingle = single(refIm);
referenceImagePreprocessed.conjFfti = conj(fft(mean(single(refImSingle),2)));
referenceImagePreprocessed.conjFftj = conj(fft(mean(single(refImSingle),1)));
end

%--------------------------------------------------------------------------%
% fftCorrSideProj_preprocessFcn.m                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
