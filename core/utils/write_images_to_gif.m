function write_images_to_gif(image_files, save_name, delay_time)
% Creates an animated GIF from a series images on disk.
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
%     Fully qualified name (folder + name + extension).
%     The directory and filename where the output GIF file will be saved.
% from_file : logical
%     Flag for whether inputs are filenames or in-memory data, true
%     indicates filenames. Default is true.
% delay_time : int, optional
%     Time, in ms, to delay each frame of the gif.
%

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

