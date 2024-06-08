function make_tiled_figure(images, metadata, fig_title, tile_titles, scale_bar_size_um, savename)
% MAKE_TILED_FIGURE Creates a tiled figure with scale bars and specified titles.
%
% Parameters
% ----------
% images : 4D array
%     Array of images to be tiled (height x width x num_planes x num_frames).
% metadata : struct
%     Metadata structure containing necessary information.
% fig_title : char
%     Title for the entire figure.
% tile_titles : cell array
%     Cell array of titles for each image.
% scale_bar_size_um : int
%     Size of scale bar, in microns.

pixel_resolution = metadata.pixel_resolution;
scale_fact = scale_bar_size_um; % Length of the scale bar in microns
scale_length_pixels = scale_fact / pixel_resolution;

num_images = size(images, 3);

f = figure('Color', 'k');
sgtitle(fig_title, 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
tiledlayout(1, num_images, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:num_images
    img = images{i}; % Assuming using the first frame for visualization
    nd = size(img);
    if length(nd) > 2
        img=img(:,:,2);
    end
    
    nexttile;
    imagesc(img);
    axis image; axis tight; axis off; colormap('gray');
    title(tile_titles{i}, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'w');
    hold on;

    % Scale bar coordinates relative to the image
    scale_bar_x = [size(img, 2) - scale_length_pixels - 3, size(img, 2) - 3]; % 3 pixels padding from the right
    scale_bar_y = [size(img, 1) - 3, size(img, 1) - 3]; % 3 pixels padding from the bottom
    line(scale_bar_x, scale_bar_y, 'Color', 'r', 'LineWidth', 5);
    text(mean(scale_bar_x), scale_bar_y(1), sprintf('%d µm', scale_fact), 'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    hold off;
end

if ~exist('savename', 'var')
    return
else
    saveas(f, savename, 'png');
    close(f);
end
