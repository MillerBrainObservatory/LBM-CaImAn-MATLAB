function testResScan2D()
    h2D = scanimage.components.scan2d.ResScan2D();
    assignin('base','h2D',h2D);
    h2D.stripeAcquiredCallback = @(src,evnt)callbackFcn(src,evnt);
    h2D.start();
    h2D.trigIssueSoftwareAcq();
end

function callbackFcn(src,evnt)
    stripeData = src.readStripeData();
    fprintf('Received stripe: frameNumberAcqMode: %d, acqNumber: %d, frameNumberAcq:%d\n',...
        stripeData.frameNumberAcqMode, stripeData.acqNumber, stripeData.frameNumberAcq);
    
    if stripeData.endOfAcquisition
        disp('end of Acquisition');
    end
    
    if stripeData.endOfAcquisitionMode
        disp('end of AcquisitionMode');
    end
    
    assignin('base','stripeData',stripeData);
end


%--------------------------------------------------------------------------%
% testResScan2D.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
