function [success,ijOffset,quality,cii,cjj] = fftCorrGpu_detectMotionFcn(refImagePreprocessed,image)
% function to detect motion between an image and a reference image using
% GPU acceleration
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
% c = ifft(fft(image)*conj(fft(referenceImage)));
% where conj(fft(referenceImage)) is precalculated and passed into the
% function with refImagePreprocessed_g
%
% this function is used to precalculate the complex conjugate of
% the i and j mean side projections of the reference image

assert(isequal(refImagePreprocessed.imageSize,size(image)), ...
    'The resolution of the video stream and the reference image does not match');

g_image = gpuArray(image);
g_cc = real(ifft2(fft2(single(g_image)) .* refImagePreprocessed.g_imageSingleFft));
g_cii = fftshift(max(g_cc,[],2));
g_cjj = fftshift(max(g_cc,[],1));

[quality,idx_g] = max(g_cc(:));

idx = gather(idx_g);
cii = gather(g_cii);
cjj = gather(g_cjj);

cdim = size(image);
[i,j] = ind2sub(cdim,idx);

icenter = floor(cdim(1)/2)+1;
jcenter = floor(cdim(2)/2)+1;
i = i - (icenter - 1)*(i >= icenter) + (icenter - 1)*(i < icenter);
j = j - (jcenter - 1)*(j >= jcenter) + (jcenter - 1)*(j < jcenter);

ijOffset = [icenter-i,jcenter-j];
success = true;
end

%--------------------------------------------------------------------------%
% fftCorrGpu_detectMotionFcn.m                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
