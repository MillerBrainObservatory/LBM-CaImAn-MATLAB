classdef GalvoGalvo < scanimage.mroi.scannerset.ScannerSet
    properties
        fillFractionSpatial;  % fillFractionSpatial and fillFractionTemporal are equal for pure galvo galvo scanning
        settleTimeFraction;
        pixelTime;
        bidirectional;
        stepY = true;
        angularRange;
    end
    
    properties (Constant)
        CONSTRAINTS = struct(...
            'scanimage_mroi_scanfield_ImagingField',{{@scanimage.mroi.constraints.evenPixelsPerLine @scanimage.mroi.constraints.maxWidth @scanimage.mroi.constraints.xCenterInRange,@scanimage.mroi.constraints.maxHeight @scanimage.mroi.constraints.yCenterInRange}}...
           ,'scanimage_mroi_scanfield_fields_StimulusField',{{@scanimage.mroi.constraints.maxWidth @scanimage.mroi.constraints.xCenterInRange,@scanimage.mroi.constraints.maxHeight @scanimage.mroi.constraints.yCenterInRange}}...
            );
    end
    
    properties (Constant)
        optimizableScanners = {'G','Z'};
    end
    
    methods(Static)
        function obj=default
            g=scanimage.mroi.scanners.Galvo.default;
            b=scanimage.mroi.scanners.Beams.default;
            z=scanimage.mroi.scanners.FastZ.default;
            obj=scanimage.mroi.scannerset.GalvoGalvo('Default GG set',g,g,b,z,.7,.001,true,true,0);
            obj.refToScannerTransform = eye(3);
        end
    end
    
    methods
        function obj = GalvoGalvo(name,galvox,galvoy,beams,fastz,fillFractionSpatial,pixelTime,bidirectional,stepY,settleTimeFraction)
            %% Describes a galvo-galvo scanner set.
            obj = obj@scanimage.mroi.scannerset.ScannerSet(name,beams,fastz);
            
            scanimage.mroi.util.asserttype(galvox,'scanimage.mroi.scanners.Galvo');
            scanimage.mroi.util.asserttype(galvoy,'scanimage.mroi.scanners.Galvo');
            
            obj.name = name;
            obj.scanners={galvox,galvoy};
            obj.fillFractionSpatial = fillFractionSpatial;
            obj.pixelTime = pixelTime;
            obj.bidirectional = bidirectional;
            obj.stepY = stepY;
            obj.settleTimeFraction = settleTimeFraction;
        end
        
        function path_FOV = pathAoToFov(obj,ao_volts)
            path_FOV.G(:,1) = obj.volts2degrees(ao_volts(:,1),1);
            path_FOV.G(:,3) = obj.volts2degrees(ao_volts(:,2),2);
            
            path_FOV.G = scanimage.mroi.util.xformPoints(path_FOV.G,obj.scannerToRefTransform);
        end
        
        function path_FOV = refFovToScannerFov(obj,path_FOV)
            % transform to scanner space
            path_FOV.G = scanimage.mroi.util.xformPoints(path_FOV.G,obj.refToScannerTransform);
            
            % ensure we are scanning within the angular range of the scanners
            tol = 0.0001; % tolerance to account for rounding errors
            
            %path_FOV.G = bsxfun(@minus,path_FOV.G,obj.slm.galvoReferenceAngleXY);
            
            rng = max([obj.scanners{1}.travelRange(2) abs(obj.scanners{1}.parkPosition)]);
            assert(all(path_FOV.G(:,1) >= -rng-tol) && all(path_FOV.G(:,1) <= rng+tol), 'Attempted to scan outside X galvo scanner FOV.');
            path_FOV.G(path_FOV.G(:,1) < -rng,1) = -rng;
            path_FOV.G(path_FOV.G(:,1) > rng,1) = rng;
            
            rng = max([obj.scanners{2}.travelRange(2) abs(obj.scanners{2}.parkPosition)]);
            assert(all(path_FOV.G(:,2) >= -rng-tol) && all(path_FOV.G(:,2) <= rng+tol), 'Attempted to scan outside Y galvo scanner FOV.');
            path_FOV.G(path_FOV.G(:,2) < -rng,2) = -rng;
            path_FOV.G(path_FOV.G(:,2) > rng,2) = rng;
            
            if obj.hasSlm && isfield(path_FOV, 'SLM')
                % in reference space, path_FOV.SLM is relative to path_FOV.G already
                %galvoReferencePt_REF = scanimage.mroi.util.xformPoints(obj.slm.galvoReferenceAngleXY,obj.scannerToRefTransform);
                 slmOffset = scanimage.mroi.util.xformPoints([0,0],obj.slm.scannerToRefTransform);
                
                for idx = 1:length(path_FOV.SLM)
                    % path_FOV.SLM(idx).pattern(:,1:2) = bsxfun(@plus,path_FOV.SLM(idx).pattern(:,1:2),galvoReferencePt_REF);
                     path_FOV.SLM(idx).pattern(:,1:2) = bsxfun(@plus,path_FOV.SLM(idx).pattern(:,1:2),slmOffset);
                end
            end
        end
        
        function ao_volts = pathFovToAo(obj,path_FOV)
            % transform to scanner space
            path_FOV = obj.refFovToScannerFov(path_FOV);
            
            % scanner space to volts
            ao_volts.G(:,1) = obj.degrees2volts(path_FOV.G(:,1),1);
            ao_volts.G(:,2) = obj.degrees2volts(path_FOV.G(:,2),2);
            
            if obj.hasBeams
                bIDs = obj.beams.beamIDs;
                ao_volts.B = zeros(size(path_FOV.B));
                for i = 1:numel(bIDs)
                    ao_volts.B(:,i) = obj.beams.powerFracToVoltageFunc(bIDs(i),path_FOV.B(:,i));
                    
                    if obj.hasPowerBox
                        ao_volts.Bpb(:,i) = obj.beams.powerFracToVoltageFunc(bIDs(i),path_FOV.Bpb(:,i));
                    end
                end
            end
            
            if obj.hasFastZ
                ao_volts.Z = obj.fastz.position2Volts(path_FOV.Z);
            end
            
            if obj.hasSlm && isfield(path_FOV, 'SLM')
                slmAo = obj.slm.pathFovToAo(path_FOV);
                ao_volts.SLM = slmAo.SLM;
            end
        end
        
        function [path_FOV, seconds] = scanPathFOV(obj,scanfield,roi,zPowerReference,actz,dzdt,zActuator,maxPtsPerSf)
            if nargin < 8 || isempty(maxPtsPerSf)
                maxPtsPerSf = inf;
            end
            
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));
            obj.checkScannerSampleRateRatios();
            
            if isa(scanfield,'scanimage.mroi.scanfield.ImagingField')
                [path_FOV, seconds] = obj.scanPathImagingFOV(scanfield,roi,zPowerReference,actz,dzdt,zActuator);
            elseif isa(scanfield,'scanimage.mroi.scanfield.fields.StimulusField')
                [path_FOV, seconds] = obj.scanPathStimulusFOV(scanfield,zPowerReference,actz,dzdt,[],[],maxPtsPerSf);
            else
                error('function scanPathFOV is undefined for class of type %s',class(scanfield));
            end
        end
        
        function calibrateScanner(obj,scanner,hWb)
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            switch upper(scanner)
                case 'G'
                    obj.scanners{1}.hDevice.calibrate(hWb);
                    obj.scanners{2}.hDevice.calibrate(hWb);
                case 'Z'
                    obj.fastz.hDevice.calibrate(hWb);
                otherwise
                    error('Cannot optimized scanner %s', scanner);
            end
        end
        
        %% Optimization Functions
        function ClearCachedWaveform(obj, scanner, ao_volts, sampleRateHz)
            switch upper(scanner)
                case 'G'
                    assert(size(ao_volts,2)==2);
                    
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{1}.sampleRateHz;
                    end
                    obj.scanners{1}.clearCachedWaveform(sampleRateHz,ao_volts(:,1));
                    
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{2}.sampleRateHz;
                    end
                    obj.scanners{2}.clearCachedWaveform(sampleRateHz,ao_volts(:,2));
                    
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz.sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    obj.fastz.clearCachedWaveform(sampleRateHz,ao_volts);
                otherwise
                    error('Cannot clear optimized ao for scanner %s', scanner);
            end
            
        end
        
        function ClearCache(obj, scanner)
           switch upper(scanner)
               case 'G'                   
                   obj.scanners{1}.hDevice.clearCache();
                   obj.scanners{2}.hDevice.clearCache();
               case 'Z'
                   obj.fastz.hDevice.clearCache();
               otherwise
                   error('Cannot clear cache for scanner %s', scanner);
           end
        end
        
        function [ao_volts_out,metaData] = retrieveOptimizedAO(obj, scanner, ao_volts, sampleRateHz) 
            ao_volts_out = [];
            metaData = [];
            switch upper(scanner)
                case 'G'
                    % Check for 2 columns
                    assert(size(ao_volts,2)==2);
                    % Check for provided sample rate
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{2}.sampleRateHz;
                    end
                    
                    [metaData_1,ao_volts_temp_1] = obj.scanners{1}.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,1));
                    [metaData_2,ao_volts_temp_2] = obj.scanners{2}.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,2));
                    if ~isempty(metaData_1) && ~isempty(metaData_2)
                        ao_volts_out = horzcat(ao_volts_temp_1,ao_volts_temp_2);
                        metaData    = metaData_1;
                        metaData(2) = metaData_2;
                    end
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz.sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    [metaData_,ao_volts_temp] = obj.fastz.getCachedOptimizedWaveform(sampleRateHz,ao_volts);
                    if ~isempty(metaData_)
                        ao_volts_out = ao_volts_temp;
                        metaData = metaData_;
                    end
                otherwise
                    error('Cannot get cached optimized ao for scanner %s',scanner);
            end
        end
        
        
        
        function ao_volts = optimizeAO(obj, scanner, ao_volts, sampleRateHz)
            % take scanner name, convert to upper case, handle differently
            % for each option (galvo, piezo)
            switch upper(scanner)
                case 'G'
                    % Check the particular scanners columns and make sure
                    % there are 2.
                    assert(size(ao_volts,2)==2);
                    % if you didn't provide it or there is no data...
                    if nargin < 4 || isempty(sampleRateHz)
                        % Go into hSI.hScan2D.scannerset.scanners{1} (X
                        % galvo in this case) and pull the sample rate out.
                        sampleRateHz = obj.scanners{1}.sampleRateHz;
                    end
                    % The output ao volts for all the rows in column 1 set
                    % to the output of optimizeWaveformIteratively whose
                    % inputs are the sample rate provided or pulled as
                    % explained above and all the rows of column 1 of
                    % hSI.hWaveformManager.scannerAO.ao_volts.G
                    % So in this case column 1 is the X galvo and column 2
                    % is the Y galvo.
                    ao_volts(:,1) = obj.scanners{1}.optimizeWaveformIteratively(ao_volts(:,1),sampleRateHz);
                    
                    % Repeat process for Y galvo. 
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{2}.sampleRateHz;
                    end
                    ao_volts(:,2) = obj.scanners{2}.optimizeWaveformIteratively(ao_volts(:,2),sampleRateHz);
                    
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz.sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    ao_volts = obj.fastz.optimizeWaveformIteratively(ao_volts,sampleRateHz);
                otherwise
                    error('Cannot optimize ao for scanner %s',scanner);
            end
        end
        %%
        function [success,imageData,stripePosition] = formImage(obj,scanfieldParams,sampleBuffer,fieldSamples,channelsActive,linePhaseSamples)
            [dataBuffer,bufferStartSample,bufferEndSample] = sampleBuffer.getData();
            datatypeAi = class(dataBuffer);
            
            % apply line phase
            dataBuffer = circshift(dataBuffer, [-linePhaseSamples 0]);
            placeholdervalue = intmin(datatypeAi);
            dataBuffer(1:-linePhaseSamples,:) = placeholdervalue; % we don't want the circshift to roll over
            dataBuffer(end-linePhaseSamples+1:end,:) = placeholdervalue;
            
            xPixels = scanfieldParams.pixelResolution(1);
            yPixels = scanfieldParams.pixelResolution(2);
            
            fieldStartSample = fieldSamples(1);
            fieldEndSample   = fieldSamples(2);
            
            stripeStartSample = round( fieldStartSample + floor( ( bufferStartSample - fieldStartSample + 1 ) / scanfieldParams.lineScanSamples ) * scanfieldParams.lineScanSamples );
            stripeStartSample = max(fieldStartSample,stripeStartSample);
            stripeEndSample   = round( fieldStartSample + floor( (  bufferEndSample  - fieldStartSample + 1 ) / scanfieldParams.lineScanSamples ) * scanfieldParams.lineScanSamples - 1);
            stripeEndSample   = min(stripeEndSample,fieldEndSample);
            
            stripePosition(1) = round( (stripeStartSample - fieldStartSample)/scanfieldParams.lineScanSamples + 1 );
            stripePosition(2) = round( (stripeEndSample - fieldStartSample + 1)/scanfieldParams.lineScanSamples );
            
            if stripePosition(1) < 1 || stripePosition(2) > yPixels || stripePosition(1) > stripePosition(2)
                success = false;
                imageData = {};
                stripePosition = [];
                return
            end
            
            numLines = diff(stripePosition) + 1;
            numChans = length(channelsActive);
            
            imageData = {};
            for idx = 1:numChans
                chan = channelsActive(idx);
                chanAi = dataBuffer(stripeStartSample:stripeEndSample,chan);
                chanAi = reshape(chanAi,scanfieldParams.lineScanSamples,numLines); % image is transposed at this point
                
                % crop 'overscan'
                overScanSamples = (scanfieldParams.lineScanSamples-scanfieldParams.lineAcqSamples)/2;
                chanAi(1:overScanSamples,:) = [];
                chanAi(end-overScanSamples+1:end,:) = [];
                
                % flip lines for bidirectional scanning
                if obj.bidirectional
                    flipevenlines = mod(stripePosition(1),2)>0;
                    chanAi(:,2^flipevenlines:2:end) = flipud(chanAi(:,2^flipevenlines:2:end)); % mirror every second line of the image
                end
                
                pixelBinFactor = scanfieldParams.lineAcqSamples/xPixels;
                assert(mod(pixelBinFactor,1) == 0)
                
                if pixelBinFactor > 1
                    chanAi = reshape(mean(reshape(chanAi,pixelBinFactor,[]),1),xPixels,numLines);
                    chanAi = cast(chanAi,datatypeAi);
                end
                imageData{idx} = chanAi; % imageData is transposed at this point
            end
            success = true;
        end
        
        function v = frameFlybackTime(obj)
            v = obj.scanners{2}.flybackTimeSeconds;
        end
        
        function [seconds,durationPerRepetitionInt,durationPerRepetitionFrac] = scanTime(obj,scanfield,limPts)
            if nargin < 3 || isempty(limPts)
                limPts = false;
            end
            
            if isa(scanfield,'scanimage.mroi.scanfield.ImagingField')
                lineScanPeriod = obj.linePeriod(scanfield);
                numLines = scanfield.pixelResolution(2);
                seconds = lineScanPeriod * numLines;
                durationPerRepetitionInt = [];
                durationPerRepetitionFrac = [];
            elseif isa(scanfield,'scanimage.mroi.scanfield.fields.StimulusField')
                if limPts
                    reps = min(1,scanfield.repetitions);
                else
                    reps = scanfield.repetitions;
                end
                slowestRate = obj.slowestScannerSampleRate(); % normalize period to integer number of samples of slowest output
                repetitionsInteger        = fix(reps);
                durationPerRepetitionInt  = round(slowestRate * scanfield.duration) / slowestRate;
                durationPerRepetitionFrac = round(slowestRate * scanfield.duration * (reps-repetitionsInteger) ) / slowestRate;
                seconds = durationPerRepetitionInt * repetitionsInteger + durationPerRepetitionFrac;
            elseif isa(scanfield,'scanimage.mroi.scanfield.fields.IntegrationField')
                seconds = 0;
                durationPerRepetitionInt = 0;
                durationPerRepetitionFrac = 0;
            else
                error('Function scanTime is undefined for class of type %s',class(scanfield));
            end
        end
        
        function [lineScanPeriod,lineAcquisitionPeriod] = linePeriod(obj,scanfield)
            assert(isempty(scanfield)||isa(scanfield,'scanimage.mroi.scanfield.ImagingField'),...
                'Function linePeriod undefined for class of type %s',class(scanfield));
            pixelsX = scanfield.pixelResolution(1);
            
            slowestRate = obj.slowestScannerSampleRate(); % normalize line period to integer number of samples of slowest output
                        
            lineAcquisitionPeriod = pixelsX * obj.pixelTime;
            samplesAcq = lineAcquisitionPeriod * slowestRate;
            samplesTurnaroundHalf = ceil(((samplesAcq / obj.fillFractionSpatial) - samplesAcq)/2); % making sure this is an integer number
            
            samplesScan = samplesAcq + 2*samplesTurnaroundHalf;
            lineScanPeriod = samplesScan / slowestRate;
        end
        
        function [startTimes, endTimes] = acqActiveTimes(obj,scanfield)
            assert(isa(scanfield,'scanimage.mroi.scanfield.ImagingField'),'Function acqActiveTimes undefined for class of type %s',class(scanfield));
            lines   = scanfield.pixelResolution(2);
            [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod(scanfield);
            
            padTime = (lineScanPeriod-lineAcquisitionPeriod)/2;
            startTimes = linspace(padTime,padTime + lineScanPeriod*(lines-1),lines)';
            endTimes = startTimes + lineAcquisitionPeriod; 
        end
        
        function seconds = transitTime(obj,scanfield_from,scanfield_to) %#ok<INUSL>
            if isa(scanfield_from,'scanimage.mroi.scanfield.fields.StimulusField') ||...
                isa(scanfield_to,'scanimage.mroi.scanfield.fields.StimulusField')
                seconds = 0;
                return                
            end
            
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
                        
            if isnan(scanfield_from)
                seconds = 0; % do not scan first flyto in plane
                return
            end
            
            if isnan(scanfield_to)
                seconds = obj.scanners{2}.flybackTimeSeconds;
            else
                seconds = obj.scanners{2}.flytoTimeSeconds;
            end
                
            seconds = obj.nseconds(obj.scanners{1},obj.nsamples(obj.scanners{1},seconds)); % round to closest multiple of sample time
        end
        
        function position_FOV = mirrorsActiveParkPosition(obj)
            position_FOV(:,1) = obj.scanners{1}.parkPosition;
            position_FOV(:,2) = obj.scanners{2}.parkPosition;
            position_FOV = scanimage.mroi.util.xformPoints(position_FOV,obj.scannerToRefTransform);
        end
        
        function [path_FOV, dt] = transitNaN(obj,scanfield_from,scanfield_to)
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
            
            dt=obj.transitTime(scanfield_from,scanfield_to);
            
            gsamples = obj.nsamples(obj.scanners{1},dt);
            path_FOV.G = nan(gsamples,2);
            
            if obj.hasBeams
                bsamples = obj.nsamples(obj.beams,dt);
                bIDs = obj.beams.beamIDs;
                
                if isnan(scanfield_to) && obj.beams.flybackBlanking
                    path_FOV.B = zeros(bsamples,numel(bIDs));
                else
                    path_FOV.B = nan(bsamples,numel(bIDs));
                end
                
                if obj.hasPowerBox
                    path_FOV.Bpb = path_FOV.B;
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.transitNaN(obj,dt);
            end
        end
        
        function path_FOV = interpolateTransits(obj,path_FOV,tuneZ,zWaveformType)
            if nargin < 3
                tuneZ = true;
            end
            if nargin < 4
                zWaveformType = '';
            end
            
            path_FOV.G(:,1:2) = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV.G(:,1:2),obj.fovCornerPoints);
            
            % beams output FOV
            if obj.hasBeams && isfield(path_FOV, 'B')
                bIDs = obj.beams.beamIDs;
                if obj.beams.flybackBlanking || any(obj.beams.interlaceDecimation(bIDs) > 1)
                    for ctr = 1:numel(bIDs)
                        path_FOV.B(isnan(path_FOV.B(:,ctr)),ctr) = 0;
                    end
                else
                    for ctr = 1:numel(bIDs)
                        path_FOV.B(:,ctr) = scanimage.mroi.util.expInterpolateCircularNaNRanges(path_FOV.B(:,ctr),obj.beams.Lzs(bIDs(ctr)));
                        path_FOV.B(end,ctr) = 0;
                    end
                end
                
                if obj.hasPowerBox
                    if obj.beams.flybackBlanking || any(obj.beams.interlaceDecimation(bIDs) > 1)
                        for ctr = 1:numel(bIDs)
                            path_FOV.Bpb(isnan(path_FOV.Bpb(:,ctr)),ctr) = 0;
                        end
                    else
                        for ctr = 1:numel(bIDs)
                            path_FOV.Bpb(:,ctr) = scanimage.mroi.util.expInterpolateCircularNaNRanges(path_FOV.Bpb(:,ctr),obj.beams.Lzs(bIDs(ctr)));
                            path_FOV.Bpb(end,ctr) = 0;
                        end
                    end
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.interpolateTransits(obj,path_FOV.Z,tuneZ,zWaveformType);
            end
            
            if obj.hasSlm && isfield(path_FOV, 'SLM')
                path_FOV = obj.slm.interpolateTransits(path_FOV);
            end
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,outputData)
            % input: unconcatenated output for the stack
            samplesPerTrigger.G = max( cellfun(@(frameAO)size(frameAO.G,1),outputData) );
            
            if obj.hasBeams && isfield(outputData{1}, 'B')
                samplesPerTrigger.B = max( cellfun(@(frameAO)size(frameAO.B,1),outputData) );
            end
            
            if obj.hasFastZ
                samplesPerTrigger.Z = obj.fastz.samplesPerTriggerForAO(obj,outputData);
            end
        end
        
        function cfg = beamsTriggerCfg(obj)
            cfg = struct();
            if obj.hasBeams
                cfg.triggerType = 'frameClk';
                cfg.requiresReferenceClk = true;
            else
                cfg.triggerType = '';
                cfg.requiresReferenceClk = [];
            end
        end
        
        function path_FOV = padFrameAO(obj, path_FOV, frameTime, flybackTime, zWaveformType)
            %TODO: Not sure yet what to do with this
            padSamplesG = obj.nsamples(obj.scanners{1},frameTime+flybackTime) - size(path_FOV.G,1);
            if padSamplesG > 0
                path_FOV.G(end+1:end+padSamplesG,:) = NaN;
            end
            
            % Beams AO
            if obj.hasBeams && isfield(path_FOV, 'B')
                padSamplesB = obj.nsamples(obj.beams,frameTime+flybackTime) - size(path_FOV.B,1);
                if padSamplesB > 0
                    path_FOV.B(end+1:end+padSamplesB,:) = NaN;
                    if obj.hasPowerBox
                        path_FOV.Bpb(end+1:end+padSamplesB,:) = NaN;
                    end
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.padFrameAO(obj, path_FOV.Z, frameTime, flybackTime, zWaveformType);
            end
        end
        
        function path_FOV = zFlybackFrame(obj, frameTime)
            position_FOV = obj.mirrorsActiveParkPosition();
            path_FOV.G = repmat(position_FOV(1:2),obj.nsamples(obj.scanners{2},frameTime),1);
            
            if obj.hasBeams
                bSamples = obj.nsamples(obj.beams,frameTime);
                bIDs = obj.beams.beamIDs;
                
                if obj.beams.flybackBlanking
                    path_FOV.B = zeros(bSamples,numel(bIDs));
                else
                    path_FOV.B = NaN(bSamples,numel(bIDs));
                end
                
                if obj.hasPowerBox
                    path_FOV.Bpb = path_FOV.B;
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.zFlybackFrame(obj,frameTime);
            end
        end
    end
    
    methods(Hidden)
        function checkScannerSampleRateRatios(obj)
            assert( obj.scanners{1}.sampleRateHz == obj.scanners{2}.sampleRateHz );
            if obj.hasBeams
                galvosSampleRate = obj.scanners{1}.sampleRateHz;
                beamsSampleRate  = obj.beams.sampleRateHz;
                
                sampleRateRatio = galvosSampleRate / beamsSampleRate;
                assert(log2(sampleRateRatio) == nextpow2(sampleRateRatio),...
                    'The galvo output sample rate has to be 2^x times the beams output rate');
            end
        end
        
        function val = slowestScannerSampleRate(obj)
            if obj.hasBeams
                val = min( cellfun(@(scanner)scanner.sampleRateHz,obj.scanners) );
            else
                val = min( cellfun(@(scanner)scanner.sampleRateHz,obj.scanners(1:2)) );
            end
        end
        
        function [path_FOV, seconds] = scanPathImagingFOV(obj,scanfield,roi,zPowerReference,actz,dzdt,zActuator)
            %% Returns struct. Each field has ao channel data in column vectors
            % 
            % path_FOV.G: galvo (columns are X,Y)
            % path_FOV.B: beams (columns are beam1,beam2,...,beamN)
            %
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));
            
            path_FOV = struct();
            [path_FOV,seconds] = generateGalvoPathImaging(path_FOV);
            
            if obj.hasBeams
                path_FOV = generateBeamsPathImaging(path_FOV);
            end
            
            if obj.hasFastZ
                if strcmp(zActuator,'slow')
                    actz = 0;
                end
                
                path_FOV.Z = obj.fastz.scanPathFOV(obj,zPowerReference,actz,dzdt,seconds,path_FOV.G);
            end
            
            %%% nested functions
            function [path_FOV,seconds] = generateGalvoPathImaging(path_FOV)
                % generate grid       
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod(scanfield);
                nxAcq = obj.nsamples(obj.scanners{1},lineAcquisitionPeriod); % number of active acquisition samples per line
                nx = obj.nsamples(obj.scanners{1},lineScanPeriod);           % total number of scan samples per line
                ny = scanfield.pixelResolution(2);             % number of lines
                nTurn = nx - nxAcq;
                
                assert(obj.settleTimeFraction>=0 && obj.settleTimeFraction<=1,'settleTimeFraction must be in interval [0,1]. Current value: %f',obj.settleTimeFraction);
                nSettle = min(round(nTurn*obj.settleTimeFraction),nTurn);
                
                assert(rem(nTurn,2)==0); % sanity check: at the moment we only support even number of samples per line
                
                xxFillfrac = NaN(1,nTurn/2); % placeholder will be replaced below
                xxLine = [xxFillfrac linspace(0,1,nxAcq) xxFillfrac];
                xx = repmat(xxLine(:),1,ny);
                
                if obj.stepY
                    [yy,~]=meshgrid(linspace(0,ny,ny),linspace(0,nx,nx));
                    yy=yy./ny;
                else
                    yy = linspace(0,1,(nx*ny-nTurn))';
                    yy = [zeros(nTurn/2,1);yy;ones(nTurn/2,1)];
                end
                
                if obj.bidirectional
                    xx(:,2:2:end)=flipud(xx(:,2:2:end)); % flip every second line
                    
                    % compute turnaround
                    slopeX = 1/nxAcq;
                    
                    splineInterp  = nan(1,nTurn-nSettle);
                    settleInterp = linspace(nSettle*slopeX,slopeX,nSettle);
                    interpTurnAround = [splineInterp settleInterp];
                    
                    turnXOdd  = 1 + interpTurnAround;
                    turnXEven = - interpTurnAround;
                else
                    % compute turnaround
                    slopeX = 1/nxAcq;
                    splineInterp = nan(1,nTurn-nSettle);
                    settleInterp = linspace(-nSettle*slopeX,-slopeX,nSettle);
                    
                    turnXOdd  = [splineInterp settleInterp];
                    turnXEven = turnXOdd;
                end
                
                slopeY = 0;
                turnY = nan(1,nTurn);
                
                % transform meshgrid into column vectors
                xx = reshape(xx,[],1);
                yy = reshape(yy,[],1);
                for line = 1:(ny-1)
                    startIdx = nTurn/2 + line*nx - nTurn + 1;
                    endIdx   = nTurn/2 + line*nx;
                    
                    if mod(line,2) == 0 % line is even
                        xx(startIdx:endIdx) = turnXEven;
                    else
                        xx(startIdx:endIdx) = turnXOdd;
                    end
                    
                    if obj.stepY
                        yy(startIdx:endIdx) = turnY + (line-1)/(ny-1);
                    end
                end
                
                %%% linspace(0,1,nxAcq) means that pixel centers lie on
                %%% border of scanfield. However, we want the centers to be
                %%% inside the scanfields. We want
                %%% linspace((1/nxAcq)/2,1-(1/nxAcq)/2,nxAcq
                %%% use transform to postprocess x,y
                sampleWidthX = 1/nxAcq;
                pixelHeightY = 1/ny;
                
                m = eye(3);
                m(1) = 1-sampleWidthX;
                m(5) = 1-pixelHeightY;
                m(7) = sampleWidthX/2;
                m(8) = pixelHeightY/2;
                    
                [xx,yy]=scanimage.mroi.util.xformPointsXY(xx,yy,m);
                [xx,yy]=scanfield.transform(xx,yy);
                
                path_FOV.G(:,1) = xx;
                path_FOV.G(:,2) = yy;                
                samples = size(path_FOV.G,1);
                seconds = obj.nseconds(obj.scanners{1},samples);
            end
            
            function path_FOV = generateBeamsPathImaging(path_FOV)               
                % get roi specific beam settings
                [powers, pzAdjust, Lzs, interlaceDecimation, interlaceOffset] = obj.getRoiBeamProps(...
                    roi, 'powers', 'pzAdjust', 'Lzs', 'interlaceDecimation', 'interlaceOffset');                
                
                % determine number of samples
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod(scanfield);
                nxAcq = obj.nsamples(obj.beams,lineAcquisitionPeriod); % number of active acquisition samples per line
                nx = obj.nsamples(obj.beams,lineScanPeriod);           % total number of scan samples per line, guaranteed to be an integer due to implementation of obj.linePeriod
                ny = scanfield.pixelResolution(2);
                nBlank = (nx - nxAcq) / 2;
                assert(rem(nBlank,1)==0); % sanity check, nBlank needs to be an integer number

                totalSamples = nx * ny;
                sampleTime = obj.nseconds(obj.beams,1);
                
                % start with nomimal power fraction sample array for single line
                powerFracs = repmat(powers(:)',totalSamples,1);
                               
                % determine which beams need decimation
                ids = find(interlaceDecimation ~= 1);
                for id = ids
                    grid = nan(ny,nx);
                    grid(interlaceOffset(id)+1:interlaceDecimation(id):end,:) = 1;
                    mask = reshape(grid',[],1);
                    powerFracs(:,id) = powerFracs(:,id) .* mask;
                end
                
                % mask turnaround samples
                if obj.beams.flybackBlanking || numel(ids)
                    grid = nan(ny,nx);
                    grid(:,(nBlank+1):(nBlank+nxAcq)) = 1;
                    mask = reshape(grid',[],1);
                    for iter = 1:size(powerFracs,2)
                        powerFracs(:,iter) = powerFracs(:,iter) .* mask;
                    end
                end
                
                % apply power box samples
                powerFracsPb = powerFracs;
                for pb = obj.beams.powerBoxes
                    rx1 = pb.rect(1);
                    rx2 = pb.rect(1)+pb.rect(3);
                    ry1 = pb.rect(2);
                    ry2 = pb.rect(2)+pb.rect(4);
                    
                    xStart = floor(min(nxAcq-1,max(0,(nxAcq-1) * rx1))+1);
                    xEnd   = floor(min(nxAcq-1,max(0,(nxAcq-1) * rx2))+1);
                    yStart = floor(min(ny-1,max(0,(ny-1) * ry1))+1);
                    yEnd   = floor(min(ny-1,max(0,(ny-1) * ry2))+1);
                    
                    lines = yStart:yEnd;
                    inds = logical(mod(lines,2));
                    fwdLines = lines(inds);
                    revLines = lines(~inds);
                    xrStart = nxAcq - xEnd + 1;
                    xrEnd = nxAcq - xStart + 1;
                    
                    for iter = 1:size(powerFracs,2)
                        grid = nan(ny,nx);
                        if obj.bidirectional
                            grid(fwdLines,(nBlank+xStart):(nBlank+xEnd)) = pb.powers(iter);
                            grid(revLines,(nBlank+xrStart):(nBlank+xrEnd)) = pb.powers(iter);
                        else
                            grid(lines,(nBlank+xStart):(nBlank+xEnd)) = pb.powers(iter);
                        end
                        mask = reshape(grid',[],1);
                        powerFracsPb(~isnan(mask),iter) = mask(~isnan(mask));
                    end
                end
                
                % adjust for line phase and beamClockDelay
                shiftSamples = obj.nsamples(obj.scanners{1},obj.beams.beamClockDelay - obj.beams.linePhase);
                powerFracs = circshift(powerFracs, [-shiftSamples 0]);
                powerFracs(1:-shiftSamples,:) = NaN;
                powerFracs(end-shiftSamples+1:end,:) = NaN;
                %same for the power box version
                powerFracsPb = circshift(powerFracsPb, [-shiftSamples 0]);
                powerFracsPb(1:-shiftSamples,:) = NaN;
                powerFracsPb(end-shiftSamples+1:end,:) = NaN;
                
                
                if any(pzAdjust)
                    % create array of z position corresponding to each sample
                    if dzdt ~= 0
                        sampleTimes = cumsum(repmat(sampleTime,totalSamples,1)) - sampleTime;
                        sampleZs = actz + sampleTimes * dzdt;
                    else
                        sampleZs = repmat(actz,totalSamples,1);
                    end
                    
                    

                    % scale power fracs using Lz
                    adjs = find(pzAdjust == true);
                    for beamIdx = adjs
                        nanMask = isnan(powerFracs(:,beamIdx));
                        nanMaskPb = isnan(powerFracs(:,beamIdx));
                        powerFracs(:,beamIdx) = obj.beams.powerDepthCorrectionFunc(beamIdx,powerFracs(:,beamIdx), zPowerReference, sampleZs, Lzs(beamIdx));
                        powerFracsPb(:,beamIdx) = obj.beams.powerDepthCorrectionFunc(beamIdx,powerFracsPb(:,beamIdx), zPowerReference, sampleZs, Lzs(beamIdx));
                        powerFracs(nanMask,beamIdx) = NaN;
                        powerFracsPb(nanMaskPb,beamIdx) = NaN;
                          
                    end
%                     powerFracs(isnan(powerFracs)) = 0;
%                     powerFracsPb(isnan(powerFracsPb)) = 0;
                    
                end
                
                % this is handled in the interpolate transits step
%                 % replace NaNs with zeros
%                 powerFracs(isnan(powerFracs)) = 0;
%                 powerFracsPb(isnan(powerFracsPb)) = 0;

                % convert fracs to voltage
                bIDs = obj.beams.beamIDs;
                for i = 1:numel(bIDs)
                    pFs = powerFracs(:,bIDs(i));
                    path_FOV.B(:,i) = min(powerFracs(:,bIDs(i)),obj.beams.powerLimits(bIDs(i))) / 100;
                    path_FOV.B(isnan(pFs),i) = nan;
                    if obj.hasPowerBox
                        pFs = powerFracsPb(:,bIDs(i));
                        path_FOV.Bpb(:,i) = min(pFs,obj.beams.powerLimits(bIDs(i))) / 100;
                        path_FOV.Bpb(isnan(pFs),i) =  path_FOV.B(isnan(pFs),i);
                    end
                end
            end
        end
        
        function [path_FOV, seconds] = scanPathStimulusFOV(obj,scanfield,zPowerReference,actz,dzdt,transform,scanBeams,maxPoints)
            if nargin < 6 || isempty(transform)
                transform = true;
            end
            
            if nargin < 7 || isempty(scanBeams)
                scanBeams = true;
            end
            
            if nargin < 8 || isempty(maxPoints)
                maxPoints = inf;
            end
            
            repetitionsInteger = fix(scanfield.repetitions);
            if ~isinf(maxPoints)
                repetitionsInteger = min(1,repetitionsInteger);
                scanBeams = false;
            end
            
            parkfunctiondetected = false;
            
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));
            
            % the implementation of scanTime ensures that the galvo task
            % and beams task stay in sync
            [totalduration,durationPerRepetitionInt,durationPerRepetitionFrac] = obj.scanTime(scanfield,~isinf(maxPoints));
            seconds = totalduration;
            
            path_FOV = struct();
            path_FOV = generateGalvoPathStimulus(path_FOV);
            
            if obj.hasBeams && scanBeams
                path_FOV = obj.beams.generateBeamsPathStimulus(path_FOV,scanfield,parkfunctiondetected,repetitionsInteger,durationPerRepetitionInt,durationPerRepetitionFrac,totalduration,maxPoints);
            end
            
            if obj.hasFastZ
                fnc = func2str(scanfield.stimfcnhdl);
                if scanfield.isPause
                    startz = nan;
                    endz = nan;
                elseif scanfield.isPark
                    startz = nan;
                    endz = actz;
                elseif strcmp('scanimage.mroi.stimulusfunctions.waypoint',fnc)
                    startz = inf;
                    endz = actz;
                else
                    startz = actz;
                    endz = actz;
                end
                path_FOV.Z = obj.fastz.scanStimPathFOV(obj,startz,endz,seconds,maxPoints);
            end
            
            if obj.hasSlm
                [path_FOV.SLM, ~] = obj.slm.generateSlmPathStimulus(scanfield,seconds);
            end
            
            %%% nested functions
            function path_FOV = generateGalvoPathStimulus(path_FOV)
                %TODO: make sure galvo and beams stay in sync here
                numsamples = obj.nsamples(obj.scanners{1},durationPerRepetitionInt);
                tt = linspace(0,obj.nseconds(obj.scanners{1},numsamples-1),min(numsamples,maxPoints));
                numsamples = length(tt); % recalculate in case maxPoints < numsamples
                
                [xx,yy] = scanfield.stimfcnhdl(tt,scanfield.stimparams{:},'actualDuration',durationPerRepetitionInt,'scanfield',scanfield);
                assert(length(xx) == numsamples && length(yy) == numsamples,...
                    ['Stimulus generation function ''%s'' returned incorrect number of samples:',...
                    'Expected: %d Returned: x:%d, y:%d'],...
                    func2str(scanfield.stimfcnhdl),numsamples,length(xx),length(yy));
                
                % convert to column vector
                xx = xx(:);
                yy = yy(:);
                
                if transform
                    if any(isinf(abs(xx))) || any(isinf(abs(yy)))
                        % replace inf values from the park stimulus
                        % function with the appropriate park values
                        parkFov = obj.mirrorsActiveParkPosition();
                        xx(isinf(xx)) = parkFov(1);
                        yy(isinf(yy)) = parkFov(2);
                        parkfunctiondetected = true;
                    else
                        [xx,yy] = scanfield.transform(xx,yy);
                    end
                else
                    repetitionsInteger = 1;
                    durationPerRepetitionFrac = 0;
                end
                
                
                path_FOV.G(:,1) = repmat(xx,repetitionsInteger,1);
                path_FOV.G(:,2) = repmat(yy,repetitionsInteger,1);
                
                % fractional repetitions
                numsamples = obj.nsamples(obj.scanners{1},durationPerRepetitionFrac);
                path_FOV.G(end+1:end+numsamples,:) = [xx(1:numsamples),yy(1:numsamples)];
            end
        end
        
        function ao_volts=degrees2volts(obj,path_FOV,iscanner)
            ao_volts = path_FOV * obj.scanners{iscanner}.voltsPerDistance;
        end
        
        function path_FOV = volts2degrees(obj,ao_volts,iscanner)
            path_FOV = ao_volts / obj.scanners{iscanner}.voltsPerDistance;
        end
    end
    
    %% Property access methods
    methods
        function v = get.angularRange(obj)
            v = [diff(obj.scanners{1}.travelRange) diff(obj.scanners{2}.travelRange)];
        end
    end
end

%% NOTES
%{

(Some note numbers may be missing.  Those notes were deleted.)

3. The scannerset somehow determines the constraints on rois.
   Not sure how to manage this.

4. FIXME
   Need to check/correct the scan pattern in practice.
   Current scan pattern calculation is just a guess.

%}

%% TODO
%{
    [ ] - incorporate internalLineSettlingTime
    [ ] - bidi v non-bidi (cycloid waveform)
%}



%--------------------------------------------------------------------------%
% GalvoGalvo.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
