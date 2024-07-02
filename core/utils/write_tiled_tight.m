function [f] = write_tiled_tight(images, metadata, varargin)
% Creates a tiled figure with scale bars and specified titles.
%
% Parameters
% ----------
% images : cell array
%     Cell array of 2D or 3D images to be tiled.
% metadata : struct
%     Metadata structure containing necessary information.
% titles : cell array, optional
%     Cell array of titles for each image.
% scales : cell array, optional
%      Cell array of sizes for the scale bar, in micron.
%      If empty or 0, no scale is drawn.
% fig_title : char, optional
%     Title for the entire figure.
% save_name : char, optional
%     Name to save the figure.
% layout : char, optional
%     Layout for the tiles ('horizontal', 'vertical', 'square').
% show_figure : logical, optional
%     If false, the figure will not be displayed. Default is true.

p = inputParser;
addRequired(p, 'images', @iscell);
addRequired(p, 'metadata', @isstruct);
addParameter(p, 'fig_title', '');
addParameter(p, 'titles', {}, @iscell);
addParameter(p, 'scales', {}, @iscell);
addParameter(p, 'save_name', 'unnamed.png');
addParameter(p, 'layout', 'square', @(x) any(validatestring(x, {'horizontal', 'vertical', 'square'})));
addParameter(p, 'show_figure', true, @islogical);
addParameter(p, 'font_size', 10, @isscalar);
parse(p, images, metadata, varargin{:});

images = p.Results.images;
metadata = p.Results.metadata;
fig_title = p.Results.fig_title;
titles = p.Results.titles;
scales = p.Results.scales;
save_name = p.Results.save_name;
layout = p.Results.layout;
font_size = p.Results.font_size;
show_figure = p.Results.show_figure;

num_images = length(images);
num_titles = length(titles);

% set figure visibility
f = figure('Color', 'k', 'Visible', show_figure);

if ~isempty(fig_title)
    sgtitle(fig_title, 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
end

switch layout
    case 'horizontal'
        tiledlayout(1, num_images, 'TileSpacing', 'none', 'Padding', 'none');
    case 'vertical'
        tiledlayout(num_images, 1, 'TileSpacing', 'none', 'Padding', 'none');
    case 'square'
        n = ceil(sqrt(num_images));
        tiledlayout(n, n, 'TileSpacing', 'none', 'Padding', 'none');
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
    if ~isempty(titles) > 0
        title(titles{i}, 'FontSize', font_size, 'Color', 'w');
    end
end

if ~isempty(save_name)
    saveas(f, save_name, 'png');
    if ~show_figure
        close(f);
    end
end

if nargout == 0 && show_figure
    clear f;
end
end
