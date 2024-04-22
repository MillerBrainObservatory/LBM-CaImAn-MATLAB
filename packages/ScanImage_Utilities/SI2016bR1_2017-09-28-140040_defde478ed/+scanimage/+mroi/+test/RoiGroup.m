classdef RoiGroup < matlab.unittest.TestCase
    methods(Test)
        
        function constructionExample(testcase)
            import matlab.unittest.constraints.*
            testcase.verifyThat(@scanimage.mroi.RoiGroup,IssuesNoWarnings);
        end
        
        function timeExample(testcase)
            import matlab.unittest.constraints.*
            import scanimage.mroi.scanners.*
            g=scanimage.mroi.RoiGroup();
            m=Galvo.default();
            s=scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5);  
            % no rois
            testcase.verifyThat(g.planeTime(s,5),IsEqualTo(1e-3+128*128/5e5+1e-3));
            % add empty roi
            r=scanimage.mroi.Roi();
            g.add(r);
            testcase.verifyThat(g.planeTime(s,5),IsEqualTo(0));
            % add non-trivial roi
            r.add(1,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            testcase.verifyThat(g.planeTime(s,5),IsEqualTo(1e-3+128*128/5e5+1e-3));
            % add another non-trivial roi
            r=scanimage.mroi.Roi();            
            g.add(r);
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.4 0.5 0.1 0.2]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.4 0.5 0.1 0.2]));
            testcase.verifyThat(g.planeTime(s,5),IsEqualTo(1e-3+128*128/5e5+1e-3+128*128/5e5+1e-3));
        end
        
        function scanExample(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            m=scanimage.mroi.scanners.Galvo.default();
            s=scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5);  
            % no rois -- full field of view
            % time to scan + two parking transits -- not ideal
            testcase.verifyThat(g.scan(s,5),HasSize([128*128+1000 2]));
            % add empty roi
            r=scanimage.mroi.Roi();
            g.add(r);
            testcase.verifyThat(g.scan(s,5),IsEmpty);
            % add one non-trivial roi
            r.add(1,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            ao=g.scan(s,5);
            testcase.verifyThat(size(ao,1),IsEqualTo(128*128+1000)); % scan + two parking transits
            testcase.verifyThat(size(ao,2),IsEqualTo(2));
            % add another non-trivial roi
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            g.add(r);
            ao=g.scan(s,5);
            %include transits
            testcase.verifyThat(size(ao,1),IsGreaterThan(2*128*128));
            testcase.verifyThat(size(ao,2),IsEqualTo(2));
            % add another non-trivial roi
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            g.add(r);
            ao=g.scan(s,5);
            %include transits
            testcase.verifyThat(size(ao,1),IsGreaterThan(3*128*128));
            testcase.verifyThat(size(ao,2),IsEqualTo(2));
        end
        
        function scanfieldCountExample(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            m=scanimage.mroi.scanners.Galvo.default();
            s=scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5);  
            % no rois -- full field of view
            testcase.verifyThat(g.nfields(5),IsEqualTo(1));
            % add empty roi
            r=scanimage.mroi.Roi();
            g.add(r);
            % add one non-trivial roi
            r.add(1,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            testcase.verifyThat(g.nfields(5),IsEqualTo(1));
            % add another non-trivial roi
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            g.add(r);
            testcase.verifyThat(g.nfields(5),IsEqualTo(2));
            % add another non-trivial roi
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            g.add(r);
            testcase.verifyThat(g.nfields(5),IsEqualTo(3));
        end

        function scanfieldGetterExample(testcase)
            % TODO
        end
        
        function timingExample(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            m=scanimage.mroi.scanners.Galvo.default();
            ss=scanimage.mroi.scannerset.GalvoGalvo(m,m,5e5);  
            % no rois -- full field of view
            [t,s]=g.timing(ss,5,1);
            testcase.verifyThat(t,IsEqualTo(1e-3));
            testcase.verifyThat(s,IsEqualTo(0.032768));
            % add empty roi
            r=scanimage.mroi.Roi();
            g.add(r);
            [t,s]=g.timing(ss,5,1);
            testcase.verifyThat(t,IsEqualTo(0));
            testcase.verifyThat(s,IsEqualTo(0));
            % add a few non-trivial roi
            r.add(1,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            r.add(10,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.7 0.7 0.1 0.1]));
            g.add(r);
            r=scanimage.mroi.Roi();
            r.add(3,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            r.add(7,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.9 0.1 0.1]));
            g.add(r);

            [t,s]=g.timing(ss,5,1);
            testcase.verifyThat(t,IsEqualTo(1e-3));
            testcase.verifyThat(s,IsEqualTo(0.032768));
            [t,s]=g.timing(ss,5,2);
            testcase.verifyThat(t,IsEqualTo(1e-3));
            testcase.verifyThat(s,IsEqualTo(0.032768));
            [t,s]=g.timing(ss,5,3);
            testcase.verifyThat(t,IsEqualTo(1e-3));
            testcase.verifyThat(s,IsEqualTo(0.032768));
        end

        function emptyRoiGroupReturnsFullFieldOfView(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            s=scanimage.mroi.scannerset.GalvoGalvo.default;
            testcase.verifyThat(g.rois(s),IsOfClass(?scanimage.mroi.Roi));
            % should return a default full field-of-view
            testcase.verifyThat(g.rois(s),HasElementCount(1));
            % some random plane (z=10) is the expected field of view
            testcase.verifyThat(g.rois(s).get(10),IsOfClass(?scanimage.mroi.scanfield.fields.RotatedRectangle));             
        end
        
        function addRoiBasics(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            s=scanimage.mroi.scannerset.GalvoGalvo.default;
            testcase.verifyThat(g.rois(s),IsOfClass(?scanimage.mroi.Roi));
            % should return a default full field-of-view
            testcase.verifyThat(g.rois(s),HasElementCount(1));
            g.add(scanimage.mroi.Roi());
            testcase.verifyThat(g.rois(s),IsOfClass(?scanimage.mroi.Roi));
            testcase.verifyThat(g.rois(s),HasElementCount(1));
            g.add(scanimage.mroi.Roi());
            testcase.verifyThat(g.rois(s),HasElementCount(2));
        end
        
        function addRoiChecksType(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            r=scanimage.mroi.Roi();
            g.add(r); % should be ok
            testcase.verifyThat(@()g.add('hi there'),Throws('MROI:TypeError'));
        end
        
        function canModifyRoiByReference(testcase)
            import matlab.unittest.constraints.*
            g=scanimage.mroi.RoiGroup();
            r=scanimage.mroi.Roi();
            g.add(r);
            r.add(1,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            testcase.verifyThat(g.rois(1).scanfields,HasElementCount(1));
            g.rois(1).add(10,scanimage.mroi.scanfield.fields.Rectangle([0.1 0.1 0.2 0.3]));
            testcase.verifyThat(g.rois(1).scanfields,HasElementCount(2));
        end
    end
end


%--------------------------------------------------------------------------%
% RoiGroup.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
