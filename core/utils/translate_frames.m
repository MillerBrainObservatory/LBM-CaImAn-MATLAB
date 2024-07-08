function translatedFrames = translate_frames(Y, shifts_2D)
% Translate image frames based on provided translation vectors.
%
% This function applies 2D translations to an image time series based on
% a series of translation vectors, one per frame. Each frame is translated
% independently, and the result is returned as a 3D stack of
% (Height x Width x num_frames) translated frames.
%
% Parameters
% ----------
% Y - A 3D time series of image frames (Height x Width x Number of Frames).
% t_shifts - An Nx2 matrix of translation vectors for each frame (N is the number of frames).
%
% Returns
% -------
% translatedFrames - A 3D array of translated image frames, same size and type as Y.

arguments
	Y double {mustBeNumeric, mustBeNonempty}
	shifts_2D (:,2) double {mustBeNumeric, mustBeNonempty} % should match size as well
end

% Initialize the output array with the same size and type as Y
translatedFrames = zeros(size(Y), 'like', Y);

% Process each frame
for k = 1:size(Y, 3)
	current_frame = Y(:, :, k);  % Extract the k-th frame
	translation_vector = shifts_2D(k, :);  % Extract the translation vector for frame k
	% Note: Ensure the translation vector is in the correct order [X Y]
	translated_frame = imtranslate(current_frame, translation_vector, 'FillValues', 0);
	translatedFrames(:, :, k) = translated_frame;
end
end
