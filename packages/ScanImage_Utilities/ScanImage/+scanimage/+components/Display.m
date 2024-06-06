classdef Display < scanimage.interfaces.Component
    %% Display Component
    % Manages image display related settings andfunctionality

    %% USER PROPS
    properties (SetObservable)
        displayRollingAverageFactor = 1;         % [Numeric] Number of frames averaged (using a simple moving average) for display purposes.
        displayRollingAverageFactorLock = false; % [Logical] If true, lock displayRollingAverageFactor to the logging average factor
        volumeDisplayStyle = '3D';               % [String] One of {'3D' 'Tiled' 'Current'} to specify how to display slices of a volume in the channel window
        selectedZs = [];                         % [Numeric] Array of z values to show in the display. Leave empty to show all
        autoScaleSaturationFraction = [.1 .01];  % [Numeric] 1x2 Array specifying percentage of pixels to put in saturation for black and white respectively when using the auto scale fuction
        
        lineScanHistoryLength = 1000;            % 

        channelsMergeEnable = false;             % [Logical] If true, the channels merge window is updated.
        channelsMergeFocusOnly = false;          % [Logical] If true, the channels merge image is not updated during GRAB/LOOP acquisitions.
        
        roiDisplayEdgeColor = 'blue';            % [String] Color for roi-display edges
        roiDisplayEdgeAlpha = 1;                 % [Numeric] Alpha value for roi-display edges
        roiProjectionDisplayEdgeColor = 'blue';  % [String] Color for roi-projection-display edges
        roiProjectionDisplayEdgeAlpha = 1;       % [Numeric] Alpha value for roi-projection-display edges
        
        renderer = 'auto';                       % [String] One of {'auto','painters','opengl'}
        
        enableScanfieldDisplays = false;         % [Logical] Enables update of scanfield display window
        showScanfieldDisplayNames = true;        % [Logical] Show scanfield names in scanfield display window
        scanfieldDisplayTilingMode = 'Auto';     % [String] One of {'Auto','Set Columns','Set Rows'}
        scanfieldDisplayColumns = 5;             % [Numeric] Number of colums in scanfield display window. Applicable when scanfieldDisplayTilingMode = 'Set Columns'
        scanfieldDisplayRows = 5;                % [Numeric] Number of rows in scanfield display window. Applicable when scanfieldDisplayTilingMode = 'Set Rows'
        scanfieldDisplays = ...                  % Array of structures with parameters for each scanfield in the scanfield display window.
            struct('enable', false, 'name', 'Display 1', 'channel', 1, 'roi', 1,'z',0);
    end
    
    properties (SetObservable, Transient)
        mouseHoverInfo;                          % [struct] information about the current mouse position in the RoiDisplay
    end
    
    properties (SetObservable, Dependent, Transient)
        lastFrame;                               % [cell array] returns the last frame in the image buffer for each channel
        lastFrameChannels;                       % [numeric array] returns the channel numbers for each frame in obj.lastFrame
        lastFrameTimestamp;                      % [numeric] returns the timestamp of obj.lastFrame
        lastFrameNumber;                         % [numeric] returns the frame number of obj.lastFrame
        lastFrameNumberAcquisition;              % [numeric] returns the frame number in the current acquisition of obj.lastFrame
    end
    
    properties (SetObservable, Hidden)
        frameRateDisplay = false;
        frameRateAverageFactor = 1;
        frameRateAverageBuffer = [];
        lastDisplayUpdate = [];
        lastStripeData;
        frameRate;
        
        needsReset = false;
        displayType;
    end
    
    events (Hidden)
        displayReset;
    end
    
    %% FRIEND PROPS    
    properties (Hidden, SetAccess=private)
        hFigs = [];
        hMergeFigs = [];
        zTiled = false;
        z3D = false;
        zCurrent = false;
        zMax = false;
    end
    
    properties (SetObservable, Hidden)
        forceRoiDisplayTransform = false;        % If true, rois will be drawn at correct location within the normalized coordinate system. If false, rois will fill entire figure
        useNewTileMode = true;
        
        %Hidden because these should be set from hChannels
        chan1LUT = [0 100];                      % Channel 1 intensity lookup table extents.
        chan2LUT = [0 100];                      % Channel 2 intensity lookup table extents.
        chan3LUT = [0 100];                      % Channel 3 intensity lookup table extents.
        chan4LUT = [0 100];                      % Channel 4 intensity lookup table extents.
    end
        
    %% INTERNAL PROPS
    properties (Hidden, SetAccess=private)
        hAxes = {};
        hMergeAxes = [];
        scanfieldDisplayFrameSelection;
        rollingStripeDataBufferDirty;           % Indicates that there is new data in the buffer that has not been displayed
        rollingStripeDataBuffer;                % Buffer used for stripe (display) averaging computation. Stored as double type.
        lastAcqStripeDataBuffer;                % Stores last stripe data at the end of acq for copy purposes
        lastAcqScannerName = '';                % Stores name of scanner that captured data in lastAcqStripeDataBuffer
        lastAcqMergeStripeDataBuffer;           % Cell array containing mergedStripeData from last acquisition
        mergeStripeDataBuffer;                  % Cell array containing mergedStripeData. This is for tiled display of stripes.
        frameAverageIndex = 0;                  % Index used to reference a specific RoiData object within in a rolling window.
        stripeDataBuffer = {};                  % Cell array containing most recently acquired stripeBufferLength stripeData elements.        
        stripeDataBufferPointer = 1;            % Index of current element in stripeDataBuffer
        displayLastFrameDisplayed = 0;          % Internal accounting of last frame displayed for frame display function.
        
        maxProjBuffer = [];
        maxProjBufferPrep = {};
        
        lineScanFrameLength;                    %
        lineScanDataBufferChannels;
        lineScanRawDataBuffer;
        lineScanAvgDataBuffer;
        lineScanMrgDataBuffer;
        lineScanLastFramePtr;

        cameraProps = {};                       % Cell array containing cameraProps struct for each channel. Used with getCameraProps() function. 
        cameraPropsNumFrames = 0;                   % Number of frames that existed when props were saved
        hLinesPhotostimMonitor = [];            % array of lines in the roidisplay. used for photostim monitoring
        
        resetReq = {};
        duringInit = false;
        displayZs = [];
        numDisplayZs = 1;
        resetInProgress = false;
    end
    
    properties (Hidden, SetAccess=?most.Model, Dependent)
        stripeBufferLength;                     % Length of running buffer used to store most-recently acquired stripes.
    end
    
    properties (Constant, Hidden, Access=private)
        MAXIMUM_CHANNELS = 32;                  % Maximum number of total channels including virtual, logical, and physical.
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlInitSetExcludeProps;
        mdlHeaderExcludeProps = {'roiDisplayEdgeColor' 'roiDisplayEdgeAlpha'...
            'roiProjectionDisplayEdgeColor' 'roiProjectionDisplayEdgeAlpha'...
            'lastFrame' 'lastFrameTimestamp' 'lastFrameNumber'...
            'lastFrameNumberAcquisition' 'lastFrameChannels' 'mouseHoverInfo'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Display';                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'displayRollingAverageFactor',... % Cell array of strings specifying properties that can be set while the component is active
            'displayRollingAverageFactorLock','chan1LUT','chan2LUT','chan3LUT','chan4LUT','renderer',...
            'channelsMergeEnable','channelsMergeFocusOnly','forceRoiDisplayTransform' 'roiDisplayEdgeAlpha'...
            'roiDisplayEdgeColor' 'roiProjectionDisplayEdgeColor' 'roiProjectionDisplayEdgeAlpha'};
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};               % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                     % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'displayChannels','displayStripe'};  % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};            % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = Display(hSI)
            obj = obj@scanimage.interfaces.Component(hSI,[]);
        end
        
        function delete(obj)
            obj.hLinesPhotostimMonitor = [];
            delete(obj.hFigs); % hFigs is parent to hAxes is parent to hImages. Deleting hFigs deletes its children too
            delete(obj.hMergeFigs);
        end
    end
    
    %% PROP ACCESS
    methods
        function set.selectedZs(obj,val)
            [~,sd] = setdiff(val,obj.hSI.hStackManager.zs);
            val(sd) = [];
            
            obj.selectedZs = val;
            
            if ~obj.resetInProgress
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.volumeDisplayStyle(obj,val)
            if strcmpi(val,'Max')
                % can only do max projection if current roi group is
                % uniform in z
                if all(arrayfun(@(r)numel(r.zs),obj.hSI.hRoiManager.currentRoiGroup.rois) == 1) &&...
                        ~any([obj.hSI.hRoiManager.currentRoiGroup.rois.discretePlaneMode])
                    val = 'Max';
                    obj.zMax = true;
                else
                    val = 'Current';
                    obj.zMax = false;
                end
            else
                obj.zMax = false;
                assert(ismember(val,{'3D' 'Tiled' 'Current' 'Max'}), 'Invalid display mode.');
            end
            obj.volumeDisplayStyle = val;
            obj.zTiled = strcmp(obj.volumeDisplayStyle, 'Tiled');
            obj.z3D = strcmp(obj.volumeDisplayStyle, '3D');
            obj.zCurrent = strcmp(obj.volumeDisplayStyle, 'Current');
            obj.resetActiveDisplayFigs();
        end
        
        function set.renderer(obj,val)
            val = lower(val);
            val = obj.validatePropArg('renderer',val);
            if obj.componentUpdateProperty('renderer',val)
                switch val
                    case {'auto'}
                        set([obj.hFigs obj.hMergeFigs],'RendererMode','auto');                    
                    case {'painters','opengl'}
                        set([obj.hFigs obj.hMergeFigs],'Renderer',val,...
                                  'RendererMode','manual');
                    otherwise
                        %Note: zbuffer is not allowed, since it is
                        %deprecated in Matlab 2014b and later
                        error('Unknown renderer: %s',val);
                end
                obj.renderer = val;
            end
        end
        
        function set.forceRoiDisplayTransform(obj,val)
            val = obj.validatePropArg('forceRoiDisplayTransform',val);
            if obj.componentUpdateProperty('forceRoiDisplayTransform',val)
                oldval = obj.forceRoiDisplayTransform;
                obj.forceRoiDisplayTransform = val;
                
                if oldval ~= val
                    obj.resetDisplayFigs(obj.hSI.hChannels.channelDisplay,true);
                end
            end
        end
        
        function set.displayRollingAverageFactor(obj,val)
            if obj.componentUpdateProperty('displayRollingAverageFactor',val)
                %Enforce displayRollingAverageFactorLock constraint
                if obj.displayRollingAverageFactorLock
                    allowedVal = obj.zprpLockDisplayRollAvgFactor();
                    if val ~= allowedVal
                        return;
                    end
                end
                
                %Proceed with set
                val = obj.validatePropArg('displayRollingAverageFactor',val); %allow while running
                oldVal = obj.displayRollingAverageFactor;
                obj.displayRollingAverageFactor = val;
                
                for ch = obj.hSI.hChannels.channelDisplay(:)'
                    obj.zprpUpdateChanLUT(ch,obj.hSI.hChannels.channelLUT{ch});
                end
                
                obj.zprvResizeAvgBuffers(oldVal);
            end
        end
        
        function set.displayRollingAverageFactorLock(obj,val)
            val = obj.validatePropArg('displayRollingAverageFactorLock',val); %Allow while running
            if obj.componentUpdateProperty('displayRollingAverageFactorLock',val)
                obj.displayRollingAverageFactorLock = val;
                
                %Dependencies
                if val
                    obj.zprpLockDisplayRollAvgFactor();
                end
            end
        end
        
        function set.chan1LUT(obj,val)
            val = obj.validatePropArg('chan1LUT',val);
            if obj.componentUpdateProperty('chan1LUT',val)
                val = obj.zprvCoerceLutToAdcRange(val);
                obj.chan1LUT = val;
                
                if ismember(1,obj.hSI.hChannels.channelDisplay)
                    obj.zprpUpdateChanLUT(1,val);
                end
            end
        end
        
        function set.chan2LUT(obj,val)
            val = obj.validatePropArg('chan2LUT',val);
            if obj.componentUpdateProperty('chan2LUT',val)
                val = obj.zprvCoerceLutToAdcRange(val);
                obj.chan2LUT = val;
                if ismember(2,obj.hSI.hChannels.channelDisplay)
                    obj.zprpUpdateChanLUT(2,val);
                end
            end
        end
        
        function set.chan3LUT(obj,val)
            val = obj.validatePropArg('chan3LUT',val);
            if obj.componentUpdateProperty('chan3LUT',val)
                val = obj.zprvCoerceLutToAdcRange(val);
                obj.chan3LUT = val;
                
                if ismember(3,obj.hSI.hChannels.channelDisplay)
                    obj.zprpUpdateChanLUT(3,val);
                end
            end
        end
        
        function set.chan4LUT(obj,val)
            val = obj.validatePropArg('chan4LUT',val);
            if obj.componentUpdateProperty('chan4LUT',val)
                val = obj.zprvCoerceLutToAdcRange(val);
                obj.chan4LUT = val;
                
                if ismember(4,obj.hSI.hChannels.channelDisplay)
                    obj.zprpUpdateChanLUT(4,val);
                end
            end
        end
        
        function set.channelsMergeEnable(obj,val)
            val = obj.validatePropArg('channelsMergeEnable',val); %allow during acq
            if obj.componentUpdateProperty('channelsMergeEnable',val)
                obj.channelsMergeEnable = val;
                if val
                    obj.resetDisplayFigs([],true); %Resets merge figure, setting up tiling, etc
                else
                    set(obj.hMergeFigs,'Visible','off');
                end
            end
        end
        
        function set.channelsMergeFocusOnly(obj,val)
            val = obj.validatePropArg('channelsMergeFocusOnly',val);
            if obj.componentUpdateProperty('channelsMergeFocusOnly',val)
                obj.channelsMergeFocusOnly = val;
            end
        end
        
        function val = get.stripeBufferLength(obj)
            val = obj.displayRollingAverageFactor * length(obj.displayZs);
        end
        
        function set.roiDisplayEdgeColor(obj,v)
            v = obj.validatePropArg('roiDisplayEdgeColor',v);
            if obj.componentUpdateProperty('roiDisplayEdgeColor',v)
                obj.roiDisplayEdgeColor = v;
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.roiDisplayEdgeAlpha(obj,v)
            v = obj.validatePropArg('roiDisplayEdgeAlpha',v);
            if obj.componentUpdateProperty('roiDisplayEdgeAlpha',v)
                obj.roiDisplayEdgeAlpha = v;
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.roiProjectionDisplayEdgeColor(obj,v)
            v = obj.validatePropArg('roiProjectionDisplayEdgeColor',v);
            if obj.componentUpdateProperty('roiProjectionDisplayEdgeColor',v)
                obj.roiProjectionDisplayEdgeColor = v;
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.roiProjectionDisplayEdgeAlpha(obj,v)
            v = obj.validatePropArg('roiProjectionDisplayEdgeAlpha',v);
            if obj.componentUpdateProperty('roiProjectionDisplayEdgeAlpha',v)
                obj.roiProjectionDisplayEdgeAlpha = v;
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.scanfieldDisplays(obj, val)
            val = obj.validatePropArg('scanfieldDisplays',val);
            
            if isempty(val)
                val = repmat(struct('enable', false, 'name', 'Display 1', 'channel', 1, 'roi', 1,'z',0),0,0);
            else
                if ~isfield(val, 'enable')
                    val = arrayfun(@(s)setfield(s,'enable',false),val);
                end
                if ~isfield(val, 'name')
                    val = arrayfun(@(s)setfield(s,'name',''),val);
                end
                if ~isfield(val, 'channel')
                    val = arrayfun(@(s)setfield(s,'channel',1),val);
                end
                if ~isfield(val, 'roi')
                    val = arrayfun(@(s)setfield(s,'roi',1),val);
                end
                if ~isfield(val, 'z')
                    val = arrayfun(@(s)setfield(s,'z',0),val);
                end
            end
            
            obj.scanfieldDisplays = val;
        end
        
        function set.enableScanfieldDisplays(obj,v)
            v = obj.validatePropArg('enableScanfieldDisplays',v);
            obj.enableScanfieldDisplays = v;
        end
        
        function set.showScanfieldDisplayNames(obj,v)
            v = obj.validatePropArg('showScanfieldDisplayNames',v);
            obj.showScanfieldDisplayNames = v;
        end
        
        function set.scanfieldDisplayTilingMode(obj,v)
            v = obj.validatePropArg('scanfieldDisplayTilingMode',v);
            obj.scanfieldDisplayTilingMode = v;
        end
        
        function set.scanfieldDisplayColumns(obj,v)
            v = obj.validatePropArg('scanfieldDisplayColumns',v);
            obj.scanfieldDisplayColumns = v;
        end
        
        function set.scanfieldDisplayRows(obj,v)
            v = obj.validatePropArg('scanfieldDisplayRows',v);
            obj.scanfieldDisplayRows = v;
        end
        
        function data = get.lastStripeData(obj)
            data = obj.stripeDataBuffer{obj.stripeDataBufferPointer};
        end
        
        function set.lastStripeData(obj, data)
            obj.stripeDataBuffer{obj.stripeDataBufferPointer} = data;
        end
        
        function val = get.lastFrame(obj)
            stripe = obj.lastStripeData;
            
            % fix for inconsistent behavior between resscan and linscan
            % when some channels are enabled for logging only
            [~,idxs] = ismember(obj.hSI.hChannels.channelDisplay, stripe.roiData{1}.channels);
            
            val = stripe.roiData{1}.imageData(idxs);
            val = [val{:}];
            if stripe.roiData{1}.transposed
                val = cellfun(@(im)im',val,'UniformOutput',false);
            end
        end
        
        function val = get.lastFrameChannels(obj)
            val = obj.lastStripeData.roiData{1}.channels;
        end
        
        function val = get.lastFrameNumber(obj)
            val = obj.lastStripeData.frameNumberAcqMode;
        end
        
        function hRoiData = getRoiDataArray(obj)
            % returns a roi data array, where the first index is the roi
            % idx, the second dimension is the rolling buffer idx
            
            nZs = numel(obj.rollingStripeDataBuffer);
            nBuffer = numel(obj.rollingStripeDataBuffer{1}) - 1; % the first cell element of obj.stripeDataBuffer{zIdx} contains the averaged result
            
            hRoiData = [];
            for volIdx = 1:nBuffer
                hRoiData_vol = scanimage.mroi.RoiData.empty(0,1);
                for zIdx = 1:nZs
                    if nBuffer == 1
                        roiDatas = obj.rollingStripeDataBuffer{zIdx}{volIdx}.roiData;
                    else
                        roiDatas = obj.rollingStripeDataBuffer{zIdx}{volIdx+1}.roiData;
                    end
                    
                    if ~isempty(roiDatas)
                        hRois = cellfun(@(rd)rd.hRoi,roiDatas,'UniformOutput',false); % Matlab 2016 does not support uniformoutput on objects
                        hRois = horzcat(hRois{:});
                        hRoiUuiduint64s = [hRois.uuiduint64];
                    end
                    for rIdx = 1:numel(roiDatas)
                        uuiduint64s_vol = arrayfun(@(r)r.uuiduint64,[hRoiData_vol.hRoi]);
                        mask = uuiduint64s_vol == hRoiUuiduint64s(rIdx);
                        assert(sum(mask)<=1,'Something bad happened');
                        [~,rIdx_vol] = find(mask,1);
                        
                        if isempty(rIdx_vol)
                            hRoiData_vol(end+1,1) = roiDatas{rIdx}.copy(); %#ok<AGROW>
                        else
                            zs_ = hRoiData_vol(rIdx_vol).zs;
                            zs_(end+1) = roiDatas{rIdx}.zs;
                            [zsSorted, zSortIdxs] = sort(zs_);
                            
                            hRoiData_vol(rIdx_vol).zs = zsSorted;
                            for chIdx = 1:numel(hRoiData_vol(rIdx_vol).channels)
                                hRoiData_vol(rIdx_vol).imageData{chIdx}{end+1} = roiDatas{rIdx}.imageData{chIdx}{1};
                                hRoiData_vol(rIdx_vol).imageData{chIdx} = hRoiData_vol(rIdx_vol).imageData{chIdx}(zSortIdxs);
                            end
                        end
                    end
                end
                
                hRoiData = [hRoiData, hRoiData_vol]; %#ok<AGROW>
            end
        end
        
        function val = get.lastFrameNumberAcquisition(obj)
            val = obj.lastStripeData.frameNumberAcq;
        end
        
        function val = get.lastFrameTimestamp(obj)
            val = obj.lastStripeData.frameTimestamp;
        end
        
        function set.lineScanHistoryLength(obj,val)
            obj.lineScanHistoryLength = val;
            
            if obj.hSI.hRoiManager.isLineScan
                obj.zprvResetBuffers();
                obj.resetActiveDisplayFigs();
            end
        end
        
        function set.autoScaleSaturationFraction(obj,v)
            v = obj.validatePropArg('autoScaleSaturationFraction',v);
            obj.autoScaleSaturationFraction = v;
        end
    end
    
    %% USER METHODS
    methods
        function channelAutoScale(obj,ch,pixels)
            if nargin < 2 || isempty(ch)
                ch = 1:obj.MAXIMUM_CHANNELS;
            end
            
            if ~isscalar(ch)
                if nargin < 3 || isempty(pixels)
                    pixels = [];
                end
                
                for idx = 1:length(ch)
                    obj.channelAutoScale(ch(idx),pixels);
                end
            else
                if ch == 0
                    error('Cannot adjust look up table for merge window');
                end

                if nargin < 3 || isempty(pixels)
                    if obj.hSI.hRoiManager.isLineScan
                        chIdx = ismembc2(ch,obj.lineScanDataBufferChannels);
                        if ~chIdx
                            return
                        end
                        pixels = single(obj.lineScanAvgDataBuffer(:,:,chIdx));
                        pixels = pixels(:)./obj.displayRollingAverageFactor;
                    else
                        if isempty(obj.lastAcqStripeDataBuffer)
                            srcVar = 'rollingStripeDataBuffer';
                        else
                            srcVar = 'lastAcqStripeDataBuffer';
                        end

                        pixels = single.empty();

                        % get all applicable pixels
                        for i = 1:numel(obj.(srcVar))
                            sd = obj.(srcVar){i};
                            if iscell(sd)
                                sd = sd{1};
                            end

                            [tf,cIdx] = ismember(ch, sd.channelNumbers);

                            if tf
                                for j = 1:numel(sd.roiData)
                                    rd = sd.roiData{j};

                                    npix = single(rd.imageData{cIdx}{1})./obj.displayRollingAverageFactor;
                                    pixels = [pixels;npix(:)];
                                end
                            else
                                continue;
                            end
                        end
                    end
                else
                    pixels = single(pixels(:));
                end

                if ~isempty(pixels)
                    pixels = sort(pixels);
                    N = numel(pixels);
                    iblk = ceil(N*obj.autoScaleSaturationFraction(1));
                    iwht = ceil(N*(1-obj.autoScaleSaturationFraction(2)));
                    lut = round([pixels(iblk) pixels(iwht)]);
                    lut = sort(lut); % just to be sure
                    if diff(lut) <= 0
                        lut = [lut(1) lut(1)+1];
                    end
                    obj.hSI.hChannels.channelLUT{ch} = lut;
                end
            end
        end
        
        function resetActiveDisplayFigs(obj,preserveCameraProps)
            % hSI.hDisplay.resetActiveDisplayFigs(preserveCameraProps)
            %
            % Resets display windows for all active channels
            %
            % Arguments
            %  - preserveCameraProps: [Logical] Indicates that camera position should be preserved through reset
            
            if nargin < 2 || isempty(preserveCameraProps)
                preserveCameraProps = true;
            end
            
            obj.resetDisplayFigs([],[],preserveCameraProps);
        end
       
        function resetDisplayFigs(obj,chansToReset,resetMergeTF,preserveCameraProps)
            % hSI.hDisplay.resetDisplayFigs(chansToReset,resetMergeTF,channelsLUTVal,preserveCameraProps)
            %
            % Resets display windows for selected channels
            %
            % Arguments
            %  - chansToReset:        [Numeric] Array of channel numbers to reset
            %  - resetMergeTF:        [Logical] Indicates if merge channel should be reset
            %  - channelsLUTVal:      [Numeric] Lookup tables to use. Leave empty to use defaults
            %  - preserveCameraProps: [Logical] Indicates that camera position should be preserved through reset
            
            if nargin < 2 || isempty(chansToReset)
                chansToReset = obj.hSI.hChannels.channelDisplay;
            end
            
            if nargin < 3 || isempty(resetMergeTF)
                resetMergeTF = obj.channelsMergeEnable;
            end
            
            if nargin < 4 || isempty(preserveCameraProps)
                preserveCameraProps = true;
            end
            
            if (~obj.hSI.mdlInitialized && ~obj.duringInit) || isempty(chansToReset)
                return;
            end
            
            if obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                return
            end
            
            if ~obj.resetInProgress
                obj.resetInProgress = true;
                try
                    obj.hLinesPhotostimMonitor = []; % set to empty array before surface handles become invalid in zprvPrepareDisplayAxesImages
                    
                    % dont save camera props if display is 2D mode and imaging parameters have changed
                    if preserveCameraProps && ~obj.needsReset
                        obj.saveCameraProps();
                    else
                        obj.cameraProps = [];
                    end
                    obj.needsReset = false;
                    volumeView = '';
                    
                    if obj.hSI.hRoiManager.isLineScan
                        obj.frameAverageIndex = 1;
                        displayMode = 'line';
                        obj.displayType = 'line';
                        
                        if obj.hSI.hFastZ.enable
                            obj.displayZs = obj.hSI.hRoiManager.currentRoiGroup.zs;
                            obj.numDisplayZs = numel(obj.displayZs);
                        else
                            obj.displayZs = 0;
                            obj.numDisplayZs = 1;
                        end
                        
                        % these values are ignored for the line scan display
                        zs = 0;
                    else
                        obj.displayZs = obj.hSI.hStackManager.zs;
                        obj.numDisplayZs = numel(obj.displayZs);
                        obj.frameAverageIndex = zeros(obj.numDisplayZs,1);
                        
                        [~,sd] = setdiff(obj.selectedZs,obj.displayZs);
                        obj.selectedZs(sd) = [];
                        if isempty(obj.selectedZs)
                            zs = obj.displayZs;
                        else
                            zs = obj.selectedZs;
                        end
                        numZs = numel(zs);
                        
                        if obj.z3D && numZs > 1
                            obj.displayType = '3d';
                            displayMode = '3d';
                            volumeView = '';
                        else
                            if numZs < 2
                                volumeView = '';
                            elseif obj.zTiled
                                volumeView = 'tiled';
                            elseif obj.zCurrent
                                volumeView = 'current';
                            elseif obj.zMax
                                volumeView = 'max';
                            end
                            
                            if obj.hSI.hRoiManager.mroiEnable || obj.forceRoiDisplayTransform
                                displayMode = 'transform';
                            else
                                displayMode = 'no_transform';
                            end
                        end
                        
                        obj.displayType = [displayMode volumeView];
                    end
                    
                    newAxes = cell(1,max(obj.hSI.hChannels.channelDisplay(:)));
                    for ch=obj.hSI.hChannels.channelDisplay(:)'
                        if ismember(ch,chansToReset)
                            set(obj.hFigs(ch),'Name',obj.hSI.hChannels.channelName{ch});
                            newAxes{ch} = obj.zprvPrepareDisplayAxesImages(obj.hFigs(ch),zs,displayMode,volumeView,ch);
                        else
                            newAxes{ch} = obj.hAxes{ch};
                        end
                    end
                    obj.hAxes = newAxes;
                    
                    % get the photostim lines
                    for idx = 1:length(obj.hSI.hChannels.channelDisplay)
                        hAx = obj.hAxes{obj.hSI.hChannels.channelDisplay(idx)}{1};
                        obj.hLinesPhotostimMonitor = [obj.hLinesPhotostimMonitor, hAx.hLinePhotostimMonitor]; %#ok<AGROW>
                    end
                    
                    if resetMergeTF
                        obj.hMergeAxes = obj.zprvPrepareDisplayAxesImages(obj.hMergeFigs,zs,displayMode,volumeView,0);
                    end
                    
                    obj.chan1LUT = obj.chan1LUT;
                    obj.chan2LUT = obj.chan2LUT;
                    obj.chan3LUT = obj.chan3LUT;
                    obj.chan4LUT = obj.chan4LUT;
                    
                    if ~isempty(obj.cameraProps)
                        obj.restoreCameraProps(chansToReset);
                    end
            
                    % restore images if possible
                    if ~obj.hSI.hRoiManager.isLineScan
                        if ~isempty(obj.lastAcqStripeDataBuffer)
                            bf = obj.lastAcqStripeDataBuffer;
                        else
                            bf = obj.rollingStripeDataBuffer;
                        end
                        for chan = obj.hSI.hChannels.channelDisplay(:)'
                            obj.displayStripe(chan,bf,true);
                        end
                    end
                catch ME
                    obj.resetInProgress = false;
                    ME.rethrow();
                end
                obj.resetInProgress = false;
                
                if ~isempty(obj.resetReq)
                    vars = obj.resetReq;
                    obj.resetReq = {};
                    obj.resetDisplayFigs(vars{:})
                end
            else
                obj.resetReq = {chansToReset,resetMergeTF,preserveCameraProps};
            end
            
            notify(obj,'displayReset');
        end
        function saveCameraProps(obj)
            % hSI.hDisplay.saveCameraProps()
            %
            % Saves the camera position for channel windows
            nCh = length(obj.hAxes);
            obj.cameraProps.zs = obj.displayZs;
            obj.cameraProps.channels = [];
            obj.cameraProps.displayType = obj.displayType;
            obj.cameraProps.data = cell(1,nCh);
            
            for i = 1:nCh
                if ~isempty(obj.hAxes{i})
                    obj.cameraProps.channels = [obj.cameraProps.channels i];
                    
                    nFr = length(obj.hAxes{i});
                    obj.cameraProps.data{i} = cell(1,nFr);
                    for j = 1:nFr
                        if most.idioms.isValidObj(obj.hAxes{i}{j})
                            obj.cameraProps.data{i}{j} = obj.hAxes{i}{j}.cameraProps;
                        end
                    end
                end
            end
        end
        
        function restoreCameraProps(obj,chansToReset)
            % hSI.hDisplay.restoreCameraProps()
            %
            % Restores the saved camera position for channel windows
            
            if strcmp(obj.cameraProps.displayType, obj.displayType) && (numel(obj.cameraProps.zs) == obj.numDisplayZs)...
                    && all(obj.cameraProps.zs == obj.displayZs)
                for ch = 1:chansToReset
                    nFr = length(obj.hAxes{ch});
                    if ismember(ch,obj.cameraProps.channels) && length(obj.cameraProps.data{ch}) == nFr
                        for j = 1:nFr
                            if most.idioms.isValidObj(obj.hAxes{ch}{j})
                                obj.hAxes{ch}{j}.cameraProps = obj.cameraProps.data{ch}{j};
                            end
                        end
                    end
                end
            end
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        %%% Frame Decimation
        function val = zprpLockDisplayRollAvgFactor(obj)
            %Identify (and apply or return) constrained displayRollingAverageFactor value
            val = obj.displayRollingAverageFactor;
            
            constrainedRollAvgFactor = obj.hSI.hScan2D.logAverageFactor;
            if val ~= constrainedRollAvgFactor
                if constrainedRollAvgFactor == round(constrainedRollAvgFactor)
                    val = constrainedRollAvgFactor;
                else
                    val = 1;
                end
            end
            
            if nargout == 0
                obj.displayRollingAverageFactor = val;
            end
        end

        function averageStripe(obj,newStripe)
            if ~isempty(newStripe.roiData)
                % frame acquisition
                
                if ~newStripe.startOfFrame || ~newStripe.endOfFrame
                    % stripe is partial frame
                    newStripe.merge(obj.lastStripeData);
                end
                
                if newStripe.startOfFrame
                    obj.stripeDataBufferPointer = obj.stripeDataBufferPointer+1;
                    if obj.stripeDataBufferPointer > obj.stripeBufferLength
                        obj.stripeDataBufferPointer = 1;
                    end
                end
                
                obj.lastStripeData = newStripe;
                
                zIdx = find(newStripe.roiData{1}.zs == obj.displayZs);
                displayTF = isempty(obj.selectedZs) || any(obj.displayZs(zIdx) == obj.selectedZs);
                
                if displayTF && ~isempty(obj.hSI.hChannels.channelDisplay)
                    aveIdx = obj.frameAverageIndex(zIdx);
                    if newStripe.startOfFrame
                        aveIdx = aveIdx + 1;
                        if aveIdx > obj.displayRollingAverageFactor
                            aveIdx = 1;
                        end
                    end
                    obj.frameAverageIndex(zIdx) = aveIdx;
                    
                    rollAveFactor = obj.displayRollingAverageFactor;
                    if rollAveFactor > 1 %Display averaging enabled
                        rollingBufferDatatype = 'int32';
                        newStripe.castRoiData(rollingBufferDatatype);
                        if isempty(obj.rollingStripeDataBuffer{zIdx}{1}.roiData)
                            %if any buffer element is empty it means buffers
                            %were just reset. fill all buffers with current
                            %image data to get the averaging started
                            if newStripe.startOfFrame && newStripe.endOfFrame
                                % no stripes in this frame
                                for i = 2:(obj.displayRollingAverageFactor+1)
                                    obj.rollingStripeDataBuffer{zIdx}{i} = newStripe;
                                end
                                
                                %buffer #1 is the averaged data. stripeData is a
                                %handle class! we need a fresh unique piece of
                                %memory for the averaged data to reside in
                                averagedStripe = copy(newStripe);
                                averagedStripe.multiplyRoiData(rollAveFactor);
                                obj.rollingStripeDataBuffer{zIdx}{1} = averagedStripe;
                            else
                                % striping
                                newStripe.resetData();
                                obj.rollingStripeDataBuffer{zIdx}{2} = newStripe;
                                newStripeCp = copy(newStripe);
                                newStripeCp.resetDataToZero();
                                for i = 3:(obj.displayRollingAverageFactor+1)
                                    obj.rollingStripeDataBuffer{zIdx}{i} = newStripeCp;
                                end
                                
                                %buffer #1 is the averaged data. stripeData is a
                                %handle class! we need a fresh unique piece of
                                %memory for the averaged data to reside in
                                averagedStripe = copy(newStripe);
                                %averagedStripe.multiplyRoiData(rollAveFactor);
                                obj.rollingStripeDataBuffer{zIdx}{1} = averagedStripe;
                            end
                        else
                            for iterRoiData = 1:length(obj.rollingStripeDataBuffer{zIdx}{1}.roiData)
                                stripePos = newStripe.roiData{iterRoiData}.stripePosition;
                                for iterChannel = 1:length(obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.channels)
                                    %this if/else structure is here to handle the case where selection factor ~= number of planes and there are flyback frames
                                    if isempty(newStripe.roiData)
                                        %no new data to add
                                        if isempty(obj.rollingStripeDataBuffer{zIdx}{aveIdx+1}.roiData)
                                            %no old data to subtract
                                            %do nothing
                                        else
                                            %old data to subtract
                                            obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) = ...
                                                obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) - ...
                                                obj.rollingStripeDataBuffer{zIdx}{aveIdx+1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2));
                                        end
                                    else
                                        %new data to add
                                        if isempty(obj.rollingStripeDataBuffer{zIdx}{aveIdx+1}.roiData)
                                            %no old data to subtract
                                            obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) = ...
                                                obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos(1):stripePos(2)) + ...
                                                newStripe.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos(1):stripePos(2));
                                        else
                                            %old data to subtract
                                            %normal case
                                            obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) = ...
                                                obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) + ...
                                                newStripe.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2)) - ...
                                                obj.rollingStripeDataBuffer{zIdx}{aveIdx+1}.roiData{iterRoiData}.imageData{iterChannel}{1}(:,stripePos{1}(1):stripePos{1}(2));
                                        end
                                    end
                                end
                                
                                %update roi data and frame number
                                if ~isempty(newStripe.roiData)
                                    obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.hRoi = newStripe.roiData{iterRoiData}.hRoi;
                                    obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.frameNumberAcq = newStripe.roiData{iterRoiData}.frameNumberAcq;
                                    obj.rollingStripeDataBuffer{zIdx}{1}.roiData{iterRoiData}.zs = newStripe.roiData{iterRoiData}.zs;
                                end
                            end
                            
                            newStripe.merge(obj.rollingStripeDataBuffer{zIdx}{aveIdx+1});
                            obj.rollingStripeDataBuffer{zIdx}{aveIdx+1} = newStripe;
                        end
                    else
                        obj.rollingStripeDataBuffer{zIdx}{1} = newStripe;
                    end
                    
                    if obj.zMax
                        Nr = numel(newStripe.roiData);
                        Nc = numel(newStripe.roiData{1}.imageData);
                        
                        if isempty(obj.maxProjBuffer)
                            stripeCpy = copy(newStripe);
                            obj.maxProjBuffer = stripeCpy.roiData;
                        end
                        
                        for r = 1:Nr
                            rd = obj.rollingStripeDataBuffer{zIdx}{1}.roiData{r};
                            if isempty(obj.maxProjBufferPrep{r})
                                obj.maxProjBufferPrep{r} = cell(1,Nc);
                                
                                imSz = size(rd.imageData{1}{1});
                                imClss = class(rd.imageData{1}{1});
                                for c = 1:Nc
                                    obj.maxProjBufferPrep{r}{c} = cast(-inf,imClss) * ones(imSz(1),imSz(2),numel(obj.displayZs),imClss);
                                end
                            end
                            
                            for c = 1:Nc
                                obj.maxProjBufferPrep{r}{c}(:,:,zIdx) = rd.imageData{c}{1};
                                obj.maxProjBuffer{r}.imageData{c}{1} = max(obj.maxProjBufferPrep{r}{c},[],3);
                            end
                        end
                    end
                    
                    obj.rollingStripeDataBufferDirty{zIdx} = true(1,obj.hSI.hChannels.channelsAvailable);
                    obj.mergeStripe(zIdx);
                end
            elseif ~isempty(newStripe.rawData)
                histN = obj.lineScanHistoryLength;
                if newStripe.startOfFrame && newStripe.endOfFrame
                    % one or more frames
                    frmN = obj.lineScanFrameLength;
                    
                    wp = obj.lineScanLastFramePtr + (1:numel(newStripe.frameNumberAcq));
                    wp(wp > histN) = wp(wp > histN) - histN;
                    obj.lineScanLastFramePtr = wp(end);
                    
                    if obj.displayRollingAverageFactor > 1
                        obj.lineScanRawDataBuffer(:,wp,:) = reshape(newStripe.rawData,frmN,numel(wp),[]);
                        
                        ap = wp-1;
                        ap(ap<1) = ap(ap<1) + histN;
                        sp = wp-obj.displayRollingAverageFactor;
                        sp(sp<1) = sp(sp<1) + histN;
                        for i = 1:numel(wp)
                            f = wp(i);
                            a = ap(i);
                            s = sp(i);
                            obj.lineScanAvgDataBuffer(:,f,:) = obj.lineScanRawDataBuffer(:,f,:) + obj.lineScanAvgDataBuffer(:,a,:) - obj.lineScanRawDataBuffer(:,s,:);
                        end
                    else
                        obj.lineScanAvgDataBuffer(:,wp,:) = reshape(newStripe.rawData,frmN,numel(wp),[]);
                    end
                else
                    % partial frame
                    strpN = size(newStripe.rawData,1);
                    strt = newStripe.rawDataStripePosition;
                    nd = newStripe.rawDataStripePosition + strpN - 1;
                    
                    if newStripe.startOfFrame
                        wp = obj.lineScanLastFramePtr + 1;
                        wp(wp > histN) = 1;
                        obj.lineScanAvgDataBuffer(:,wp,:) = obj.lineScanAvgDataBuffer(:,obj.lineScanLastFramePtr,:);
                        obj.lineScanLastFramePtr = wp;
                    else
                        wp = obj.lineScanLastFramePtr;
                    end
                    
                    if obj.displayRollingAverageFactor > 1
                        obj.lineScanRawDataBuffer(strt:nd,wp,:) = reshape(newStripe.rawData,strpN,numel(wp),[]);
                        
                        ap = wp-1;
                        ap(ap<1) = histN;
                        sp = wp-obj.displayRollingAverageFactor;
                        sp(sp<1) = 1;
                        obj.lineScanAvgDataBuffer(strt:nd,wp,:) = obj.lineScanRawDataBuffer(strt:nd,wp,:) + obj.lineScanAvgDataBuffer(strt:nd,ap,:) - obj.lineScanRawDataBuffer(strt:nd,sp,:);
                    else
                        obj.lineScanAvgDataBuffer(strt:nd,wp,:) = reshape(newStripe.rawData,strpN,1,[]);
                    end
                end
                obj.lastStripeData = newStripe;
            end
        end
        
        function roiDatas = getAveragedRoiDatas(obj)
            numZs = numel(obj.hSI.hDisplay.rollingStripeDataBuffer);
            
            roiDatas = scanimage.mroi.RoiData.empty(1,0);
            
            % the averaged data is stored in the first entry of
            % rollingStripeDataBuffer{zidx}{1}
            
            for zidx = 1:numZs
                stripeData_ = obj.hSI.hDisplay.rollingStripeDataBuffer{zidx}{1};
                [hRois_,uuiduint64s_] = getStripeDataRois(stripeData_);
                
                for roiidx = 1:length(uuiduint64s_)
                    [hRois,uuiduint64s] = getRoiDatasRois(roiDatas);
                    idx = find(ismember(uuiduint64s,uuiduint64s_(roiidx)));
                    if isempty(idx)
                        % create a new roidata
                        roiDatas(end+1) = scanimage.mroi.RoiData();
                        idx = length(roiDatas);
                        roiDatas(idx).hRoi = hRois_(roiidx);
                    end
                    assert(isscalar(stripeData_.roiData{roiidx}.zs));
                    roiDatas(idx).zs(end+1) = stripeData_.roiData{roiidx}.zs;
                    roiDatas(idx).channels = stripeData_.roiData{roiidx}.channels;
                    roiDatas(idx).transposed = stripeData_.roiData{roiidx}.transposed;
                    imageData = stripeData_.roiData{roiidx}.imageData;
                    for chIdx = 1:numel(imageData)
                        roiDatas(idx).imageData{chIdx}{numel(roiDatas(idx).zs)} = imageData{chIdx}{1} ./ obj.displayRollingAverageFactor;
                    end
                end
            end
            
            
            %%% local functions
            function [hRois,uuiduint64s] = getStripeDataRois(stripeData)
                if isempty(stripeData) || isempty(stripeData.roiData)
                    hRois = scanimage.mroi.Roi.empty(1,0);
                    uuiduint64s = uint64.empty(1,0);
                else
                    roiDatas__ = [stripeData.roiData{:}];
                    [hRois,uuiduint64s] = getRoiDatasRois(roiDatas__);
                end
            end
            
            function [hRois,uuiduint64s] = getRoiDatasRois(roiDatas)
                if isempty(roiDatas)
                    hRois = scanimage.mroi.Roi.empty(1,0);
                    uuiduint64s = uint64.empty(1,0);
                else
                    hRois = [roiDatas.hRoi];
                    uuiduint64s = [hRois.uuiduint64];
                end
            end
        end
        
        function mergeStripe(obj,zIdx)
            if obj.channelsMergeEnable
                lclStripeData = obj.rollingStripeDataBuffer{zIdx}{1};
                % Determine which channels to display, and the merge colors
                % (based on user selections in the GUI)
                chansToDisp = obj.hSI.hChannels.channelDisplay;
                mergeColors = obj.hSI.hChannels.channelMergeColor;

                mergeStripeData = copy(lclStripeData);
                
                % Iterate through the number of roiDatas in this
                % stripeData.
                for iter = 1:numel(lclStripeData.roiData)
                    lclRoiData = copy(lclStripeData.roiData{iter});
                    % Get dimensions of this roiData in pixels. Remember
                    % that this varies in MROI mode.
                    [ roiPixelsX, roiPixelsY ] = size(lclRoiData.imageData{1}{1});
                    % Create empty mergeData array, which is sized to the current roiData, and will hold
                    % a 3D RGB array for all channels displaying this ROI.
                    mergeData = zeros(roiPixelsX,roiPixelsY,3,'uint8');
                    % Loop through all channels displaying this roiData.
                    for chanIdx = 1:numel(chansToDisp)
                        channel = chansToDisp(chanIdx);
                        % Get the actual image data in the roiData for this
                        % channel.
                        imageData = lclRoiData.imageData{chanIdx}{1};
                        chanProp = sprintf('chan%dLUT',channel);
                        chanLut = (obj.(chanProp)) * obj.displayRollingAverageFactor; % adjust LUT to perform frame averaging
                        % Iteratively merge all channels displaying this roiData with the
                        % user-selected channel colors and LUTs.
                        mergeData = obj.zprvAddChanDataToMergeData(mergeData,imageData,mergeColors{channel},chanLut);
                    end
                    %Take the merged channel data and write it into
                    %mergeStripeData.
                    lclRoiData.imageData = {{mergeData}};
                    lclRoiData.channels = 0;
                    mergeStripeData.roiData{iter} = lclRoiData;
                end
                % Put merged stripe data into the mergeStripeDataBuffer.
                obj.mergeStripeDataBuffer{zIdx} = mergeStripeData;
            end
        end

        function displayChannels(obj)
            %if obj.componentExecuteFunction('displayChannels') % remove for performance
                for chanIdx = 1:numel(obj.hSI.hChannels.channelDisplay)
                    % Get the actual channel number.
                    lclChannelNumber = obj.hSI.hChannels.channelDisplay(chanIdx);
                    % Get the display function registered for this channel.
                    lclDisplayFunction = obj.hSI.hChannels.channelDisplayFunction{lclChannelNumber};                    
                    if ~isempty(lclDisplayFunction)
                        % Call the registered display function (if it exists.)
                        obj.(lclDisplayFunction)(lclChannelNumber,[]);
                    else
                        fprintf('Warning: No display function specified for channel %d.\n',chanIdx);
                    end
                end
                if obj.frameRateDisplay && ~isempty(obj.lastDisplayUpdate)
                    obj.frameRateAverageBuffer(end+1) = toc(obj.lastDisplayUpdate);
                    nToDel = max(0,length(obj.frameRateAverageBuffer) - obj.frameRateAverageFactor);
                    obj.frameRateAverageBuffer(1:nToDel) = [];
                    obj.frameRate = 1/mean(obj.frameRateAverageBuffer);
                    fprintf('Frame rate: %.2f fps\n', obj.frameRate);
                end
                obj.lastDisplayUpdate = tic;
            %end
        end
        
        
        function displayStripe(obj,channelNumber,buffer,forceAll)
            if nargin < 4
                forceAll = false;
            end
            
            if obj.hSI.hRoiManager.isLineScan
                obj.hAxes{channelNumber}{1}.updateDisplay(obj.lastStripeData);
            else
                if isempty(buffer)
                    bufferTemp = obj.rollingStripeDataBuffer;
                else
                    bufferTemp = buffer;
                end
                bufferDirtyFlagsTemp = obj.rollingStripeDataBufferDirty;
                chanAxes = obj.hAxes{channelNumber};
                
                % Update channel windows
                if isempty(obj.selectedZs)
                    zs = obj.displayZs;
                else
                    zs = obj.selectedZs;
                end
                
                for bufind = 1:numel(bufferTemp)
                    sd = bufferTemp{bufind};
                    if iscell(sd)
                        sd = sd{1};
                    end
                    if ~isempty(sd) && ~isempty(sd.roiData) && (forceAll || any(bufferDirtyFlagsTemp{bufind}(channelNumber))) % Any added because if not this causes logic fail with multiple channels 1/2
                        z = sd.roiData{1}.zs;
                        if ismember(z,zs)
                            if obj.zMax
                                lclRoiData = obj.maxProjBuffer;
                            else
                                lclRoiData = sd.roiData;
                            end
                            
                            motionMatrix = sd.motionMatrix;
                            
                            if ~isempty(lclRoiData)
                                if obj.zTiled && ~obj.useNewTileMode
                                    hRoiDisplay = chanAxes{z == zs};
                                else
                                    hRoiDisplay = chanAxes{1};
                                end
                                
                                if isvalid(hRoiDisplay) % hRoiDisplay can become invalid if axes are reset
                                    hRoiDisplay.drawRoiData(lclRoiData);
                                    hRoiDisplay.motionMatrix = motionMatrix;
                                end
                                
                                obj.rollingStripeDataBufferDirty{bufind}(channelNumber) = false; % Only place channels used after logical doesn't care. Will apply to all active channesl 2/2
                            end
                            
                            if obj.channelsMergeEnable
                                % TODO: Get rid of this hack and fix the issue where
                                % the mergeStripe has no roiData or the imageData is not 3D.
                                mergeRoiData = obj.mergeStripeDataBuffer{bufind}.roiData;
                                motionMatrix = obj.mergeStripeDataBuffer{bufind}.motionMatrix;
                                if iscell(mergeRoiData) && ~isempty(mergeRoiData)
                                    if numel(size(mergeRoiData{1}.imageData{1}{1})) == 3
                                        if obj.zTiled && ~obj.useNewTileMode
                                            hMergeDisplay = obj.hMergeAxes{z == zs};
                                        else
                                            hMergeDisplay = obj.hMergeAxes{1};
                                        end
                                        
                                        if isvalid(hMergeDisplay) % hMergeDisplay can become invalid if axes are reset
                                            hMergeDisplay.drawRoiData(mergeRoiData);
                                            hMergeDisplay.motionMatrix = motionMatrix;
                                        end
                                    else
                                        fprintf('obj.mergeStripeData not 3D as expected...\n');
                                    end
                                end
                            end
                        end
                    end
                    
                end
            end
        end
        
        function updatePosFdbk(obj)
            for ch=obj.hSI.hChannels.channelDisplay(:)'
                obj.hAxes{ch}{1}.updatePosFdbk();
            end
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function zprpUpdateChanLUT(obj,chanIdx,newVal)
            if chanIdx>length(obj.hAxes)
                return;
            end
            
            for i = 1:length(obj.hAxes{chanIdx})
                hRoiAx = obj.hAxes{chanIdx}{i};
                hRoiAx.CLim = newVal;
                hRoiAx.dataMultiplier = obj.displayRollingAverageFactor; % adjust LUT to perform frame averaging
            end
        end
        
        function lclDisplayFigCloseEventHandler(obj,src,evnt) 
            channelToHide = find(obj.hFigs == src);
            if isempty(channelToHide) %this should never occur
                set(src,'Visible','off');
                return
            end
            
            if isempty(find(obj.hSI.hChannels.channelDisplay==channelToHide, 1))
                set(src,'Visible','off'); % if the channel is not actively displayed, the window can be closed during an active acquisition
            else
                if obj.componentExecuteFunction('lclDisplayFigCloseEventHandler',src,evnt)
                    obj.hSI.hChannels.channelDisplay(obj.hSI.hChannels.channelDisplay==channelToHide) = [];
                    if ~ismember(channelToHide,obj.hSI.hChannels.channelDisplay)
                        set(src,'Visible','off');
                    end
                end
            end
        end
    end
    
    methods (Hidden)
        function mergeData = zprvAddChanDataToMergeData(obj,mergeData,chanData,clr,lut)
                lut = single(lut);
                maxVal = single(255);
                chanDataRescaled = uint8((single(chanData) - lut(1)) .* (maxVal / (lut(2)-lut(1))));
                
                switch clr
                    case 'red'
                        mergeData(:,:,1) = mergeData(:,:,1) + chanDataRescaled;
                    case 'green'
                        mergeData(:,:,2) = mergeData(:,:,2) + chanDataRescaled;
                    case 'blue'
                        mergeData(:,:,3) = mergeData(:,:,3) + chanDataRescaled;
                    case 'gray'
                        mergeData(:,:,:) = mergeData(:,:,:) + repmat(chanDataRescaled,[1 1 3]);
                    case 'none'
                        % no-op
                    otherwise
                        assert(false);
                end
        end        
        
        function numChannelFigs = ziniCreateFigs(obj)
            %Initialize channel figure windows
            numChans = obj.hSI.hChannels.channelsAvailable;

            %Create the figures first.
            if most.idioms.graphics2014b
                obj.hFigs = gobjects(1,obj.MAXIMUM_CHANNELS); % ensure the figures are stored as object handles, not as numeric values
            end
            
            for i=1:obj.MAXIMUM_CHANNELS
                obj.hFigs(i) = most.idioms.figureSquare('Name',sprintf('CH%s',i),'Visible','off',...
                    'ColorMap',gray(255),'NumberTitle','off','Menubar','none','Tag',sprintf('image_channel%d',i),...
                    'CloseRequestFcn',@(src,evnt)obj.lclDisplayFigCloseEventHandler(src,evnt));
            end
            
            numChannelFigs = numChans;
            obj.hMergeFigs = most.idioms.figureSquare('Name','Channel Merge',...
                'Visible','off','NumberTitle','off','Menubar','none',...
                'Tag','channel_merge','CloseRequestFcn',@lclMergeFigCloseEventHandler);
            
            obj.duringInit = true;
            obj.resetDisplayFigs(1:numChans,true,false);
            obj.duringInit = false;
            
            % register all channel figs with controller
            assert(numel(obj.hController) <= 1); % for now always have a single controller
            if ~isempty(obj.hController)
                ctrler = obj.hController{1};
                for c = 1:numChans
                    ctrler.registerGUI(obj.hFigs(c));
                end
                ctrler.registerGUI(obj.hMergeFigs);
            end
            
            function lclMergeFigCloseEventHandler(~,~)
                obj.channelsMergeEnable = false;
            end
        end
        
        function zzzSetImageFigureAxesLimits(obj)
            if ~isempty(obj.hSI.hChannels.channelDisplay)
                for i=1:numel(obj.hSI.hChannels.channelDisplay)
                    chan = obj.hSI.hChannels.channelDisplay(i);
                    figure(obj.hFigs(chan));
                    set(obj.hFigs(chan),'HandleVisibility','callback');
                    for tileIdx = 1:numel(obj.hAxes{chan})
                        obj.hAxes{chan}{tileIdx}.resetScanFields();
                    end
                end
            end
        end
        
        function zprvResetBuffers(obj)
            if obj.hSI.hRoiManager.isLineScan
                APB = obj.hSI.hScan2D.hAcq.acqParamBuffer;
                if ~isempty(fieldnames(APB))
                    try
                        obj.lineScanFrameLength = APB.samplesPerFrame;
                        obj.lineScanRawDataBuffer = zeros(APB.samplesPerFrame,obj.lineScanHistoryLength,numel(APB.channelsActive));
                        obj.lineScanDataBufferChannels = APB.channelsActive;
                        obj.lineScanLastFramePtr = obj.lineScanHistoryLength;
                        obj.lineScanAvgDataBuffer = zeros(APB.samplesPerFrame,obj.lineScanHistoryLength,numel(APB.channelsActive));
                        obj.lineScanMrgDataBuffer = zeros(APB.samplesPerFrame,obj.lineScanHistoryLength);
                    catch
                        error('Failed to allocate display buffer. Reduce the history length, reduce the sample rate, or shorten the cycle.');
                    end
                end
                
                obj.stripeDataBufferPointer = 1;
                obj.stripeDataBuffer = {};
                obj.rollingStripeDataBuffer = {};
                obj.mergeStripeDataBuffer = {};
                obj.maxProjBuffer = [];
                obj.maxProjBufferPrep = {};
            else
                % the frameBuffers hold references to stripeData objects
                % (no need to preallocate the buffers)
                
                % the frameBuffers hold references to stripeData objects
                % (no need to preallocate the buffers)
                obj.stripeDataBuffer = cell(obj.stripeBufferLength,1);
                for i=1:obj.stripeBufferLength
                    obj.stripeDataBuffer{i} = scanimage.interfaces.StripeData();
                end
                obj.stripeDataBufferPointer = obj.stripeBufferLength;
                
                tmpBufDirty = cell(1,obj.numDisplayZs);
                tmpBuf = cell(1,obj.numDisplayZs);
                tmpMergeBuffer = cell(1,obj.numDisplayZs);
                for i=1:obj.numDisplayZs
                    tmpBufDirty{i} = false(1,obj.hSI.hChannels.channelsAvailable);
                    for j=1:(obj.displayRollingAverageFactor+1)
                        tmpBuf{i}{j} = scanimage.interfaces.StripeData;
                    end
                    % The Merge Buffer uses already averaged frame data, and
                    % therefore doesn't require a 2D buffer.
                    tmpMergeBuffer{i} = scanimage.interfaces.StripeData;
                end
                
                obj.rollingStripeDataBufferDirty = tmpBufDirty;
                obj.rollingStripeDataBuffer = tmpBuf;
                obj.mergeStripeDataBuffer = tmpMergeBuffer;
                
                obj.maxProjBuffer = [];
                obj.maxProjBufferPrep = cell(1,numel(obj.hSI.hRoiManager.currentRoiGroup.rois));
            end
        end
        
        function zprvResizeAvgBuffers(obj,oldAvg)
            if obj.hSI.hRoiManager.isLineScan
                obj.zprvResetBuffers();
            else
                obj.frameAverageIndex = ones(obj.numDisplayZs,1);
                if isempty(obj.rollingStripeDataBuffer) || (length(obj.rollingStripeDataBuffer) < obj.numDisplayZs)
                    obj.zprvResetBuffers();
                else
                    tmpBufDirty = cell(1,obj.numDisplayZs);
                    tmpBuf = cell(1,obj.numDisplayZs);
                    tmpMergeBuffer = cell(1,obj.numDisplayZs);
                    
                    for i=1:obj.numDisplayZs
                        if isempty(obj.rollingStripeDataBuffer{i}{1}.roiData)
                            tmpBufDirty{i} = false(1,obj.hSI.hChannels.channelsAvailable);
                            for j=1:(obj.displayRollingAverageFactor+1)
                                tmpBuf{i}{j} = scanimage.interfaces.StripeData;
                            end
                        else
                            tmpBufDirty{i} = true(1,obj.hSI.hChannels.channelsAvailable);
                            tmpBuf{i}{1} = obj.rollingStripeDataBuffer{i}{1};
                            
                            rollingBufferDatatype = 'int32';
                            tmpBuf{i}{1}.castRoiData(rollingBufferDatatype);
                            tmpBuf{i}{1}.multiplyRoiData(1/oldAvg);
                            
                            copiedStripe = copy(tmpBuf{i}{1});
                            
                            for j=2:(obj.displayRollingAverageFactor+1)
                                tmpBuf{i}{j} = copiedStripe;
                            end
                            
                            tmpBuf{i}{1}.multiplyRoiData(obj.displayRollingAverageFactor);
                        end
                        tmpMergeBuffer{i} = scanimage.interfaces.StripeData;
                    end
                    obj.rollingStripeDataBufferDirty = tmpBufDirty;
                    obj.rollingStripeDataBuffer = tmpBuf;
                    obj.mergeStripeDataBuffer = tmpMergeBuffer;
                end
                
                if ~isempty(obj.lastAcqStripeDataBuffer)
                    bf = obj.lastAcqStripeDataBuffer;
                else
                    bf = obj.rollingStripeDataBuffer;
                end
                for chan = obj.hSI.hChannels.channelDisplay
                    obj.displayStripe(chan,bf);
                end
            end
        end
        
        function hRoiAx = zprvPrepareDisplayAxesImages(obj,hFig,zs,displayMode,volumeView,chan)
            clf(hFig);
            hFig.SizeChangedFcn = [];
            hFig.WindowButtonDownFcn = [];
            hFig.WindowButtonMotionFcn = [];
            hFig.WindowButtonUpFcn = [];
            set(hFig,'HandleVisibility','callback');
            set(0, 'CurrentFigure', hFig);
            hRoiAx = {};
            
            if strcmp(displayMode, 'line')
                hRoiAx{1} = scanimage.guis.LineScanDisplay(obj.hSI,hFig,chan);
            else
                if (numel(zs) > 1) && obj.zTiled && ~obj.useNewTileMode
                    numZs = numel(zs);
                    columns = round(sqrt(numZs));
                    rows = ceil(numZs/columns);
                    
                    hGrid = uigridcontainer('v0','Parent',hFig,'Units','norm','Position',[0 0 1 1],'Margin',2);
                    set(hGrid,'GridSize',[columns rows]);
                    
                    for tileIdx=1:numel(zs);
                        hRoiAx{tileIdx} = scanimage.mroi.RoiDisplay(obj.hSI,hGrid,chan);
                        hRoiAx{tileIdx}.debugEnabled = obj.hSI.debugEnabled;
                        hRoiAx{tileIdx}.initialize(zs(tileIdx),displayMode,'');
                    end
                else
                    hRoiAx{1} = scanimage.mroi.RoiDisplay(obj.hSI,hFig,chan);
                    hRoiAx{1}.initialize(zs,displayMode,volumeView);
                    hRoiAx{1}.debugEnabled = obj.hSI.debugEnabled;
                end
            end
        end
        
        function val = zprvCoerceLutToAdcRange(obj,val)
            val = cast(val,'int16');
            rangeMax = obj.hSI.hChannels.channelLUTRange(2);
            rangeMin = obj.hSI.hChannels.channelLUTRange(1);
            % ensure that the values are within the ADC range
            val = max(val,rangeMin);
            val = min(val,rangeMax);
            
            % ensure that val(2) > val(1)
            if val(2) == rangeMax
                val(1) = min(val(1),val(2)-1);
            else
                val(2) = max(val(2),val(1)+1);
            end
        end
    end
    
    %%%Abstract method impementations (most.Model)
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            %Initialize Channel Figures
            numChannelFigs = obj.ziniCreateFigs();
            obj.numInstances = numChannelFigs;
            
            mdlInitialize@most.Model(obj);
            
            %Reset Buffers for Frame Averaging
            obj.zprvResetBuffers();
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command

            if ~obj.hSI.hRoiManager.isLineScan
                obj.lastAcqStripeDataBuffer = [];
                obj.lastAcqMergeStripeDataBuffer = [];
                obj.lastAcqScannerName = '';
            end
            
            %avoid error during reset
            obj.lineScanLastFramePtr = min(obj.lineScanLastFramePtr,obj.lineScanHistoryLength);
            
            % this will cause a display reset
            obj.volumeDisplayStyle = obj.volumeDisplayStyle;
            
            % reset the buffers
            obj.zprvResetBuffers();
        end
        
        function componentAbort(obj,soft)
        %   Runs code that aborts with the global acquisition-abort command
            obj.lastDisplayUpdate = [];
            obj.frameRateAverageBuffer = [];
            % save data
            if ~soft && ~isempty(obj.rollingStripeDataBuffer)
                obj.lastAcqScannerName = obj.hSI.imagingSystem;
                obj.lastAcqStripeDataBuffer = cell(1,obj.numDisplayZs);
                if numel(obj.rollingStripeDataBuffer) >= obj.numDisplayZs
                    for i=1:obj.numDisplayZs
                        obj.lastAcqStripeDataBuffer{i} = obj.rollingStripeDataBuffer{i}{1};
                    end
                else
                    obj.lastAcqStripeDataBuffer = [];
                    obj.lastAcqMergeStripeDataBuffer = [];
                end
                
                if ~isempty(obj.mergeStripeDataBuffer)
                    obj.lastAcqMergeStripeDataBuffer = obj.mergeStripeDataBuffer;
                end
            end
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
s.displayRollingAverageFactorLock = struct('Classes','binaryflex','Attributes','scalar');
s.displayRollingAverageFactor = struct('Classes','numeric','Attributes',{{'positive' 'integer' 'finite' '<' 10000}});
s.lineScanHistoryLength = struct('Classes','numeric','Attributes',{{'positive' 'integer' 'finite'}});
s.scanfieldDisplays = struct('Classes','struct','AllowEmpty',true);
s.autoScaleSaturationFraction = struct('Classes','numeric','Attributes',{{'numel', 2,'>=',0,'<',.5}});

s.roiDisplayEdgeColor           = struct('Options',{{'none','y','yellow','m','magenta','c','cyan','r','red','g','green','b','blue','w','white','k','black'}});
s.roiDisplayEdgeAlpha           = struct('Classes','numeric','Attributes',{{'scalar','>=',0,'<=',1}});
s.roiProjectionDisplayEdgeColor	= struct('Options',{{'none','y','yellow','m','magenta','c','cyan','r','red','g','green','b','blue','w','white','k','black'}});
s.roiProjectionDisplayEdgeAlpha = struct('Classes','numeric','Attributes',{{'scalar','>=',0,'<=',1}});

s.chan1LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan2LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan3LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.chan4LUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
s.channelsMergeEnable = struct('Classes','binaryflex','Attributes','scalar');
s.channelsMergeFocusOnly = struct('Classes','binaryflex','Attributes','scalar');
s.renderer = struct('Options',{{'auto' 'painters' 'opengl'}});
s.forceRoiDisplayTransform = struct('Classes','binaryflex','Attributes','scalar');

s.enableScanfieldDisplays = struct('Classes','binaryflex','Attributes','scalar');
s.showScanfieldDisplayNames = struct('Classes','binaryflex','Attributes','scalar');
s.scanfieldDisplayTilingMode = struct('Options',{{'Auto','Set Columns','Set Rows'}});
s.scanfieldDisplayColumns = struct('Classes','numeric','Attributes',{{'positive' 'integer' 'finite'}});
s.scanfieldDisplayRows = struct('Classes','numeric','Attributes',{{'positive' 'integer' 'finite'}});
end


%--------------------------------------------------------------------------%
% Display.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
