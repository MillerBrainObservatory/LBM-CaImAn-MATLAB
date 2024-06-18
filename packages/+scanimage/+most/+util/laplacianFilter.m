function out = laplacianFilter(image)
    kernelSize = 9;
    sigma = 4;
    
    lin = round(linspace(-floor(kernelSize/2),floor(kernelSize/2),kernelSize));
    [X,Y] = meshgrid(lin,lin);
    hg = exp(-(X.^2 + Y.^2)/(2*(sigma^2)));
    kernel_t = hg.*(X.^2 + Y.^2-2*sigma^2)/(sigma^4*sum(hg(:)));
    % make the filter sum to zero
    kernel = kernel_t - sum(kernel_t(:))/kernelSize^2;
    
%     I = im2double(image);
%     out = conv2(I, kernel);
    out = kernel;

end


%--------------------------------------------------------------------------%
% laplacianFilter.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
