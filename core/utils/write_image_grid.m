function write_image_grid(directory)
    files = dir(fullfile(directory, '*.h5'));
    num_files = 30;
    tiledlayout(5, 6, 'Padding', 'none', 'TileSpacing', 'none');
    for i = 1:num_files
        filepath = fullfile(directory, files(i).name);
        data = h5read(filepath, '/Ym');
        nexttile;
        imshow(data, []);
    end
end
