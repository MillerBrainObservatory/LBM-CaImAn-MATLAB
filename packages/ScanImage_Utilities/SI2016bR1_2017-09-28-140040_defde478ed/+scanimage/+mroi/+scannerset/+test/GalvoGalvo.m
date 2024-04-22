classdef GalvoGalvo < matlab.unittest.TestCase
    properties
        default
    end
    methods(TestMethodSetup)
        function create(testcase)
            m=scanimage.mroi.scanners.Galvo.default();
            testcase.default=scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5);
        end
    end
    methods(TestMethodTeardown)
        function close(testcase)
            testcase.default=[];
        end
    end
    methods(Test)
        function constructionExample(testcase)
            import matlab.unittest.constraints.*
            m=scanimage.mroi.scanners.Galvo.default();
            testcase.verifyThat(@() scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5),IssuesNoWarnings);
        end
        
        function scanGenerationExample(testcase)
            % tests output has the right size
            % TODO: test that scan generates something that looks right
            import matlab.unittest.constraints.*
            sf = scanimage.mroi.scanfield.fields.Rectangle([0.1,0.1,0.1,0.1]);
            ao = testcase.default.scan(sf);
            testcase.verifyThat(size(ao,1),IsEqualTo(128*128));
            testcase.verifyThat(size(ao,2),IsEqualTo(2));
        end
        
        function transitTimeExample(testcase)
            import matlab.unittest.constraints.*
            from    = scanimage.mroi.scanfield.fields.Rectangle([0.1,0.1,0.1,0.1]);
            to      = scanimage.mroi.scanfield.fields.Rectangle([0.7,0.7,0.1,0.1]);
            seconds = testcase.default.transitTime(from,to);
            testcase.verifyThat(seconds,IsGreaterThan(0));
        end
        
        function transit(testcase) 
            import matlab.unittest.constraints.*
            from    = scanimage.mroi.scanfield.fields.Rectangle([0.1,0.1,0.1,0.1]);
            to      = scanimage.mroi.scanfield.fields.Rectangle([0.7,0.7,0.1,0.1]);
            ao = testcase.default.transit(from,to);
            testcase.verifyThat(size(ao,1),IsGreaterThan(0));
            testcase.verifyThat(size(ao,2),IsEqualTo(2));
        end
            
        function fullFieldIsConstructed(testcase)
            import matlab.unittest.constraints.*
            testcase.verifyThat(testcase.default.fullField,IsInstanceOf('scanimage.mroi.scanfield.ScanField'));
        end

        function parkingWorks(testcase)
            import matlab.unittest.constraints.*
            % Parking is done by passing []
            sf = scanimage.mroi.scanfield.fields.Rectangle([0.1,0.1,0.1,0.1]);
            testcase.verifyThat(...
                testcase.default.transitTime(sf,[]),...
                IsGreaterThan(0));
            testcase.verifyThat(...
                testcase.default.transitTime([],sf),...
                IsGreaterThan(0));

            ao=testcase.default.transit(sf,[]);
            testcase.verifyThat(size(ao,1),IsGreaterThan(0));

            ao=testcase.default.transit([],sf);
            testcase.verifyThat(size(ao,1),IsGreaterThan(0));
        end

        function nsamples(testcase)
            import matlab.unittest.constraints.*
            testcase.verifyThat(...
                testcase.default.nsamples(1),...
                IsEqualTo(5e5));
        end
    end
end


%--------------------------------------------------------------------------%
% GalvoGalvo.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
