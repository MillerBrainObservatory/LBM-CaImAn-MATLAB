function [f] = make_tiled_figure(images, metadata, varargin)
% MAKE_TILED_FIGURE Creates a tiled figure with scale bars and specified titles.
%
% Parameters
% ----------
% images : cell array
%     Cell array of 2D or 3D images to be tiled.
% metadata : struct
%     Metadata structure containing necessary information.
% 'fig_title' : char, optional
%     Title for the entire figure.
% 'tile_titles' : cell array, optional
%     Cell array of titles for each image.
% 'scale_size' : int, optional
%     Size of scale bar, in microns. If empty, no scale is drawn.
% 'save_name' : char, optional
%     Name to save the figure.
% 'layout' : char, optional
%     Layout for the tiles ('horizontal', 'vertical', 'square').

p = inputParser;
addRequired(p, 'images', @iscell);
addRequired(p, 'metadata', @isstruct);
addParameter(p, 'fig_title', '');
addParameter(p, 'tile_titles', {}, @iscell);
addParameter(p, 'scale_size', 10, @isnumeric);
addParameter(p, 'save_name', '');
addParameter(p, 'layout', 'horizontal', @(x) any(validatestring(x, {'horizontal', 'vertical', 'square'})));
parse(p, images, metadata, varargin{:});

images = p.Results.images;
metadata = p.Results.metadata;
fig_title = p.Results.fig_title;
tile_titles = p.Results.tile_titles;
scale_size = p.Results.scale_size;
save_name = p.Results.save_name;
layout = p.Results.layout;

num_images = length(images);

f = figure('Color', 'k');
sgtitle(fig_title, 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');

switch layout
    case 'horizontal'
        tiledlayout(1, num_images, 'TileSpacing', 'compact', 'Padding', 'compact');
    case 'vertical'
        tiledlayout(num_images, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    case 'square'
        n = ceil(sqrt(num_images));
        tiledlayout(n, n, 'TileSpacing', 'compact', 'Padding', 'compact');
    otherwise
        error('Invalid layout option. Use ''horizontal'', ''vertical'', or ''square''.');
end

for i = 1:num_images

    img = images{i};
    if ndims(img) == 3
        img = img(:, :, 2);
    end

    nexttile;
    imagesc(img);
    axis image; axis tight; axis off; colormap('gray');
    if ~isempty(tile_titles) > 0
        title(tile_titles{i}, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'w');
    end
    
    if scale_size
        scale_length_pixels = scale_size / metadata.pixel_resolution;

        hold on;
        scale_bar_x = [size(img, 2) - scale_length_pixels - 3, size(img, 2) - 3];
        scale_bar_y = [size(img, 1) - 3, size(img, 1) - 3];
        line(scale_bar_x, scale_bar_y, 'Color', 'r', 'LineWidth', 5);
        text(mean(scale_bar_x), scale_bar_y(1), sprintf('%d µm', scale_size), 'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        hold off;
    end
end

if ~isempty(save_name)
    saveas(f, save_name, 'png');
    close(f);
end
end
