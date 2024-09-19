function write_images_to_tile(images, metadata, varargin)
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

p = inputParser;
addRequired(p, 'images', @iscell);
addRequired(p, 'metadata', @isstruct);
addParameter(p, 'fig_title', '');
addParameter(p, 'titles', {}, @iscell);
addParameter(p, 'scales', {}, @iscell);
addParameter(p, 'save_name', 'unnamed.png');
addParameter(p, 'layout', 'horizontal', @(x) any(validatestring(x, {'horizontal', 'vertical', 'square'})));
parse(p, images, metadata, varargin{:});

images = p.Results.images;
metadata = p.Results.metadata;
fig_title = p.Results.fig_title;
titles = p.Results.titles;
scales = p.Results.scales;
save_name = p.Results.save_name;
layout = p.Results.layout;

num_images = length(images);
if isempty(scales) || length(scales) ~= num_images
    scales = repmat({0}, 1, num_images);
end

f = figure('Visible', 'off');

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

if ~iscell(scales)
    this_scale = cell(num_images);
    for ii = 1:length(images)
        this_scale{ii} = scales;
    end
end

for i = 1:num_images
    img = images{i};
    this_scale = scales{i};
    if ndims(img) == 3
        warning("Input for tiled figure must be 2D images. Using 2nd frame.")
        img = img(:, :, 2);
    end

    nexttile;
    imagesc(img);
    axis image; axis tight; axis off; colormap('gray');
    if ~isempty(titles) > 0
        title(titles{i}, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'w');
    end

    if this_scale < size(img, 2) / 10 % make sure its not too small
        mod_scale = calculate_scale(size(img, 2), metadata.pixel_resolution);
    else
        mod_scale = this_scale;
    end

    if mod_scale > 0
        scale_length_pixels = mod_scale / metadata.pixel_resolution;

        hold on;
        % Move the scale bar up and to the left by a fraction of the image height and width
        y_offset = size(img, 1) * 0.1; % 10% of the image height
        x_offset = size(img, 2) * 0.1; % 10% of the image width
        scale_bar_x = [size(img, 2) - scale_length_pixels - 3 - x_offset, size(img, 2) - 3 - x_offset];
        scale_bar_y = [size(img, 1) - y_offset, size(img, 1) - y_offset];

        % TODO: Scale line width with image resolution
        line(scale_bar_x, scale_bar_y, 'Color', 'r', 'LineWidth', 3);

        % Adjust text position to match the new scale bar location
        text(mean(scale_bar_x), scale_bar_y(1) - 5, sprintf('%d µm', mod_scale), ...
            'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
        hold off;
    end

end
if ~isempty(fig_title)
    % underscores make subscripts, replace with a space and capitalize
    fig_title = strrep(fig_title, '_', ' ');
    fig_title = regexprep(fig_title, '(\<\w)', '${upper($1)}');

    sgtitle(fig_title, 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
end

if ~isempty(save_name)
    exportgraphics(gcf, save_name, 'Resolution',600);
end
end
