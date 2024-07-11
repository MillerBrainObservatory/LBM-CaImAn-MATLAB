function scale_size = calculate_scale(img_size, pixel_resolution)
% Calculates the appropriate scale bar size from an image size and pixel resolution.
%
% Parameters
% ----------
% img_size : int
%     Width of the image in pixels.
% pixel_resolution : double
%     Pixel resolution in microns per pixel.
%
% Returns
% -------
% scale_size : int
%     Calculated scale bar size in microns.

img_width_microns = img_size * pixel_resolution;
min_scale_size = img_width_microns / 10;
scale_size = ceil(min_scale_size / 10) * 10;
end
