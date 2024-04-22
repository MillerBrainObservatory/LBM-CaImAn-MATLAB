function [success,ijOffset,quality,cii,cjj] = fftCorrSideProj_detectMotionFcn(refImagePreprocessed,image)
% function to detect motion between an image and a reference image
%
% inputs:
%     refImagePreProcessed: pre-processed reference image
%     image: current image
% outputs:
%     success: (logical) indicates if a match between the images was found
%     ijOffset: (1x2 numeric array) the row (i) and column (j) offset between the image and reference image
%     quality: metric indicating the quality of the registration
%     cii: correlation for each pixel in dimension j
%     cjj: correlation for each pixel in dimension i
% estimate motion according to the formula
% c = ifft(fft(imageSideProjection)*conj(fft(refImageSideProjection)));
% where conj(fft(refImageSideProjection)) is precalculated and passed into the
% function with refImagePreprocessed
%
% this function is used to precalculate the complex conjugate of
% the i and j mean side projections of the reference image

assert(size(image,1)==length(refImagePreprocessed.conjFfti) && ...
       size(image,2)==length(refImagePreprocessed.conjFftj), ...
       'The resolution of the video stream and the reference image does not match');

imageSingle = single(image);
cii = real(ifftn(fft(mean(imageSingle,2)).*refImagePreprocessed.conjFfti));
cjj = real(ifftn(fft(mean(imageSingle,1)).*refImagePreprocessed.conjFftj));

[ci,i] = max(cii(:));
[cj,j] = max(cjj(:));
quality = mean([ci,cj]);

cii = fftshift(cii);
cjj = fftshift(cjj);

cdim = size(image);

icenter = floor(cdim(1)/2)+1;
jcenter = floor(cdim(2)/2)+1;
i = i - (icenter - 1)*(i >= icenter) + (icenter - 1)*(i < icenter);
j = j - (jcenter - 1)*(j >= jcenter) + (jcenter - 1)*(j < jcenter);

ijOffset = [icenter-i,jcenter-j];
success = true;
end

%--------------------------------------------------------------------------%
% fftCorrSideProj_detectMotionFcn.m                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
