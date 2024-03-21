%
% Simple replacement function for imshow
% 

function [imRef] = imshow(varargin)
	%% Handle parameters
	rendParams = [];
	if nargin == 0
		disp('Error: Unexpected number of arguments');
		return;
	end

	idx = 1;
	rendParams = ['varargin{' num2str(idx) '}'];

	%% In imagesc, this should be the last argument
	if mod(nargin, 2) == 0
		idx = idx + 1;
	end

	idx = idx + 1;
	while (idx <= nargin)
		if isstr(varargin{idx}) && (strcmp(varargin{idx},'Border') || strcmp(varargin{idx},'tight'))
			idx = idx + 2; 
			% Matlab doesn't allow this in for loops, which kind of makes 
			% considering scope differences with C++
			continue;
		end
		rendParams = [rendParams  ', varargin{' num2str(idx) '}'];
		idx = idx + 1;
	end

	%if ~isempty(lastArg)
	if mod(nargin, 2) == 0
		rendParams = [rendParams  ', varargin{2}'];
	end

	eval(['imRef = imagesc(' rendParams ');']);
end


%--------------------------------------------------------------------------%
% imshow.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
