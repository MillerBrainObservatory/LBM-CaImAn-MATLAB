function edge = edgeFilter(img, tf)
    gFilt = most.util.gaussianFilter();
    
    if nargin < 2 || isempty(tf)
       tf = false; 
    end
    
    if tf
        im = single(gpuArray(img));
    else
        im = single((img));
    end
    
    gFilteredImage = conv2(gFilt, im);
    gFilteredImage = gFilteredImage(5:end-4, 5:end-4);
    edge = im-gFilteredImage;
end

%--------------------------------------------------------------------------%
% edgeFilter.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
