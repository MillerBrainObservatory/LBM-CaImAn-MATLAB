function set_caxis(stack)
% Set the color axis limits for an image stack.
%
% This function sets the color axis limits of the current figure based on
% the cumulative distribution function (CDF) of pixel values in the first
% image of the provided stack. The limits are set to the 0.5th and 99.5th
% percentiles to improve the contrast of the displayed images.
%
% Parameters
% ----------
% stack : 3D array
%     The input image stack (height x width x frames).

[counts, grayLevels] = hist(double(reshape(stack(:,:,1),1,[])),50);
cdf = cumsum(counts);
cdf = cdf / numel(stack(:,:,1));
index99 = find(cdf >= 0.995, 1, 'first');
maxval = grayLevels(index99);
if isempty(maxval)
   maxval = max(reshape(stack(:,:,2),1,[]));
end
index01 = find(cdf <= 0.995, 1, 'first');
minval = grayLevels(index01);
if isempty(minval)
   minval = min(reshape(stack(:,:,2),1,[]));
end

gcf;
caxis([minval maxval])
end
