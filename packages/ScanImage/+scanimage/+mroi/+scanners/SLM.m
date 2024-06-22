classdef SLM < handle
    % defines the SLM base functionality
    properties (Abstract, Constant)
        queueAvailable;
    end
    
    properties (SetAccess = protected)
        description;
        pixelResolutionXY; % [1x2 numeric] pixel resolution of SLM
        pixelPitchXY;      % [1x2 numeric] distance from pixel center to pixel center in meters
        interPixelGapXY;   % [1x2 numeric] pixel spacing in x and y
        pixelBitDepth;     % numeric, one of {8,16,32,64} corresponds to uint8, uint16, uint32, uint64 data type
        maxRefreshRate = Inf; % [Hz], numeric
        
        computeTransposedPhaseMask = true;
    end
    
    properties
        lut = [];                               % [Nx2 numeric] first column radiants, second column pixel values
        wavefrontCorrectionNominal = [];        % [NxM numeric] wavefront correction image in radians (non transposed)
        wavefrontCorrectionNominalWavelength = []; % [numeric] wavelength in meter, at which nominal wavefront correction was measured
        wavelength = 635e-9;                    % numeric, wavelength of incident light in meter
        focalLength = 50e-3;                    % [numeric] focal length of the lens in meter
        zeroOrderBlockRadius = 0;
        rad2PixelValFcn = @scanimage.mroi.scanners.SLM.rad2PixelValFcnDefault;
        
        updatedTriggerIn = [];
        sampleRateHz = 100;
        
        computationDatatype = 'single';
        bidirectionalScan = true;
        
        parkPosition = [0,0,0];
        beamProfile = [];                       % [MxN]intensity profile of the beam at every pixel location of the SLM
        
        showPhaseMaskDisplay = false;
        
        zAlignment = scanimage.mroi.util.zAlignmentData;
        
        slmUpdateTriggerOutputTerm = '';
        slmUpdateTriggerInputTerm = '';
    end
    
    properties (Dependent)
        pixelDataType;
        angularRangeXY;
        scanDistanceRangeXY;
        computationDatatypeNumBytes;
    end
    
    properties (Dependent, SetAccess = private)
        wavefrontCorrectionCurrentWavelength;
    end
    
    properties (SetAccess = private)
        lastWrittenPhaseMask;
        lastWrittenPoint;
        queueStarted = false;
    end
    
    properties (SetAccess = private,Hidden)
        geometryBuffer;
        linearLutBuffer;
        
        hFig;
        hAx1;
        hAx2;
        hAx3;
        hCenterPt;
        hCurrentPt;
        hCurrentPtZ;
        markedPositions = double.empty(0,3);
        hMarkedPts;
        hMarkedPtsZ;
        hText;
        hSurf;
        hDispUpdateTimer;
        phaseMaskDisplayNeedsUpdate = false;
    end
    
    %% LifeCycle
    methods
        function obj = SLM()
            
        end
        
        function delete(obj)
            if obj.queueStarted
                try
                    obj.abortQueue();
                catch ME
                    most.idioms.reportError(ME);
                end
            end
            most.idioms.safeDeleteObj(obj.hDispUpdateTimer);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% Abstract methods
    methods (Abstract)
        writePhaseMaskRawToSlm(obj,phaseMaskRaw,waitForTrigger)
    end
        
    methods (Abstract, Access = protected)
        writeSlmQueue(obj,frames);
        startSlmQueue(obj);
        abortSlmQueue(obj);
    end
    
    %% User methods
    methods        
        function writeQueue(obj,frames)
            assert(obj.queueAvailable,'Queue is not available for SLM');
            if obj.computeTransposedPhaseMask
                assert(size(frames,2)==obj.pixelResolutionXY(2) && size(frames,1) == obj.pixelResolutionXY(1),'Incorrect frame pixel resolution');
            else
                assert(size(frames,2)==obj.pixelResolutionXY(1) && size(frames,1) == obj.pixelResolutionXY(2),'Incorrect frame pixel resolution');
            end
            frames = cast(frames,obj.pixelDataType);
            
            obj.writeSlmQueue(frames);
        end
        
        function startQueue(obj)
            assert(obj.queueAvailable,'Queue is not available for SLM');
            obj.startSlmQueue();
            obj.queueStarted = true;
        end
        
        function abortQueue(obj)
            assert(obj.queueAvailable,'Queue is not available for SLM');
            obj.queueStarted = false;
            obj.abortSlmQueue();
            obj.parkScanner();
        end
        
        function out = rad2PixelVal(obj,in)
            assert(~isempty(obj.lut),'No lut specified');
            mode = 'forward';
            out = obj.rad2PixelValFcn(in,obj.lut,obj.geometryBuffer.wavefrontCorrection,mode,obj.pixelDataType);
        end
        
        function out = pixelVal2Rad(obj,in)
            assert(~isempty(obj.lut),'No lut specified');
            mode = 'reverse';
            out = obj.rad2PixelValFcn(in,obj.lut,mode,obj.pixelDataType);
        end
        
        function out = coerceRad2PixelVal(obj,in)
            assert(~isempty(obj.lut),'No lut specified');
            mode = 'coerce';
            out = obj.rad2PixelValFcn(in,obj.lut,mode,obj.pixelDataType);
        end
        
        function lut_ = loadLutFromFile(obj,filePath)
            lut_ = [];
            if nargin < 2 || isempty(filePath)
                [fileName,filePath] = uigetfile('*.*','Select look up table file');
                if isequal(fileName,0)
                    % cancelled by user
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            assert(logical(exist(filePath,'file')),'File %s could not be found on disk.',filePath);
            
            lut_ = obj.parseLutFromFile(filePath);
            
            if nargout < 1
                obj.lut = lut_;
            end
        end
        
        function saveLutToFile(obj,filePath,lut,wavelength)
            if nargin < 4 || isempty(wavelength)
                wavelength = obj.wavelength;
            end
            
            if nargin < 2 || isempty(filePath)
                defaultName = sprintf('%.0fnm.lut',wavelength*1e9);
                [fileName,filePath] = uiputfile('*.lut','Select look up table file name',defaultName);
                if isequal(fileName,0)
                    % cancelled by user
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            if nargin < 3 || isempty(lut)
                lut = obj.lut;
            end
            
            hFile = fopen(filePath,'w');
            assert(hFile>0,'Error creating file %s.',filePath);
            fprintf(hFile,'%f\t%f\n',lut');
            fclose(hFile);
        end
        
        function [wc,wavelength] = loadWavefrontCorrectionFromFile(obj,filePath,wavelength)
            if nargin < 2 || isempty(filePath)
                [fileName,filePath] = uigetfile('*.*','Select wavefront correction file');
                if isequal(fileName,0)
                    % cancelled by user
                    return
                else
                    filePath = fullfile(filePath,fileName);
                end
            end
            
            wc = double(imread(filePath));
            wc = mean(wc,3); % reduce RGB to grayscale
            
            if ~isequal(obj.pixelResolutionXY,fliplr(size(wc)))
                xRes = obj.pixelResolutionXY(1);
                yRes = obj.pixelResolutionXY(2);
                wc(:,xRes+1:end) = [];
                wc(:,end+1:xRes) = NaN;
                wc(yRes+1:end,:) = [];
                wc(end+1:yRes,:) = NaN;
                
                most.idioms.warn('Wavefront Correction File was cropped/extended to match resolution of SLM');
            end
            
            wc = wc ./ (2^obj.pixelBitDepth) * 2*pi; % convert to radians
            
            wc = unwrap(wc,[],1);
            wc = unwrap(wc,[],2);
            
            wc = wc - min(wc(:),[],'omitnan');
            
            if nargin < 3 || isempty(wavelength)
                answer = inputdlg('Wavelength (nm) for the wavefront correction:','Wavelength',1,{'1060'});
                answer = answer{1};
                
                if isempty(answer)
                    wavelength = [];
                else
                    wavelength = str2double(answer);
                    wavelength = wavelength / 1e9; % convert to meter
                end
            end

            if nargout < 1
                obj.wavefrontCorrectionNominal = wc;
                obj.wavefrontCorrectionNominalWavelength = wavelength;
            end
        end
        
        function writePhaseMaskRad(obj,phaseMaskRads,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            
            maskPixelVals = obj.rad2PixelVal(phaseMaskRads);
            obj.writePhaseMaskRaw(maskPixelVals,waitForTrigger);
        end
        
        function writePhaseMaskRaw(obj,maskPixelVals,waitForTrigger)
            if nargin < 3 || isempty(waitForTrigger)
                waitForTrigger = false;
            end
            
            if isscalar(maskPixelVals)
                maskPixelVals = repmat(maskPixelVals,obj.pixelResolutionXY(2),obj.pixelResolutionXY(1));
            end
            
            if obj.computeTransposedPhaseMask
                assert(isequal(size(maskPixelVals),obj.pixelResolutionXY));
            else
                assert(isequal(size(maskPixelVals),fliplr(obj.pixelResolutionXY)));
            end
            
            assert(~obj.queueStarted,'Cannot write to SLM while queue is started');
            
            obj.writePhaseMaskRawToSlm(maskPixelVals,waitForTrigger);
            obj.lastWrittenPhaseMask = maskPixelVals;
            obj.lastWrittenPoint = [];
            obj.phaseMaskDisplayNeedsUpdate = true;
        end

        function val = computeMultiPointPhaseMask(obj,pts)
            pts(:,end+1:4) = 1;
            val = scanimage.mroi.scanners.cghFunctions.GSW(obj,pts(:,1),pts(:,2),pts(:,3),pts(:,4));
        end
        
        function phi = computeBitmapPhaseMask(obj,bitmap)
            assert(size(bitmap,2)==obj.pixelResolutionXY(1) && size(bitmap,1)==obj.pixelResolutionXY(2));            
            
            if obj.computeTransposedPhaseMask
                bitmap = bitmap';
            end
            
            phi =  scanimage.mroi.scanners.cghFunctions.GS(obj,bitmap);
        end
        
        function val = computeSinglePointPhaseMask(obj,xm,ym,zm)
           %val = obj.computeSinglePointPhaseMaskFft(xm,ym,zm);
           val = obj.computeSinglePointPhaseMaskScalarDiffraction(xm,ym,zm);
        end

        function val = computeSinglePointPhaseMaskScalarDiffraction(obj,xm,ym,zm)
            assert(isvector(xm)&&isvector(ym)&&isvector(zm));
            assert(isequal(numel(xm),numel(ym),numel(zm)));
            assert(~isempty(obj.geometryBuffer));
            
            M = length(xm);
            xm = cast(xm,obj.computationDatatype);
            ym = cast(ym,obj.computationDatatype);
            zm = cast(zm,obj.computationDatatype);
            
            if obj.computeTransposedPhaseMask
                val = zeros(obj.pixelResolutionXY(1),obj.pixelResolutionXY(2),M,obj.computationDatatype);
            else
                val = zeros(obj.pixelResolutionXY(2),obj.pixelResolutionXY(1),M,obj.computationDatatype);
            end
            
            for m = 1:M
                if xm(m)~= 0 || ym(m)~=0
                    val(:,:,m) = obj.geometryBuffer.xj * xm(m) + obj.geometryBuffer.yj * ym(m);
                end
                if zm(m) ~= 0
                    val(:,:,m) = val(:,:,m) + zm(m)*obj.geometryBuffer.lensFactor;
                end                    
            end
        end
        
        function val = computeSinglePointPhaseMaskFft(obj,xm,ym,zm)
            assert(isvector(xm)&&isvector(ym)&&isvector(zm));
            assert(isequal(numel(xm),numel(ym),numel(zm)));
            
            M = length(xm);
            
            [px,py] = scanimage.mroi.util.xformPointsXY(xm,ym,obj.geometryBuffer.meterToPixelTransform);
            
            % This rounding means loss in precision. Can we improve this? Maybe some interpolation?
            px = round(px);
            py = round(py);
            
            if obj.computeTransposedPhaseMask
                val = zeros(obj.pixelResolutionXY(1),obj.pixelResolutionXY(2),M,obj.computationDatatype);
            else
                val = zeros(obj.pixelResolutionXY(2),obj.pixelResolutionXY(1),M,obj.computationDatatype);
            end
            
            for m = 1:M
                if obj.computeTransposedPhaseMask
                    if px >=1 && px <=size(val,1) && py >=1 && py <=size(val,2)
                        val(px,py,m) = 1;
                    end
                else
                    if py >=1 && py <=size(val,1) && px >=1 && px <=size(val,2)
                        val(py,px,m) = 1;
                    end
                end
                
                val(:,:,m) = angle(ifft2(ifftshift(val(:,:,m))));
                
                if zm(m) ~= 0
                    val(:,:,m) = val(:,:,m) + zm(m)*obj.geometryBuffer.lensFactor;
                end
            end
        end
        
        function parkScanner(obj)
            obj.pointScanner(obj.parkPosition)
        end
        
        function zeroScanner(obj)
            pt = [0 0 0];
            obj.pointScanner(pt);
        end
        
        function pointScanner(obj,point)
            if size(point,2)==2
                point(:,3) = 0;
            end
            
            if isempty(point)
                obj.parkScanner();
                return
            elseif size(point,1) == 1
                phaseMaskRad = obj.computeSinglePointPhaseMask(point(1),point(2),point(3));
            else
                phaseMaskRad = obj.computeMultiPointPhaseMask(point);
            end
            obj.writePhaseMaskRad(phaseMaskRad);
            obj.lastWrittenPoint = point;
            obj.phaseMaskDisplayNeedsUpdate = true;
        end
        
        function [pixelVals,intensities] = measureCheckerPatternResponse(obj,intensityMeasureFcn,checkerSize,numPoints,referenceVal)
            if nargin < 3 || isempty(checkerSize)
                checkerSize = 2;
            end
            
            if nargin < 4 || isempty(numPoints)
                numPoints = 256;
            end
            
            if nargin < 5 || isempty(referenceVal)
                referenceVal = 0;
            end
            
            pattern = scanimage.mroi.util.checkerPattern(obj.pixelResolutionXY,checkerSize);
            pattern(pattern == 0) = NaN;
            
            if obj.computeTransposedPhaseMask
                pattern = pattern';
            end
            
            minVal = double(intmin(obj.pixelDataType));
            maxVal = double(intmax(obj.pixelDataType));
            
            pixelVals = round(linspace(minVal,maxVal,numPoints));
            pixelVals = unique(pixelVals);
            
            intensities = zeros(size(pixelVals)); % intensity values
            
            hWb = waitbar(0,'Measuring SLM response');
            
            try
                for idx = 1:numel(pixelVals)
                    pattern_ = pattern * pixelVals(idx);
                    pattern_(isnan(pattern_)) = referenceVal;
                    
                    waitForTrigger = false;
                    obj.writePhaseMaskRaw(pattern_,waitForTrigger);
                    pause(0.06);
                    intensities(idx) = double(intensityMeasureFcn());
                    
                    assert(isvalid(hWb),'Calibration aborted by user');
                    hWb = waitbar(idx/numel(pixelVals),hWb);
                end
                delete(hWb);
            catch ME
                delete(hWb);
                rethrow(ME);
            end
        end
        
        function lut = calculateLut(obj,pixelVals,intensities)
            [pkVal,pkIdx] = obj.findPeak(intensities);            
            
            assert(~isempty(pkIdx),'Did not find peak in data');
            
            % scale Is
            intensities = abs(intensities - pkVal);
            intensities(1:pkIdx) = intensities(1:pkIdx)./intensities(1);
            intensities(pkIdx+1:end) = intensities(pkIdx+1:end)./intensities(end);
            
            intensities(intensities < 0) = 0;
            intensities(intensities > 1) = 1;
            
            phase = zeros(size(intensities));
            phase(1:pkIdx) = 2*acos(sqrt(intensities(1:pkIdx)));
            phase(pkIdx+1:end) = 2*(pi-acos(sqrt(intensities(pkIdx+1:end))));
            
            [phase,idx] = unique(phase);
            pixelVals = pixelVals(idx);
            
            assert(all(isreal(phase)),'Invalid intensities');
            lut = [phase(:),pixelVals(:)];
        end
    end
    
    %% Private Methods
    methods (Hidden)
        function lut = parseLutFromFile(obj,filePath)
            %%%
            % default function for parsing lut from file
            % can be overloaded by child classes
            hFile = fopen(filePath,'r');
            assert(hFile>0,'Error opening file %s.',filePath);
            
            formatSpec = '%f %f';
            sizeLut = [2 Inf];
            lut = fscanf(hFile,formatSpec,sizeLut)';
            fclose(hFile);
            
            if any(lut(:,1)<0 | lut(:,1)>2*pi)
                minVal = 0;
                maxVal = double(intmax(obj.pixelDataType));
                lut(:,1) = (lut(:,1)-minVal)./(maxVal-minVal).*2*pi;
            end
        end
        
        function geometryBuffer_ = updateGeometryBuffer(obj)            
            if isempty(obj.pixelResolutionXY) || isempty(obj.pixelPitchXY)...
                    || isempty(obj.wavelength) || isempty(obj.focalLength) || isempty(obj.computationDatatype)
                % Can't compute geometry buffer, some parameters are missing
                geometryBuffer_ = [];
            else
                xSpan = (obj.pixelResolutionXY(1)-1)*obj.pixelPitchXY(1);
                ySpan = (obj.pixelResolutionXY(2)-1)*obj.pixelPitchXY(2);
                
                % center coordinate of pixels
                [xj,yj] = meshgrid(linspace(-xSpan/2,xSpan/2,obj.pixelResolutionXY(1)),linspace(-ySpan/2,ySpan/2,obj.pixelResolutionXY(2)));
                lensFactor = -(pi/(obj.wavelength*obj.focalLength^2))*(xj.^2+yj.^2);
                
                prismFactor = 2*pi/(obj.wavelength*obj.focalLength);
                xj = xj*prismFactor;
                yj = yj*prismFactor;
                
                if obj.computeTransposedPhaseMask
                    % most devices use Row-major order for phase mask
                    xj = xj';
                    yj = yj';
                    lensFactor = lensFactor';
                end
                
                geometryBuffer_ = struct();
                geometryBuffer_.xj = cast(xj,obj.computationDatatype);
                geometryBuffer_.yj = cast(yj,obj.computationDatatype);
                geometryBuffer_.lensFactor  = cast(lensFactor,obj.computationDatatype);
                
                geometryBuffer_.beamProfileNormalized = abs(cast(obj.beamProfile / sum(sum(obj.beamProfile)),obj.computationDatatype));
                if obj.computeTransposedPhaseMask
                    geometryBuffer_.beamProfileNormalized = geometryBuffer_.beamProfileNormalized';
                end
                
                geometryBuffer_.meterToPixelTransform = meterToPixelTransform();
                geometryBuffer_.pixelToMeterTransform = inv(geometryBuffer_.meterToPixelTransform); 
                
                if ~isempty(obj.wavefrontCorrectionNominalWavelength)
                    wc = double(obj.wavefrontCorrectionNominal) * double((obj.wavefrontCorrectionNominalWavelength / obj.wavelength));
                else
                    wc = obj.wavefrontCorrectionNominal;
                end
                
                geometryBuffer_.wavefrontCorrection = cast(wc,obj.computationDatatype);
                if obj.computeTransposedPhaseMask
                    geometryBuffer_.wavefrontCorrection = geometryBuffer_.wavefrontCorrection';
                end
            end
            obj.geometryBuffer = geometryBuffer_;
            
            function T = meterToPixelTransform()
                S = eye(3);
                S([1,5]) = obj.pixelPitchXY .* obj.pixelResolutionXY / (obj.focalLength*obj.wavelength);
                
                O = eye(3);
                O([7,8]) = (obj.pixelResolutionXY-1)/2 + 1;
                
                T = O*S;
            end
        end
        
        function [val,idx] = findPeak(obj,intensities)
            d = abs(bsxfun(@minus,[intensities(1),intensities(end)],intensities(:)));
            d = max(d,[],2);
            [~,idx] = max(d);
            val = intensities(idx);
            
            if idx==1 || idx==length(intensities)
                idx = [];
                val = [];
            end
        end
        
        function hidePhaseMaskDisplay(obj)
            obj.showPhaseMaskDisplay = false;
        end
        
        function updateDisplayTimerFcn(obj,varargin)
            if obj.phaseMaskDisplayNeedsUpdate
                obj.phaseMaskDisplayNeedsUpdate = false;
                obj.updateDisplay();
            end
        end
        
        function updateDisplay(obj,pts)
            if nargin<2
                pts = obj.lastWrittenPoint;
            end
            
            obj.hSurf.CData = obj.lastWrittenPhaseMask;
            obj.hAx1.CLim = [0 double(intmax(obj.pixelDataType))];
            
            obj.hCenterPt.XData = 0;
            obj.hCenterPt.YData = 0;
            obj.hCenterPt.ZData = 0;
            
            if isempty(obj.markedPositions)
                obj.hMarkedPts.Visible = 'off';
                obj.hMarkedPtsZ.Visible = 'off';
            else
                obj.hMarkedPts.XData = obj.markedPositions(:,1);
                obj.hMarkedPts.YData = obj.markedPositions(:,2);
                obj.hMarkedPts.ZData = obj.markedPositions(:,3);
                
                obj.hMarkedPtsZ.XData = obj.markedPositions(:,1);
                obj.hMarkedPtsZ.YData = obj.markedPositions(:,2);
                obj.hMarkedPtsZ.ZData = obj.markedPositions(:,3);
                
                obj.hMarkedPts.Visible = 'on';
                obj.hMarkedPtsZ.Visible = 'on';
            end
            
            if isempty(obj.lastWrittenPoint)
                obj.hCurrentPt.Visible = 'off';
                obj.hCurrentPtZ.Visible = 'off';
                obj.hText.Visible = 'off';
            else
                obj.hCurrentPt.Visible = 'on';
                obj.hCurrentPtZ.Visible = 'on';
                
                obj.hCurrentPt.XData = pts(:,1);
                obj.hCurrentPt.YData = pts(:,2);
                obj.hCurrentPt.ZData = pts(:,3);
                
                obj.hCurrentPtZ.XData = pts(:,1);
                obj.hCurrentPtZ.YData = pts(:,2);
                obj.hCurrentPtZ.ZData = pts(:,3);
                
                if size(obj.lastWrittenPoint,1)>=2
                    obj.hText.Visible = 'off';
                else
                    obj.hText.Visible = 'on';
                    obj.hText.String = sprintf('X: %s \nY: %s \nZ: %s ',most.idioms.engineersStyle(pts(1,1),'m','%.f'),most.idioms.engineersStyle(pts(1,2),'m','%.f'),most.idioms.engineersStyle(pts(1,3),'m','%.f'));
                end
            end
        end
        
        function initPhaseMaskDisplay(obj)                
            obj.hFig = figure('Visible','off','CloseRequestFcn',@(src,evt)obj.hidePhaseMaskDisplay,'Name','Phase Mask Display','Numbertitle','off','WindowScrollWheelFcn',@obj.windowScroll);
            p = most.gui.centeredScreenPos([620 800],'characters');
            obj.hFig.Position = p;
            
            obj.hAx1 = subplot(3,2,1:4);
            obj.hAx2 = subplot(3,2,5);
            obj.hAx3 = subplot(3,2,6);
            
            dims = obj.pixelResolutionXY;
            [xx,yy,zz] = meshgrid([-dims(1) dims(1)]/2,[-dims(2) dims(2)]/2,0);
            if obj.computeTransposedPhaseMask
                xx = xx';
                yy = yy';
                zz = zz';
            end
            obj.hSurf = surface('Parent',obj.hAx1,...
                'XData',xx,'YData',yy,'ZData',zz,'CData',0,...
                'FaceColor','texturemap',...
                'CDataMapping','scaled',...
                'FaceLighting','none',...
                'LineStyle','none');
            obj.hAx1.XLim = [-dims(1) dims(1)]/2;
            obj.hAx1.YLim = [-dims(2) dims(2)]/2;
            obj.hAx1.DataAspectRatio = [1 1 1];
            box(obj.hAx1,'on');
            
            %view(obj.hAx1,0,-90); % this messes up the zoom functions in the menu bar
            obj.hAx1.YDir = 'reverse';
            
            title(obj.hAx1,'SLM Phase Mask [pixel value]');
            colorbar(obj.hAx1);
            
            obj.hAx2.XLim = [-obj.scanDistanceRangeXY(1)/2 obj.scanDistanceRangeXY(1)/2];
            obj.hAx2.YLim = [-obj.scanDistanceRangeXY(2)/2 obj.scanDistanceRangeXY(2)/2];
            obj.hAx2.DataAspectRatio = [1,1,1];
            view(obj.hAx2,0,-90); % [x,-y] view
            grid(obj.hAx2,'on');
            box(obj.hAx2,'on');
            title(obj.hAx2,'SLM Position');
            xlabel(obj.hAx2,'x');
            ylabel(obj.hAx2,'y');
            zlabel(obj.hAx2,'z');
            
            obj.hAx3.XLim = [-obj.scanDistanceRangeXY(1)/2 obj.scanDistanceRangeXY(1)/2];
            obj.hAx3.YLim = [-obj.scanDistanceRangeXY(2)/2 obj.scanDistanceRangeXY(2)/2];
            obj.hAx3.ZLim = [-obj.scanDistanceRangeXY(2) obj.scanDistanceRangeXY(2)];
            obj.hAx3.DataAspectRatio = [diff(obj.hAx3.XLim),diff(obj.hAx3.YLim),diff(obj.hAx3.ZLim)];
            view(obj.hAx3,0,180); % [x,-z] view
            grid(obj.hAx3,'on');
            box(obj.hAx3,'on');
            title(obj.hAx3,'Z');
            xlabel(obj.hAx3,'x');
            ylabel(obj.hAx3,'y');
            zlabel(obj.hAx3,'z');
            
            hPtContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hPtContextMenu,'Label','Park','Callback',@(src,evt)obj.parkScanner);
            uimenu('Parent',hPtContextMenu,'Label','Zero','Callback',@(src,evt)obj.zeroScanner);
            uimenu('Parent',hPtContextMenu,'Label','Mark Point','Callback',@mark);
            uimenu('Parent',hPtContextMenu,'Label','Delete Point','Callback',@deletePoint);
            
            hAx2ContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hAx2ContextMenu,'Label','Park','Callback',@(src,evt)obj.parkScanner);
            uimenu('Parent',hAx2ContextMenu,'Label','Zero','Callback',@(src,evt)obj.zeroScanner);
            uimenu('Parent',hAx2ContextMenu,'Label','Delete Marks','Callback',@deleteMarks);
            uimenu('Parent',hAx2ContextMenu,'Label','Add Point','Callback',@addPoint);
            obj.hAx2.UIContextMenu = hAx2ContextMenu;
            
            hMarkedPtsContextMenu = uicontextmenu('Parent',obj.hFig);
            uimenu('Parent',hMarkedPtsContextMenu,'Label','Goto Mark','Callback',@goToMark);
            uimenu('Parent',hMarkedPtsContextMenu,'Label','Delete Mark','Callback',@deleteMark);
            
            obj.hCenterPt = line('Parent',obj.hAx2,'XData',0,'YData',0,'ZData',0,'Marker','+','Color','black','HitTest','off','PickableParts','none');
            obj.hMarkedPts = line('Parent',obj.hAx2,'XData',[],'YData',[],'Marker','x','Color','black','LineStyle','none','UIContextMenu',hMarkedPtsContextMenu);
            obj.hMarkedPtsZ = line('Parent',obj.hAx3,'XData',[],'YData',[],'Marker','x','Color','black','LineStyle','none');
            obj.hText = text('Parent',obj.hAx2,'Position',[obj.hAx2.XLim(2) obj.hAx2.YLim(1)],'HorizontalAlignment','right','VerticalAlignment','top','HitTest','off','PickableParts','none');
            obj.hCurrentPt = line('Parent',obj.hAx2,'XData',NaN,'YData',NaN,'ZData',NaN,'Marker','o','Color','red','LineStyle','none','ButtonDownFcn',@obj.startMove,'UIContextMenu',hPtContextMenu);
            obj.hCurrentPtZ = line('Parent',obj.hAx3,'XData',NaN,'YData',NaN,'ZData',NaN,'Marker','o','Color','red','LineStyle','none','ButtonDownFcn',@obj.startMove,'UIContextMenu',hPtContextMenu);
            
            obj.hDispUpdateTimer = timer('Period',0.3,'ExecutionMode','fixedSpacing','BusyMode','drop','Name','SLM Phase Mask Display Update Timer','TimerFcn',@obj.updateDisplayTimerFcn);
            
            function mark(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.lastWrittenPoint);
                obj.markedPositions(end+1,:) = obj.lastWrittenPoint(idx,:);
            end
            
            function deleteMark(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.markedPositions);
                obj.markedPositions(idx,:) = [];
            end
            
            function deleteMarks(src,evt)
                obj.markedPositions = [];
            end
            
            function goToMark(src,evt)
                pt = obj.hAx2.CurrentPoint(1,1:2);
                pts = obj.markedPositions;
                d = bsxfun(@minus,pts(:,1:2),pt);
                d = sqrt(d(:,1).^2+d(:,2).^2);
                [~,idx] = min(d);
                
                obj.pointScanner(obj.markedPositions(idx,:));
            end
            
            function deletePoint(src,evt)
                idx = obj.closestPointIdx(obj.hAx2,obj.lastWrittenPoint);
                pts_ = obj.lastWrittenPoint;
                pts_(idx,:) = [];
                obj.pointScanner(pts_);
            end
            
            function addPoint(src,evt)
                newPt = obj.hAx2.CurrentPoint(1,1:2);
                pts_ = obj.lastWrittenPoint;
                pts_(end+1,:) = [newPt 0];
                obj.pointScanner(pts_);
            end
        end
        
        function windowScroll(obj,src,evt)
            ct = evt.VerticalScrollCount;
            
            ct = sign(ct);
            factor = 2^(ct/10);
            obj.hAx3.ZLim = obj.hAx3.ZLim * factor;
            xspan = diff(obj.hAx3.XLim);
            yspan = diff(obj.hAx3.YLim);
            zspan = diff(obj.hAx3.ZLim);
            obj.hAx3.DataAspectRatio = [xspan, yspan, zspan];
        end
        
        function startMove(obj,src,evt)
            hFig_ = ancestor(src,'figure');
            hAx_ = ancestor(src,'axes');
            idx = obj.closestPointIdx(hAx_,obj.lastWrittenPoint);
            hFig_.WindowButtonMotionFcn = @(src_,evt_)obj.move(src_,evt,src,idx);
            hFig_.WindowButtonUpFcn = @obj.endMove;
        end
        
        function endMove(obj,src,evt)
            hFig_ = ancestor(src,'figure');
            hFig_.WindowButtonMotionFcn = [];
            hFig_.WindowButtonUpFcn = [];
        end
        
        function move(obj,src,evt,line,idx)
            try
                hAx_ = ancestor(line,'axes');
                mousePt = hAx_.CurrentPoint;
                
                pts = obj.lastWrittenPoint;
                pt = pts(idx,:);
                
                [~,projectedPt] = scanimage.mroi.util.distanceLinePts3D(mousePt(1,:),diff(mousePt),pt);
                
                pts(idx,:) = projectedPt;
                
                obj.updateDisplay(pts);
                obj.pointScanner(pts);
            catch ME
                obj.endMove(src,evt);
                rethrow(ME);
            end
        end
        
        function idx = closestPointIdx(obj,hAx_,pts)
            mousept = hAx_.CurrentPoint;
            d = scanimage.mroi.util.distanceLinePts3D(mousept(1,:),diff(mousept),pts); 
            [~,idx] = min(d);
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.zAlignment(obj,val)
            if isempty(val)
                val = scanimage.mroi.util.zAlignmentData();
            end
            
            assert(isa(val,'scanimage.mroi.util.zAlignmentData'));
            
            obj.zAlignment = val;
        end
        
        function set.markedPositions(obj,val)
            if isempty(val)
                val = double.empty(0,3);
            end
                
            obj.markedPositions = val;
            obj.updateDisplay();
        end
        
        function set.showPhaseMaskDisplay(obj,val)
            obj.showPhaseMaskDisplay = val;
            
            if isempty(obj.hFig) || ~isvalid(obj.hFig)
                obj.initPhaseMaskDisplay();
            end
            
            if val
                obj.hFig.Visible = 'on';
                uistack(obj.hFig,'top');
                if ~strcmpi(obj.hDispUpdateTimer.Running,'on')
                    start(obj.hDispUpdateTimer);
                end
            else
                obj.hFig.Visible = 'off';
                stop(obj.hDispUpdateTimer);
            end
        end
        
        function set.parkPosition(obj,val)
            assert(isnumeric(val) && isrow(val) && (numel(val)==2 || numel(val)==3));
            if numel(val) == 2
                val(3) = 0;
            end
            obj.parkPosition = val;
        end
        
        function set.pixelBitDepth(obj,val)
            obj.pixelBitDepth = val;
            
            minVal = double(intmin(obj.pixelDataType));
            maxVal = double(intmax(obj.pixelDataType));
            numVals = 2;
            
            obj.linearLutBuffer = [linspace(0,2*pi,numVals)',linspace(minVal,maxVal,numVals)'];
        end
        
        function set.pixelResolutionXY(obj,val)
            obj.pixelResolutionXY = val;
            obj.updateGeometryBuffer();
        end
        
        function set.pixelPitchXY(obj,val)
            obj.pixelPitchXY = val;
            obj.updateGeometryBuffer();
        end
        
        function set.wavelength(obj,val)
            obj.wavelength = val;
            obj.updateGeometryBuffer();
        end
        
        function set.focalLength(obj,val)
            obj.focalLength = val;
            obj.updateGeometryBuffer();
        end 
        
        function set.computationDatatype(obj,val)
            obj.computationDatatype = val;
            obj.updateGeometryBuffer();
            obj.updateBeamProfileNormalized();
        end            
        
        function set.computeTransposedPhaseMask(obj,val)
            obj.computeTransposedPhaseMask = val;
            obj.updateGeometryBuffer();
        end
            
        
        function val = get.pixelDataType(obj)
            switch obj.pixelBitDepth
                case 8
                    val = 'uint8';
                case 16
                    val = 'uint16';
                case 32
                    val = 'uint32';
                case 64
                    val = 'uint64';
                otherwise
                    error('Unknown datatype of length %d',obj.pixelBitDepth);
            end
        end
        
        function set.maxRefreshRate(obj,val)
            validateattributes(val,{'numeric'},{'positive','nonnan','scalar'});
            obj.maxRefreshRate = val;
        end
        
        function val = get.lut(obj)
            val = obj.lut;
            
            if isempty(val)
                val = obj.linearLutBuffer;
            end
        end
        
        function set.wavefrontCorrectionNominal(obj,val)
            if ~isempty(val)
                assert(isequal(fliplr(size(val)),obj.pixelResolutionXY),'Wavefront correction must be a %dx%d matrix',obj.pixelResolutionXY(1),obj.pixelResolutionXY(2));
            end
            
            obj.wavefrontCorrectionNominal = val;
            obj.updateGeometryBuffer();
        end
        
        function set.wavefrontCorrectionNominalWavelength(obj,val)
            if ~isempty(val)
                validateattributes(val,{'numeric'},{'scalar','positive','finite'});
            end
            
            obj.wavefrontCorrectionNominalWavelength = val;
            obj.updateGeometryBuffer();
        end
        
        function val = get.wavefrontCorrectionCurrentWavelength(obj)
            val = obj.geometryBuffer.wavefrontCorrection;
            
            if obj.computeTransposedPhaseMask
                val = val';
            end
        end
        
        function val = get.computationDatatypeNumBytes(obj)
            sample = zeros(1,obj.computationDatatype);
            info = whos('sample');
            val = info.bytes;
        end
        
        function val = get.angularRangeXY(obj)            
            maximumDeflection = atan(obj.wavelength./obj.pixelPitchXY/2)*(180/pi);
            val = 2*maximumDeflection;
        end
        
        function val = get.scanDistanceRangeXY(obj)
            val = obj.focalLength*tan(obj.angularRangeXY/180*pi/2)*2;
            %val = abs(scanimage.mroi.util.xformPoints(obj.pixelResolutionXY,obj.geometryBuffer.pixelToMeterTransform) - scanimage.mroi.util.xformPoints([1,1],obj.geometryBuffer.pixelToMeterTransform));
        end
        
        function set.beamProfile(obj,val)
            val = cast(val,obj.computationDatatype);
            obj.beamProfile = val;
            obj.updateGeometryBuffer();
        end
        
        function val = get.beamProfile(obj)
            val = obj.beamProfile;
            if isempty(val)
                val = ones(obj.pixelResolutionXY(2),obj.pixelResolutionXY(1),obj.computationDatatype);
            end
        end
    end
    
    methods (Static)
        function out = rad2PixelValFcnDefault(phi,lut,wavefrontCorrection,mode,pixelDataType)
            if nargin < 3 || isempty(wavefrontCorrection)
                wavefrontCorrection = [];
            end
            
            if nargin < 4 || isempty(mode)
                mode = 'forward';
            end
            
            if nargin < 5 || isempty(pixelDataType)
                pixelDataType = class(phi);
            end
            
            if ~isempty(wavefrontCorrection)
                phi = phi + wavefrontCorrection;
            end
            
            
            phi_size = size(phi);
            phi = phi(:);
            switch mode
                case 'forward'
                    % coerce to [0,2*pi], center around pi
                    % phi = phi-min(phi(:));
                    %phiMean = mod(mean(phi(:)),2*pi);
                    %phi = phi+(3*pi-phiMean);
                    %phi = mod(phi,2*pi); % why is this so slow? Any chance we can speed this up?
%                    assert(min(lut(:,1))>=0);
                    n = double(max(lut(:,1)))/(2*pi);
                    if mod(n,1) > 0.95
                        n = ceil(n);
                    else
                        n = floor(n);
                    end
                    n = max(1,n);
                    lutmax = cast(n*2*pi,'like',phi); % n*(2*pi)
                    phi = phi - lutmax*floor(phi/lutmax); % mod is slower than this
                    
                    lut = cast(lut,'like',phi);
                    hGI = griddedInterpolant(lut(:,1),lut(:,2),'linear','nearest'); % about twice as fast as interp1
                    out_float = hGI(phi);
                    
                    out = cast(out_float,pixelDataType);
                case 'reverse'
                    error('Implement me!');
                case 'coerce'
                    error('Implement me!');
                otherwise
                    error('Unknown mode: %s',mode);
            end
            
            out = reshape(out,phi_size);
        end
    end
end



%--------------------------------------------------------------------------%
% SLM.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
