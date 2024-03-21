%
% Simple replacement function for imresize
%
%	Simplest user case:
%		Nearest pixel for now
%

function [imgOut] = imresize(varargin)
	%% Handle parameters
	% Ignore parameters after the second argument

	imgOut = [];


	if nargin == 0
	end

	% parse arguments
	switch nargin 
		case 0
			disp('Error: Unexpected number of arguments');
			return;
		case 1
			imgIn = varargin{1};
			imgOut = imgIn;
			return;
		case 2
			imgIn = varargin{1};
			imgOutParams = varargin{2};
		otherwise
			imgIn = varargin{1};
			imgOutParams = varargin{2};
			imgMethod = varargin{3};	%+++Add support for this, ignored for now
	end

	imgInSize = size(imgIn);
	imgInRows = imgInSize(1);
	imgInCols = imgInSize(2);

	if isscalar(imgOutParams)
		% In this case, we expect the scale directly
		imgOutRowScale = imgOutParams;
		imgOutColScale = imgOutParams;

		imgOutRows = floor(imgOutRowScale * imgInRows);
		imgOutCols = floor(imgOutColScale * imgInCols);
	else
		% Here, we expect the output size
		imgOutRows = imgOutParams(1);
		imgOutCols = imgOutParams(2);
		
		imgOutRowScale = floor(imgOutRows / imgInRows);
		imgOutColScale = floor(imgOutCols / imgInCols);
	end

	imgOut = zeros(imgOutRows, imgOutCols);

	for i = 1 : imgOutRows
		for j = 1 : imgOutCols
			imgOut(i,j) = imgIn(ceil(1/imgOutRowScale * i), ceil(1/imgOutColScale * j));
		end
	end
end


%--------------------------------------------------------------------------%
% imresize.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
