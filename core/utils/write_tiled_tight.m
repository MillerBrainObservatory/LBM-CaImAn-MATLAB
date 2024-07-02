function write_tiled_tight(images,varargin)
    % write_tiled_tight Tiling function for 2D images with titles.
    %
    % Parameters
    % ----------
    % images : cell array
    %     Cell array containing 2D images to be tiled.
    % varargin : additional parameters
    %     fig_title : string, optional
    %         Title of the figure.
    %     titles : cell array, optional
    %         Titles for each individual image.
    %     save_name : string, optional
    %         Path to save the resulting figure.
    %     show_figure : logical, optional
    %         Whether to display the figure.

    p = inputParser;
    addRequired(p, 'images', @iscell);
    addParameter(p, 'fig_title', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'titles', {}, @iscell);
    addParameter(p, 'save_name', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'show_figure', false, @islogical);
    parse(p, images, varargin{:});

    images = p.Results.images;
    fig_title = p.Results.fig_title;
    titles = p.Results.titles;
    save_name = p.Results.save_name;
    show_figure = p.Results.show_figure;

    num_images = numel(images);
    grid_size = ceil(sqrt(num_images));

    figure('Visible', 'off');

    for i = 1:num_images
        subplot(grid_size, grid_size, i);
        imshow(images{i}, []);
        if ~isempty(titles)
            title(titles{i}, 'Interpreter', 'none', 'FontSize', 10);
        end
        axis tight;
    end

    if ~isempty(fig_title)
        sgtitle(fig_title, 'FontSize', 12);
    end

    set(gcf, 'Position', [100, 100, 1200, 800]);
    tight_layout();

    if ~isempty(save_name)
        exportgraphics(gcf, save_name, "Resolution",600);
    end

    if show_figure
        close(gcf);
    end
end

function tight_layout()
    % tight_layout Adjusts subplot layout to minimize whitespace.
    ha = get(gcf, 'Children');
    for i = 1:numel(ha)
        if isprop(ha(i), 'OuterPosition')
            outerpos = get(ha(i), 'OuterPosition');
            ti = get(ha(i), 'TightInset');
            left(i) = outerpos(1) - ti(1);
            bottom(i) = outerpos(2) - ti(2);
            right(i) = outerpos(1) + outerpos(3) + ti(3);
            top(i) = outerpos(2) + outerpos(4) + ti(4);
        else
            left(i) = Inf;
            bottom(i) = Inf;
            right(i) = -Inf;
            top(i) = -Inf;
        end
    end
    left = min(left);
    bottom = min(bottom);
    right = max(right);
    top = max(top);
    set(gcf, 'Units', 'normalized', 'OuterPosition', [left, bottom, right - left, top - bottom]);
end
