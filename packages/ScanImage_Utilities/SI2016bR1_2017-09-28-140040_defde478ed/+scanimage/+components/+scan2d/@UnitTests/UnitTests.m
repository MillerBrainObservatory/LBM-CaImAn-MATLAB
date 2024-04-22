classdef UnitTests < handle
 
    % Example Usage:
    %   >> obj = scanimage.components.scan2d.UnitTests('c:\Temp\')
    %   >> [res, numFailed] = obj.testAll()         => Run All Unit Tests
    %   >> [res, numFailed] = obj.testAllNewFile()  => Run All New File Unit Tests
    %   >> r1 = obj.testNewFileGood()               => Run a single New File Unit Test
    
    properties(Access = private)
        tiffFileDirectory = '';
        tw;
        testFrame;
        testFrameSize;
        
        % 3001 Series
        img1;
        img2;
    end % private properties
    
    methods(Access = public)    % Constructor
        
        function obj = UnitTests(testTiffFileDirectory)
            import scanimage.components.scan2d.TiffStream;
            obj.tw = scanimage.components.scan2d.TiffStream;
            
            obj.tiffFileDirectory = testTiffFileDirectory;
            
            obj.testFrame = double(ones(512, 512));
            obj.testFrameSize = 512 * 512;
            
            %3001 Series Initialization
            obj.img1 = int16(zeros(37 * 56));
            obj.img2 = int16(zeros(49 * 38 * 2 * 3));
            
            for dx = 1 : (37 * 56)
                
                obj.img1(dx) = mod(dx, 3) * 50;
                    
            end % for - dx

            for dx = 1 : (49 * 38 * 2)
                
                obj.img2(dx) = mod(dx, 2) * 10000;
                    
            end % for - dx
                        
            for dx = (49 * 38 * 2) : ((49 * 38) * 2)
                
                obj.img2(dx) = mod(dx, 3) * 10000;
                    
            end % for - dx
                        
            for dx = ((49 * 38) * 2 * 2) : ((49 * 38) * 2)
                
                obj.img2(dx) = mod(dx, 4) * 10000;
                    
            end % for - dx

        end
        
    end % Constructor
    
    methods(Access = public)    % Test all methods section
    
        function [res, numFailed] = testAll(obj)
            
            [r1,n1] = obj.testAllCleanUp();
            [r2,n2] = obj.testAllOpen();
            [r3,n3] = obj.testAllNewFile();
            [r4,n4] = obj.testAllClose();
            [r5,n5] = obj.testAllCloseWithAppendedData();
            [r6,n6] = obj.testAllUpdateDescription();
            [r7,n7] = obj.testAllReplaceImageDescription();
            [r8,n8] = obj.testAllAppendFrame();
            [r9,n9] = obj.testAllConfigureImage();
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9); 
            
            numFailed = n1 + n2 + n3 + n4 + n5 + n6 + n7 + n8 + n9;
            
        end % testAll
        
        function [res, numFailed]  = testAllAppendFrame(obj)

            numFailed = 0;
            
            r1 = obj.TestAppendGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestAppendGood_TwiceCall();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.TestAppendBad_NoOpen();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.TestAppendGood_NoConfig();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.TestAppendBad_CallAfterClose();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.TestAppendBad_CallAfterCleanUp();
            if (~r6)
                numFailed = numFailed + 1;
            end
            
            r7 = obj.TestAppendBad_SizeLessThanImage();
            if (~r7)
                numFailed = numFailed + 1;
            end
                        
            r8 = obj.TestAppendBad_EmptyImage();
            if (~r8)
                numFailed = numFailed + 1;
            end
            
            r9 = obj.TestAppendBad_ZeroSize();
            if (~r9)
                numFailed = numFailed + 1;
            end
            
            r10 = obj.TestAppendBad_NegativeSize();
            if (~r10)
                numFailed = numFailed + 1;
            end
            
            r11 = obj.TestAppendBad_SizeGreaterThanImage();
            if (~r11)
                numFailed = numFailed + 1;
            end
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10 && r11);
            
        end % testAllAppendFrame
        
        function [res, numFailed]  = testAllCleanUp(obj)

            numFailed = 0;
            
            r1 = obj.testCleanUpGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.testCleanUpGood_CalledTwice();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.testCleanUpGood_NoTiffOpen();
            if (~r3)
                numFailed = numFailed + 1;
            end            
            
            res = (r1 && r2 && r3);
            
        end % testAllCleanUp
            
        function [res, numFailed]  = testAllClose(obj)

            numFailed = 0;
            
            r1 = obj.TestCloseGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestCloseGood_TwiceCall();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.TestCloseBad_NoOpen();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.TestCloseBad_AfterCleanUp();
            if (~r4)
                numFailed = numFailed + 1;
            end
                        
            res = (r1 && r2 && r3 && r4);
            
        end % testAllClose
        
        function [res, numFailed]  = testAllCloseWithAppendedData(obj)

            numFailed = 0;
            
            r1 = obj.TestCloseAppendedGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestCloseAppendedGood_TwiceCall();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.TestCloseAppendedBad_NaNDataZeroLen();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.TestCloseAppendedBad_EmptyDataZeroLen();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.TestCloseAppendedBad_DataWithZeroLen();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.TestCloseAppendedGood_DataWithPositiveGreaterLen();
            if (~r6)
                numFailed = numFailed + 1;
            end
            
            r7 = obj.TestCloseAppendedGood_DataWithPositiveLesserLen();
            if (~r7)
                numFailed = numFailed + 1;
            end
            
            r8 = obj.TestCloseAppendedBad_EmptyDataPositiveLen();
            if (~r8)
                numFailed = numFailed + 1;
            end
            
            r9 = obj.TestCloseAppendedBad_NoOpen();
            if (~r9)
                numFailed = numFailed + 1;
            end
            
            r10 = obj.TestCloseAppendedBad_AfterCleanUp();
            if (~r10)
                numFailed = numFailed + 1;
            end
            
            r11 = obj.TestCloseAppendedBad_NaNDataPositiveLen();
            if (~r11)
                numFailed = numFailed + 1;
            end
            
            r12 = obj.TestCloseAppendedBad_DataWithNegativeLen();
            if (~r12)
                numFailed = numFailed + 1;
            end
            
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10 && r11 && r12);
            
        end % testAllCloseWithAppendedData
                
        function [res, numFailed] = testAllConfigureImage(obj)

            numFailed = 0;
            
            r1 = obj.testConfigureImageGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.testConfigureImageGood_CalledTwice();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.testConfigureImageGood_CallAfterClose();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.testConfigureImageGood_CallAppendCloseOpenAppend();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.testConfigureImageBad_TiffStreamNotOpen();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.testConfigureImageBad_CallAfterCleanUp();
            if (~r6)
                numFailed = numFailed + 1;
            end
            
            r7 = obj.testConfigureImageBad_ZeroWidth();
            if (~r7)
                numFailed = numFailed + 1;
            end
            
            r8 = obj.testConfigureImageBad_NegativeWidth();
            if (~r8)
                numFailed = numFailed + 1;
            end
            
            r9 = obj.testConfigureImageBad_NullWidth();
            if (~r9)
                numFailed = numFailed + 1;
            end
            
            r10 = obj.testConfigureImageBad_ZeroLength();
            if (~r10)
                numFailed = numFailed + 1;
            end
            
            r11 = obj.testConfigureImageBad_NegativeLength();
            if (~r11)
                numFailed = numFailed + 1;
            end
            
            r12 = obj.testConfigureImageBad_NullLength();
            if (~r12)
                numFailed = numFailed + 1;
            end
            
            r13 = obj.testConfigureImageBad_ZeroBytesPerPixel();
            if (~r13)
                numFailed = numFailed + 1;
            end
            
            r14 = obj.testConfigureImageBad_NegativeBytesPerPixel();
            if (~r14)
                numFailed = numFailed + 1;
            end
            
            r15 = obj.testConfigureImageBad_NullBytesPerPixel();
            if (~r15)
                numFailed = numFailed + 1;
            end
            
            r16 = obj.testConfigureImageBad_ZeroChannels();
            if (~r16)
                numFailed = numFailed + 1;
            end
            
            r17 = obj.testConfigureImageBad_NegativeChannels();
            if (~r17)
                numFailed = numFailed + 1;
            end
            
            r18 = obj.testConfigureImageBad_NullChannels();
            if (~r18)
                numFailed = numFailed + 1;
            end
            
            r19 = obj.testConfigureImageBad_NullSignedData();
            if (~r19)
                numFailed = numFailed + 1;
            end
            
            r20 = obj.testConfigureImageBad_ZeroTargetBytes();
            if (~r20)
                numFailed = numFailed + 1;
            end
            
            r21 = obj.testConfigureImageBad_NegativeTargetBytes();
            if (~r21)
                numFailed = numFailed + 1;
            end
            
            r22 = obj.testConfigureImageBad_NullTargetBytes();
            if (~r22)
                numFailed = numFailed + 1;
            end
            
            r23 = obj.testConfigureImageGood_NullDescription();
            if (~r23)
                numFailed = numFailed + 1;
            end
            
            r24 = obj.testConfigureImageGood_EmptyDescription();
            if (~r24)
                numFailed = numFailed + 1;
            end
                        
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10 && r11 && r12 ...
                && r13 && r14 && r15 && r16 && r17 && r18 && r19 && r20 && r21 && r22 && r23 && r24);
            
        end %testAllConfigureImage
        
        function [res, numFailed]  = testAllNewFile(obj)

            numFailed = 0;
            
            r1 = obj.testNewFileGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.testNewFileGood_CalledTwice();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.testNewFileBad_FilenameNaN();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.testNewFileBad_FilenameEmpty();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.testNewFileBad_TiffStreamNotOpen();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.testNewFileBad_CallAfterCleanUp();
            if (~r6)
                numFailed = numFailed + 1;
            end
                     
            r7 = testNewFileBad_MetadataNaN(obj);
            if (~r7)
                numFailed = numFailed + 1;
            end
                        
            r8 = testNewFileBad_MetadataEmpty(obj);
            if (~r8)
                numFailed = numFailed + 1;
            end
                        
            r9 = testNewFileBad_MetadataSizeZero(obj);
            if (~r9)
                numFailed = numFailed + 1;
            end
                        
            r10 = testNewFileBad_MetadataSizeNegative(obj);
            if (~r10)
                numFailed = numFailed + 1;
            end
                        
            r11 = testNewFileBad_MetadataOffsetZero(obj);
            if (~r11)
                numFailed = numFailed + 1;
            end
                        
            r12 = testNewFileBad_MetadataOffsetNegative(obj);
            if (~r12)
                numFailed = numFailed + 1;
            end
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10 && r11 && r12);
            
        end % testAllNewFile
        
        function [res, numFailed]  = testAllOpen(obj)

            numFailed = 0;
            
            r1 = testOpenGood(obj);
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = testOpenGood_CalledTwice(obj);
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = testOpenBad_FilenameNaN(obj);
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = testOpenBad_FilenameEmpty(obj);
            if (~r4)
                numFailed = numFailed + 1;
            end
                        
            r5 = testOpenBad_MetadataNaN(obj);
            if (~r5)
                numFailed = numFailed + 1;
            end
                        
            r6 = testOpenBad_MetadataEmpty(obj);
            if (~r6)
                numFailed = numFailed + 1;
            end
                        
            r7 = testOpenBad_MetadataSizeZero(obj);
            if (~r7)
                numFailed = numFailed + 1;
            end
                        
            r8 = testOpenBad_MetadataSizeNegative(obj);
            if (~r8)
                numFailed = numFailed + 1;
            end
                        
            r9 = testOpenBad_MetadataOffsetZero(obj);
            if (~r9)
                numFailed = numFailed + 1;
            end
                        
            r10 = testOpenBad_MetadataOffsetNegative(obj);
            if (~r10)
                numFailed = numFailed + 1;
            end
                        
            res = r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10;
            
        end % testAllOpen
        
        function [res, numFailed]  = testAllUpdateDescription(obj)

            numFailed = 0;
            
            r1 = obj.TestUpdateDescGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestUpdateDescGood_CallTwice();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.TestUpdateDescBad_NaNBuf();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.TestUpdateDescBad_EmptyBuf();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.TestUpdateDescBad_NegativeLoc();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.TestUpdateDescBad_ExceededLoc();
            if (~r6)
                numFailed = numFailed + 1;
            end
            
            r7 = obj.TestUpdateDescBad_NegativeCount();
            if (~r7)
                numFailed = numFailed + 1;
            end
            
            r8 = obj.TestUpdateDescGood_ZeroCount();
            if (~r8)
                numFailed = numFailed + 1;
            end
            
            r9 = obj.TestUpdateDescGood_MissMatchCount();
            if (~r9)
                numFailed = numFailed + 1;
            end
            
            r10 = obj.TestUpdateDescGood_GreaterCount();
            if (~r10)
                numFailed = numFailed + 1;
            end
            
            r11 = obj.TestUpdateDescGood_BufferMoreThanDesc();
            if (~r11)
                numFailed = numFailed + 1;
            end
            
            r12 = obj.TestUpdateDescGood_ReplacementExceedsDesc();
            if (~r12)
                numFailed = numFailed + 1;
            end
            
            r13 = obj.TestUpdateDescBad_CallNoConfig();
            if (~r13)
                numFailed = numFailed + 1;
            end
            
            r14 = obj.TestUpdateDescBad_CallNoOpen();
            if (~r14)
                numFailed = numFailed + 1;
            end
            
            r15 = obj.TestUpdateDescBad_CallAfterCleanUp();
            if (~r15)
                numFailed = numFailed + 1;
            end
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7 && r8 && r9 && r10 && r11 && r12 && r13 && r14 && r15);
            
        end % testAllUpdateDescription        

        function [res, numFailed]  = testAllReplaceImageDescription(obj)

            numFailed = 0;
            
            r1 = obj.TestReplaceImageDescGood();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestReplaceImageDescGood_CallTwice();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            r3 = obj.TestReplaceImageDescBad_NaNDesc();
            if (~r3)
                numFailed = numFailed + 1;
            end
            
            r4 = obj.TestReplaceImageDescBad_EmptyDesc();
            if (~r4)
                numFailed = numFailed + 1;
            end
            
            r5 = obj.TestReplaceImageDescGood_CallNoConfig();
            if (~r5)
                numFailed = numFailed + 1;
            end
            
            r6 = obj.TestReplaceImageDescBad_CallNoOpen();
            if (~r6)
                numFailed = numFailed + 1;
            end
            
            r7 = obj.TestReplaceImageDescBad_CallAfterCleanUp();
            if (~r7)
                numFailed = numFailed + 1;
            end
            
            res = (r1 && r2 && r3 && r4 && r5 && r6 && r7);
            
        end % testAllReplaceImageDescription        

        function [res, numFailed]  = testAllAdHoc(obj)

            numFailed = 0;
            
            r1 = obj.TestImage3000Series();
            if (~r1)
                numFailed = numFailed + 1;
            end
            
            r2 = obj.TestImage3001Series();
            if (~r2)
                numFailed = numFailed + 1;
            end
            
            res = (r1 && r2);
            
        end % testAllAdHoc
                
    end % Test all methods section
    
    methods(Access = public) % Test testAppendFrame methods section
        
        function res = TestAppendGood(obj)

            filename = [obj.tiffFileDirectory 'TestAppendTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendGood...Passed');
            else
                disp('Test...TestAppendGood...FAILED');
            end

        end % TestAppendGood
        
        function res = TestAppendGood_TwiceCall(obj)

            filename = [obj.tiffFileDirectory 'TestAppendTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res)
               res = obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendGood_TwiceCall...Passed');
            else
                disp('Test...TestAppendGood_TwiceCall...FAILED');
            end

        end % TestAppendGood_TwiceCall
        
        function res = TestAppendBad_NoOpen(obj)
 
            res = ~obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            
            if (res) 
                disp('Test...TestAppendBad_NoOpen...Passed');
            else
                disp('Test...TestAppendBad_NoOpen...FAILED');
            end

       end % TestAppendBad_NoOpen
        
        function res = TestAppendGood_NoConfig(obj)

            filename = [obj.tiffFileDirectory 'TestAppendTiffFile3.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendGood_NoConfig...Passed');
            else
                disp('Test...TestAppendGood_NoConfig...FAILED');
            end

        end % TestAppendGood_NoConfig
        
        function res = TestAppendBad_CallAfterClose(obj)

            filename = [obj.tiffFileDirectory 'TestAppendTiffFile5.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            obj.tw.close();
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_CallAfterClose...Passed');
            else
                disp('Test...TestAppendBad_CallAfterClose...FAILED');
            end

        end % TestAppendBad_CallAfterClose
        
        function res = TestAppendBad_CallAfterCleanUp(obj)

            filename = [obj.tiffFileDirectory 'TestAppendTiffFile6.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            obj.tw.cleanUp();
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res) 
                disp('Test...TestAppendBad_CallAfterCleanUp...Passed');
            else
                disp('Test...TestAppendBad_CallAfterCleanUp...FAILED');
            end

        end % TestAppendBad_CallAfterCleanUp
        
        function res = TestAppendBad_EmptyImage(obj)
 
            filename = [obj.tiffFileDirectory 'TestAppendTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                m = [];
               res = ~obj.tw.appendFrame(double(m), obj.testFrameSize);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_EmptyImage...Passed');
            else
                disp('Test...TestAppendBad_EmptyImage...FAILED');
            end

        end % TestAppendBad_EmptyImage
        
        function res = TestAppendBad_ZeroSize(obj)
 
            filename = [obj.tiffFileDirectory 'TestAppendTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), 0);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_ZeroSize...Passed');
            else
                disp('Test...TestAppendBad_ZeroSize...FAILED');
            end

        end % TestAppendBad_ZeroSize
        
        function res = TestAppendBad_NegativeSize(obj)
 
            filename = [obj.tiffFileDirectory 'TestAppendTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), -1);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_NegativeSize...Passed');
            else
                disp('Test...TestAppendBad_NegativeSize...FAILED');
            end

        end % TestAppendBad_NegativeSize
        
        function res = TestAppendBad_SizeGreaterThanImage(obj)
 
            filename = [obj.tiffFileDirectory 'TestAppendTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), (obj.testFrameSize * 2));
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_SizeGreaterThanImage...Passed');
            else
                disp('Test...TestAppendBad_SizeGreaterThanImage...FAILED');
            end

        end % TestAppendBad_SizeGreaterThanImage
        
        function res = TestAppendBad_SizeLessThanImage(obj)
 
            filename = [obj.tiffFileDirectory 'TestAppendTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
               res = ~obj.tw.appendFrame(int16(obj.testFrame), (obj.testFrameSize / 2));
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestAppendBad_SizeLessThanImage...Passed');
            else
                disp('Test...TestAppendBad_SizeLessThanImage...FAILED');
            end

        end % TestAppendBad_SizeLessThanImage
        
    end % Test testAppendFrame methods section
    
    methods(Access = public) % Test testCleanUp methods section

        function res = testCleanUpGood(obj)
       
            filename = [obj.tiffFileDirectory 'TestCleanUpTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            obj.tw.open(filename, data, dataSize, dataOffset);
            
            obj.tw.cleanUp();

            disp('Test...testCleanUpGood...Passed');
            
            res = true;
            
        end % testCleanUpGood
        
        function res = testCleanUpGood_CalledTwice(obj)
       
            filename = [obj.tiffFileDirectory 'TestCleanUpTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            obj.tw.open(filename, data, dataSize, dataOffset);
            
            obj.tw.cleanUp();
            obj.tw.cleanUp();

            disp('Test...testCleanUpGood_CalledTwice...Passed');
            
            res = true;
                        
        end % testCleanUpGood_CalledTwice
        
        function res = testCleanUpGood_NoTiffOpen(obj)
       
            obj.tw.cleanUp();

            disp('Test...testCleanUpGood_NoTiffOpen...Passed');
            
            res = true;
            
        end % testCleanUpGood_NoTiffOpen
        
    end % Test testCleanUp methods section
    
    methods(Access = public) % Test testClose methods section
        
        function res = TestCloseGood(obj)

            filename = [obj.tiffFileDirectory 'TestCloseTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.close();
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseGood...Passed');
            else
                disp('Test...TestCloseGood...FAILED');
            end

        end % TestCloseGood
        
        function res = TestCloseGood_TwiceCall(obj)
            
            filename = [obj.tiffFileDirectory 'TestCloseTwiceTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.close();
            end

            if (res)
                res = obj.tw.close();
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseGood_TwiceCall...Passed');
            else
                disp('Test...TestCloseGood_TwiceCall...FAILED');
            end

        end % TestCloseGood_TwiceCall
        
        function res = TestCloseBad_NoOpen(obj)
            
            res = ~obj.tw.close();
            
            if (res) 
                disp('Test...TestCloseBad_NoOpen...Passed');
            else
                disp('Test...TestCloseBad_NoOpen...FAILED');
            end

        end % TestCloseBad_NoOpen
        
        function res = TestCloseBad_AfterCleanUp(obj)
            
            filename = [obj.tiffFileDirectory 'TestCloseAfterCleanUpTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.close();
            end

            if (res) 
                disp('Test...TestCloseBad_AfterCleanUp...Passed');
            else
                disp('Test...TestCloseBad_AfterCleanUp...FAILED');
            end

        end % TestCloseBad_AfterCleanUp
        
    end % Test testClose methods section
    
    methods(Access = public) % Test testCloseWithAppendedData methods section
        
        function res = TestCloseAppendedGood(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                % Force IFD Header and imageto be outputted in order to see
                % appended data on close.
                obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res)
                res = obj.tw.closeWithAppendedData('Appended Data', 13);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedGood...Passed');
            else
                disp('Test...TestCloseAppendedGood...FAILED');
            end

        end % TestCloseAppendedGood
        
        function res = TestCloseAppendedGood_TwiceCall(obj)
            
            filename = [obj.tiffFileDirectory 'TestCloseAppendedTwiceTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                % Force IFD Header and imageto be outputted in order to see
                % appended data on close.
                obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res)
                res = obj.tw.closeWithAppendedData('Appended Data', 13);
            end

            if (res)
                res = obj.tw.closeWithAppendedData('Appended Data', 13);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedGood_TwiceCall...Passed');
            else
                disp('Test...TestCloseAppendedGood_TwiceCall...FAILED');
            end

        end % TestCloseAppendedGood_TwiceCall
        
        function res = TestCloseAppendedBad_NaNDataZeroLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData(NaN, 0);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_NaNDataZeroLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_NaNDataZeroLen...FAILED');
            end

        end % TestCloseAppendedBad_NaNDataZeroLen
        
        function res = TestCloseAppendedBad_EmptyDataZeroLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData('', 0);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_EmptyDataZeroLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_EmptyDataZeroLen...FAILED');
            end

        end % TestCloseAppendedBad_EmptyDataZeroLen
        
        function res = TestCloseAppendedBad_DataWithZeroLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData('Appended Data', 0);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_DataWithZeroLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_DataWithZeroLen...FAILED');
            end

        end % TestCloseAppendedBad_DataWithZeroLen
        
        function res = TestCloseAppendedGood_DataWithPositiveGreaterLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                % Force IFD Header and imageto be outputted in order to see
                % appended data on close.
                obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res)
                res = obj.tw.closeWithAppendedData('Appended Data', 10000);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedGood_DataWithPositiveGreaterLen...Passed');
            else
                disp('Test...TestCloseAppendedGood_DataWithPositiveGreaterLen...FAILED');
            end

        end % TestCloseAppendedGood_DataWithPositiveGreaterLen
        
        function res = TestCloseAppendedGood_DataWithPositiveLesserLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFile3.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                % Force IFD Header and imageto be outputted in order to see
                % appended data on close.
                obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end
            
            if (res)
                res = obj.tw.closeWithAppendedData('Appended Data', 3);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedGood_DataWithPositiveLesserLen...Passed');
            else
                disp('Test...TestCloseAppendedGood_DataWithPositiveLesserLen...FAILED');
            end

        end % TestCloseAppendedGood_DataWithPositiveLesserLen
        
        function res = TestCloseAppendedBad_EmptyDataPositiveLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData('', 100);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_EmptyDataPositiveLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_EmptyDataPositiveLen...FAILED');
            end

        end % TestCloseAppendedBad_EmptyDataPositiveLen
        
        function res = TestCloseAppendedBad_NoOpen(obj)
            
            res = ~obj.tw.closeWithAppendedData('Appended Data', 13);
            
            if (res) 
                disp('Test...TestCloseAppendedBad_NoOpen...Passed');
            else
                disp('Test...TestCloseAppendedBad_NoOpen...FAILED');
            end

        end % TestCloseAppendedBad_NoOpen
        
        function res = TestCloseAppendedBad_AfterCleanUp(obj)
            
            filename = [obj.tiffFileDirectory 'TestCloseAppendedAfterCleanUpTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.closeWithAppendedData('Appended Data', 13);
            end

            if (res) 
                disp('Test...TestCloseAppendedBad_AfterCleanUp...Passed');
            else
                disp('Test...TestCloseAppendedBad_AfterCleanUp...FAILED');
            end

        end % TestCloseAppendedBad_AfterCleanUp
        
        function res = TestCloseAppendedBad_NaNDataPositiveLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData(NaN, 100);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_NaNDataPositiveLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_NaNDataPositiveLen...FAILED');
            end

        end % TestCloseAppendedBad_NaNDataPositiveLen
        
        function res = TestCloseAppendedBad_DataWithNegativeLen(obj)

            filename = [obj.tiffFileDirectory 'TestCloseAppendedTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.closeWithAppendedData('Appended Data', -13);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestCloseAppendedBad_DataWithNegativeLen...Passed');
            else
                disp('Test...TestCloseAppendedBad_DataWithNegativeLen...FAILED');
            end

        end % TestCloseAppendedBad_DataWithNegativeLen
        
    end % Test testCloseWithAppendedData methods section
    
    methods(Access = public) % Test testConfigureImage methods section
        
        function res = testConfigureImageGood(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageGood...Passed');
            else
                disp('Test...testConfigureImageGood...FAILED');
            end

        end % testConfigureImageGood
               
        function res = testConfigureImageGood_CalledTwice(obj)
       
            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)    
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(88, 99, 2, 1, true, 'Test Image Description');
            end
            
            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageGood_CalledTwice...Passed');
            else
                disp('Test...testConfigureImageGood_CalledTwice...FAILED');
            end

        end % testConfigureImageGood_CalledTwice
               
        function res = testConfigureImageGood_CallAfterClose(obj)
        
            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFile3.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            obj.tw.close();
            
            if (res)
                res = obj.tw.configureImage(88, 99, 2, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...testConfigureImageGood_CallAfterClose...Passed');
            else
                disp('Test...testConfigureImageGood_CallAfterClose...FAILED');
            end

        end % testConfigureImageGood_CallAfterClose

        function res = testConfigureImageGood_CallAppendCloseOpenAppend(obj)
       
            % Test: Open file=>Config=>AppendFrame=>Close=>Re-Open File=>AppendFrame=>Close=>CleanUp
            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFile4.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description');
            end
            
            if (res)
                res = obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end

            if (res)
                res = obj.tw.close();
            end
            
            if (res)
                res = obj.tw.open(filename, data, dataSize, dataOffset);
            end
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end
            end % if - res

            if (res)
                res = obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end

            if (res)
                res = obj.tw.close();
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageGood_CallAppendCloseOpenAppend...Passed');
            else
                disp('Test...testConfigureImageGood_CallAppendCloseOpenAppend...FAILED');
            end

        end % testConfigureImageGood_CallAppendCloseOpenAppend
        
        function res = testConfigureImageBad_TiffStreamNotOpen(obj)
        
            res = ~obj.tw.configureImage(88, 99, 2, 1, false, 'Test Image Description');
            
            if (res) 
                disp('Test...testConfigureImageBad_TiffStreamNotOpen...Passed');
            else
                disp('Test...testConfigureImageBad_TiffStreamNotOpen...FAILED');
            end

        end % testConfigureImageBad_TiffStreamNotOpen
        
        function res = testConfigureImageBad_CallAfterCleanUp(obj)
        
            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                res = obj.tw.newFile(filename, data, dataSize, dataOffset);
            end 
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.configureImage(88, 99, 2, 1, false, 'Test Image Description');
            end
            
            if (res) 
                disp('Test...testConfigureImageBad_CallAfterCleanUp...Passed');
            else
                disp('Test...testConfigureImageBad_CallAfterCleanUp...FAILED');
            end

        end % testConfigureImageBad_CallAfterCleanUp
        
        function res = testConfigureImageBad_ZeroWidth(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(0, 512, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_ZeroWidth...Passed');
            else
                disp('Test...testConfigureImageBad_ZeroWidth...FAILED');
            end

        end % testConfigureImageBad_ZeroWidth
               
        function res = testConfigureImageBad_NegativeWidth(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(-1, 512, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NegativeWidth...Passed');
            else
                disp('Test...testConfigureImageBad_NegativeWidth...FAILED');
            end

        end % testConfigureImageBad_NegativeWidth
        
        function res = testConfigureImageBad_NullWidth(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(NaN, 512, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullWidth...Passed');
            else
                disp('Test...testConfigureImageBad_NullWidth...FAILED');
            end

        end % testConfigureImageBad_NullWidth
        
        function res = testConfigureImageBad_ZeroLength(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 0, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_ZeroLength...Passed');
            else
                disp('Test...testConfigureImageBad_ZeroLength...FAILED');
            end

        end % testConfigureImageBad_ZeroLength
 
        function res = testConfigureImageBad_NegativeLength(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, -1, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NegativeLength...Passed');
            else
                disp('Test...testConfigureImageBad_NegativeLength...FAILED');
            end

        end % testConfigureImageBad_NegativeLength
 
        function res = testConfigureImageBad_NullLength(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, NaN, 1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullLength...Passed');
            else
                disp('Test...testConfigureImageBad_NullLength...FAILED');
            end

        end % testConfigureImageBad_NullLength
 
        function res = testConfigureImageBad_ZeroBytesPerPixel(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 0, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_ZeroBytesPerPixel...Passed');
            else
                disp('Test...testConfigureImageBad_ZeroBytesPerPixel...FAILED');
            end

        end % testConfigureImageBad_ZeroBytesPerPixel
 
        function res = testConfigureImageBad_NegativeBytesPerPixel(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, -1, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NegativeBytesPerPixel...Passed');
            else
                disp('Test...testConfigureImageBad_NegativeBytesPerPixel...FAILED');
            end

        end % testConfigureImageBad_NegativeBytesPerPixel
 
        function res = testConfigureImageBad_NullBytesPerPixel(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, NaN, 1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullBytesPerPixel...Passed');
            else
                disp('Test...testConfigureImageBad_NullBytesPerPixel...FAILED');
            end

        end % testConfigureImageBad_NullBytesPerPixel
 
        function res = testConfigureImageBad_ZeroChannels(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, 0, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_ZeroChannels...Passed');
            else
                disp('Test...testConfigureImageBad_ZeroChannels...FAILED');
            end

        end % testConfigureImageBad_ZeroChannels
        
        function res = testConfigureImageBad_NegativeChannels(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, -1, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NegativeChannels...Passed');
            else
                disp('Test...testConfigureImageBad_NegativeChannels...FAILED');
            end

        end % testConfigureImageBad_NegativeChannels
        
        function res = testConfigureImageBad_NullChannels(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, NaN, false, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullChannels...Passed');
            else
                disp('Test...testConfigureImageBad_NullChannels...FAILED');
            end

        end % testConfigureImageBad_NullChannels
        
        function res = testConfigureImageBad_NullSignedData(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, 1, NaN, 'Test Image Description');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullSignedData...Passed');
            else
                disp('Test...testConfigureImageBad_NullSignedData...FAILED');
            end

        end % testConfigureImageBad_NullSignedData
        
        function res = testConfigureImageBad_ZeroTargetBytes(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description', 0);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_ZeroTargetBytes...Passed');
            else
                disp('Test...testConfigureImageBad_ZeroTargetBytes...FAILED');
            end

        end % testConfigureImageBad_ZeroTargetBytes
        
        function res = testConfigureImageBad_NegativeTargetBytes(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description', -1);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NegativeTargetBytes...Passed');
            else
                disp('Test...testConfigureImageBad_NegativeTargetBytes...FAILED');
            end

        end % testConfigureImageBad_NegativeTargetBytes
        
        function res = testConfigureImageBad_NullTargetBytes(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = ~obj.tw.configureImage(512, 512, 1, 1, false, 'Test Image Description', NaN);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageBad_NullTargetBytes...Passed');
            else
                disp('Test...testConfigureImageBad_NullTargetBytes...FAILED');
            end

        end % testConfigureImageBad_NullTargetBytes
        
        function res = testConfigureImageGood_NullDescription(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, NaN);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageGood_NullDescription...Passed');
            else
                disp('Test...testConfigureImageGood_NullDescription...FAILED');
            end

        end % testConfigureImageGood_NullDescription
        
        function res = testConfigureImageGood_EmptyDescription(obj)

            filename = [obj.tiffFileDirectory 'TestConfigureImageTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)             
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, '');
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testConfigureImageGood_EmptyDescription...Passed');
            else
                disp('Test...testConfigureImageGood_EmptyDescription...FAILED');
            end

        end % testConfigureImageGood_EmptyDescription
        
    end % Test testConfigureImage methods section
    
    methods(Access = public) % Test testNewFile methods section
        
        function res = testNewFileGood(obj)
            %testNewFileGood Test a good path for the creation of a new
            %   Tiff file. This function ensures that a Tiff file has already 
            %   been opened prior to the new file request (prerequisite).
            %
            %   Upon completion of the test, TiffStream.cleanUp() is called
            %   to release resources and free memory.
            %
            %Return
            %   res = true => a Tiff file has been successfully opened and
            %   a new file request successfully closed the open file and
            %   created a new file.
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)                
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                filename = [obj.tiffFileDirectory 'TestNewFileTiffFile1A.tif'];
                res = obj.tw.newFile(filename, data, dataSize, dataOffset);
            end 
            
            if (res)                
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileGood...Passed');
            else
                disp('Test...testNewFileGood...FAILED');
            end

        end % testNewFileGood
               
        function res = testNewFileGood_CalledTwice(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile2A.tif'];
                res = obj.tw.newFile(filename, data, dataSize, dataOffset);
            end 
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile2B.tif'];              
                res = obj.tw.newFile(filename, data, dataSize, dataOffset);

                if (res)
                    if (~exist(filename, 'file'))
                        res = false;
                    end
                end
                
            end % if - res

            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileGood_CalledTwice...Passed');
            else
                disp('Test...testNewFileGood_CalledTwice...FAILED');
            end

        end % testNewFileGood_CalledTwice
               
        function res = testNewFileBad_FilenameNaN(obj)
        
            filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile3.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                res = ~obj.tw.newFile(NaN, data, dataSize, dataOffset);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_FilenameNaN...Passed');
            else
                disp('Test...testNewFileBad_FilenameNaN...FAILED');
            end

        end % testNewFileBad_FilenameNaN
        
        function res = testNewFileBad_FilenameEmpty(obj)
        
            filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile4.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                res = ~obj.tw.newFile('', data, dataSize, dataOffset);
            end
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_FilenameEmpty...Passed');
            else
                disp('Test...testNewFileBad_FilenameEmpty...FAILED');
            end

        end % testNewFileBad_FilenameEmpty
        
        function res = testNewFileBad_TiffStreamNotOpen(obj)
        
            filename = [obj.tiffFileDirectory 'TestNewFileTwiceTiffFile5.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, data, dataSize, dataOffset);
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_TiffStreamNotOpen...Passed');
            else
                disp('Test...testNewFileBad_TiffStreamNotOpen...FAILED');
            end

        end % testNewFileBad_TiffStreamNotOpen
        
        function res = testNewFileBad_CallAfterCleanUp(obj)
        
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile6.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)      
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.newFile(filename, data, dataSize, dataOffset);
            end
            
            if (res) 
                disp('Test...testNewFileBad_CallAfterCleanUp...Passed');
            else
                disp('Test...testNewFileBad_CallAfterCleanUp...FAILED');
            end

        end % testNewFileBad_CallAfterCleanUp
        
        function res = testNewFileBad_MetadataNaN(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, NaN, dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_MetadataNaN...Passed');
            else
                disp('Test...testNewFileBad_MetadataNaN...FAILED');
            end

        end % testNewFileBad_MetadataNaN
               
        function res = testNewFileBad_MetadataEmpty(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, '', dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_MetadataEmpty...Passed');
            else
                disp('Test...testNewFileBad_MetadataEmpty...FAILED');
            end

        end % testNewFileBad_MetadataEmpty

        function res = testNewFileBad_MetadataSizeZero(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, data, 0, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_MetadataSizeZero...Passed');
            else
                disp('Test...testNewFileBad_MetadataSizeZero...FAILED');
            end

        end % testNewFileBad_MetadataSizeZero
        
        function res = testNewFileBad_MetadataSizeNegative(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, data, -1, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_MetadataSizeNegative...Passed');
            else
                disp('Test...testNewFileBad_MetadataSizeNegative...FAILED');
            end

        end % testNewFileBad_MetadataSizeNegative
        
        function res = testNewFileBad_MetadataOffsetZero(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, data, dataSize, 0);
            obj.tw.cleanUp();
                    
            if (res) 
                disp('Test...testNewFileBad_MetadataOffsetZero...Passed');
            else
                disp('Test...testNewFileBad_MetadataOffsetZero...FAILED');
            end

        end % testNewFileBad_MetadataOffsetZero
        
        function res = testNewFileBad_MetadataOffsetNegative(obj)
       
            filename = [obj.tiffFileDirectory 'TestNewFileTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.newFile(filename, data, dataSize, -1);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testNewFileBad_MetadataOffsetNegative...Passed');
            else
                disp('Test...testNewFileBad_MetadataOffsetNegative...FAILED');
            end

        end % testNewFileBad_MetadataOffsetNegative
                 
    end % Test testNewFile methods section
    
    methods(Access = public) % Test testOpen methods section
        
        function res = testOpenGood(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res)
                if (~exist(filename, 'file'))
                    res = false;
                end
            end
            
            if (res) 
                disp('Test...testOpenGood...Passed');
            else
                disp('Test...testOpenGood...FAILED');
            end

        end % testOpenGood
               
        function res = testOpenGood_CalledTwice(obj)
        
            filename = [obj.tiffFileDirectory 'TestTwiceOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
        
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                filename = [obj.tiffFileDirectory 'TestTwiceOpenTiffFile2.tif'];;
                
                res = obj.tw.open(filename, data, dataSize, dataOffset);

                if (res)
                    if (~exist(filename, 'file'))
                        res = false;
                    end
                end
                
            end % if - res

            obj.tw.cleanUp();

            if (res) 
                disp('Test...testOpenGood_CalledTwice...Passed');
            else
                disp('Test...testOpenGood_CalledTwice...FAILED');
            end

        end % testOpenGood_CalledTwice
               
        function res = testOpenBad_FilenameNaN(obj)
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(NaN, data, dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_FilenameNaN...Passed');
            else
                disp('Test...testOpenBad_FilenameNaN...FAILED');
            end

        end % testOpenBad_FilenameNaN
        
        function res = testOpenBad_FilenameEmpty(obj)
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open('', data, dataSize, dataOffset);
            
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_FilenameEmpty...Passed');
            else
                disp('Test...testOpenBad_FilenameEmpty...FAILED');
            end

        end % testOpenBad_FilenameEmpty
        
        function res = testOpenBad_MetadataNaN(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, NaN, dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_MetadataNaN...Passed');
            else
                disp('Test...testOpenBad_MetadataNaN...FAILED');
            end

        end % testOpenBad_MetadataNaN
               
        function res = testOpenBad_MetadataEmpty(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, '', dataSize, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_MetadataEmpty...Passed');
            else
                disp('Test...testOpenBad_MetadataEmpty...FAILED');
            end

        end % testOpenBad_MetadataEmpty

        function res = testOpenBad_MetadataSizeZero(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, data, 0, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_MetadataSizeZero...Passed');
            else
                disp('Test...testOpenBad_MetadataSizeZero...FAILED');
            end

        end % testOpenBad_MetadataSizeZero
        
        function res = testOpenBad_MetadataSizeNegative(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, data, -1, dataOffset);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_MetadataSizeNegative...Passed');
            else
                disp('Test...testOpenBad_MetadataSizeNegative...FAILED');
            end

        end % testOpenBad_MetadataSizeNegative
        
        function res = testOpenBad_MetadataOffsetZero(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, data, dataSize, 0);
            obj.tw.cleanUp();
        
            if (res) 
                disp('Test...testOpenBad_MetadataOffsetZero...Passed');
            else
                disp('Test...testOpenBad_MetadataOffsetZero...FAILED');
            end

        end % testOpenBad_MetadataOffsetZero
        
        function res = testOpenBad_MetadataOffsetNegative(obj)
       
            filename = [obj.tiffFileDirectory 'TestOpenTiffFile.tif'];
            
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = ~obj.tw.open(filename, data, dataSize, -1);
            obj.tw.cleanUp();
                    
            if (res) 
                disp('Test...testOpenBad_MetadataOffsetNegative...Passed');
            else
                disp('Test...testOpenBad_MetadataOffsetNegative...FAILED');
            end

        end % testOpenBad_MetadataOffsetNegative
                
    end % Test testOpen methods section
    
    methods(Access = public) % Test testUpdateDescription methods section
        
        function res = TestUpdateDescGood(obj)

            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(2, 'QQQQQ', 5);
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood...Passed');
            else
                disp('Test...TestUpdateDescGood...FAILED');
            end

        end % TestUpdateDescGood
        
        function res = TestUpdateDescGood_CallTwice(obj)

            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            
            if (res)
                res = obj.tw.updateDescription(2, 'QQQQQ', 5);
            end
            
            if (res)
                res = obj.tw.updateDescription(10, 'RRR', 3);
            end
                                        
            if (res)
                % Force IFD Header to be outputted to see description
                % in the associated Test Tiff file.
                obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
            end

            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_CallTwice...Passed');
            else
                disp('Test...TestUpdateDescGood_CallTwice...FAILED');
            end

        end % TestUpdateDescGood
        
        function res = TestUpdateDescGood_ZeroCount(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile3.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(0, 'QQQQQ', 0); 
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_ZeroCount...Passed');
            else
                disp('Test...TestUpdateDescGood_ZeroCount...FAILED');
            end

        end % TestUpdateDescGood_ZeroCount
        
        function res = TestUpdateDescGood_MissMatchCount(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile4.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(0, 'QQQQQ', 3); % Count miss matches the length of the buffer
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_MissMatchCount...Passed');
            else
                disp('Test...TestUpdateDescGood_MissMatchCount...FAILED');
            end

        end % TestUpdateDescGood_MissMatchCount
        
        function res = TestUpdateDescGood_GreaterCount(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile5.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(0, 'QQQQQ', 10);
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_GreaterCount...Passed');
            else
                disp('Test...TestUpdateDescGood_GreaterCount...FAILED');
            end

        end % TestUpdateDescGood_GreaterCount
        
        function res = TestUpdateDescGood_BufferMoreThanDesc(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile6.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(0, 'OriginalDescriptionPlus', 23);
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_BufferMoreThanDesc...Passed');
            else
                disp('Test...TestUpdateDescGood_BufferMoreThanDesc...FAILED');
            end

       end % TestUpdateDescGood_BufferMoreThanDesc
        
        function res = TestUpdateDescGood_ReplacementExceedsDesc(obj)

            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile7.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.updateDescription(18, 'QQQQQ', 5);
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescGood_ReplacementExceedsDesc...Passed');
            else
                disp('Test...TestUpdateDescGood_ReplacementExceedsDesc...FAILED');
            end

        end % TestUpdateDescGood_ReplacementExceedsDesc
        
        function res = TestUpdateDescBad_NaNBuf(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.updateDescription(0, NaN, 1); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_NaNBuf...Passed');
            else
                disp('Test...TestUpdateDescBad_NaNBuf...FAILED');
            end

        end % TestUpdateDescBad_NaNBuf
        
        function res = TestUpdateDescBad_EmptyBuf(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.updateDescription(0, '', 1); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_EmptyBuf...Passed');
            else
                disp('Test...TestUpdateDescBad_EmptyBuf...FAILED');
            end

        end % TestUpdateDescBad_EmptyBuf
        
        function res = TestUpdateDescBad_NegativeLoc(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.updateDescription(-10, 'QQQQQ', 5);       
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_NegativeLoc...Passed');
            else
                disp('Test...TestUpdateDescBad_NegativeLoc...FAILED');
            end

        end % TestUpdateDescBad_NegativeLoc
        
        function res = TestUpdateDescBad_ExceededLoc(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.updateDescription(30, 'QQQQQ', 5); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_ExceededLoc...Passed');
            else
                disp('Test...TestUpdateDescBad_ExceededLoc...FAILED');
            end

        end % TestUpdateDescBad_ExceededLoc
        
        function res = TestUpdateDescBad_NegativeCount(obj)
 
            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.updateDescription(0, 'QQQQQ', -1); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_NegativeCount...Passed');
            else
                disp('Test...TestUpdateDescBad_NegativeCount...FAILED');
            end

        end % TestUpdateDescBad_NegativeCount
        
        function res = TestUpdateDescBad_CallNoConfig(obj)

            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = ~obj.tw.updateDescription(2, 'QQQQQ', 5);
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestUpdateDescBad_CallNoConfig...Passed');
            else
                disp('Test...TestUpdateDescBad_CallNoConfig...FAILED');
            end

        end % TestUpdateDescBad_CallNoConfig
        
        function res = TestUpdateDescBad_CallNoOpen(obj)
            
            res = ~obj.tw.updateDescription(2, 'QQQQQ', 5);
            
            if (res) 
                disp('Test...TestUpdateDescBad_CallNoOpen...Passed');
            else
                disp('Test...TestUpdateDescBad_CallNoOpen...FAILED');
            end

        end % TestUpdateDescBad_CallNoOpen
        
        function res = TestUpdateDescBad_CallAfterCleanUp(obj)

            filename = [obj.tiffFileDirectory 'TestUpdDescTiffFile.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.updateDescription(2, 'QQQQQ', 5);
            end
            
            if (res) 
                disp('Test...TestUpdateDescBad_CallAfterCleanUp...Passed');
            else
                disp('Test...TestUpdateDescBad_CallAfterCleanUp...FAILED');
            end

        end % TestUpdateDescBad_CallAfterCleanUp
        
    end % Test testUpdateDescription methods section
    
    methods(Access = public) % Test AdHoc Test methods section
        
        function res = TestImage3000Series(obj)
            
            res = true;
            
            img = zeros(37 * 56);
            
            for dx = 1 : (37 * 56)
                
                img(dx) = mod(dx, 3) * 50;
                    
            end % for - ii
                        
            filename = [obj.tiffFileDirectory 'TestImage3000.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            if (res)
                res = obj.tw.configureImage(37, 56, 1, 1, false, '12345678901234567890');            
            end
            
            if (res)
                res = obj.tw.appendFrame(img, (37 * 56));
            end
            
            if (res)
                res = obj.tw.appendFrame(img, (37 * 56));
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestImage3000Series...Passed');
            else
                disp('Test...TestImage3000Series...FAILED');
            end
            
        end % TestImage3000Series
        
        function res = TestImage3001Series(obj)
            
            res = true;

            return;  % This test method needs some work -- skip for now
            
            %img1 = zeros(37 * 56); % Defined as a private property
            
            %for dx = 1 : (37 * 56)
            %    
            %    img1(dx) = mod(dx, 3) * 50;
            %        
            %end % for - dx
                        
            %img2 = zeros(49 * 38 * 2 * 3); % Defined as a private property
            
            %for dx = 1 : (49 * 38)
            %    
            %    img2(dx) = mod(dx, 2) * 10000;
            %        
            %end % for - ii
            %            
            %for dx = (49 * 38) : ((49 * 38) * 2)
            %    
            %    img2(dx) = mod(dx, 3) * 10000;
            %        
            %end % for - ii
            %            
            %for dx = ((49 * 38) * 2) : ((49 * 38) * 3)
            %    
            %    img2(dx) = mod(dx, 4) * 10000;
            %        
            %end % for - ii
                        
            filename = [obj.tiffFileDirectory 'TestImage3001.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)
                
                if (~exist(filename, 'file'))
                    res = false;
                end
                
            end % if - res

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if (res)
                res = obj.tw.configureImage(37, 56, 1, 1, false, '12345678901234567890');            
            end
            
            if (res)
                res = obj.tw.appendFrame(obj.img1, (37 * 56));
            end
            
            if (res)
                res = obj.tw.updateDescription(5, 'abcdefghijklmnopqrstuvwxyz', 3);
            end
            
            if (res)
                res = obj.tw.appendFrame(obj.img1, (37 * 56));
            end
            
            if (res)
                res = obj.tw.updateDescription(0, 'abcdefghijklmnopqrstuvwxyz', 2);
            end
            
            if (res)
                res = obj.tw.appendFrame(obj.img1, (37 * 56));
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            '49 x 38 Image...';
            
            if (res)
                res = obj.tw.configureImage(49, 38, 2, 3, false, 'desc2desc2desc2');            
            end

            if (res)
                res = obj.tw.updateDescription(10, 'abcdefghijklmnopqrstuvwxyz', 10);
            end
            
            if (res)
                res = obj.tw.appendFrame(obj.img2, (49 * 38 * 2));
            end
            
            if (res)
                res = obj.tw.configureImage(49, 38, 2, 3, false, 'desc3desc3desc3');            
            end

            if (res)
                res = obj.tw.appendFrame(obj.img2(49 * 38 * 2), (49 * 38 * 2));
            end
            
            if (res)
                res = obj.tw.appendFrame(obj.img2(49 * 38 * 2 * 2), (49 * 38 * 2));
            end
            
            obj.tw.close();
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestImage3001Series...Passed');
            else
                disp('Test...TestImage3001Series...FAILED');
            end
            
        end % TestImage3001Series
        
    end % Test AdHoc Test methods section

    methods(Access = public) % Test Replace Image Description methods section

        function res = TestReplaceImageDescGood(obj)
            
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFile1.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)                
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.replaceImageDescription('Brand New Image Description To Replace Original');
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescGood...Passed');
            else
                disp('Test...TestReplaceImageDescGood...FAILED');
            end

        end % TestReplaceImageDescGood

        function res = TestReplaceImageDescGood_CallTwice(obj)
            
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFile2.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)                
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = obj.tw.replaceImageDescription('Brand New Image Description To Replace Original');
                
                if (res)
                    res = obj.tw.replaceImageDescription('New Description');
                end
                
                if (res)
                    % Force IFD Header to be outputted to see description
                    % in the associated Test Tiff file.
                    obj.tw.appendFrame(int16(obj.testFrame), obj.testFrameSize);
                end
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescGood_CallTwice...Passed');
            else
                disp('Test...TestReplaceImageDescGood_CallTwice...FAILED');
            end

        end % TestReplaceImageDescGood_CallTwice
        
        function res = TestReplaceImageDescBad_NaNDesc(obj)
 
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.replaceImageDescription(NaN); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescBad_NaNDesc...Passed');
            else
                disp('Test...TestReplaceImageDescBad_NaNDesc...FAILED');
            end

        end % TestReplaceImageDescBad_NaNDesc

        function res = TestReplaceImageDescBad_EmptyDesc(obj)
 
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.configureImage(512, 512, 1, 1, false, 'OriginalDescription');            
            end
            
            if (res)
                res = ~obj.tw.replaceImageDescription(''); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescBad_EmptyDesc...Passed');
            else
                disp('Test...TestReplaceImageDescBad_EmptyDesc...FAILED');
            end

        end % TestReplaceImageDescBad_EmptyDesc
        
        function res = TestReplaceImageDescGood_CallNoConfig(obj)
 
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            if (res)
                res = obj.tw.replaceImageDescription('Replace With No Config Call'); 
            end
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescGood_CallNoConfig...Passed');
            else
                disp('Test...TestReplaceImageDescGood_CallNoConfig...FAILED');
            end

        end % TestReplaceImageDescGood_CallNoConfig

        function res = TestReplaceImageDescBad_CallNoOpen(obj)
 
            res = ~obj.tw.replaceImageDescription(''); 
            
            obj.tw.cleanUp();
            
            if (res) 
                disp('Test...TestReplaceImageDescBad_CallNoOpen...Passed');
            else
                disp('Test...TestReplaceImageDescBad_CallNoOpen...FAILED');
            end

        end % TestReplaceImageDescBad_CallNoOpen

        function res = TestReplaceImageDescBad_CallAfterCleanUp(obj)
            filename = [obj.tiffFileDirectory 'TestReplaceDescTiffFileX.tif'];
        
            [data, dataSize, dataOffset] = CreateStaticMetadata(obj);
            
            res = obj.tw.open(filename, data, dataSize, dataOffset);
            
            if (res)               
                if (~exist(filename, 'file'))
                    res = false;
                end                
            end % if - res

            obj.tw.cleanUp();
            
            if (res)
                res = ~obj.tw.replaceImageDescription(''); 
            end
            
            if (res) 
                disp('Test...TestReplaceImageDescBad_CallAfterCleanUp...Passed');
            else
                disp('Test...TestReplaceImageDescBad_CallAfterCleanUp...FAILED');
            end

        end % TestReplaceImageDescBad_CallAfterCleanUp
            
    end % Test Replace Image Description methods section
    
    methods(Access = private)
        
        function [data, dataSize, dataOffset] = CreateStaticMetadata(obj)
        
			data = '{RoiGroups : {imagingRoiGroup : {ver : 1,classname :  scanimage.mroi.RoiGroup ,name :  Default Imaging ROI Group ,rois : {ver : 1,classname :  scanimage.mroi.Roi ,name :   ,zs : 0,scanfields : {ver : 1,classname :  scanimage.mroi.scanfield.fields.RotatedRectangle ,name :   ,centerXY : [0.5,0.5],sizeXY : [0.9,0.9],rotationDegrees : 0,enable : 1,pixelResolutionXY : [512,512],pixelToRefTransform : [[0.0017578125,0,0.04912109375],[0,0.0017578125,0.04912109375],[0,0,1]],affine : [[0.9,0,0.05],[0,0.9,0.05],[0,0,1]]},discretePlaneMode : 0}},photostimRoiGroups : null,integrationRoiGroup : {ver : 1,classname :  scanimage.mroi.RoiGroup ,name :   ,rois : {_ArrayType_ :  double ,_ArraySize_ : [1,0],_ArrayData_ : null}}}}';
		
            dataSize = size(data, 2);
            
            dataOffset = 10; % Will need to change in the future.
            
        end % CreateStaticMetadata
        
    end % Test Helper Methods
        
end % UnitTests


%--------------------------------------------------------------------------%
% UnitTests.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
