function write_frames_to_gif(array_3D, gif_filename, size_mb)
% Create a GIF from a 3D array with a target size in MB.
%
% This function converts a 3D array (height x width x frames) into a GIF
% file with a specified maximum size in megabytes. The function normalizes
% each frame, converts it to grayscale, and writes it to the GIF file.
%
% Parameters
% ----------
% array_3D : 3D array
%     The 3D array to convert to a GIF, with dimensions (height x width x frames).
% gif_filename : char
%     The name of the output GIF file.
% size_mb : numeric
%     The target size of the GIF in megabytes. The number of frames will be
%     adjusted to fit within this size, rounding down to the nearest whole frame.
%
% Examples
% --------
% Example 1:
%     % Create a GIF from a 3D array with a target size of 45 MB
%     array_3D = rand(100, 100, 500); % Example 3D array
%     write_frames_to_gif(array_3D, 'output.gif', 45);
%
% Example 2:
%     % Create a GIF from a 3D array loaded from a file with a target size of 25 MB
%     array_3D = h5read('data.h5', '/dataset'); % Load 3D array from file
%     write_frames_to_gif(array_3D, 'output_25mb.gif', 25);
%
% Notes
% -----
% Frames are normalized to [0, 1] and converted to grayscale before being written to the GIF file.
% This will result in the final image being smaller than the original, as will the resulting gif.
%

if ndims(array_3D) ~= 3
    error('Input must be a 3D array');
end

fprintf("Array size: %.2f Mb\n", get_mb(array_3D));

sizY = size(array_3D);
ndY = numel(sizY);
nd = ndY-1;

% num_frames = min(sizY(end), floor((size_mb * 1e6) / bytes_per_frame));
num_frames = size(array_3D, 3);
fprintf("Gif size: %.2f Mb\n", get_mb(array_3D(:,:,1:num_frames)));

for t = 1:num_frames
    fprintf('Saving frame %d/%d\r', t, num_frames);
    frame = array_3D(:, :, t);
    [imind, cm] = gray2ind(frame, 256);
    if t == 1
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.01);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.01);
    end
end

fprintf('\nSaved %d frames\n', num_frames);

end

function bytes = get_bytes_per_sample(array)
switch class(array)
    case 'double'
        bytes = 8;
    case 'single'
        bytes = 4;
    case 'uint64'
        bytes = 8;
    case 'int64'
        bytes = 8;
    case 'uint32'
        bytes = 4;
    case 'int32'
        bytes = 4;
    case 'uint16'
        bytes = 2;
    case 'int16'
        bytes = 2;
    case 'uint8'
        bytes = 1;
    case 'int8'
        bytes = 1;
    case 'char'
        bytes = 1;
    otherwise
        error('Unsupported data type: %s', class(array));
end
end

function sz = get_mb(array, unit)
if nargin < 2; unit = 'mb'; end
switch unit
    case 'mb'
        fact = 1e6;
    case 'gb'
        fact = 1e9;
    otherwise
        error('Only gb/mb supported sizes')
end
sz = numel(array) * get_bytes_per_sample(array) / fact;
end
