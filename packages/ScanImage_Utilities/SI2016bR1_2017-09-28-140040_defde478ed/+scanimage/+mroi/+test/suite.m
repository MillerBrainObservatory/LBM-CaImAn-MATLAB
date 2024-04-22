function s=suite
s=horzcat(...
    matlab.unittest.TestSuite.fromPackage('scanimage.mroi.test')...
    ,scanimage.mroi.scanfield .test.suite()...
    ,scanimage.mroi.scannerset.test.suite()...
    );
end


%--------------------------------------------------------------------------%
% suite.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
