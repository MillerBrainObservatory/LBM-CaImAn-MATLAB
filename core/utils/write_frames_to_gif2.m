function write_frames_to_gif2(array_3D, gif_filename, size_mb)
% Create a GIF from a 3D array with a target size in MB.
%
% Parameters
% ----------
% array_3D : 3D array
%     The 3D array (height x width x frames) to convert to a GIF.
% gif_filename : char
%     The name of the output GIF file.
% size_mb : numeric
%     The target size of the GIF in megabytes. Rounds down to the
%     nearest whole frame.
%
% Examples
% --------
% write_frames_to_gif(array_3D, 'output.gif', 45) % 45 Mb file

% Ensure array_3D is 3D
if ndims(array_3D) ~= 3
    error('Input must be a 3D array');
end

fprintf("Array size: %.2f Mb\n", get_mb(array_3D));

sizY = size(array_3D);
ndY = numel(sizY);
nd = ndY-1;

samples_per_frame = prod(sizY(1:nd));
bytes_per_sample = get_bytes_per_sample(array_3D(:,:,1));
bytes_per_frame = samples_per_frame * bytes_per_sample;

num_frames = min(sizY(end), floor((size_mb * 1e6) / bytes_per_frame));

fprintf("Gif size: %.2f Mb\n", get_mb(array_3D(:,:,1:num_frames)));

min_mov = min(array_3D(:));
max_mov = max(array_3D(:));
for t = 1:num_frames
    fprintf('Saving frame %d/%d\r', t, num_frames);
    frame = (array_3D(:, :, t) - min_mov) / (max_mov - min_mov);
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
