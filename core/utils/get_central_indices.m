function [yind, xind] = get_central_indices(img, margin)
% Returns the central indices of the image with a given margin.
%
% Parameters
% ----------
% img : 2D array
%     The input image.
% margin : int
%     The margin around the central part.
%
% Returns
% -------
% yind : array
%     Indices for the y-dimension.
% xind : array
%     Indices for the x-dimension.

[~, max_idx] = max(img(:));
[max_y, max_x] = ind2sub(size(img), max_idx);

yind = max(max_y - margin, 1):min(max_y + margin, size(img, 1));
xind = max(max_x - margin, 1):min(max_x + margin, size(img, 2));
end