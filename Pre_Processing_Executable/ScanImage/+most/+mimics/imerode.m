%
% Simple replacement function for imerode
%
%	WARNING: Assumes input strel is of type "disk" with and argument of 2
%			 This is meant to work only with the cell selection routines for now
%

function [imgOut] = imerode(varargin)
	%% Handle parameters
	% Ignore parameters after the second argument

	if nargin ~= 2
		disp('Error: Unexpected number of arguments');
		return;
	end

	% parse arguments
	imgIn = varargin{1};
	ignoreMe = varargin{2};

	imgInSize = size(imgIn);
	binImg = most.mimics.im2bw(imgIn);
	imgTemp = ones(imgInSize+4);
	imgTemp(3:end-2, 3:end-2) = binImg(:,:);

	%Reenable for mex speed-ups
	%If you do, comment the code after the following line
	imgOut = most.mimics.imerode_helper(imgTemp);

	%% stel is the morphological structuring element
	%stel = ones(5,5);
	%stel(1,1) = 0;	stel(1,4) = 0;	stel(4,1) = 0; stel(4,5) = 0;
	%stel(1,2) = 0;	stel(1,5) = 0;	stel(5,1) = 0; stel(5,4) = 0;
	%stel(2,1) = 0;	stel(2,5) = 0;	stel(5,2) = 0; stel(5,5) = 0;

	%[rowStrel colStrel]=size(stel);
	%[rows cols]=size(binImg);
	%imgOut = zeros(imgInSize);
	%for i=1:rows
		%for j=1:cols
			%smallTemp = imgTemp(i:i+4,j:j+4);
			%idxTrue = find(stel==1);
			%if (smallTemp(idxTrue)==1)
				%imgOut(i,j) = 1;
			%end
		%end
	%end
end


%--------------------------------------------------------------------------%
% imerode.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
