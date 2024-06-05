classdef ResonantGalvo < scanimage.mroi.scannerset.ScannerSet
    
    properties
        fillFractionSpatial;
        angularRange;
    end
    
    properties(Constant)
        CONSTRAINTS = struct(...
            'scanimage_mroi_scanfield_ImagingField',{{...
                @scanimage.mroi.constraints.positiveWidth @scanimage.mroi.constraints.maxWidth @scanimage.mroi.constraints.sameWidth...
                @scanimage.mroi.constraints.centeredX @scanimage.mroi.constraints.maxHeight @scanimage.mroi.constraints.yCenterInRange...
                @scanimage.mroi.constraints.samePixelsPerLine @scanimage.mroi.constraints.sameRotation @scanimage.mroi.constraints.evenPixelsPerLine}}...
             );
    end
    
    properties (Constant)
        optimizableScanners = {'G','Z'};
    end
    
    methods(Static)
        function obj=default()
            %% Construct a default version of this scanner set for testing
            g=scanimage.mroi.scanners.Galvo.default();
            r=scanimage.mroi.scanners.Resonant.default();
            r=scanimage.mroi.scanners.FastZ.default();
            obj=scanimage.mroi.scannerset.ResonantGalvo(r,g,z,[]);
            obj.refToScannerTransform = eye(3);
        end
    end
    
    methods
        function obj = ResonantGalvo(name,resonantx,galvoy,beams,fastz,fillFractionSpatial)
            %% Describes a resonant-galvo scanner set.
            obj = obj@scanimage.mroi.scannerset.ScannerSet(name,beams,fastz);
            
            scanimage.mroi.util.asserttype(resonantx,'scanimage.mroi.scanners.Resonant');
            scanimage.mroi.util.asserttype(galvoy,'scanimage.mroi.scanners.Galvo');
            
            obj.scanners={resonantx,galvoy};
            obj.fillFractionSpatial = fillFractionSpatial;
        end
        
        function path_FOV = refFovToScannerFov(obj,path_FOV)
            % transform to scanner space
            % assumes there is no rotation and pathFOV.R is unique (except for NANs)
            
            path_FOV.R = path_FOV.R * obj.refToScannerTransform(1);
            
            xCenter = obj.fovCenterPoint(1);
            gpath = [repmat(xCenter,length(path_FOV.G),1),path_FOV.G];
            gpath = scanimage.mroi.util.xformPoints(gpath,obj.refToScannerTransform);
            path_FOV.G = gpath(:,2);
            
            % ensure we are scanning within the angular range of the scanners
            tol = 0.0001; % tolerance to account for rounding errors
            
            rng = obj.scanners{1}.fullAngleDegrees;
            assert(all(path_FOV.R >= 0-tol) && all(path_FOV.R <= rng+tol), 'Attempted to scan outside resonant scanner FOV.');
            path_FOV.R(path_FOV.R < 0) = 0;
            path_FOV.R(path_FOV.R > rng) = rng;
            
            rng = obj.scanners{2}.travelRange;
            assert(all(path_FOV.G(:,1) >= rng(1)-tol) && all(path_FOV.G(:,1) <= rng(2)+tol), 'Attempted to scan outside Y galvo scanner FOV.');
            path_FOV.G(path_FOV.G < rng(1),1) = rng(1);
            path_FOV.G(path_FOV.G > rng(2),1) = rng(2);
        end
        
        function ao_volts = pathFovToAo(obj,path_FOV)
            % transform to scanner space
            path_FOV = obj.refFovToScannerFov(path_FOV);
            
            % scanner space to volts
            ao_volts.R = obj.degrees2volts(path_FOV.R,1);
            ao_volts.G = obj.degrees2volts(path_FOV.G,2);
            
            if obj.hasBeams
                bIDs = obj.beams.beamIDs;
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
        end
            
        function [path_FOV, seconds] = scanPathFOV(obj,scanfield,roi,zPowerReference,actz,dzdt,zActuator,maxPtsPerSf)
           %% Returns struct. Each field has ao channel data in collumn vectors
            % 
            % ao_volts.R: resonant amplitude
            % ao_volts.G: galvo
            % ao_volts.B: beams (columns are beam1,beam2,...,beamN)
            %
            % Output should look like:
            % 1.  Resonant_amplitude is constant. Set for width of scanned
            %     field
            % 2.  Galvo is continuously moving down the field.
            assert(isa(scanfield,'scanimage.mroi.scanfield.ScanField'));            
            seconds=obj.scanTime(scanfield);
            
            rsamples=ceil(seconds*obj.scanners{1}.sampleRateHz);
            gsamples=ceil(seconds*obj.scanners{2}.sampleRateHz);
            
            rfov = scanfield.sizeXY(1) * ones(rsamples,1);

            hysz = scanfield.sizeXY(2)/2;
            gfov = linspace(scanfield.centerXY(2)-hysz,scanfield.centerXY(2)+hysz,gsamples)';
            
            path_FOV.R = round(rfov * 1000000 / obj.fillFractionSpatial) / 1000000;
            path_FOV.G = gfov;
            
            %% Beams AO
            % determine number of samples
            if obj.hasBeams
                hBm = obj.beams;
                
                [~,lineAcquisitionPeriod] = obj.linePeriod(scanfield);
                bExtendSamples = floor(hBm.beamClockExtend * 1e-6 * hBm.sampleRateHz);
                bSamplesPerLine = ceil(lineAcquisitionPeriod*hBm.sampleRateHz) + 1 + bExtendSamples;
                nlines = scanfield.pixelResolution(2);
                
                % get roi specific beam settings
                [powers, pzAdjust, Lzs, interlaceDecimation, interlaceOffset] = obj.getRoiBeamProps(...
                    roi, 'powers', 'pzAdjust', 'Lzs', 'interlaceDecimation', 'interlaceOffset');
                
                % determine which beams need decimation
                ids = find(interlaceDecimation ~= 1);
                
                % start with nomimal power fraction sample array for single line
                powerFracs = repmat(powers,bSamplesPerLine,1);
                
                % zero last sample of line if blanking flyback. beam decimation requires blanking
                if hBm.flybackBlanking || numel(ids)
                    powerFracs(end,:) = 0;
                    powerFracs(end,logical(pzAdjust)) = NaN;
                end
                % replicate for n lines
                powerFracs = repmat(powerFracs,nlines,1);
                
                % mask off lines if decimated
                for i = 1:numel(ids)
                    lineMask = zeros(1,interlaceDecimation(ids(i)));
                    lineMask(1+interlaceOffset(ids(i))) = 1;
                    lineMask = repmat(lineMask, bSamplesPerLine, ceil(nlines/interlaceDecimation(ids(i))));
                    lineMask(:,nlines+1:end) = [];
                    lineMask = reshape(lineMask,[],1);
                    powerFracs(:,ids(i)) = powerFracs(:,ids(i)) .* lineMask;
                end
                
                % apply power boxes
                powerFracsPb = powerFracs;
                for pb = obj.beams.powerBoxes
                    ry1 = pb.rect(2);
                    ry2 = pb.rect(2)+pb.rect(4);
                    
                    % correct for sinusoidal velocity
                    xs = ([pb.rect(1) pb.rect(1)+pb.rect(3)] - .5) * 2 * obj.scanners{1}.fillFractionSpatial;
                    tts = asin(xs) / asin(obj.scanners{1}.fillFractionSpatial);
                    xs = (tts + 1) / 2;
                    
                    lineSamps = bSamplesPerLine-1;
                    smpStart = ceil(max(1,min(lineSamps,lineSamps*xs(1))));
                    smpEnd = ceil(max(1,min(lineSamps,lineSamps*xs(2))));
                    lineStart = floor(min(nlines-1,max(0,nlines * ry1)));
                    lineEnd = floor(min(nlines-1,max(0,nlines * ry2)));
                    
                    for ln = lineStart:lineEnd
                        md = mod(ln+1,2)>0;
                        if (md && pb.oddLines) || ((~md) && pb.evenLines)
                            if obj.scanners{1}.bidirectionalScan && mod(ln,2)
                                se = bSamplesPerLine - smpStart;
                                ss = bSamplesPerLine - smpEnd;
                            else
                                ss = smpStart;
                                se = smpEnd;
                            end
                            powerFracsPb(bSamplesPerLine*ln+ss:bSamplesPerLine*ln+se,:) = repmat(pb.powers,se-ss+1,1);
                        end
                    end
                end
                
                if any(pzAdjust)
                    % create array of z position corresponding to each sample
                    if dzdt ~= 0
                        lineSampleTimes = nan(bSamplesPerLine,nlines);
                        lineSampleTimes(1,:) = linspace(0,obj.linePeriod(scanfield)*(nlines-1),nlines);
                        lineSampleTimes(1,:) = lineSampleTimes(1,:) + 0.25*((1-obj.scanners{1}.fillFractionTemporal) * obj.scanners{1}.scannerPeriod);
                        
                        for i = 1:nlines
                            lineSampleTimes(:,i) = linspace(lineSampleTimes(1,i), lineSampleTimes(1,i) + (bSamplesPerLine-1)/hBm.sampleRateHz, bSamplesPerLine);
                        end
                        
                        lineSampleZs = actz + lineSampleTimes * dzdt;
                        lineSampleZs = reshape(lineSampleZs,[],1);
                    else
                        lineSampleZs = actz * ones(size(powerFracs,1),1);
                    end
                    
                    % scale power fracs using Lz
                    adj = find(pzAdjust == true);
                    for beamIdx = adj
                        LzArray = repmat(Lzs(beamIdx), bSamplesPerLine*nlines,1);
                        
                        nanMask = isnan(powerFracs(:,beamIdx));
                        nanMaskPb = isnan(powerFracsPb(:,beamIdx));
                        
                        powerFracs(:,beamIdx) = obj.beams.powerDepthCorrectionFunc(beamIdx,powerFracs(:,beamIdx), zPowerReference, lineSampleZs, LzArray);
                        if obj.hasPowerBox
                            powerFracsPb(:,beamIdx) = obj.beams.powerDepthCorrectionFunc(beamIdx,powerFracsPb(:,beamIdx), zPowerReference, lineSampleZs, LzArray);
                        end
                        
                        powerFracs(nanMask,beamIdx) = 0;
                        powerFracsPb(nanMaskPb,beamIdx) = 0;
                        
                    end
                end
                
                % IDs of the beams actually being used in this acq
                bIDs = hBm.beamIDs;
                for i = 1:numel(bIDs)
                    path_FOV.B(:,i) = min(powerFracs(:,bIDs(i)),hBm.powerLimits(bIDs(i))) / 100;
                    if obj.hasPowerBox
                        pFs = powerFracsPb(:,bIDs(i));
                        path_FOV.Bpb(:,i) = min(pFs,hBm.powerLimits(bIDs(i))) / 100;
                        path_FOV.Bpb(isnan(pFs),i) =  path_FOV.B(isnan(pFs),i);
                    end
                end
            end
            
            if obj.hasFastZ
                if strcmp(zActuator,'slow')
                    actz = 0;
                end
                
                path_FOV.Z = obj.fastz.scanPathFOV(obj,zPowerReference,actz,dzdt,seconds,[scanfield.centerXY(1)*ones(length(path_FOV.G),1) path_FOV.G]);
            end
        end
        
        function calibrateScanner(obj,scanner,hWb)
            if nargin < 3 || isempty(hWb)
                hWb = [];
            end
            
            switch upper(scanner)
                case 'G'
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
                    assert(size(ao_volts,2)==1);
                    
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{2}.sampleRateHz;
                    end
                    obj.scanners{2}.clearCachedWaveform(ao_volts(:,1), sampleRateHz);                    
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.fastz.sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    obj.fastz.clearCachedWaveform(ao_volts,sampleRateHz);
                otherwise
                    error('Cannot clear optimized ao for scanner %s', scanner);
            end
            
        end
        
        function ClearCache(obj, scanner)
           switch upper(scanner)
               case 'G'                   
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
                    % Check for 1 columns
                    assert(size(ao_volts,2)==1);
                    % Check for provided sample rate
                    if nargin < 4 || isempty(sampleRateHz)
                        sampleRateHz = obj.scanners{2}.sampleRateHz;
                    end
                    
                    [metaData_,ao_volts_temp] = obj.scanners{2}.getCachedOptimizedWaveform(sampleRateHz,ao_volts(:,1));
                    if ~isempty(metaData_)
                        ao_volts_out = ao_volts_temp;
                        metaData = metaData_;
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
        
        function ao_volts = optimizeAO(obj,scanner,ao_volts,sampleRateHz)            
            switch upper(scanner)
                case 'G'
                    assert(size(ao_volts,2)==1);
                    if nargin < 4 || isempty(sampleRateHz)
                        rate = obj.scanners{2}.sampleRateHz;
                    end
                    ao_volts(:,1) = obj.scanners{2}.optimizeWaveformIteratively(ao_volts(:,1),rate);
                case 'Z'
                    if nargin < 4 || isempty(sampleRateHz)
                        rate = obj.fastz.sampleRateHz;
                    end
                    assert(size(ao_volts,2)==1);
                    ao_volts = obj.fastz.optimizeWaveformIteratively(ao_volts,rate);
                otherwise
                    error('Cannot optimize ao for scanner %s',scanner);
            end
        end
        %%
        function position_FOV = mirrorsActiveParkPosition(obj) 
            position_FOV = scanimage.mroi.util.xformPoints([0 obj.scanners{2}.parkPosition],obj.scannerToRefTransform);
            position_FOV(:,1) = NaN; % we can't really calculate that here. the resonant scanner amplitude should not be touched for the flyback. NaN makes sure that nobody accidentally tries to use this value.
        end
        
        function path_FOV = interpolateTransits(obj,path_FOV,tuneZ,zWaveformType)
            if nargin < 3
                tuneZ = true;
            end
            if nargin < 4
                zWaveformType = '';
            end
            
            pts = [0 diff(obj.scanners{2}.travelRange)];
            pts = [-pts; pts] * .5;
            pts = scanimage.mroi.util.xformPoints(pts,obj.scannerToRefTransform);
            
            yGalvoRg = [pts(1,2) pts(2,2)];

            path_FOV.R = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV.R);
            path_FOV.G = scanimage.mroi.util.interpolateCircularNaNRanges(path_FOV.G,yGalvoRg);
            
            % beams ao
            if obj.hasBeams
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
        end
        
        function [path_FOV, dt] = transitNaN(obj,scanfield_from,scanfield_to)
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
            
            dt = obj.transitTime(scanfield_from,scanfield_to);
            if ~isempty(scanfield_to) && isnan(scanfield_to)
                dt = 0; % flyback time is added in padFrameAO
            end
            
            rsamples = round(dt*obj.scanners{1}.sampleRateHz);
            path_FOV.R = nan(rsamples,1);
            
            gsamples = round(dt*obj.scanners{2}.sampleRateHz);
            path_FOV.G = nan(gsamples,1);
            
            if obj.hasBeams
                hBm = obj.beams;
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bExtendSamples = floor(hBm.beamClockExtend * 1e-6 * hBm.sampleRateHz);
                bSamplesPerLine = ceil(lineAcquisitionPeriod*hBm.sampleRateHz) + 1 + bExtendSamples;
                nlines = round(dt/lineScanPeriod);
                path_FOV.B = nan(bSamplesPerLine*nlines,numel(hBm.beamIDs));
                if obj.hasPowerBox
                    path_FOV.Bpb = path_FOV.B;
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.transitNaN(obj,dt);
            end
        end
        
        function path_FOV = zFlybackFrame(obj, frameTime)
            path_FOV.R = nan(round(obj.nsamples(obj.scanners{1},frameTime)),1);
            path_FOV.G = nan(round(obj.nsamples(obj.scanners{2},frameTime)),1);
            
            % Beams AO
            if obj.hasBeams
                hBm = obj.beams;
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bExtendSamples = floor(hBm.beamClockExtend * 1e-6 * hBm.sampleRateHz);
                bSamplesPerLine = ceil(lineAcquisitionPeriod*hBm.sampleRateHz) + 1 + bExtendSamples;
                nlines = round(frameTime/lineScanPeriod);

                if hBm.flybackBlanking
                    path_FOV.B = zeros(bSamplesPerLine*nlines,numel(hBm.beamIDs));
                else
                    path_FOV.B = NaN(bSamplesPerLine*nlines,numel(hBm.beamIDs));
                end
                
                if obj.hasPowerBox
                    path_FOV.Bpb = path_FOV.B;
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.zFlybackFrame(obj,frameTime);
            end
        end
        
        function path_FOV = padFrameAO(obj, path_FOV, frameTime, flybackTime, zWaveformType)
                   
            padSamples = ceil(obj.nsamples(obj.scanners{2},frameTime+flybackTime/2)) - size(path_FOV.G,1); % cut off half of the flyback time to leave some breathing room to receive the next frame trigger
            if padSamples > 0
                path_FOV.R(end+1:end+padSamples,:) = NaN;
                path_FOV.G(end+1:end+padSamples,:) = NaN;
            end
            
            % Beams AO
            if obj.hasBeams
                hBm = obj.beams;
                [lineScanPeriod,lineAcquisitionPeriod] = obj.linePeriod([]);
                bExtendSamples = floor(hBm.beamClockExtend * 1e-6 * hBm.sampleRateHz);
                bSamplesPerLine = ceil(lineAcquisitionPeriod*hBm.sampleRateHz) + 1 + bExtendSamples;
                nlines = round(frameTime/lineScanPeriod);
                nTotalSamples = bSamplesPerLine * nlines;
                padSamples = nTotalSamples - size(path_FOV.B,1);
                if padSamples > 0
                    path_FOV.B(end+1:end+padSamples,:) = NaN;
                    if obj.hasPowerBox
                        path_FOV.Bpb(end+1:end+padSamples,:) = NaN;
                    end
                end
            end
            
            if obj.hasFastZ
                path_FOV.Z = obj.fastz.padFrameAO(obj, path_FOV.Z, frameTime, flybackTime, zWaveformType);
            end
        end
        
        function v = frameFlybackTime(obj)
            v = obj.scanners{2}.flybackTimeSeconds;
        end
        
        function seconds = scanTime(obj,scanfield)
            %% Returns the time required to scan the scanfield in seconds
            if ~isa(scanfield,'scanimage.mroi.scanfield.ImagingField')
                seconds = 0;
                return
            end
            
            numLines = scanfield.pixelResolution(2);
            seconds = (numLines/2^(obj.scanners{1}.bidirectionalScan)) * obj.scanners{1}.scannerPeriod; %eg 512 lines / (7920 lines/s)
            numSamples = round(seconds * obj.scanners{2}.sampleRateHz);
            seconds = numSamples / obj.scanners{2}.sampleRateHz;
        end

        function [lineScanPeriod,lineAcquisitionPeriod] = linePeriod(obj,scanfield)
            % Definition of lineScanPeriod:
            %   * scanPeriod is lineAcquisitionPeriod + includes the turnaround time for MROI scanning
            % Definition of lineAcquisitionPeriod:
            %   * lineAcquisitionPeriod is the period that is actually used for the image acquisition

            % These are set to the line scan period of the resonant scanner. Since the resonant scanner handles image
            % formation, these parameters do not have the same importance as in Galvo Galvo scanning.
            lineScanPeriod = obj.scanners{1}.scannerPeriod / 2^(obj.scanners{1}.bidirectionalScan);
            lineAcquisitionPeriod = obj.scanners{1}.scannerPeriod / 2 * obj.scanners{1}.fillFractionTemporal;
        end
        
        function [startTimes, endTimes] = acqActiveTimes(obj,scanfield)
            % TODO: implement this
            startTimes = [NaN];
            endTimes   = [NaN];
        end
        
        function seconds = transitTime(obj,scanfield_from,scanfield_to)
            %% Returns the estimated time required to position the scanners when
            % moving from scanfield to scanfield.
            % Must be a multiple of the line time
            assert(scanimage.mroi.util.transitArgumentTypeCheck(scanfield_from,scanfield_to));
            
            % FIXME: compute estimated transit time for reals
            % caller should constraint this to be an integer number of periods
            if isnan(scanfield_from)
                seconds = 0; % do not scan first flyto in plane
                return
            end
            
            if isnan(scanfield_to)
                seconds = obj.scanners{2}.flybackTimeSeconds;
            else
                seconds = obj.scanners{2}.flytoTimeSeconds;
            end
                
            samples = round(seconds * obj.scanners{2}.sampleRateHz);
            seconds = samples / obj.scanners{2}.sampleRateHz;
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,outputData)
            % input: unconcatenated output for the stack
            samplesPerTrigger.G = max( cellfun(@(frameAO)size(frameAO.G,1),outputData) );
            
            if obj.hasBeams
                hBm = obj.beams;
                [~,lineAcquisitionPeriod] = obj.linePeriod([]);
                bExtendSamples = floor(hBm.beamClockExtend * 1e-6 * hBm.sampleRateHz);
                samplesPerTrigger.B = ceil( lineAcquisitionPeriod * hBm.sampleRateHz ) + 1 + bExtendSamples;
            end
            
            if obj.hasFastZ
                samplesPerTrigger.Z = obj.fastz.samplesPerTriggerForAO(obj,outputData);
            end
        end
        
        function cfg = beamsTriggerCfg(obj)
            cfg = struct();
            if obj.hasBeams
                cfg.triggerType = 'lineClk';
                cfg.requiresReferenceClk = false;
            else
                cfg.triggerType = '';
                cfg.requiresReferenceClk = [];
            end
        end
        
        function v = resonantScanFov(obj, roiGroup)
            % returns the resonant fov that will be used to scan the
            % roiGroup. Assumes all rois will have the same x fov
            if ~isempty(roiGroup.activeRois) && ~isempty(roiGroup.activeRois(1).scanfields)
                %avoid beam and fast z ao generation
                b = obj.beams;
                z = obj.fastz;
                obj.beams = {};
                obj.fastz = {};
                
                try
                    [path_FOV,~] = obj.scanPathFOV(roiGroup.activeRois(1).scanfields(1),roiGroup.activeRois(1),0,0,0,'');
                    path_FOV = obj.refFovToScannerFov(path_FOV);
                    v = path_FOV.R(1) / obj.scanners{1}.fullAngleDegrees;
                catch ME
                    obj.beams = b;
                    obj.fastz = z;
                    ME.rethrow;
                end
                
                obj.beams = b;
                obj.fastz = z;
            else
                v = 0;
            end
        end
        
        function v = resonantScanVoltage(obj, roiGroup)
            % returns the resonant voltage that will be used to scan the
            % roiGroup. Assumes all rois will have the same x fov
            if ~isempty(roiGroup.activeRois) && ~isempty(roiGroup.activeRois(1).scanfields)
                %avoid beam and fast z ao generation
                b = obj.beams;
                z = obj.fastz;
                obj.beams = {};
                obj.fastz = {};
                
                try
                    [path_FOV,~] = obj.scanPathFOV(roiGroup.activeRois(1).scanfields(1),roiGroup.activeRois(1),0,0,0);
                    ao_volts = obj.pathFovToAo(path_FOV);
                    v = ao_volts.R(1);
                catch ME
                    obj.beams = b;
                    obj.fastz = z;
                    ME.rethrow;
                end
                
                obj.beams = b;
                obj.fastz = z;
            else
                v = 0;
            end
        end
    end
    
    methods(Access=private)
        function volts=degrees2volts(obj,fov,iscanner)
            %% Converts from fov coordinates to volts
            s=obj.scanners{iscanner};
            if isa(s,'scanimage.mroi.scanners.Resonant')
                u_fov = unique(fov);
                u_fov(isnan(u_fov)) = [];
                volts = fov; %preallocate, copy nan's
                for i = 1:numel(u_fov)
                    volts(fov == u_fov(i)) = s.fov2VoltageFunc(u_fov(i) / s.fullAngleDegrees);
                end
            else
                volts = s.position2Volts(fov);
            end
        end
    end
    
    %% Property access methods
    methods
        function v = get.angularRange(obj)
            v = [obj.scanners{1}.fullAngleDegrees diff(obj.scanners{2}.travelRange)];
        end
    end
end


%--------------------------------------------------------------------------%
% ResonantGalvo.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
