classdef SLM < handle
    % defines the SLM base functionality
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
        wavelength = 635e-9;                    % numeric, wavelength of incident light in meter
        focalLength = 50e-3;                    % [numeric] focal length of the lens in meter
        zeroOrderBlockRadius = 0;
        rad2PixelValFcn = @scanimage.mroi.scanners.SLM.rad2PixelValFcnDefault;
        
        updatedTriggerIn = [];;
        sampleRateHz = 100;
        
        computationDatatype = 'single';
        bidirectionalScan = true;
        
        parkPosition = [0,0,0];
        staticOffset = [0,0,0];
        beamProfile = [];
        
        showPhaseMaskDisplay = false;
    end
    
    properties (Dependent)
        pixelDataType;
        angularRangeXY;
        scanDistanceRangeXY;
        computationDatatypeNumBytes;
        waveNumber;
    end
    
    properties (SetAccess = private)
        lastWrittenPhaseMask;
    end
    
    properties (SetAccess = private,Hidden)
        geometryBuffer;
        linearLutBuffer;
        
        hFig;
        hAx;
        hSurf;
        hDispUpdateTimer;
        phaseMaskDisplayNeedsUpdate = false;
    end
    
    %% LifeCycle
    methods
        function obj = SLM()
            
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hDispUpdateTimer);
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    %% Abstract methods
    methods (Abstract)
        writePhaseMaskRawToSlm(obj,phaseMaskRaw,waitForTrigger)
    end
    
    %% User methods
    methods
        function out = rad2PixelVal(obj,in)
            assert(~isempty(obj.lut),'No lut specified');
            mode = 'forward';
            out = obj.rad2PixelValFcn(in,obj.lut,mode,obj.pixelDataType);
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
        
        function lut = loadLutFromFile(obj,filePath)
            lut = [];
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
            
            hFile = fopen(filePath,'r');
            assert(hFile>0,'Error opening file %s.',filePath);
            
            formatSpec = '%d %d';
            sizeLut = [2 Inf];
            lut = fscanf(hFile,formatSpec,sizeLut)';
            fclose(hFile);
            
            if any(lut(:,1)<0 | lut(:,1)>2*pi)
                maxVal = max(lut(:,1));
                minVal = min(lut(:,1));
                lut(:,1) = (lut(:,1)-minVal)./(maxVal-minVal).*2*pi;
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
            
            obj.writePhaseMaskRawToSlm(maskPixelVals,waitForTrigger);
            obj.lastWrittenPhaseMask = maskPixelVals;
            obj.phaseMaskDisplayNeedsUpdate = true;
        end

        function val = computeMultiPointPhaseMask(obj,pts)
            pts(:,end+1:4) = 1;
            val = scanimage.mroi.scanners.cghFunctions.GSW(obj,pts(:,1),pts(:,2),pts(:,3),pts(:,4));
        end
        
        function val = computeSinglePointPhaseMask(obj,xm,ym,zm)
           %val = obj.computeSinglePointPhaseMaskFft(xm,ym,zm);
           val = obj.computeSinglePointPhaseMaskScalarDiffraction(xm,ym,zm);
        end

        function val = computeSinglePointPhaseMaskScalarDiffraction(obj,xm,ym,zm)
            assert(isvector(xm)&&isvector(ym)&&isvector(zm));
            assert(isequal(numel(xm),numel(ym),numel(zm)));
            assert(~isempty(obj.geometryBuffer));
            
            xm = xm + obj.staticOffset(1);
            ym = ym + obj.staticOffset(2);
            zm = zm + obj.staticOffset(3);
            
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
                if zm(m) ~= 0;
                    val(:,:,m) = val(:,:,m) + zm(m)*obj.geometryBuffer.lensFactor;
                end                    
            end
        end
        
        function val = computeSinglePointPhaseMaskFft(obj,xm,ym,zm)
            assert(isvector(xm)&&isvector(ym)&&isvector(zm));
            assert(isequal(numel(xm),numel(ym),numel(zm)));
            
            xm = xm + obj.staticOffset(1);
            ym = ym + obj.staticOffset(2);
            zm = zm + obj.staticOffset(3);
            
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
                
                if zm(m) ~= 0;
                    val(:,:,m) = val(:,:,m) + zm(m)*obj.geometryBuffer.lensFactor;
                end
            end
        end
        
        function parkScanner(obj)
            obj.pointScanner(obj.parkPosition)
        end
        
        function pointScanner(obj,point)
            point = point(:);
            if length(point)==2
                point(3) = 0;
            end
            
            phaseMaskRad = obj.computeSinglePointPhaseMask(point(1),point(2),point(3));
            obj.writePhaseMaskRad(phaseMaskRad);
        end
        
        function lut = calibrateLut(obj,intensityMeasureFcn)
            checkerSize = 2;
            pattern = scanimage.mroi.util.checkerPattern(obj.pixelResolutionXY,checkerSize);
            pattern = cast(pattern,obj.pixelDataType);
            
            if obj.computeTransposedPhaseMask
                pattern = pattern';
            end
            
            minVal = intmin(obj.pixelDataType);
            maxVal = intmax(obj.pixelDataType);
            
            staticVal = 255;
            outputVals = double((maxVal:-1:minVal))';
            
            I = zeros(size(outputVals));
            
            hWb = waitbar(0,'Calibrating SLM LUT');
            try
                for idx = 1:numel(outputVals)
                    pattern_ = pattern * outputVals(idx);
                    pattern_(pattern_ == 0) = staticVal;
                    
                    waitForTrigger = false;
                    obj.writePhaseMaskRaw(pattern_,waitForTrigger);
                    pause(0.05);
                    I(idx) = double(intensityMeasureFcn());
                    
                    hWb = waitbar(idx/numel(outputVals),hWb);
                end
                delete(hWb);
            catch ME
                delete(hWb);
                rethrow(ME);
            end
            
            obj.parkScanner();
            
%            I = scanimage.util.smooth(I,3);
            
            figure
            plot(outputVals,I)
            hold on
            
            % process data
            peakIdxsMax = scanimage.util.peakFinder(I,[],[], 1,false,[]);
            peakIdxsMin = scanimage.util.peakFinder(I,[],[],-1,false,[]);
            
            peakIdxsMax = vertcat(1,peakIdxsMax);
            if peakIdxsMax(2) <  peakIdxsMin
                peakIdxsMax(2) = [];
            end            
            
            peakIdxs = sort(unique(vertcat(peakIdxsMax,peakIdxsMin)));
            
            plot(outputVals(peakIdxs),I(peakIdxs),'+');
            
            % scaling
            I_scaled = nan(size(I));
            phase  = nan(size(I));
            for idx = 2:length(peakIdxs)
                idx1 = peakIdxs(idx-1);
                idx2 = peakIdxs(idx);
                
                Imin = min(I(idx1:idx2));
                Imax = max(I(idx1:idx2));
                
                I_scaled(idx1:idx2) = (I(idx1:idx2)-Imin)./(Imax-Imin);
                
                if I(idx1) > I(idx2)
                    phase(idx1:idx2) = 2*acos(sqrt(I_scaled(idx1:idx2)));
                else
                    phase(idx1:idx2) = 2*(pi-acos(sqrt(I_scaled(idx1:idx2))));
                end
            end
            
            phase = unwrap(phase);
            phase = phase - phase(1);
            
            cutoff = find(~(phase < 2*pi),1,'first');
            
            phase = phase(1:cutoff);
            outputVals = outputVals(1:cutoff);            
            
            [~,uniqueIdxs] = unique(phase);
            uniqueMask = false(size(phase));
            uniqueMask(uniqueIdxs) = true;
            
            nanMask = ~isnan(phase);
            mask = uniqueMask & nanMask;
            
            phase = phase(mask);
            outputVals = outputVals(mask);
            
            
            polyDegree = 3;
            p = polyfit(outputVals,phase,polyDegree);
            phase_smooth = polyval(p,outputVals);
            
            %phase_smooth = (phase_smooth-min(phase_smooth))/(max(phase_smooth)-min(phase_smooth))*2*pi;
            phase_smooth = -phase_smooth + 2*pi;
            
            lut = [phase_smooth,outputVals];
        end
    end
    
    %% Private Methods
    methods (Hidden)
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
                
                geometryBuffer_.beamProfileNormalized = cast(obj.beamProfile / sum(sum(obj.beamProfile)),obj.computationDatatype);
                if obj.computeTransposedPhaseMask
                    geometryBuffer_.beamProfileNormalized = geometryBuffer_.beamProfileNormalized';
                end
                
                geometryBuffer_.meterToPixelTransform = meterToPixelTransform();
                geometryBuffer_.pixelToMeterTransform = inv(geometryBuffer_.meterToPixelTransform); 
            end
            obj.geometryBuffer = geometryBuffer_;
            
            function T = meterToPixelTransform()
                S = eye(3);
                S([1,5]) = obj.pixelPitchXY .* obj.pixelResolutionXY / (obj.focalLength*obj.wavelength);
                
                O = eye(3);
                O([7,8]) = floor(obj.pixelResolutionXY/2)+1;
                
                T = O*S;
            end
        end
        
        function hidePhaseMaskDisplay(obj)
            obj.showPhaseMaskDisplay = false;
        end
        
        function updateDisplay(obj,varargin)
            if obj.phaseMaskDisplayNeedsUpdate
                obj.phaseMaskDisplayNeedsUpdate = false;
                obj.hSurf.CData = obj.lastWrittenPhaseMask;
            end
        end
        
        function initPhaseMaskDisplay(obj)
            obj.hFig = figure('Visible','off','CloseRequestFcn',@(src,evt)obj.hidePhaseMaskDisplay,'Name','Phase Mask Display','Numbertitle','off');
            obj.hAx  = axes('Parent',obj.hFig);
            dims = obj.pixelResolutionXY;
            [xx,yy,zz] = meshgrid([-dims(1) dims(1)]/2,[-dims(2) dims(2)]/2,0);
            if obj.computeTransposedPhaseMask
                xx = xx';
                yy = yy';
                zz = zz';
            end
            obj.hSurf = surface('Parent',obj.hAx,...
                'XData',xx,'YData',yy,'ZData',zz,'CData',0,...
                'FaceColor','texturemap',...
                'CDataMapping','scaled',...
                'FaceLighting','none');
            obj.hAx.XLim = [-dims(1) dims(1)]/2;
            obj.hAx.YLim = [-dims(2) dims(2)]/2;
            obj.hAx.DataAspectRatio = [1 1 1];
            
            %view(obj.hAx,0,-90); % this messes up the zoom functions in the menu bar
            obj.hAx.YDir = 'reverse';
            
            title(obj.hAx,'SLM Phase Mask');
            colorbar(obj.hAx);
            
            obj.hDispUpdateTimer = timer('Period',0.3,'ExecutionMode','fixedSpacing','BusyMode','drop','Name','SLM Phase Mask Display Update Timer','TimerFcn',@obj.updateDisplay);
        end
    end
    
    %% Property Getter/Setter
    methods
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
            obj.parkPosition = val;
        end
        
        function set.staticOffset(obj,val)
            assert(isnumeric(val) && isrow(val) && (numel(val)==2 || numel(val)==3));
            obj.staticOffset = val;
        end
        
        function set.pixelBitDepth(obj,val)
            obj.pixelBitDepth = val;
            
            minVal = double(intmin(obj.pixelDataType));
            maxVal = double(intmax(obj.pixelDataType));
            numVals = maxVal-minVal+1;
            
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
        
        function k = get.waveNumber(obj)
            k = 2*pi/obj.wavelength;
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
        function out = rad2PixelValFcnDefault(phi,lut,mode,pixelDataType)
            if nargin < 3 || isempty(mode)
                mode = 'forward';
            end
            
            if nargin < 4 || isempty(pixelDataType)
                pixelDataType = class(phi);
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
                    n = max(lut(:,1))/(2*pi);
                    if mod(n,1) > 0.95
                        n = ceil(n);
                    else
                        n = floor(n);
                    end
                    n = max(1,n);
                    lutmax = cast(n*2*pi,'like',phi); % n*(2*pi)
                    phi = phi - lutmax*floor(phi/lutmax); % mod is slower than this
                    
                    lut = cast(lut,'like',phi);
                    hGI = griddedInterpolant(lut(:,1),lut(:,2),'nearest','nearest'); % about twice as fast as interp1
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
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
