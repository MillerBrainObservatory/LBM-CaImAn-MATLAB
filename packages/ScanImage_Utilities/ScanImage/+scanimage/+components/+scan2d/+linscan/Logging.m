classdef Logging < scanimage.interfaces.Class
    properties (SetAccess = private, Hidden)
        hLinScan;
        hTifs;
        
        hMetaFile;
        hPmtFile;
        hScannerFile;
        
        active = false;
        
        fileCounter;
        fileFrameCounter;
        fileSubCounter;
        stackRolloverFlag = false;
        
        blankFrameDescription;
        
        stripeBuffer = [];
        avgBuffer = [];
        avgFlag = false;
        
        mRoiLogging = false;
        linesPerFrame;
        pixelsPerLine;
        isLineScan;
        channelSave;
        numChannelSave;
        
        useJson;
    end
    
    properties (SetAccess = private)
%    properties (Dependent, SetAccess = private)
       bitsPerSample;
       dataSigned;
       castFrameData;  % This is the cast used to assure the image (frame) data is corrently passed to the Mex TiffStream
    end
    
    properties (Constant)
        FRAME_DESCRIPTION_LENGTH = 2000; % same value as in ResScan       
    end
    
    %% Lifecycle
    methods
        function obj = Logging(hLinScan)
            obj.hLinScan = hLinScan;
            obj.blankFrameDescription = repmat(' ',1,obj.FRAME_DESCRIPTION_LENGTH);
        end
        
        function delete(obj)
            obj.abort();
            obj.closeFiles(); % forces all open file handles to be closed
        end
    end
    
    methods
        function start(obj)
            obj.active = false;
            obj.closeFiles();
            obj.stripeBuffer = [];
            
            if ~obj.hLinScan.hSI.hChannels.loggingEnable;return;end
            if isempty(obj.hLinScan.hSI.hChannels.channelSave);return;end
            
            obj.fileCounter = obj.hLinScan.logFileCounter;
            obj.fileFrameCounter = 0;
            obj.fileSubCounter = 0;
            obj.channelSave = obj.hLinScan.hSI.hChannels.channelSave;
            obj.numChannelSave = numel(obj.channelSave);
            obj.isLineScan = obj.hLinScan.hSI.hRoiManager.isLineScan;
                        
            %Placing this logic here because this is originally don in the
            %TifStream.m constructor. The dataSigned and bitsPerSample are
            %needed by the new TiffStream.configureImage() method.
            switch obj.hLinScan.channelsDataType
                case 'uint8'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 8;
                    obj.castFrameData = @uint8;
                case 'int8'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 8;
                    obj.castFrameData = @int8;
                case 'uint16'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 16;
                    obj.castFrameData = @uint16;
                case 'int16'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 16;
                    obj.castFrameData = @int16;
                case 'uint32'
                    obj.dataSigned    = false;
                    obj.bitsPerSample = 32;
                    obj.castFrameData = @uint32;
                case 'int32'
                    obj.dataSigned    = true;
                    obj.bitsPerSample = 32;
                    obj.castFrameData = @int32;
                otherwise
                    assert('false','TifStream: Unsupported datatype: ''%s''',obj.dataType);
            end %switch
            
            if obj.isLineScan
                % create and write metadata file
                obj.hMetaFile = fopen(obj.makeFullFilePath([],'.meta.txt'),'w+t');
                assert(obj.hMetaFile > 0, 'Failed to create log file.');
                dat = char(obj.hLinScan.tifHeaderData');
                dat(obj.hLinScan.tifRoiDataStringOffset) = sprintf('\n');
                fprintf(obj.hMetaFile,'%s\n',dat(obj.hLinScan.tifHeaderStringOffset+1:end-1));
                fclose(obj.hMetaFile);
                obj.hMetaFile = [];
                
                % write mat file with reference images
                if ~isempty(obj.hLinScan.hSI.hController) && isprop(obj.hLinScan.hSI.hController{1}, 'hRoiGroupEditor')
                    hRGE = obj.hLinScan.hSI.hController{1}.hRoiGroupEditor;
                    
                    if sum(hRGE.contextImageVis)
                        contextImageLuts = hRGE.contextImageLuts(hRGE.contextImageVis);
                        contextImageZs = hRGE.contextImageZs(hRGE.contextImageVis);
                        contextImageRoiCPs = hRGE.contextImageRoiCPs(hRGE.contextImageVis);
                        contextImageImgs = hRGE.contextImageImgs(hRGE.contextImageVis);
                        contextImageChans = hRGE.contextImageChans(hRGE.contextImageVis);
                        contextImageChanSel = hRGE.contextImageChanSel(hRGE.contextImageVis);
                        
                        save(obj.makeFullFilePath([],'.ref.dat'), 'contextImageLuts', 'contextImageZs',...
                            'contextImageRoiCPs', 'contextImageImgs', 'contextImageChans', 'contextImageChanSel');
                    end
                end
                
                % create binary pmt data file
                obj.hPmtFile = fopen(obj.makeFullFilePath([],'.pmt.dat'),'w+');
                
                % create galvo logging file
                if obj.hLinScan.recordScannerFeedback
                    obj.hScannerFile = fopen(obj.makeFullFilePath([],'.scnnr.dat'),'w+');
                end
            else
                zs=obj.hLinScan.hSI.hStackManager.zs; % generate planes to scan based on motor position etc
                roiGroup = obj.hLinScan.currentRoiGroup;
                scanFields = arrayfun(@(z)roiGroup.scanFieldsAtZ(z),...
                    zs,'UniformOutput',false);
                
                obj.mRoiLogging = false;
                cumPixelResolutionAtZ = zeros(0,2);
                for zidx = 1:length(scanFields)
                    sfs = scanFields{zidx};
                    pxRes = zeros(0,2);
                    for sfidx = 1:length(sfs)
                        sf = sfs{sfidx};
                        pxRes(end+1,:) = sf.pixelResolution(:)';
                    end
                    obj.mRoiLogging = obj.mRoiLogging || size(pxRes,1) > 1;
                    cumPixelResolutionAtZ(end+1,:) = [max(pxRes(:,1)), sum(pxRes(:,2))];
                end
                
                obj.mRoiLogging = obj.mRoiLogging || any(cumPixelResolutionAtZ(1,1) ~= cumPixelResolutionAtZ(:,1));
                obj.mRoiLogging = obj.mRoiLogging || any(cumPixelResolutionAtZ(1,2) ~= cumPixelResolutionAtZ(:,2));
                obj.linesPerFrame = max(cumPixelResolutionAtZ(:,2));
                obj.pixelsPerLine = max(cumPixelResolutionAtZ(:,1));
                
                sf = scanFields{1}{1};
                resDenoms = 2^30 ./ (1e4 * sf.pixelResolutionXY ./ (sf.sizeXY * obj.hLinScan.hSI.mdfData.objectiveResolution));
                
                xResolutionNumerator = 2^30;
                xResolutionDenominator = resDenoms(1);
                yResolutionNumerator = 2^30;
                yResolutionDenominator = resDenoms(2);
                
                obj.useJson = obj.hLinScan.hSI.useJsonHeaderFormat;
                
                % create TifStream objects
                if obj.hLinScan.logFilePerChannel
                    obj.hTifs = cell(1,obj.numChannelSave);
                    for i = 1:obj.numChannelSave
                        
                        chan = obj.channelSave(i);
                        obj.hTifs{i} = scanimage.components.scan2d.TiffStream;
                        assert(obj.hTifs{i}.open(obj.makeFullFilePath(chan),obj.hLinScan.tifHeaderData,obj.hLinScan.tifHeaderStringOffset,obj.hLinScan.tifRoiDataStringOffset), 'Failed to create log file.');
                        obj.hTifs{i}.configureImage(obj.pixelsPerLine, obj.linesPerFrame, (obj.bitsPerSample/8), 1, obj.dataSigned,...
                            obj.blankFrameDescription, xResolutionNumerator, xResolutionDenominator, yResolutionNumerator, yResolutionDenominator);
                        
                        %        obj.hTifs{i} = scanimage.components.scan2d.linscan.TifStream(obj.makeFullFilePath(chan),...
                        %            obj.pixelsPerLine, obj.linesPerFrame, obj.blankFrameDescription,...
                        %            'dataType',obj.hLinScan.channelsDataType,'overwrite',true);
                        
                        
                    end
                else
                    obj.hTifs = cell(1,1);
                    
                    obj.hTifs{1} = scanimage.components.scan2d.TiffStream;
                    assert(obj.hTifs{1}.open(obj.makeFullFilePath,obj.hLinScan.tifHeaderData,obj.hLinScan.tifHeaderStringOffset,obj.hLinScan.tifRoiDataStringOffset), 'Failed to create log file.');
                    obj.hTifs{1}.configureImage(obj.pixelsPerLine, obj.linesPerFrame, (obj.bitsPerSample/8), obj.numChannelSave, obj.dataSigned,...
                        obj.blankFrameDescription, xResolutionNumerator, xResolutionDenominator, yResolutionNumerator, yResolutionDenominator);
                    
                    %    obj.hTifs{1} = scanimage.components.scan2d.linscan.TifStream(obj.makeFullFilePath,...
                    %        obj.pixelsPerLine, obj.linesPerFrame, obj.blankFrameDescription,...
                    %        'dataType',obj.hLinScan.channelsDataType,'overwrite',true);
                end
            end
            
            obj.active = true;
        end
        
        function logScannerFdbk(obj,data)            
            if ~obj.active;return;end
            fwrite(obj.hScannerFile, data', 'single');
        end
        
        function logStripe(obj,stripeData)            
            if ~obj.active;return;end
            
            if obj.isLineScan
                fwrite(obj.hPmtFile, stripeData.rawData(:,ismembc2(obj.channelSave,stripeData.channelNumbers))', 'int16');
                obj.fileFrameCounter = obj.fileFrameCounter + numel(stripeData.frameNumberAcq);
                
                newFileFlag = false;
                
                if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                    obj.fileSubCounter = obj.fileSubCounter + 1;
                    newFileFlag = true;
                end
                
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    obj.fileCounter = obj.fileCounter + 1;
                    obj.fileSubCounter = 0;
                    newFileFlag = true;
                end
                
                if newFileFlag
                    obj.newFile();
                end
            else % frame Scan
                if stripeData.startOfFrame && stripeData.endOfFrame
                    obj.stripeToDisk(stripeData);
                else
                    assert(~obj.mRoiLogging,'Something bad happened: trying to save a partial frame (''stripe'') while logging mroi data. This is not allowed.');
                    % striped frame coming in
                    if stripeData.startOfFrame
                        obj.stripeBuffer = copy(stripeData); % If start of frame buffer is just a direct copy of first stripe
                    else % ... other wise add new stripe to buffer
                        newStripe = copy(stripeData); % memory copy of entire frame for every stripe -> not good for performance
                        newStripe.merge(obj.stripeBuffer); % newStripe now contains current stripe data and data that was in stripeBuffer
                        obj.stripeBuffer = newStripe; % Update stripeBuffer to reflect addition of new stripe
                    end
                    
                    if stripeData.endOfFrame % If end of frame send it to disk
                        obj.stripeToDisk(obj.stripeBuffer);
                    end
                end
            end
        end
        
        function stripeToDisk(obj,stripeData)
            % write frames to disk
            obj.fileFrameCounter = obj.fileFrameCounter + 1;
            
            frameDescription = sprintf('%s\n',stripeData.getFrameDescription(obj.useJson));

            for i = 1:obj.numChannelSave % write for all channels, stripeData includes image data for all saved channels. 
                chanNum = obj.channelSave(i);

                if obj.hLinScan.logFilePerChannel
                    fileIndex = i;
                else
                    fileIndex = 1;
                end

                chIdx = find(stripeData.roiData{1}.channels == chanNum,1,'first');
                
                obj.hTifs{fileIndex}.replaceImageDescription(frameDescription);
                %obj.hTifs{fileIndex}.imageDescription = frameDescription;
                
                imageSize = obj.pixelsPerLine * obj.linesPerFrame * (obj.bitsPerSample/8);
                
                if obj.mRoiLogging
                    line = 1;
                    tempbuf = zeros(obj.pixelsPerLine,obj.linesPerFrame,obj.hLinScan.channelsDataType);
                    for roiIdx = 1:length(stripeData.roiData)
                        imdata = stripeData.roiData{roiIdx}.imageData{chIdx}{1};
                        dims = size(imdata);
                        tempbuf(1:dims(1),line:line+dims(2)-1) = imdata;
                        line = line + dims(2);
                    end
                    
                    obj.hTifs{fileIndex}.appendFrame(obj.castFrameData(tempbuf), imageSize);
                    
                    %obj.hTifs{fileIndex}.appendFrame(tempbuf,true);
 
                else   % Averaging Code           
                    if obj.hLinScan.logAverageFactor > 1
                        if mod(obj.fileFrameCounter,obj.hLinScan.logAverageFactor)== 0 %Nth frame
                            obj.avgFlag(i) = true;
                            avgStripeData = copy(stripeData);

                            avgStripeData.roiData{1}.imageData{chIdx}{1} = int32(avgStripeData.roiData{1}.imageData{chIdx}{1})+int32(obj.avgBuffer{i}.roiData{1}.imageData{chIdx}{1});
                            frameData = avgStripeData.roiData{1}.imageData{chIdx}{1};
                            frameData = frameData / cast(obj.hLinScan.logAverageFactor,'like',frameData);
                            obj.hTifs{fileIndex}.appendFrame(obj.castFrameData(frameData), imageSize);
                            
                            obj.avgBuffer{i} = [];
                        else
                            if obj.fileFrameCounter == 1 || obj.avgFlag(i) == true
                                obj.avgBuffer{i} = copy(stripeData);
                                obj.avgFlag(i) = false;
                            else
                                obj.avgBuffer{i}.roiData{1}.imageData{chIdx}{1} = int32(obj.avgBuffer{i}.roiData{1}.imageData{chIdx}{1})+int32(stripeData.roiData{1}.imageData{chIdx}{1});
                            end
                        end

                    else
                        obj.hTifs{fileIndex}.appendFrame(obj.castFrameData(stripeData.roiData{1}.imageData{chIdx}{1}), imageSize);
                    end
                end
            end

            % determine if file is split after this frame
            newFileFlag = false;
            fileSplitFlag = false;
            
%%
           
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % FastZ handled here.
            if obj.hLinScan.hSI.hStackManager.isFastZ
                % We have reached a file frame split point
                if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                    fileSplitFlag = true; % Don't Need?
                    obj.fileSubCounter = obj.fileSubCounter + 1;
                    newFileFlag = true;
                end
                
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                        obj.fileCounter = obj.fileCounter + 1;
                        obj.fileSubCounter = 0;
                        newFileFlag = true;
                end
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % SlowZ logic is simpler and different.
            elseif obj.hLinScan.hSI.hStackManager.isSlowZ
                % We make sure to set this flag to false because it is a
                % param (needed) so it will exist under all acquisitions
                % BUT is only used for FastZ. It will cause issues with
                % file saving if left true. SlowZ doesn't have the
                % rollover issue.
                obj.stackRolloverFlag = false;
                % Okay Split point reached.
                if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                    if ~((obj.hLinScan.hSI.hStackManager.stackSlicesDone) < obj.hLinScan.hSI.hStackManager.slicesPerAcq) 
                    % BUT it is the end of an acquisistion and new
                    % acquisitions get a new file handled elsewhere.
                    % Probably dont need to set this flag just do noting.
                        newFileFlag = false;
                    else
                    % AND you are in the middle of an acquisition so split
                    % this up into a sub file.
                        obj.fileSubCounter = obj.fileSubCounter + 1;
                        newFileFlag = true;
                    end
                end

                % End of stripe reached but not end of mode. This could
                % happend at the end of a slice so we perform some logic to
                % make sure this the end of an actual acquisition.
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    % Check to see if last slice.
                    if ~((obj.hLinScan.hSI.hStackManager.stackSlicesDone + 1) < obj.hLinScan.hSI.hStackManager.slicesPerAcq)
                    % It is the last slice so create a new file. 
                        obj.fileCounter = obj.fileCounter + 1;
                        obj.fileSubCounter = 0;
                        newFileFlag = true;
                    end
                end
                %Not a stack
                
                
            else
                if ~stripeData.endOfAcquisition
                    if obj.fileFrameCounter >= obj.hLinScan.logFramesPerFile
                        obj.fileSubCounter = obj.fileSubCounter + 1;
                        newFileFlag = true;
                    end
                end
                if stripeData.endOfAcquisition && ~stripeData.endOfAcquisitionMode
                    obj.fileCounter = obj.fileCounter + 1;
                    obj.fileSubCounter = 0;
                    newFileFlag = true;
                end
            end

            % For FastZ if your rollover flag is true and the current slice
            % is 0 then that means it is actually the final slice of the
            % acquisition and you need to create a new file.
%             if (obj.stackRolloverFlag) && (obj.hLinScan.hSI.hStackManager.stackSlicesDone == 0)
%                 obj.fileCounter = obj.fileCounter + 1;
%                 obj.fileSubCounter = 0;
%                 newFileFlag = true;
%                 obj.stackRolloverFlag = false;
%             end

            % Rollover is true, you are definitely on the second to last
            % slice, and this all occured as the result of a file split
            % point being reached then instead of creating a new file you
            % create a new SUB file. New File will be created on the next
            % execution when the slices done finishes its rollover to 0
%             if (obj.stackRolloverFlag) && (obj.hLinScan.hSI.hStackManager.stackSlicesDone == obj.hLinScan.hSI.hStackManager.slicesPerAcq - 1) && (fileSplitFlag == true);
%                 obj.fileSubCounter = obj.fileSubCounter + 1;
%                 newFileFlag = true;
%             end

            % Regardless of everything else if you have reached the end of
            % an acquistion mode (loop, grab) do NOT create a new file.
            if stripeData.endOfAcquisitionMode
                newFileFlag = false;
            end
  
            if newFileFlag
                obj.newFile();
            end
            
        end
        
        function newFile(obj)
            if ~obj.active;return;end
            
            obj.fileFrameCounter = 0;
            
            if obj.isLineScan
                if ~isempty(obj.hPmtFile)
                    fclose(obj.hPmtFile);
                    obj.hPmtFile = [];
                end

                if ~isempty(obj.hScannerFile)
                    fclose(obj.hScannerFile);
                    obj.hScannerFile = [];
                end
                
                obj.hPmtFile = fopen(obj.makeFullFilePath([],'.pmt.dat'),'w+');
                
                % create galvo logging file
                if obj.hLinScan.recordScannerFeedback
                    obj.hScannerFile = fopen(obj.makeFullFilePath([],'.scnnr.dat'),'w+');
                end
            else
                if obj.hLinScan.logFilePerChannel
                    for i = 1:obj.numChannelSave
                        chan = obj.channelSave(i);
                        
                        if ~obj.hTifs{i}.newFile(obj.makeFullFilePath(chan))
                            obj.hLinScan.abort();
                            error('Failed to create log file.');
                        end
                    end
                else
                    if ~obj.hTifs{1}.newFile(obj.makeFullFilePath())
                        obj.hLinScan.abort();
                        error('Failed to create log file.');
                    end
                end
            end
        end
        
        function abort(obj)            
            obj.closeFiles();
            obj.active = false;
        end
    end
    
    methods (Access = private)
        function closeFiles(obj)
            if ~isempty(obj.hMetaFile) && obj.hMetaFile > 0
                fclose(obj.hMetaFile);
            end
            obj.hMetaFile = [];
            
            if ~isempty(obj.hPmtFile) && obj.hPmtFile > 0
                fclose(obj.hPmtFile);
            end
            obj.hPmtFile = [];
            
            if ~isempty(obj.hScannerFile) && obj.hScannerFile > 0
                fclose(obj.hScannerFile);
            end
            obj.hScannerFile = [];
            
            if ~isempty(obj.hTifs)
                for i = 1:length(obj.hTifs)
                    try
                        hTif = obj.hTifs{i};
                        if ~isempty(hTif) && isvalid(hTif)
                            hTif.close();
                            hTif.cleanUp();
                        end
                    catch ME
                        most.idioms.reportError(ME);
                    end
                end
            end
            obj.hTifs = {};
        end
        
        function fullPath = makeFullFilePath(obj,channelNum,ext)
            if nargin < 2
                channelNum = [];
            end
            if nargin < 3
                ext = '.tif';
            end
            
            stringFileCounter = sprintf('_%05u',obj.fileCounter);
            
            % No extra number if Inf
            if isinf(obj.hLinScan.logFramesPerFile)
                stringFileSubCounter = '';
            else
                stringFileSubCounter = sprintf('_%05u',obj.fileSubCounter+1);
            end
            
            if isempty(channelNum)
                stringChannelNum = '';
            else
                stringChannelNum = sprintf('_chn%u',channelNum);
            end
            
            fileName = [obj.hLinScan.logFileStem stringFileCounter stringFileSubCounter stringChannelNum ext];   % extension is NOT automatically appended by TifStream
            fullPath = fullfile(obj.hLinScan.logFilePath,fileName);
        end
    end
end


%--------------------------------------------------------------------------%
% Logging.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
