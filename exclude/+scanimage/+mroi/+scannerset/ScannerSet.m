classdef ScannerSet < handle
    properties
        scanners = {};
        beams = {};
        fastz = {};
        slm = {};
    end

    properties
        name = 'scanner';
        refToScannerTransform=eye(3);
        scannerToRefTransform=eye(3);
        transformParams = struct('offsetX', 0, 'offsetY', 0, 'scaleX', 1, 'scaleY', 1, 'rotation', 0, 'shear', 0);
        fovCornerPoints;
        fovCenterPoint;
    end
    
    properties (Abstract)
        angularRange;
    end
    
    properties (Abstract, Constant)
        optimizableScanners; % Cell array of strings e.g. {'G','Z'}
    end

    properties (Hidden, SetAccess=private)
        internalSet = false;
    end
    
    properties(Abstract, Hidden)
        CONSTRAINTS;      % Cell array of scanimage.mroi.constraints function handles
    end
    
    methods(Abstract)        
        % converts a path for all scanners (resonant, galvos, beams)
        % from field of view coordinates to output volts
        ao_volts = pathFovToAo(obj,path_FOV);
        
        % generates scan path for all scanners (resonant, galvos, beams)
        % in field of view coordinates
        [path_FOV, seconds] = scanPathFOV(obj,scanfield,scanPathFOV,actz,dzdt)
        
        % optimizes an analog waveform for tracking accuracy
        ao_volts = optimizeAO(obj,scanner,volts)
        
        % Returns the time required to scan the scanfield in seconds
        % scanfield must be a scanimage.mroi.scanfield.ScanField object.
        seconds  = scanTime(obj,scanfield);
        
        % Returns the total time required to scan a line (including scanner
        % turnaround time) and the time during which the acquisition takes
        % place
        [scanPeriod,acquisitionPeriod] = linePeriod(obj,scanfield);
        
        % Returns the active acquisition time for each line of the
        % scanfield (for precalculation of beams output)
        [startTime,endTime] = acqActiveTimes(obj,scanfield);

        % Returns array of mirror positions in FOV coordinates for parking the mirror
        % during an active scan
        position_FOV = mirrorsActiveParkPosition(obj);
        
        % Returns the estimated time required to position the scanners when
        % moving from scanfield to scanfield.
        %
        % The park position is represented by NaN
        % Either scanfield_from or scanfield_to may be NaN
        seconds  = transitTime(obj,scanfield_from,scanfield_to);
        
        % Returns the path in field of view coordinates for transitioning from one scanfield
        % to another. the transti path is represented as NaN and can be filled
        % in subsequently with the function interpolateTransits
        %
        % The park position is represented by NaN
        % Either scanfield_from or scanfield_to may be NaN
        % transits samples will be filled in with NaN
        path_FOV = transitNaN(obj,scanfieldFrom,scanfieldTo);
        
        % interpolates over NaN ranges of a path in FOV coordinates 
        path_FOV = interpolateTransits(obj,path_FOV,zWaveformType);
        
        % generates path in field of view coordinates for a flyback frame
        path_FOV = zFlybackFrame(obj, frameTime);
        
        % pads all channels to the specified time duration with NaN's
        path_FOV = padFrameAO(obj, path_FOV, frameTime, flybackTime, zWaveformType);
        
        % returns number of samples per trigger for each scanner
        samplesPerTrigger = samplesPerTriggerForAO(obj,outputData);
        
        % returns triggerType (lineClk/frameClk) and configuration of
        % refernce clock
        cfg = beamsTriggerCfg(obj);
        
        v = frameFlybackTime(obj);
    end
    
    % PROP ACCESS
    methods
        function set.refToScannerTransform(obj, v)
            obj.refToScannerTransform = v;
            
            if ~obj.internalSet
                obj.internalSet = true;
                obj.scannerToRefTransform = inv(v);
            end
            obj.internalSet = false;
        end
        
        function set.scannerToRefTransform(obj, v)
            obj.scannerToRefTransform = v;
            [a.offsetX,a.offsetY,a.scaleX,a.scaleY,a.rotation,a.shear] = scanimage.mroi.util.paramsFromTransform(v);
            obj.transformParams = a;
            
            rg = obj.angularRange * .5;
            pts = [-rg; rg.*[1 -1]; rg; rg.*[-1 1]];
            obj.fovCornerPoints = scanimage.mroi.util.xformPoints(pts,obj.scannerToRefTransform);
            obj.fovCenterPoint = scanimage.mroi.util.xformPoints([0 0],obj.scannerToRefTransform);
            
            if ~obj.internalSet
                obj.internalSet = true;
                obj.refToScannerTransform = inv(v);
            end
            obj.internalSet = false;
        end
    end
    
    methods
        function obj = ScannerSet(name,beams,fastz)
            obj.name = name;
            
            if ~isempty(beams)
                scanimage.mroi.util.asserttype(beams,'scanimage.mroi.scanners.Beams');
                obj.beams=beams;
            end
            
            if ~isempty(fastz)
                scanimage.mroi.util.asserttype(fastz,'scanimage.mroi.scanners.FastZ');
                obj.fastz = fastz;
            end
        end
        
        function count = nsamples(~,scanner,seconds)
            if isobject(scanner)
                sampleRateHz = scanner.sampleRateHz;
            else
                sampleRateHz = scanner;
            end
            
            count = round(seconds * sampleRateHz);
        end
        
        function seconds = nseconds(~,scanner,nsamples)
            
            if isobject(scanner)
                sampleRateHz = scanner.sampleRateHz;
            else
                sampleRateHz = scanner;
            end
            
            seconds = nsamples / sampleRateHz;
        end
        
        % Returns t/f indication if the scannerset includes beams
        function tf = hasBeams(obj)
            tf = ~isempty(obj.beams)...
                && (numel(obj.beams.beamIDs) > 0);
        end
        
        % Returns t/f indication if the scannerset includes fastz
        function tf = hasFastZ(obj)
            tf = ~isempty(obj.fastz);
        end
        
        % Returns t/f indication if the scannerset includes an slm
        function tf = hasSlm(obj)
            tf = ~isempty(obj.slm);
        end
        
        function tf = hasPowerBox(obj)
            tf = ~isempty(obj.beams.powerBoxes);
        end
        
        function varargout = getRoiBeamProps(obj, hRoi, varargin)
            assert((nargin-2) == nargout, 'Incorrect use of getRoiBeamProps. Number of inputs must equal outputs.');
            
            assert(obj.hasBeams)
                        
            for i = 1:nargout
                varargout{i} = hRoi.(varargin{i});
                if isempty(varargout{i})
                    varargout{i} = obj.beams.(varargin{i});
                else
                    varargout{i}(isnan(varargout{i})) = obj.beams.(varargin{i})(isnan(varargout{i}));
                end
            end
        end

        % returns a recomputed scanfield that satisfies any constraints
        % that need to be fullfilled for the scannerset.
        function roigroup = satisfyConstraintsRoiGroup(obj,roigroup,scanfield)
            sf_sample = [];
            if nargin < 3 || isempty(scanfield)
                % get a scanfield from roigroup to determine type
                scanfield = [];
                for roi = roigroup.rois(:)'
                    if ~isempty(roi.scanfields)
                       sf_sample = roi.scanfields(1);
                       break
                    end
                end
            else
                sf_sample = scanfield;
            end
            
            if isempty(sf_sample)
                return % Nothing to do
            end
            
            constraints_fields = fieldnames(obj.CONSTRAINTS);
            constraints_classes = strrep(constraints_fields,'_','.');
            
            for idx = 1:length(constraints_classes)
                if isa(sf_sample,constraints_classes{idx})
                    cellfun(@(constraint)constraint(roigroup,obj,scanfield),obj.CONSTRAINTS.(constraints_fields{idx}));
                end
            end
        end
        
        function [t,wDes,wCmd] = zWvfm(obj,roiGroup,zPowerReference,zs,fb,wvType)
            if obj.hasFastZ
                % generate ao using scannerset
                [~,~,~,fovd] = roiGroup.scanStackAO(obj,zPowerReference,zs,wvType,fb,[],[],false);
                [~,~,~,fovc] = roiGroup.scanStackAO(obj,zPowerReference,zs,wvType,fb,[],[],true);
                wDes = fovd.Z;
                wCmd = fovc.Z;
                t = (1:length(wDes))'/obj.fastz.sampleRateHz;
            else
                t = 0;
                wDes = 0;
                wCmd = 0;
            end
        end
    end % public methods
end


%--------------------------------------------------------------------------%
% ScannerSet.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
