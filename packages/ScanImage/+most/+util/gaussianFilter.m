function Output = gaussianFilter()
    kernelSize = 9;
    sigma = 4;
    
    lin = round(linspace(-floor(kernelSize/2),floor(kernelSize/2),kernelSize));
    [X,Y] = meshgrid(lin,lin);
    kernel = exp(-(X.^2 + Y.^2)/(2*sigma^2));
    kernel = kernel/sum(kernel(:));

    Output = kernel;
end

%--------------------------------------------------------------------------%
% gaussianFilter.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
