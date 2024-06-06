function writeMatToTiffStack(files, savePath, numFrames)
% WRITEMATTOTIFF Convert a .mat file into a stack.
%
% Parameters
% ----------
% files : struct
%     List of paths to motion-corrected movies containing _plane_ in the filename.
% savePath : str, optional
%     Path to save the output files. Default is the current directory.
% numFrames : int, optional
%     Number of frames to save. Default is 2000.

% mean projection
for i = 1:length(files)
    file = fullfile(path, files(i).name);
    load(file, 'Ym');
    Ym = imresize(Ym, 16);
    Ym = Ym - min(Ym, [], 'all');
    Ym = double(Ym ./ max(Ym, [], 'all')); % mean normalization
    
    write_tiff_stack(fullfile(savePath, [files(i).name(1:end-4) '_Ym_16x.tif']), Ym);
end

% save specified number of frames
for i = 1:length(files)
    disp(i)
    if ~exist(fullfile(savePath, [files(i).name(1:end-4) '_Y_' num2str(numFrames) 'frames.tif']), 'file')
        file = fullfile(path, files(i).name);
        mat = matfile(file);
        Y = mat.Y(:,:,1:numFrames);
        Y = double(Y - quantile(Y(:,:,1:100), 0.05, 'all'));
        Y = Y ./ quantile(Y(:,:,1:100), 0.95, 'all'); % normalize
        
        write_tiff_stack(fullfile(savePath, [files(i).name(1:end-4) '_Y_' num2str(numFrames) 'frames.tif']), Y);
    end
end
end

function write_tiff_stack( save_fn, volume)
save_fn = fullfile(save_fn);
imwrite(volume(:,:,1), save_fn);
for k = 2:size(volume,3)
    imwrite(volume(:,:,k), save_fn, 'WriteMode', 'append');
end
end