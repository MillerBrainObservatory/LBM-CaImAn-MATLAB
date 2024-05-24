function getStripMetrics(data, metadata)
%

fitting_metrics = [];
for plane_idx = 1:metadata.num_planes
    for roi_idx = 2:metadata.num_rois
        strip1 = data(:, (roi_idx - 2) * trimmed_x + 1 : (roi_idx - 1) * trimmed_x, plane_idx, :);
        strip2 = data(:, (roi_idx - 1) * trimmed_x + 1 : roi_idx * trimmed_x, plane_idx, :);
        mse_value = immse(strip1, strip2);
        fitting_metrics = [fitting_metrics; mse_value];
    end
end

figure;
imshow(data(:, :, 1, 1), []);
title(sprintf('Concatenated Strips: File %d', 2));
end
