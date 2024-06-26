function make_tiled_figure_close(images, titles)
% MAKE_TILED_FIGURE_CLOSE Display a set of images in a tiled layout with titles.
%
% Parameters
% ----------
% images : cell array
%     A cell array containing the images to be displayed.
% titles : cell array
%     A cell array containing the titles for each image.

% Check that the number of images matches the number of titles
if numel(images) ~= numel(titles)
    error('The number of images and titles must be the same.');
end

% Determine the number of images
num_images = numel(images);

% Determine the number of rows and columns for the tiled layout
num_cols = ceil(sqrt(num_images));
num_rows = ceil(num_images / num_cols);

% Create a new figure
figure;

% Loop through each image and display it in the subplot
for i = 1:num_images
    subplot(num_rows, num_cols, i);
    imagesc(images{i});
    axis image;
    axis off;
    title(titles{i}, 'Interpreter', 'none');
end

% Adjust the layout for minimal space between tiles
set(gcf, 'Position', get(0, 'Screensize')); % Maximize figure window
tight_layout(num_rows, num_cols); % Adjust layout

end

function tight_layout(num_rows, num_cols)
% TIGHT_LAYOUT Adjust the layout to minimize space between tiles.
    for i = 1:num_rows*num_cols
        subplot(num_rows, num_cols, i);
        pos = get(gca, 'Position');
        pos(3) = pos(3) * 1.1; % Adjust width
        pos(4) = pos(4) * 1.1; % Adjust height
        set(gca, 'Position', pos);
    end
end
