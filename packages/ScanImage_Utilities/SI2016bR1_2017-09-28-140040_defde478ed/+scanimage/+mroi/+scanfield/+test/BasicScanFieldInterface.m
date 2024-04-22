classdef BasicScanFieldInterface < matlab.unittest.TestCase
    
    
    properties
        xs
        ys
        
        % See Note (4)
        scanfields
    end
    
    methods(TestMethodSetup)
        function unitscan(testcase)
            nx=320;
            ny=240;
            [y,x]=meshgrid((1:ny)-1,(1:nx)-1);
            testcase.xs=x./nx;
            testcase.ys=y./ny;
        end
        
        function parameters(testcase)
            testcase.scanfields = {...
                scanimage.mroi.scanfield.fields.Rectangle([0.1,0.2,0.3,0.4]),...
                scanimage.mroi.scanfield.fields.RotatedRectangle([0.5,0.5,0.2,0.3],15),...
                scanimage.mroi.scanfield.FullField...
                };
        end
    end
    
    methods(Test)
        function interpolationExample(testcase)
            import matlab.unittest.constraints.*;
            for iscanfield=1:length(testcase.scanfields)
                scanfield=testcase.scanfields{iscanfield};
                other=scanfield; % just make a copy
                
                sf=scanfield.interpolate(other,0.5);
                testcase.verifyThat(sf,IsOfClass(class(scanfield))); % return type is same as input type
                
                %  Implementations should check the input scanfield type
                other=scanimage.mroi.scanfield.test.Dummy();
                testcase.verifyThat(@()scanfield.interpolate(other,0.5),...
                    Throws('MROI:TypeError'));
                
                % Also see Note's (2) and (3)
            end
        end
        
        function boundingboxExample(testcase)
            import matlab.unittest.constraints.*;
            
            for iscanfield=1:length(testcase.scanfields)
                scanfield=testcase.scanfields{iscanfield};
                rect=scanfield.boundingbox();
                testcase.verifyThat(rect,IsOfClass('double'));
                testcase.verifyThat(rect,HasSize([1 4]));
            end
        end
        function hitExample(testcase)
            import matlab.unittest.constraints.*;
            
            for iscanfield=1:length(testcase.scanfields)
                scanfield=testcase.scanfields{iscanfield};
                bw=scanfield.hit(testcase.xs,testcase.ys);
                testcase.verifyThat(bw,IsOfClass('logical'));
                testcase.verifyThat(bw,HasSize(size(testcase.xs)));                
            end
        end
        
        function transformExample(testcase)
            import matlab.unittest.constraints.*;
            for iscanfield=1:length(testcase.scanfields)
                scanfield=testcase.scanfields{iscanfield};
                [xx,yy]=scanfield.transform(testcase.xs,testcase.ys);
                testcase.verifyThat(xx,IsOfClass('double'));
                testcase.verifyThat(xx,HasSize(size(testcase.xs)));
                testcase.verifyThat(yy,IsOfClass('double'));
                testcase.verifyThat(yy,HasSize(size(testcase.ys)));
                
                % See Note (1)
                testcase.verifyThat(min(xx(:)),IsGreaterThanOrEqualTo(0.0));
                testcase.verifyThat(min(yy(:)),IsGreaterThanOrEqualTo(0.0));
                testcase.verifyThat(max(xx(:)),IsLessThanOrEqualTo(1.0));
                testcase.verifyThat(max(yy(:)),IsLessThanOrEqualTo(1.0));
            end
        end
    end
end

%% NOTES
%{
    1. These bounds checks are mostly just to make sure implementations aren't
       super crazy.

       ScannerSet implementations should check that the voltage's generated for
       a scan pattern are in bounds.

       The ScanField "hit" method could be required to mask for when
       the described area goes out of the field-of-view box, but I'm thinking
       that this should really be delegated to the ScannerSet; it has more
       information about what constraints are important there.

    2. Maybe test for endpoint equality
       Would need to add equality operator, so only add if needed
            sf=scanfield.interpolate(other,0);
            sf=scanfield.interpolate(other,1);

    3. Maybe test for out-of-bounds behavior
       Not sure what the convention should be (if any), so only add if needed
            sf=scanfield.interpolate(other,1.5);
            sf=scanfield.interpolate(other,-1.5);

    4. UPGRADE
       Matlab R2014 has parameterized tests, which would be ideal here.
       Since I'm targeting R2013B at the moment use of paramters will be
       manual.  This should be migrated when we update to target R2014+.
%}


%--------------------------------------------------------------------------%
% BasicScanFieldInterface.m                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
