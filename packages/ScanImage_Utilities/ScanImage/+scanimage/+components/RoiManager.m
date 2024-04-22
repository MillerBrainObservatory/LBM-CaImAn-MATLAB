classdef RoiManager < scanimage.interfaces.Component
    %RoiManager     Functionality to manage regions of interest (ROIs)

    %% USER PROPS    
    properties (SetObservable)
        %%% Frame geometry and resolution

        pixelsPerLine = 512;            % defaultROI only: horizontal resolution
        linesPerFrame = 512;            % defaultROI only: vertical resolution
        
        scanZoomFactor = 1;             % defaultROI only: value of zoom. Constraint: zoomFactor >= 1
        scanRotation   = 0;             % defaultROI only: rotation counter clockwise about the Z-axis of the scanned area or line (degrees)
        scanAngleMultiplierSlow = 1;    % defaultROI only: scale slow output
        scanAngleMultiplierFast = 1;    % defaultROI only: scale fast scanner output
        scanAngleShiftSlow = 0;         % defaultROI only: shift slow scanner output (in FOV coordinates)
        scanAngleShiftFast = 0;         % defaultROI only: shift fast scanner output (in FOV coordinates)
        
        forceSquarePixelation = true;   % defaultROI only: specifies if linesPerFrame is forced to equal pixelsPerLine (logical type)
        forceSquarePixels = true;       % defaultROI only: if true scanAngleMultiplierSlow is constrained to match the fraction scanAngleMultiplierFast * linesPerFrame/pixelsPerLine (logical type)
    end
    
    properties (SetObservable, Dependent)
        %%% Frame timing

        scanFrameRate;                  % number of frames per second.
        scanFramePeriod;                % seconds per frame.
        linePeriod;                     % seconds to scan one line.
        scanVolumeRate;                 % number of volumes per second.
    end
    
    properties (SetObservable, Dependent, Transient)
        currentRoiGroup;                % The currently set roiGroup.
        
        % FOV Information for header for non mroi mode
        imagingFovDeg;                      % [deg] corner points of the scanned area in degrees
        imagingFovUm;                       % [um] corner points of the scanned area in micros
    end
    
    properties(SetObservable)
        mroiEnable = false;             % If false, scan single scanfield with settings derived from below. If true, scan scanfields/rois as defined in roiGroupMroi (logical type)
        roiGroupMroi;                   % The roiGroup used for MROI focus/grab/loop modes. (Excluded from Tiff header)
        roiGroupLineScan;               % The roiGroup used for arbitrary line scanning focus/grab/loop modes. (Excluded from Tiff header)
        scanType = 'frame';
    end
    
    properties(Hidden)
        roiLive = true;
    end
    
    
        
    properties (Hidden, Dependent)
        scanSettings;                   % summary of the scan settings for the default imaging roi
    end
    
    properties (Hidden,Constant)
        DEFAULT_NAME_ROIGROUP = 'Default Imaging ROI Group';
        DEFAULT_NAME_ROI = 'Default Imaging Roi';
        DEFAULT_NAME_SCANFIELD = 'Default Imaging Scanfield';
    end
    
    %% INTERNAL PROPS
    properties(Hidden, Access = private)
        hRoiGroupDelayedEventListener;
        hCfgLoadingListener;
        abortUpdatePixelRatioProps = false;
        preventLiveUpdate = false;
        cachedScanTimesPerPlane;
        scan2DProps = struct();         % stores settings for different scanner systems
    end
    
    properties(SetObservable, Hidden, SetAccess = private)
        roiGroupDefault_;
        isLineScan = false;
    end
    
    properties(Hidden, Dependent, SetAccess = private)
        roiGroupDefault;                % The roiGroup used for non-MROI focus/grab/loop modes.
        currentNonDefRoiGroup;          % Current not default roi group (line or mroi)
        refAngularRange;                % Angular range that encompasses FOV of all scanners;
    end
    
    properties(Hidden, Dependent, SetObservable)
        fastZSettling;
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'roiGroupMroi' 'currentRoiGroup' 'roiGroupLineScan' 'scan2DProps'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'RoiGroup';                        % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {...                  % Cell array of strings specifying properties that can be set while focusing
            'scanZoomFactor','scanRotation','scanAngleMultiplierSlow',...
            'scanAngleMultiplierFast','scanAngleShiftSlow','scanAngleShiftFast'};
        DENY_PROP_LIVE_UPDATE = {'mroiEnable' 'scanType'};                         % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% EVENTS
    events (Hidden)
        pixPerLineChanged;
        imagingRoiGroupChanged;
    end
    
    %% LIFECYCLE
    methods
        function obj = RoiManager(hSI)
            obj = obj@scanimage.interfaces.Component(hSI);
        end
        
        function delete(obj)
            % DELETE  Safely deletes the instance.

            most.idioms.safeDeleteObj(obj.roiGroupMroi);
            most.idioms.safeDeleteObj(obj.roiGroupLineScan);
            most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener);
            most.idioms.safeDeleteObj(obj.roiGroupDefault_);
            most.idioms.safeDeleteObj(obj.hCfgLoadingListener);
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@most.Model(obj);
            
            %create default roi groups
            obj.roiGroupMroi  = scanimage.mroi.RoiGroup('MROI Imaging ROI Group');
            obj.roiGroupLineScan  = scanimage.mroi.RoiGroup('Line Scanning ROI Group');
            
            %add listener to know when config file finishes loading to do batch operations on new prop values
            obj.hCfgLoadingListener = addlistener(obj.hSI.hConfigurationSaver,'cfgLoadingInProgress','PostSet',@obj.cfgLoadingChanged);
        end
    end
    
    %% PROP ACCESS
    methods
        function set.roiGroupMroi(obj,val)
            if ~isobject(val)
                % this is just a dummy set to update dependent properties
            else
                assert(isa(val,'scanimage.mroi.RoiGroup')&&most.idioms.isValidObj(val), 'Invalid roi group object');
                % set new roiGroup
                obj.roiGroupMroi = val;
                
                if ~obj.isLineScan
                    % delete old listener
                    most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener)
                    % create new listener
                    obj.hRoiGroupDelayedEventListener = most.util.DelayedEventListener(0.5,obj.roiGroupMroi,'changed',@obj.roiGroupChanged);
                end
                
                obj.updateTimingInformation();
            end
        end
        
        function set.roiGroupLineScan(obj,val)
            if ~isobject(val)
                % this is just a dummy set to update dependent properties
            else
                assert(isa(val,'scanimage.mroi.RoiGroup')&&most.idioms.isValidObj(val), 'Invalid roi group object');
                % set new roiGroup
                obj.roiGroupLineScan = val;
                
                if obj.isLineScan
                    % delete old listener
                    most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener)
                    % create new listener
                    obj.hRoiGroupDelayedEventListener = most.util.DelayedEventListener(0.5,obj.roiGroupLineScan,'changed',@obj.roiGroupChanged);
                end
                
                obj.updateTimingInformation();
            end
        end
        
        function val = get.currentNonDefRoiGroup(obj)
            if obj.isLineScan
                val = obj.roiGroupLineScan;
            else
                val = obj.roiGroupMroi;
            end
        end
        
        function set.currentRoiGroup(obj,val)
            obj.mdlDummySetProp(val,'currentRoiGroup');
            obj.updateTimingInformation();
        end
        
        function val = get.currentRoiGroup(obj)
            if obj.isLineScan
                val = obj.roiGroupLineScan;
            elseif obj.mroiEnable
                val = obj.roiGroupMroi;
            else
                val = obj.roiGroupDefault;
            end
        end
        
        function set.forceSquarePixelation(obj,val)
            val = obj.validatePropArg('forceSquarePixelation',val);
            if obj.componentUpdateProperty('forceSquarePixelation',val)
                obj.forceSquarePixelation = val;
                obj.updatePixelRatioProps('forceSquarePixelation');
            end
        end
        
        function set.forceSquarePixels(obj,val)
            val = obj.validatePropArg('forceSquarePixels',val);
            if obj.componentUpdateProperty('forceSquarePixels',val)
                obj.forceSquarePixels = val;
                obj.updatePixelRatioProps('forceSquarePixels');
            end
        end
        
        function set.linesPerFrame(obj,val)
            val = obj.validatePropArg('linesPerFrame',val);
            if obj.componentUpdateProperty('linesPerFrame',val)
                obj.linesPerFrame = val;
                obj.updatePixelRatioProps('linesPerFrame');
            end
        end
        
        function set.mroiEnable(obj,val)
            val = obj.validatePropArg('mroiEnable',val);
            
            if obj.componentUpdateProperty('mroiEnable',val)
                obj.hSI.hStackManager.updateZSeries();
                changeVal = obj.mroiEnable ~= val;
                if changeVal
                    obj.mroiEnable = val;
                    obj.hSI.hDisplay.needsReset = true;
                    obj.notify('pixPerLineChanged');
                    obj.hSI.hScan2D.updateLiveValues();
                end
            end
        end
        
        function set.scanType(obj,val)
            val = obj.validatePropArg('scanType',val);
            
            if obj.componentUpdateProperty('scanType',val)
                if ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress && isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.ResScan')
                    val = 'frame';
                end
                
                obj.hSI.hScan2D.hAcq.clearAcqParamBuffer();
                obj.cachedScanTimesPerPlane = [];
                
                obj.scanType = val;
                obj.isLineScan = strcmp(val,'line');
                
                % delete old roi group listener
                most.idioms.safeDeleteObj(obj.hRoiGroupDelayedEventListener);
                rg = obj.currentNonDefRoiGroup;
                if most.idioms.isValidObj(rg)
                    % create new listener
                    obj.hRoiGroupDelayedEventListener = most.util.DelayedEventListener(0.5,rg,'changed',@obj.roiGroupChanged);
                end
            end
            
            obj.hSI.hDisplay.resetActiveDisplayFigs();
            obj.notify('pixPerLineChanged');
        end
       
        function set.pixelsPerLine(obj,val)
            val = obj.validatePropArg('pixelsPerLine',val);
            if obj.componentUpdateProperty('pixelsPerLine',val)
                obj.pixelsPerLine = val;
                obj.updatePixelRatioProps('pixelsPerLine');
            end
            if ~obj.mroiEnable
                obj.notify('pixPerLineChanged');
            end
        end
        
        function val = get.roiGroupDefault(obj)            
            if isempty(obj.roiGroupDefault_)
                obj.roiGroupDefault_ = scanimage.mroi.RoiGroup();
                obj.roiGroupDefault_.name = obj.DEFAULT_NAME_ROIGROUP;
                scanfield = scanimage.mroi.scanfield.fields.RotatedRectangle([0 0 1 1],0,[512, 512]);
                scanfield.name = obj.DEFAULT_NAME_SCANFIELD;
                roi = scanimage.mroi.Roi();
                roi.name = obj.DEFAULT_NAME_ROI;
                roi.add(0,scanfield);
                obj.roiGroupDefault_.add(roi);
            end
            
            if ~isvalid(obj.hSI.hScan2D)
                val = [];
                return
            end
            
            pts = obj.hSI.hScan2D.fovCornerPoints;
            pt1 = pts(1,:);
            pt2 = pts(2,:);
            pt3 = pts(3,:);
            pt4 = pts(4,:);
            
            centroid = scanimage.mroi.util.centroidQuadrilateral(pt1,pt2,pt3,pt4);

            dist = [];
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1, 1],pt1,pt2-pt1));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1, 1],pt2,pt3-pt2));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1, 1],pt3,pt4-pt3));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1, 1],pt4,pt1-pt4));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1,-1],pt1,pt2-pt1));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1,-1],pt2,pt3-pt2));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1,-1],pt3,pt4-pt3));
            dist(end+1) = norm(centroid-scanimage.mroi.util.intersectLines(centroid,[1,-1],pt4,pt1-pt4));
            
            a1 = sqrt(2*min(dist)^2);
            a2 = obj.hSI.hScan2D.defaultRoiSize;
            a = min(a1,a2) * obj.hSI.hScan2D.fillFractionSpatial / obj.scanZoomFactor;

            % replace existing roi in default roi group with new roi
            scl = [obj.hSI.hScan2D.scannerset.transformParams.scaleX obj.hSI.hScan2D.scannerset.transformParams.scaleY];
            
            sf = obj.roiGroupDefault_.rois(1).scanfields(1);
            sf.centerXY = centroid + [obj.scanAngleShiftFast obj.scanAngleShiftSlow] .* scl;
            sf.sizeXY = [obj.scanAngleMultiplierFast obj.scanAngleMultiplierSlow] * a;
            sf.rotationDegrees = obj.scanRotation;
            sf.pixelResolution = [obj.pixelsPerLine, obj.linesPerFrame];
            
            scanSettings_ = struct();
            scanSettings_.imagingSystem = obj.hSI.imagingSystem;
            scanSettings_.fillFractionSpatial = obj.hSI.hScan2D.fillFractionSpatial;
            
            scanSettings_.forceSquarePixelation = obj.forceSquarePixelation;
            scanSettings_.forceSquarePixels = obj.forceSquarePixels;
            scanSettings_.scanZoomFactor = obj.scanZoomFactor;
            scanSettings_.scanAngleShiftFast = obj.scanAngleShiftFast;
            scanSettings_.scanAngleMultiplierSlow = obj.scanAngleMultiplierSlow;
            scanSettings_.scanAngleShiftSlow = obj.scanAngleShiftSlow;
            scanSettings_.scanAngleShiftFast = obj.scanAngleShiftFast;
            scanSettings_.scanRotation = obj.scanRotation;
            scanSettings_.pixelsPerLine = obj.pixelsPerLine;
            scanSettings_.linesPerFrame = obj.linesPerFrame;
           
            roi = obj.roiGroupDefault_.rois(1);
            roi.UserData = scanSettings_;
            
            val = obj.roiGroupDefault_;
        end
        
        function val = get.scanSettings(obj)
            val = obj.roiGroupDefault.rois(1).UserData;
        end
        
        function set.scanRotation(obj,val)
            val = obj.validatePropArg('scanRotation',val);
            if obj.componentUpdateProperty('scanRotation',val)
                obj.scanRotation = val;
                
                obj.coerceDefaultRoi();
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
        
        function set.scanZoomFactor(obj,val)
            val = obj.validatePropArg('scanZoomFactor',val);
            if obj.componentUpdateProperty('scanZoomFactor',val)
                obj.scanZoomFactor = round(val*100)/100;
                
                %Coerce SA shift to acceptable values
                obj.coerceDefaultRoi();
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
        
        function set.scanAngleMultiplierFast(obj,val)
            val = obj.validatePropArg('scanAngleMultiplierFast',val);
            if obj.componentUpdateProperty('scanAngleMultiplierFast',val)
                obj.scanAngleMultiplierFast = val;
                
                obj.updatePixelRatioProps('scanAngleMultiplierFast');
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
        
        function set.scanAngleMultiplierSlow(obj,val)
            val = obj.validatePropArg('scanAngleMultiplierSlow',val);
            if obj.componentUpdateProperty('scanAngleMultiplierSlow',val)
                obj.scanAngleMultiplierSlow = val;
                
                obj.updatePixelRatioProps('scanAngleMultiplierSlow');
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
        
        function set.scanAngleShiftSlow(obj,val)
            val = obj.validatePropArg('scanAngleShiftSlow',val);
            if obj.componentUpdateProperty('scanAngleShiftSlow',val)
                
                obj.scanAngleShiftSlow = round(val*1000)/1000;
                
                %Coerce SA shift to acceptable values
                obj.coerceDefaultRoi();
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
        
        function set.scanAngleShiftFast(obj,val)
            val = obj.validatePropArg('scanAngleShiftFast',val);
            if obj.componentUpdateProperty('scanAngleShiftFast',val)
                obj.scanAngleShiftFast = round(val*1000)/1000;
                
                %Coerce SA shift to acceptable values
                obj.coerceDefaultRoi();
                
                %Side effects
                obj.updateLiveNonMroiImaging();
            end
        end
    end
        
    methods(Hidden)
        function updateTimingInformation(obj,setLinePeriod)
            if obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                return
            end
            
            obj.cacheScanTimesPerPlane;
            obj.scanFramePeriod = NaN; % trigger GUI update for scanFramePeriod
            obj.hSI.hScan2D.scanPixelTimeMean = NaN; % trigger GUI update for scanPixelTimeMean
            
            if nargin < 2 || isempty(setLinePeriod) || setLinePeriod
                obj.linePeriod = NaN;      % trigger GUI update for linePeriod
            end
        end
        
        function updateLiveNonMroiImaging(obj)
            if ~obj.mroiEnable
                if ~obj.preventLiveUpdate
                    obj.hSI.hScan2D.updateLiveValues();
                    obj.hSI.hFastZ.liveUpdate();
                    
                    if obj.hSI.active
                        obj.hSI.hDisplay.resetActiveDisplayFigs(false);
                    else
                        obj.hSI.hDisplay.needsReset = true;
                    end
                end
                obj.notify('imagingRoiGroupChanged');
            end
        end
        
        function cacheScanTimesPerPlane(obj,varargin)
            % CACHESCANTIMESPERPLANE   Recomputes scan times per plane and caches the result.
            %   obj.cacheScanTimesPerPlane   Returns nothing.
            
            ss = obj.hSI.hScan2D.scannerset;
            rg = obj.hSI.hScan2D.currentRoiGroup;
            
            if obj.isLineScan
                obj.cachedScanTimesPerPlane = rg.pathTime(ss);
            else
                N = numel(obj.hSI.hStackManager.zs);
                obj.cachedScanTimesPerPlane(N+1:end) = [];
                
                for idx = N : -1 : 1
                    obj.cachedScanTimesPerPlane(idx) = rg.sliceTime(ss,obj.hSI.hStackManager.zs(idx));
                end
            end
        end
        
        function [matchedTf,hRoi_matched,hRoiGroup_matched] = matchRoi(obj,hRoi)
            matchedTf = false;
            hRoiGroup_matched = scanimage.mroi.RoiGroup.empty(1,0);
            hRoi_matched = scanimage.mroi.Roi.empty(1,0);
            
            if strcmp(hRoi.name,obj.DEFAULT_NAME_ROI)
                hRoiGroup_matched = obj.roiGroupDefault;
                hRoi_matched = obj.roiGroupDefault.rois(1);
            else
                if ~matchedTf
                    [matchedTf, hRoi_matched, hRoiGroup_matched] = matchRoiToGroup(hRoi,obj.roiGroupMroi);
                end
                
                if ~matchedTf
                    [matchedTf, hRoi_matched, hRoiGroup_matched] = matchRoiToGroup(hRoi,obj.roiGroupLineScan);
                end
            end
            
            function [matchedTf,hRoi_matched,hRoiGroup_matched] = matchRoiToGroup(hRoi,hRoiGroup)
                hRoiGroup_matched = scanimage.mroi.RoiGroup.empty(1,0);
                hRoi_matched = scanimage.mroi.Roi.empty(1,0);
                rois = hRoiGroup.rois;
                mask = arrayfun(@(otherRoi)hRoi.isequalish(otherRoi),rois);
                matchedTf = any(mask);
                if matchedTf
                    hRoi_matched = rois(mask);
                    hRoi_matched = hRoi_matched(1); % just in case same roi was added multiple times to roigroup
                end
            end
        end
        
        function applyScanSettings(obj,s)
            fields = fieldnames(s);
            fields = setdiff(fields,{'fillFractionSpatial','imagingSystem'});
            
            if ~isequal(obj.hSI.imagingSystem,s.imagingSystem)
                obj.hSI.imagingSystem = s.imagingSystem;
            end
            
            if ~isequal(obj.hSI.hScan2D.fillFractionSpatial,s.fillFractionSpatial)
                obj.hSI.hScan2D.fillFractionSpatial = s.fillFractionSpatial;
            end
            
            cellfun(@(propName)applySettings(propName),fields);
            
            function applySettings(propName)
                if ~isequal(obj.(propName),s.(propName))
                    try
                        obj.(propName) = s.(propName);
                    catch ME
                        fprintf(2,'RoiManager: Could not restore property %s',propName);
                    end
                end
            end
        end
    end

    %% Property Getter/Setter
    methods        
        function set.scanFramePeriod(obj,val)
            obj.mdlDummySetProp(val,'scanFramePeriod');
        end
        
        function val = get.scanFramePeriod(obj)
            if isempty(obj.currentRoiGroup) || obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                val = NaN;
            else
                if isempty(obj.cachedScanTimesPerPlane)
                    obj.cacheScanTimesPerPlane();
                end
                val = max(obj.cachedScanTimesPerPlane);
            end
        end
        
        function set.linePeriod(obj,val)
            obj.mdlDummySetProp(val,'linePeriod');
            obj.updateTimingInformation(false);
        end
        
        function val = get.linePeriod(obj)
            % currently this only outputs the scantime for the default roi
            scannerset = obj.hSI.hScan2D.scannerset;
            if obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                val = nan;
            elseif obj.isLineScan
                val = obj.scanFramePeriod;
            elseif obj.mroiEnable
                if ~isempty(obj.roiGroupMroi.rois) && ~isempty(obj.roiGroupMroi.rois(1).scanfields)
                    if isa(scannerset,'scanimage.mroi.scannerset.ResonantGalvoGalvo')
                        [lineScanPeriod,~] = scannerset.linePeriod(obj.roiGroupMroi.rois(1).scanfields(1));
                        val = lineScanPeriod;
                    else
                        %need to revisit
                        [lineScanPeriod,~] = arrayfun(@(roi)LPifNotEmpty(roi),obj.roiGroupMroi.rois);
                        val = min(lineScanPeriod);
                    end
                else
                    val = NaN;
                end
            else
                [lineScanPeriod,~] = scannerset.linePeriod(obj.roiGroupDefault.rois(1).scanfields(1));
                val = lineScanPeriod;
            end
            
            function [a,b] = LPifNotEmpty(roi)
                if ~isempty(roi.scanfields)
                    [a,b] = scannerset.linePeriod(roi.scanfields(1));
                else
                    a = nan;
                    b = nan;
                end
            end
        end
        
        function set.fastZSettling(obj,~)
            obj.updateTimingInformation();
        end
        
        function val = get.fastZSettling(~)
            val = NaN;
        end
        
        function set.scanFrameRate(obj,val)
            obj.mdlDummySetProp(val,'scanFrameRate');
        end
        
        function val = get.scanFrameRate(obj)
            val = 1/obj.scanFramePeriod;
        end

        function set.scanVolumeRate(obj,val)
            obj.mdlDummySetProp(val,'scanFrameRate');
        end
        
        function val = get.scanVolumeRate(obj)
            val = (1 / obj.scanFramePeriod) / (obj.hSI.hStackManager.slicesPerAcq + obj.hSI.hFastZ.numDiscardFlybackFrames);
        end
        
        function v = get.refAngularRange(obj)
            rgs = cellfun(@(h)h.fovCornerPoints,obj.hSI.hScanners,'UniformOutput',false);
            v = 2*max(abs(vertcat(rgs{:})),[],1);
        end
        
        function v = get.imagingFovDeg(obj)
            if obj.mroiEnable
                v = [];
            else
                v = obj.currentRoiGroup.rois(1).scanfields(1).cornerpoints;
            end
        end
        
        function v = get.imagingFovUm(obj)
            v = obj.imagingFovDeg * obj.hSI.objectiveResolution;
        end
    end
    
    %% USER METHODS
    methods
        function saveScan2DProps(obj)
            if isempty(obj.hSI.hScan2D) || isempty(obj.hSI.hScan2D.name)
                return
            end
            
            propStruct = struct();
            propStruct.pixelsPerLine = obj.pixelsPerLine;
            propStruct.linesPerFrame = obj.linesPerFrame;
            propStruct.scanZoomFactor = obj.scanZoomFactor;
            propStruct.scanRotation = obj.scanRotation;
            propStruct.scanAngleMultiplierSlow = obj.scanAngleMultiplierSlow;
            propStruct.scanAngleMultiplierFast = obj.scanAngleMultiplierFast;
            propStruct.scanAngleShiftSlow = obj.scanAngleShiftSlow;
            propStruct.scanAngleShiftFast = obj.scanAngleShiftFast;
            propStruct.forceSquarePixelation = obj.forceSquarePixelation;
            propStruct.forceSquarePixels = obj.forceSquarePixels;
            
            obj.scan2DProps.(obj.hSI.hScan2D.name) = propStruct;
        end
        
        function restoreScan2DProps(obj)
            if isempty(obj.hSI.hScan2D) || isempty(obj.hSI.hScan2D.name)
                return
            end
            
            if ismember(obj.hSI.hScan2D.name,fieldnames(obj.scan2DProps))
                propStruct = obj.scan2DProps.(obj.hSI.hScan2D.name);
                fields = fieldnames(propStruct);
                
                for idx = 1:length(fields)
                    field = fields{idx};
                    try
                        obj.(field) = propStruct.(field);
                    catch ME
                        most.idioms.warn('RoiManger: Could not restore property %s:\n%s',field,ME.message);
                    end
                end                
            end
        end
        
        function saveRoiGroupMroi(obj,filename)
            % saveRoiGroupMroi    Saves an roi group
            %     obj.saveRoiGroupMroi           returns nothing.  Opens a file dailog for saving an roi group.
            %     obj.saveRoiGroupMroi(filename) returns nothing.  Saves an roi group to filename.
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uiputfile('.roi','Choose filename to save roigroup','roigroup.roi');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            roigroup = obj.roiGroupMroi; %#ok<NASGU>
            save(filename,'roigroup','-mat');
        end 
        
        function loadRoiGroupMroi(obj,filename)
            % loadRoiGroupMroi  loads an roi group
            %     obj.loadRoiGroupMroi           returns nothing.  Opens a file dailog for loading an roi group.
            %     obj.loadRoiGroupMroi(filename) returns nothing.  Loads roi group from filename.
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uigetfile('.roi','Choose file to load roigroup','roigroup.roi');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            data = load(filename,'-mat','roigroup');
            roigroup = data.roigroup;
            
            %must perform a deep copy, as doing an assignment here overwrites the object handle.
            obj.roiGroupMroi.copyobj(roigroup);
            
            obj.mroiEnable = obj.mroiEnable;
        end

        function backupRoiGroup(obj)
            % BACKUPROIGROUP  Loads an RoiGroup from the last backup.
            %   obj.backupRoiGroup  returns the roigroup saved during the last backup.
            siDir = fileparts(which('scanimage'));
            filename = fullfile(siDir, 'roigroupMroi.backup');
            roigroupMroi = obj.currentRoiGroup; %#ok<NASGU>
            save(filename,'roigroupMroi','-mat');
        end
        
        function resetTransforms(obj)
            % RESETTRANSFORMS   Resets scaling and offset for scanners described in scanimage.SI
            %   obj.resetTransforms        returns nothing.  Resets all acanners
            for hScanner = obj.hSI.hScanners
                hScanner{1}.scannerToRefTransform = eye(3);
            end
        end
        
        function normalizeScannerAspectRatio(obj,hScanner,aspectRatio)
            % normalizeScannerAspectRatio rescales the reference space so
            %   that the aspect ratio of hScanner is represented correctly in reference space
            %     obj.normalizeScannerAspectRatio(hScanner)              returns nothing.  Rescales the reference space to represent the default aspect ratio of hScanner.
            %     obj.normalizeScannerAspectRatio(hScanner,aspectRatio)  returns nothing.  Rescales the reference space to represent the given aspectRatio, where aspectRatio=xdim/ydim
            
            if isa(hScanner,'scanimage.components.Scan2D')
                scannerToRefTransform = hScanner.scannerToRefTransform;
                
                if nargin < 3 || isempty(aspectRatio)
                    pts = [0 0; 1 0; 0 1];
                    defT = eye(3);
                    pts = scanimage.mroi.util.xformPoints(pts,defT);
                    sx = norm(pts(2,:)-pts(1,:));
                    sy = norm(pts(3,:)-pts(1,:));
                    aspectRatio = sx/sy;
                end
            elseif isa(hScanner,'scanimage.components.Motors')
                scannerToRefTransform = hScanner.motorToRefTransform;
                aspectRatio = 1;
            else
                error('Unknown scanner class: %s',class(hScanner));
            end
            
            assert(~any(isnan(scannerToRefTransform(:))),'Invalid scannerToRefTransform: %s',mat2str(scannerToRefTransform));
            
            orgn = [0 0];
            uvx = [1 0];
            uvy = [0 aspectRatio];
            
            % transform to reference space
            orgn_ref = scanimage.mroi.util.xformPoints(orgn,scannerToRefTransform);
            uvx_ref = orgn_ref - scanimage.mroi.util.xformPoints(uvx,scannerToRefTransform);
            uvy_ref = orgn_ref - scanimage.mroi.util.xformPoints(uvy,scannerToRefTransform);
            
            % length of unit vectors in ref space
            uvx_length = norm(uvx_ref);
            uvy_length = norm(uvy_ref);
            
            sx = sqrt( (uvx_length^2-uvy_length^2+uvy_ref(1)^2-uvx_ref(1)^2) / (uvy_ref(1)^2-uvx_ref(1)^2)); % x scaling factor
            sy = sqrt( (uvy_length^2-uvx_length^2+uvx_ref(2)^2-uvy_ref(2)^2) / (uvx_ref(2)^2-uvy_ref(2)^2)); % y scaling factor
            
            adjustment_matrix = eye(3);
            if ~isnan(sx) && ~isinf(sx) && (isnan(sy) || (abs(log(abs(sx))) < abs(log(abs(sy)))))
                adjustment_matrix(1,1) = sx;
            elseif ~isnan(sy) && ~isinf(sy)
                adjustment_matrix(2,2) = sy;
            else
                error('Adjustment matrix contains invalid values: sx=%f sy=%f',sx,sy);
            end
            
            % apply adjustment_matrix
            for idx = 1:length(obj.hSI.hScanners)
                scanner = obj.hSI.hScanners{idx};
                scanner.scannerToRefTransform = adjustment_matrix * scanner.scannerToRefTransform;
            end
            
            obj.hSI.hMotors.motorToRefTransform = adjustment_matrix * obj.hSI.hMotors.motorToRefTransform;
        end
    end % end last methods section (default attributes)
    
    %% INTERNAL METHODS
    methods (Access = protected)
        function componentStart(obj) 
        %   Runs code that starts with the global acquisition-start command
            obj.coerceRoiGroupMroi();
            obj.hRoiGroupDelayedEventListener.flushEvents();
            obj.roiLive = true;
            obj.coerceDefaultRoi();
            obj.updateTimingInformation();
            assert(~isempty(obj.hSI.hScan2D.currentRoiGroup.activeRois) && ~isempty([obj.hSI.hScan2D.currentRoiGroup.activeRois.scanfields]), 'There must be at least one active ROI with at least one scanfield within the scanner FOV to start an acquisition.');
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            % TODO: clear the cache once the acquisition completes. The
            % problem is that currently componentAbort is being called
            % prior to the end of the acquisition, which nullifies the
            % advantages of caching the scantimes per plane.
        end
        
        function roiGroupChanged(obj,~,evts)
            if obj.mroiEnable || obj.isLineScan
                if obj.hSI.active
                    if obj.roiLive
                        rejectedChanges = {};
                        for i = numel(evts):-1:1 %in reverse order in case something was changed twice
                            evt = evts{i};
                            if isa(evt, 'scanimage.mroi.EventData')
                                if ismember(evt.propertyName,{'pixelResolutionXY' 'enable' 'discretePlaneMode'})
                                    rejectedChanges = unique([rejectedChanges {evt.propertyName}]);
                                    obj.hRoiGroupDelayedEventListener.enabled = false;
                                    try
                                        evt.srcObj.(evt.propertyName) = evt.oldValue;
                                    catch ME
                                        obj.hRoiGroupDelayedEventListener.enabled = true;
                                        ME.rethrow();
                                    end
                                    obj.hRoiGroupDelayedEventListener.enabled = true;
                                elseif strcmp(evt.propertyName,'z')
                                    rejectedChanges = unique([rejectedChanges {evt.propertyName}]);
                                    obj.hRoiGroupDelayedEventListener.enabled = false;
                                    try
                                        roi = evt.srcObjParent;
                                        roi.moveSfById(find(roi.scanfields == evt.srcObj),evt.oldValue);
                                    catch ME
                                        obj.hRoiGroupDelayedEventListener.enabled = true;
                                        ME.rethrow();
                                    end
                                    obj.hRoiGroupDelayedEventListener.enabled = true;
                                elseif ismember(evt.changeType,{'added' 'removed'})
                                    obj.roiLive = false;
                                    break;
                                end
                            end
                        end
                        
                        if ~isempty(rejectedChanges)
                            most.idioms.warn('Illegal ROI group changes rejected: %s', strjoin(rejectedChanges,', '));
                        end
                    end
                    
                    if ~obj.roiLive
                        most.idioms.warn('Changes to ROI group will not take effect until acquisition is restarted.');
                        return;
                    end
                end
                
                obj.updateTimingInformation();
                obj.hSI.hScan2D.updateLiveValues();
                obj.hSI.hFastZ.liveUpdate();
                
                obj.notify('pixPerLineChanged');
                obj.notify('imagingRoiGroupChanged');
                
                if obj.hSI.active
                    obj.hSI.hDisplay.resetActiveDisplayFigs();
                else
                    obj.hSI.hDisplay.needsReset = true;
                end
            end
        end
        
        function coerceDefaultRoi(obj)
            % COERCEDEFAULTROI
            %   obj.coerceDefaultRoi
            %
            % NOTES
            %   Uses a persistent variable.
            persistent inp;
            
            if isempty(inp)
                try
                    inp = true;
                    ss = obj.hSI.hScan2D.scannerset;
                    
                    rG = obj.roiGroupDefault;
                    ss.satisfyConstraintsRoiGroup(rG);
                    
                    fovCentroid = scanimage.mroi.util.centroidQuadrilateral(obj.hSI.hScan2D.fovCornerPoints);
                    sas = (rG.rois.scanfields.centerXY - fovCentroid) ./ [obj.hSI.hScan2D.scannerset.transformParams.scaleX obj.hSI.hScan2D.scannerset.transformParams.scaleY];
                    
                    obj.preventLiveUpdate = true;
                    if abs(obj.scanAngleShiftFast - sas(1)) > 0.000001
                        obj.scanAngleShiftFast = sas(1);
                    end
                    if abs(obj.scanAngleShiftSlow - sas(2)) > 0.000001
                        obj.scanAngleShiftSlow = sas(2);
                    end
                    if ~obj.hSI.hScan2D.supportsRoiRotation
                        obj.scanRotation = 0;
                    end
                    
                    obj.preventLiveUpdate = false;
                catch ME
                    inp = [];
                    ME.rethrow;
                end
                inp = [];
            end
        end
        
        function coerceRoiGroupMroi(obj)
           if obj.mroiEnable && ~obj.isLineScan 
               scannerset = obj.hSI.hScan2D.scannerset;
               scannerset.satisfyConstraintsRoiGroup(obj.roiGroupMroi);
           end
        end
    end
    
    methods (Access = private)
        function updatePixelRatioProps(obj,sourceProp)
            if nargin < 2
                sourceProp = '';
            end
            
            if ~obj.abortUpdatePixelRatioProps && ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress % prevent infinite recursion
                obj.abortUpdatePixelRatioProps = true;
                
                if obj.forceSquarePixelation && obj.linesPerFrame ~= obj.pixelsPerLine
                    obj.linesPerFrame = obj.pixelsPerLine;
                end
                
                if obj.forceSquarePixels
                    if isempty(strfind(sourceProp, 'scanAngleMultiplier'))
                        %changed a pixel value. change SA multipliers appropriately
                        samSlow = obj.scanAngleMultiplierFast * obj.linesPerFrame/obj.pixelsPerLine;
                        if (obj.linesPerFrame/obj.pixelsPerLine) == 1
                            obj.scanAngleMultiplierSlow = 1;
                            obj.scanAngleMultiplierFast = 1;
                        elseif samSlow > 1
                            obj.scanAngleMultiplierSlow = 1;
                            obj.scanAngleMultiplierFast = obj.pixelsPerLine/obj.linesPerFrame;
                        else
                            obj.scanAngleMultiplierSlow = samSlow;
                        end
                    else
                        if obj.forceSquarePixelation
                            %changed an SA multiplier. Since both forceSquarePixels and forceSquarePixelation are on, SA multipliers must be equal
                            if strcmp(sourceProp, 'scanAngleMultiplierSlow')
                                obj.scanAngleMultiplierFast = obj.scanAngleMultiplierSlow;
                            else
                                obj.scanAngleMultiplierSlow = obj.scanAngleMultiplierFast;
                            end
                        else
                            %changed an SA multiplier. change pixel values appropriately
                            obj.linesPerFrame = round(obj.pixelsPerLine * obj.scanAngleMultiplierSlow/obj.scanAngleMultiplierFast);
                        end
                    end
                end
                
                obj.abortUpdatePixelRatioProps = false;
                if ~obj.mroiEnable
                    obj.hSI.hDisplay.resetActiveDisplayFigs(false);
                end
            end
        end
        
        function cfgLoadingChanged(obj, ~, evnt)
            if ~evnt.AffectedObject.cfgLoadingInProgress
                %Just finsihed loading cfg file
                obj.updatePixelRatioProps();
            end
        end
    end   
    
    %% USER EVENTS
    %% FRIEND EVENTS
    %% INTERNAL EVENTS
end

%% LOCAL (after classdef)
function s = ziniInitPropAttributes()
s = struct();

s.mroiEnable = struct('Classes','binaryflex','Attribues',{{'scalar'}});
s.scanType   = struct('Options',{{'frame','line'}});

%%% Frame geometry and resolution
s.pixelsPerLine             = struct('Classes','numeric','Attributes',{{'integer','positive','finite','scalar'}});
s.linesPerFrame             = struct('Classes','numeric','Attributes',{{'integer','positive','finite','scalar'}});
s.scanZoomFactor            = struct('Classes','numeric','Attributes',{{'scalar','finite','>=',1}});
s.scanRotation              = struct('Classes','numeric','Attributes',{{'scalar','finite'}});
s.scanAngleMultiplierSlow   = struct('Classes','numeric','Attributes',{{'scalar','finite','>=',0}});
s.scanAngleMultiplierFast   = struct('Classes','numeric','Attributes',{{'scalar','finite','>=',0}});
s.forceSquarePixelation     = struct('Classes','binaryflex','Attributes',{{'scalar'}});
s.forceSquarePixels         = struct('Classes','binaryflex','Attributes',{{'scalar'}});
s.scanAngleShiftSlow        = struct('Classes','numeric','Attributes',{{'scalar','finite'}});
s.scanAngleShiftFast        = struct('Classes','numeric','Attributes',{{'scalar','finite'}});

%%% Frame timing
s.scanFrameRate   = struct('DependsOn',{{'scanFramePeriod'}});
s.scanVolumeRate  = struct('DependsOn',{{'scanFramePeriod','hSI.hStackManager.slicesPerAcq','hSI.hFastZ.numDiscardFlybackFrames'}});
s.scanFramePeriod = struct('DependsOn',{{'linePeriod','hSI.hStackManager.zs','fastZSettling'}});
s.fastZSettling   = struct('DependsOn',{{'hSI.hFastZ.enable','hSI.hFastZ.waveformType','hSI.hFastZ.flybackTime'}});
s.linePeriod      = struct('DependsOn',{{'hSI.imagingSystem','hSI.hScan2D.scannerset','hSI.hScan2D.pixelBinFactor','hSI.hScan2D.sampleRate','mroiEnable','currentRoiGroup','pixelsPerLine','linesPerFrame','scanType'}});
end


%--------------------------------------------------------------------------%
% RoiManager.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
