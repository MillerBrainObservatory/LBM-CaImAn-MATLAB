function write_images_to_gif(image_files, save_name, delay_time)
% Creates an animated GIF from a series of images **on disk**.
%
% This function generates an animated GIF from a series of images specified
% by their file paths. The images are read, converted to indexed color, and
% sequentially written to a GIF file with a specified delay between frames.
%
% Parameters
% ----------
% image_files : cell array of strings
%     A cell array containing the file paths of the images to be included in the GIF.
% save_name : string
%     The directory and filename where the output GIF file will be saved.
% delay_time : int, optional
%     Time, in seconds, to delay each frame of the GIF. Defaults to 0.5 seconds.
%
% Returns
% -------
% None
%
% Notes
% -----
% The function reads each image file, converts it to an indexed color map, and writes
% it to the GIF file. The first image initializes the GIF file, and subsequent images
% are appended. If the delay_time parameter is not specified, it defaults to 0.5 seconds
% between frames. The function checks for valid input types and existence of image files
% before proceeding with the GIF creation.

if ~exist("delay_time", "var"); delay_time = 0.5; end
if ~iscell(image_files); error("First argument must be of type: Cell, not:\n%s", class(image_files)); end
if ~isfile(image_files{1}); error("%s is not a valid file.", save_name); end

for i = 1:length(image_files)
    % make sure its greyscale for imwrite
	[img, cmap] = rgb2ind(imread(image_files{i}), 256);
	if i == 1
		imwrite(img, cmap, save_name, 'gif', 'LoopCount', Inf, 'DelayTime', delay_time);
	else
		imwrite(img, cmap, save_name, 'gif', 'WriteMode', 'append', 'DelayTime', delay_time);
	end
end
fprintf("Timeseries successfully saved as a .gif to:\n%s", save_name);
end

