function plot_contours_Ac(Ac_keep, acx, acy)
% Plot contours after converting to sparse matrix
    num_neurons = size(Ac_keep, 3);
    figure; hold on;
    
    cmap = parula(num_neurons + 5);  % Generate distinct colors for neurons

    for i = 1:num_neurons
        A_temp = squeeze(Ac_keep(:,:,i)); 
        A_temp = medfilt2(A_temp, [3,3]); 
        
        thr = max(A_temp(:)) * 0.5;
        A_temp(A_temp < thr) = 0;
        
        % Extract contour boundaries
        BW = bwareaopen(A_temp > 0, 2);  % Remove small noise
        BW2 = bwboundaries(BW);
        
        % Plot contours at the corresponding (acx, acy)
        if ~isempty(BW2)
            for j = 1:length(BW2)
                boundary = BW2{j};
                x_shifted = boundary(:,2) + acx(i) - 9;  % Shift to correct position
                y_shifted = boundary(:,1) + acy(i) - 9;
                plot(x_shifted, y_shifted, 'Color', cmap(i,:), 'LineWidth', 1.5);
            end
        end
    end

    axis equal; axis tight; hold off;
    title('Neuron Contours from Ac\_keep');
end