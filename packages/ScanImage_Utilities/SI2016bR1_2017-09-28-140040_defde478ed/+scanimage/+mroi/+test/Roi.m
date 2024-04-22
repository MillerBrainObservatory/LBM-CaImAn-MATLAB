classdef Roi < matlab.unittest.TestCase

    methods(Test)
        function constructionExample(testcase)
            import matlab.unittest.constraints.*
            testcase.verifyThat(@scanimage.mroi.Roi,IssuesNoWarnings);
        end
        
        function hitDetectionExample(testcase) 
            import matlab.unittest.constraints.*
            r = scanimage.mroi.Roi();
            r.add(1 ,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            testcase.verifyThat(r.hit(0),IsFalse);
            testcase.verifyThat(r.hit(1),IsTrue);
            testcase.verifyThat(r.hit(5),IsTrue);
            testcase.verifyThat(r.hit(10),IsTrue);
            testcase.verifyThat(r.hit(10.1),IsFalse);
        end

        function scanGenerationExample(testcase)
            import matlab.unittest.constraints.*
            import matlab.unittest.constraints.*
            import scanimage.mroi.scannerset.*
            import scanimage.mroi.scanners.*;
            r=scanimage.mroi.Roi();
            
            g=Galvo.default();
            scanner=GalvoGalvo(g,g,5e5);
            % empty
            testcase.verifyThat(r.time(scanner,5),IsEqualTo(0));
            % ... Add stuff ...
            r.add(1 ,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            testcase.assertThat(r.hit(5),IsTrue);
            % Note: the scanfield in this test is some random subset of the
            % field of view, so it can be hard to interpret from a plot.
            %           plot(r.scan(scanner,128,128,5));
            testcase.verifyThat(size(r.scan(scanner,5),1),IsGreaterThanOrEqualTo(1));
            testcase.verifyThat(size(r.scan(scanner,5),2),IsGreaterThanOrEqualTo(1));
            testcase.assertThat(r.hit(0),IsFalse);
            testcase.verifyThat(r.scan(scanner,0),IsEmpty);
        end

        function scanTakesFiniteTime(testcase)
            import matlab.unittest.constraints.*
            import scanimage.mroi.scannerset.*
            import scanimage.mroi.scanners.*
            r=scanimage.mroi.Roi();
            g=Galvo.default();
            scanner=GalvoGalvo(g,g,5e5);
            % empty
            testcase.verifyThat(r.time(scanner,5),IsEqualTo(0));
            % ... Add stuff ...
            r.add(1 ,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            testcase.assertThat(r.hit(5),IsTrue);
            testcase.verifyThat(r.time(scanner,5),IsGreaterThan(0));
            testcase.assertThat(r.hit(0),IsFalse);
            testcase.verifyThat(r.time(scanner,0),IsEqualTo(0));
        end

        function canAddScanFields(testcase)
            import matlab.unittest.constraints.*
            r=scanimage.mroi.Roi();
            r.add(1 ,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            % verify added two things
            testcase.verifyThat(r.zs,HasElementCount(2));
            testcase.verifyThat(r.scanfields,HasElementCount(2));
        end

        function addScanFieldChecksType(testcase)
            import matlab.unittest.constraints.*
            r=scanimage.mroi.Roi();
            testcase.verifyThat(@() r.add(1,[3,4,5]),Throws('MROI:TypeError'));
        end

        function addScanFieldChecksThatAllAreSameKind(testcase)
            import matlab.unittest.constraints.*
            r=scanimage.mroi.Roi();
            r.add(1 ,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4)));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle(rand(1,4))); % should be ok
            %r.add(1 ,scanimage.mroi.scanfield.Polygon  (rand(2,4))); % no good
        end
    end

end


%--------------------------------------------------------------------------%
% Roi.m                                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
