function outputMatrix = matResize(inputMatrix,scale)
%MATRESIZE Resizes a matrix.
%
% inputMatrix: the matrix data to resize.
% 
% scale: either a scalar factor by which to scale the matrix, or a 2-vector
% indicating [numRows,numCols] of the output matrix.
        
    if nargin < 2 || isempty(scale)
        error('Insufficient arguments');
    end

    if isscalar(scale)
        mNew = floor(size(inputMatrix,1)/scale);
        nNew = floor(size(inputMatrix,2)/scale);
    elseif length(scale) == 2
        mNew = scale(1);
        nNew = scale(2);
    else
        error('Invalid argument.');
    end
    
    [m,n,~] = size(inputMatrix);
    [X,Y] = meshgrid( (0:n-1)/(n-1), (0:m-1)/(m-1) );
    [XI,YI] = meshgrid( (0:nNew-1)/(nNew-1) , (0:mNew-1)/(mNew-1) );
    outputMatrix = zeros(mNew,nNew,size(inputMatrix,3));
    for i = 1:size(inputMatrix,3)
        outputMatrix(:,:,i) = max(interp2(X,Y,inputMatrix(:,:,i),XI,YI,'cubic',0),0.0); % max() clamps any values < 0.0
    end

end



%--------------------------------------------------------------------------%
% matResize.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
