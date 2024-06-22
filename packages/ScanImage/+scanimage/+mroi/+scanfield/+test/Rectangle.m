classdef Rectangle < matlab.unittest.TestCase 
   methods(Test)
        function constructionExample(testcase)
            import matlab.unittest.constraints.*
            testcase.verifyThat(@() scanimage.mroi.scanfield.fields.Rectangle([1 2 3 4]),IssuesNoWarnings);
        end
    end
end


%--------------------------------------------------------------------------%
% Rectangle.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
