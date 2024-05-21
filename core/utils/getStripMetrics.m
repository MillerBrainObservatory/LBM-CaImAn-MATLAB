 
for plane_idx = 1:metadata.num_planes
    for roi_idx = 2:metadata.num_rois
        strip1 = trimmed_Aout(:, (roi_idx - 2) * trimmed_x + 1 : (roi_idx - 1) * trimmed_x, plane_idx, :);
        strip2 = trimmed_Aout(:, (roi_idx - 1) * trimmed_x + 1 : roi_idx * trimmed_x, plane_idx, :);
        mse_value = immse(strip1, strip2);
        fitting_metrics = [fitting_metrics; mse_value];
    end
end

% Process the trimmed_Aout as needed
disp(['Trimmed image size: ', num2str(size(trimmed_Aout))]);

% Visualize the concatenated strips for the first frame of the first plane
figure;
imshow(trimmed_Aout(:, :, 1, 1), []);
title(sprintf('Concatenated Strips: File %d', i));

% Further processing can be done on trimmed_Aout here