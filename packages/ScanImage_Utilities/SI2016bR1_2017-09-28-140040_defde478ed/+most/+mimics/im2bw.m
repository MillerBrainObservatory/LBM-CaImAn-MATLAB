%	Assumes single-channel input image 
%	
%	requires a threshold as a second argument
%

function [imgOut] = im2bw(varargin)
	%% Handle parameters
	% Ignore parameters after the second argument
	if nargin == 1
		imgIn = varargin{1};
		thresh = 0.5;
	elseif nargin == 2
		imgIn = varargin{1};
		thresh = varargin{2};
	else
		disp('Most.Error: Unexpected number of arguments');
		return;
	end

	imgSize = size(imgIn);
	imgDim = length(imgSize);
	if imgDim > 2
		disp('Most.Error: Unexpected image structure');
		return;
	end

	imgOut = zeros(imgSize);
	for i = 1 : imgSize(1)
		for j = 1 : imgSize(2)
			if imgIn(i,j) > thresh
				imgOut(i,j) = 1;
			end
		end
	end
end


%--------------------------------------------------------------------------%
% im2bw.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
