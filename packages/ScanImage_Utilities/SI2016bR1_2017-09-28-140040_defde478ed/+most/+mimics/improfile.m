function [c] = improfile(varargin)
%IMPROFILE Simple replacement function for improfile
%	Simple replacement function for improfile
%	The output will be a n by 1 vector for grayscale images for now
%
	if nargin == 5
		% parse arguments
		im = varargin{1};
		X = varargin{2};
		Y = varargin{3};		% This might need to be adjusted for axes direction
		n = varargin{4};		
		interpolationMode = varargin{5};

		% generate a collection XY of pointx that correspond to the path 
		% generalize from a single line to a path
		[xP, yP] = pathToImgPoints(X, Y, n);

		xP = xP';
		yP = yP';
		c = zeros(n,1);
		if size(xP) ~= size(c)
			keyboard;
			disp('Error: xP and c must be of the same size');
		end

		if strcmp(interpolationMode,'bilinear')
			for i = 1 : n
				c(i) = bilinearInterpolation(im, yP(i), xP(i));
			end
		else	% Do nearest neighbor assignment by default
			for i = 1 : n
				c(i) = im(round(yP(i)), round(xP(i)));
			end
		end
	else
		disp('Error: Unexpected number of arguments');
	end
end

function [xP, yP] = pathToImgPoints(X, Y, N)
	lenT = length(X);
	xP =[];
	yP =[];
	if lenT ~= length(Y)
		disp('most.mimics.improfile:pathToImgPoints Error: X and Y must have the same length');
		return
	end
	if lenT < 2
		disp('most.mimics.improfile:pathToImgPoints Error: length of X and Y must be greater or equal to 2');
		return
	end
	if N < 2
		disp('most.mimics.improfile:pathToImgPoints Error: N samples must be greater than 1');
		return
	end

	t = zeros(1, lenT);		% Cumulative pathDistatance vector
	sum = 0;
	t(1) = 0;	
	u = X;
	v = Y;
	for i = 1 : lenT - 1
		sum = sum + hypot(X(i+1)-X(i), Y(i+1) - Y(i));
		t(i+1) = sum;
	end

	% "Resampling"
	stepD = sum/(N-1);
	tq = 0:stepD:sum;
	xP = interp1(t,u,tq());
	yP = interp1(t,v,tq());
end

function [val] = bilinearInterpolation(img, desX, desY)
	[imgWidth, imgHeight] = size(img);
		
	% When the input exceeds image limits:
	if desX < 1 
		desX = 1;
	end 
	if desX > imgWidth 
		desX = imgWidth;
	end 
	if desY < 1 
		desY = 1;
	end 
	if desY > imgHeight 
		desY = imgHeight;
	end

	if abs(round(desX) - desX) < 0.0001 && abs(round(desY) - desY) < 0.0001
		val = img(round(desX), round(desY));
		return
	else
		x1 = floor(desX);
		y1 = floor(desY);
		x2 = ceil(desX);
		y2 = ceil(desY);
		del_x = x2 - x1;
		del_y = y2 - y1;

		if del_x == 0 && del_y == 0
			val = img(x1,y1);
		elseif del_x == 0
			val = img(x1,y1) * (y2 - desY) / del_y + img(x1,y2) * (desY - y1) / del_y;
		elseif del_y == 0
			val = img(x1,y1) * (x2 - desX) / del_x + img(x2,y1) * (desX - x1) / del_x;
		else
			val1 = img(x1,y1) * (x2 - desX) / del_x + img(x2,y1) * (desX - x1) / del_x;
			val2 = img(x1,y2) * (x2 - desX) / del_x + img(x2,y2) * (desX - x1) / del_x;
			val = val1 * (y2 - desY) / del_y + val2 * (desY - y1) / del_y;
		end
	end
end



%--------------------------------------------------------------------------%
% improfile.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
