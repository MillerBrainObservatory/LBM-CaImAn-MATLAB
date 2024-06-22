classdef AlignmentControls < most.Gui & most.HasClassDataFile
    
    %% USER PROPS
    properties (SetObservable)
        showWindow = false;
        pauseVideo = false;
        referenceLUT = [0 100];
        
        referenceImageColor = 'Green';
        videoStreamAlpha = 0.5;
        
        alignmentSource = 'Channel 1';
        videoStreamColor = 'Red';
        photostimPattern;
        testPattern;
        
        videoImToRefImTransform = eye(3);
    end
    
    properties (SetObservable, Dependent)
        vidOffsetX;
        vidOffsetY;
        vidScaleX;
        vidScaleY;
        vidRotation;
        vidShear;
    end
    
    
    %% GUI PROPERTIES
    properties (SetAccess = protected,SetObservable,Hidden)        
        hAlignmentFig = [];
        hAlignmentAx = [];
        hListeners = [];
        hStimGroupListener = [];
        stimRoiGroupNameListeners;
        hMainContextMenu = [];
        hMainContextMenuAEs = [];
        hMainContextMenuAFx = [];
        hMainContextMenuAFr = [];
        
        pbCopyChannelN;
        
        hControlPoints = [];
        hControlPointMenus = [];
        controlPointPositions = {};
        controlPointFixed = [];
        
        hRefIm = [];
        hRefImOutline = [];
        hVidIm = [];
        hVidImOutline = [];
        hStimPth = [];
        
        pathPointPositions = {};
        pathPointFixed = [];
        hPathMenus = [];
    end
    
    
    %% INTERNAL PROPS
    properties (Hidden,SetObservable,Transient)
        referenceData = struct('roiDat',{[]});
        videoData = struct('roiDat',{[]});
        
        refDirty = false;
        vidDirty = false;
        
        videoStreamSourceChan = 1;
        
        maxViewFov;
        viewFov;
        viewPos = [0 0];
        
        scanPathCache;
        scanPathCacheIds;
    end

    properties (Hidden,SetObservable,Dependent,Transient)
        referenceLUTRange;
    end
    
    properties (Hidden,SetAccess=private)
        geometryProps = struct(...
            'offsetX',0,...
            'offsetY',0,...
            'scaleX',1,...
            'scaleY',1,...
            'rotation',0,...
            'shear',0);
    end
    
    %% LIFECYCLE
    methods
        function obj = AlignmentControls(hModel, hController)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            obj = obj@most.Gui(hModel, hController, [74.6 15.8461538461539], 'characters');
            set(obj.hFig,'Name','ALIGNMENT CONTROLS','Resize','off');
            
            h2 = uipanel(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuipanelFontUnits'),...
                'Units','characters',...
                'Title','Reference Image',...
                'Position',[1.2 0.4 29.8 13.7692307692308],...
                'Clipping','off',...
                'ChildrenMode','manual',...
                'Tag','uipanel1',...
                'FontWeight','bold');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Copy CH1',...
                'Position',[1.6 10.6153846153846 12.6 1.76923076923077],...
                'Callback',@(varargin)obj.copyChannel(1),...
                'Tag','pbCopyChannel1');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Copy CH2',...
                'Position',[14.8 10.6153846153846 12.6 1.76923076923077],...
                'Callback',@(varargin)obj.copyChannel(2),...
                'Tag','pbCopyChannel2');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Copy CH3',...
                'Position',[1.6 8.61538461538462 12.6 1.76923076923077],...
                'Callback',@(varargin)obj.copyChannel(3),...
                'Tag','pbCopyChannel3');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Copy CH4',...
                'Position',[14.8 8.61538461538463 12.6 1.76923076923077],...
                'Callback',@(varargin)obj.copyChannel(4),...
                'Tag','pbCopyChannel4');
            
            obj.pbCopyChannelN = [obj.pbCopyChannel1 obj.pbCopyChannel2 obj.pbCopyChannel3 obj.pbCopyChannel4];
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','0.99',...
                'Style','edit',...
                'Position',[20.8 2.6153846153846 6.4 1.69230769230769],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'videoStreamAlpha' 'Value'},...
                'Tag','etAlpha');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Alpha:',...
                'Style','text',...
                'Position',[1.6 2.92307692307692 6.4 1.07692307692308],...
                'Tag','text4');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{  'Green'; 'Red'; 'Blue'; 'Gray' },...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[16.4 0.692307692307686 10.8 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'referenceImageColor' 'Choice'},...
                'Tag','pmRefColor');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Color:',...
                'Style','text',...
                'Position',[10.2 0.769230769230769 5.8 1.07692307692308],...
                'Tag','text6');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Load from file',...
                'Position',[1.6 6.61538461538462 25.8 1.76923076923077],...
                'Callback',@(varargin)obj.loadReference(),...
                'Tag','pbLoadReference');
            
            obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Save to file',...
                'Position',[1.6 4.61538461538462 25.8 1.76923076923077],...
                'Callback',@(varargin)obj.saveReference(),...
                'Tag','pbSaveReference');
            
            obj.slAlpha = obj.addUiControl(...
                'Parent',h2,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'SliderStep',[0.1 0.1],...
                'String',{  'Slider' },...
                'Style','slider',...
                'Position',[8 2.61538461538462 12.2 1.61538461538462],...
                'BackgroundColor',[0.9 0.9 0.9],...
                'Tag','slAlpha',...
                'Bindings',{obj 'videoStreamAlpha' 'Value'},...
                'LiveUpdate',true);
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Show Alignment Window',...
                'Style','checkbox',...
                'Position',[1.6 14.2 30.8 1.76923076923077],...
                'Bindings',{obj 'showWindow' 'Value'},...
                'Tag','cbShowWindow');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Alignment Source:',...
                'horizontalalignment','left',...
                'Style','text',...
                'Position',[33.2 13.1769230769231 35 1.07692307692308],...
                'Tag','text5');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{'Channel 1e'},...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[52 13.1 20.1 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'alignmentSource' 'Choice'},...
                'Tag','pmVideoSource');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{  'Green'; 'Red'; 'Blue'; 'Gray' },...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[61.3 11.1538461538462 10.8 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'videoStreamColor' 'Choice'},...
                'Tag','pmVidColor');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Color:',...
                'Style','text',...
                'Position',[55 11.2807692307692 5.9 1.07692307692308],...
                'Tag','stColor');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Pattern:',...
                'horizontalalignment','left',...
                'Style','text',...
                'Position',[33.2 11.0788461538462 15 1.07692307692308],...
                'Tag','stPattern');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{'Pattern 1'},...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[41.5 11.0538461538462 30.6 1.53846153846154],...
                'callback',@obj.selPattern,...
                'BackgroundColor',[1 1 1],...
                'Tag','pmPhotostimPattern');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','500',...
                'Style','edit',...
                'Position',[45 8.84615384615385 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidOffsetX' 'Value'},...
                'Tag','etOffsetX');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Offset X:',...
                'Style','text',...
                'Position',[35.6 9.07692307692308 9.2 1.07692307692308],...
                'Tag','text12');
            
            obj.etOffsetY = obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','500',...
                'Style','edit',...
                'Position',[45 7.07692307692308 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidOffsetY' 'Value'},...
                'Tag','etOffsetY');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Offset Y:',...
                'Style','text',...
                'Position',[35.4 7.30769230769231 9.25000000000001 1.07692307692308],...
                'Tag','text13');
            
            obj.etScaleX = obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','1',...
                'Style','edit',...
                'Position',[62.6 8.84615384615385 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidScaleX' 'Value'},...
                'Tag','etScaleX');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Scale X:',...
                'Style','text',...
                'Position',[54 9.07692307692308 8.4 1.07692307692308],...
                'Children',[],...
                'Tag','text14');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','1',...
                'Style','edit',...
                'Position',[62.6 7.07692307692308 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidScaleY' 'Value'},...
                'Tag','etScaleY');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Scale Y:',...
                'Style','text',...
                'Position',[53.8 7.30769230769231 8.6 1.07692307692308],...
                'Tag','text15');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','500',...
                'Style','edit',...
                'Position',[45 5.30769230769231 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidRotation' 'Value'},...
                'Tag','etRotation');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Save Scanner Alignment Transform',...
                'Position',[31.4 2.61538461538462 42.2 1.84615384615385],...
                'Callback',@obj.guiSaveScannerTransform,...
                'Tag','pgGenerate');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Pause Video',...
                'Style','togglebutton',...
                'Position',[33 11.0538461538462 16 1.69230769230769],...
                'Bindings',{obj 'pauseVideo' 'Value'},...
                'Tag','pbPause');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Reset Alignment',...
                'Position',[31.4 0.692307692307693 19 1.84615384615385],...
                'Callback',@obj.resetTransforms,...
                'Children',[],...
                'TooltipString','Clears previously set alignment data.',...
                'Tag','pbReset');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Create Alignment ROI',...
                'Position',[50.4 0.692307692307693 23.2 1.84615384615385],...
                'Callback',@obj.createAlignmentRoi,...
                'TooltipString','Creates a ROI that can be imaged by all scanners to use for alignment.',...
                'Children',[],...
                'Tag','pbCreateRoi');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Rotation:',...
                'Style','text',...
                'Position',[35.4 5.53846153846154 9.25000000000001 1.07692307692308],...
                'Tag','text16');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'ListboxTop',0,...
                'String','0',...
                'Style','edit',...
                'Value',get(0,'defaultuicontrolValue'),...
                'Position',[62.6 5.30769230769231 6.4 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'vidShear' 'Value'},...
                'Tag','etShear');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'HorizontalAlignment','right',...
                'String','Shear:',...
                'Style','text',...
                'Position',[53.8 5.53846153846154 8.6 1.15384615384615],...
                'ButtonDownFcn',blanks(0),...
                'Tag','text17');
            
            obj.updateMaxViewFov();
            obj.resetAlignmentFig(false);
            obj.hListeners = [addlistener(obj.hModel.hDisplay,'renderer','PostSet',@obj.rendererModeChanged);...
                addlistener(obj.hModel.hDisplay,'chan1LUT','PostSet',@obj.videoLutChanged);...
                addlistener(obj.hModel.hDisplay,'chan2LUT','PostSet',@obj.videoLutChanged);...
                addlistener(obj.hModel.hDisplay,'chan3LUT','PostSet',@obj.videoLutChanged);...
                addlistener(obj.hModel.hDisplay,'chan4LUT','PostSet',@obj.videoLutChanged);...
                addlistener(obj.hModel.hUserFunctions,'frameAcquired',@(varargin)obj.frameAcquired());...
                addlistener(obj.hModel,'imagingSystem','PostSet',@(varargin)obj.updateChannelOptions());...
                addlistener(obj.hModel.hPhotostim,'stimRoiGroups','PostSet',@(varargin)obj.updatePhotostimOptions());...
                addlistener(obj.pmVideoSource,'ButtonDown',@(varargin)obj.updateChannelOptions)];
            
            %listeners to cameras
            obj.hListeners(end+1) = addlistener(obj.hModel.hCameraManager,...
                'cameraLastFrameUpdated',@obj.frameAcquired);
            
            %listeners to camera LUTs
            obj.hListeners(end+1) = addlistener(obj.hModel.hCameraManager,...
                'cameraLUTChanged', @obj.videoLutChanged);
            
            obj.updateChannelOptions();
            obj.updatePhotostimOptions();
            obj.ensureClassDataFile(struct('lastReferenceFile','reference.mat'));
        end
        
        function updateChannelOptions(obj)
            % disable controls if channels don't exist
            for iterChannels = 1:4
                if iterChannels <= obj.hModel.hChannels.channelsAvailable
                    set(obj.pbCopyChannelN(iterChannels),'Enable','on');
                else
                    set(obj.pbCopyChannelN(iterChannels),'Enable','off');
                end
            end
            
            % update channel list
            pmString = arrayfun(@(x){['Channel ' num2str(x)]},1:obj.hModel.hChannels.channelsAvailable);
            if obj.hModel.hPhotostim.numInstances
                pmString{end+1} = 'Photostimulation';
            end
            if ~isempty(obj.hModel.hSlmScan) && ~isempty(obj.hModel.hSlmScan.testPattern) 
                pmString{end+1} = 'SLM Test Pattern';
            end
            if ~isempty(obj.hModel.hCameraManager) && ~isempty(obj.hModel.hCameraManager.hCameras)
                pmString = [pmString ...
                    cellfun(@(cam)cam.cameraName, obj.hModel.hCameraManager.hCameras, ...
                    'UniformOutput', false)];
            end
            set(obj.pmVideoSource, 'string', pmString);
            
            % validate previous selection
            if ~isempty(regexpi(obj.alignmentSource,'^Channel\s*.*','match','once'))
                obj.alignmentSource = ['Channel ' num2str(min(obj.pmVideoSource.Value,obj.hModel.hChannels.channelsAvailable))];
            end
        end
        
        function updatePhotostimOptions(obj,varargin)
            most.idioms.safeDeleteObj(obj.stimRoiGroupNameListeners);
            obj.stimRoiGroupNameListeners = [];
            
            if isempty(obj.hModel.hPhotostim.stimRoiGroups)
                obj.pmPhotostimPattern.String = {' '};
                obj.pmPhotostimPattern.Value = 1;
                obj.photostimPattern = [];
            else
                obj.pmPhotostimPattern.String = {obj.hModel.hPhotostim.stimRoiGroups.name};
                % add listener to name properties
                l = arrayfun(@(hRoiGroup){hRoiGroup.addlistener('name', 'PostSet', @obj.updatePhotostimOptions)},obj.hModel.hPhotostim.stimRoiGroups);
                obj.stimRoiGroupNameListeners = [l{:}];
                
                if most.idioms.isValidObj(obj.photostimPattern)
                    % make sure the selected photostim pattern still exists
                    % if not reset selection
                    i = find([obj.hModel.hPhotostim.stimRoiGroups.uuiduint64] == obj.photostimPattern.uuiduint64,1);
                    if isempty(i)
                        i = 1;
                        
                        if isempty(obj.videoStreamSourceChan)
                            % only actually load the pattern if we are in
                            % photostim mode
                            obj.photostimPattern = obj.hModel.hPhotostim.stimRoiGroups(1);
                        else
                            obj.photostimPattern = [];
                        end
                    end
                    
                    obj.pmPhotostimPattern.Value = i;
                else
                    % there was previously not a photostim pattern selected
                    % reset selection to 1
                    obj.pmPhotostimPattern.Value = 1;
                    
                    if isempty(obj.videoStreamSourceChan)
                        % only actually load the pattern if we are in
                        % photostim mode
                        obj.photostimPattern = obj.hModel.hPhotostim.stimRoiGroups(1);
                    end
                end
            end
        end
        
        function changedAlignmentPause(obj,~,~)
            if obj.hModel.hAlignment.pauseVideo
                set(obj.hGUIData.alignmentControlsV5.pbPause,'String','Resume Video');
            else
                set(obj.hGUIData.alignmentControlsV5.pbPause,'String','Pause Video');
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAlignmentAx);
            most.idioms.safeDeleteObj(obj.hMainContextMenu);
            most.idioms.safeDeleteObj(obj.hControlPoints);
            most.idioms.safeDeleteObj(obj.hControlPointMenus);
            most.idioms.safeDeleteObj(obj.hPathMenus);
            most.idioms.safeDeleteObj(obj.hStimPth);
            most.idioms.safeDeleteObj(obj.hAlignmentFig);
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hStimGroupListener);
            most.idioms.safeDeleteObj(obj.stimRoiGroupNameListeners);
        end
    end
    
    %% PROP ACCESS
    methods
        function set.showWindow(obj,val)
            val = obj.validatePropArg('showWindow',val); %allow during acq
            obj.showWindow = val;
            if val
                set(obj.hAlignmentFig,'Visible','on');
            else
                set(obj.hAlignmentFig,'Visible','off');
            end           
        end
        
        function val = get.referenceLUTRange(obj)
            %Static 16 bit reference LUT Range.
            n = 16;
            val = int16([(-2^(n-1)) 2^(n-1)-1]);
        end
        
        function set.referenceLUT(obj,val)
            val = obj.validatePropArg('referenceLUT',val);
            val = obj.zprvCoerceLutToRange(val);
            obj.referenceLUT = val;
            if ~isempty(obj.referenceData)
                obj.referenceData.LUT = obj.referenceLUT;
            end
            obj.refDirty = true;
            obj.updateFigureImage();
        end
        
        function set.videoStreamAlpha(obj, val)          
            val = obj.validatePropArg('videoStreamAlpha',val);

            if ~isnumeric(val) || isnan(val) || (val < 0) || (val > 1)

                if ~isempty(obj.etAlpha.String) && ~isempty(strtrim(obj.etAlpha.String))
                    most.idioms.warn('The Alpha value must be between 0.0 and 1.0, inclusive. Reseting Alpha to last setting.');
                end
                
                if ~isempty(obj.videoStreamAlpha)
                    val = obj.videoStreamAlpha;
                else
                    val = 0.5;
                end
            end
            
            obj.videoStreamAlpha = val;
            set(obj.hVidIm,'FaceAlpha',obj.videoStreamAlpha);
        end
        
        function set.vidOffsetX(obj, val)
            
            if ~isnumeric(val) || isnan(val) || isinf(val)

                if ~isempty(obj.etOffsetX.String) && ~isempty(strtrim(obj.etOffsetX.String))
                    most.idioms.warn('The Offset X value must be a numeric value other than NaN and Inf. Reseting Offset X to last setting.');
                end
                
                if ~isempty(obj.vidOffsetX)
                    val = obj.vidOffsetX;
                else
                    val = 0;
                end
            end
            
            val = obj.validatePropArg('vidOffsetX',val);
            obj.generateRefTransformFromGeometryProps('offsetX',val);
        end
        
        function val = get.vidOffsetX(obj)
            val = obj.geometryProps.offsetX;
        end
        
        function set.vidOffsetY(obj, val)

            if ~isnumeric(val) || isnan(val) || isinf(val)
                if ~isempty(obj.etOffsetY.String) && ~isempty(strtrim(obj.etOffsetY.String))
                    most.idioms.warn('The Offset Y value must be a numeric value other than NaN and Inf. Reseting Offset Y to last setting.');
                end
                
                if ~isempty(obj.vidOffsetY)
                    val = obj.vidOffsetY;
                else
                    val = 0;
                end
            end
            
            val = obj.validatePropArg('vidOffsetY',val);
            obj.generateRefTransformFromGeometryProps('offsetY',val);
        end
        
        function val = get.vidOffsetY(obj)
            val = obj.geometryProps.offsetY;
        end
        
        function set.vidScaleX(obj, val)

            if ~isnumeric(val) || isnan(val) || isinf(val) || (val == 0)
                
                if ~isempty(obj.etScaleX.String) && ~isempty(strtrim(obj.etScaleX.String))
                    most.idioms.warn('The Scale X value must be a numeric value other than NaN, Inf and 0. Reseting Scale X to last setting.');
                end
                
                if ~isempty(obj.vidScaleX)
                    val = obj.vidScaleX;
                else
                    val = 1;
                end
            end
            
            val = obj.validatePropArg('vidScaleX',val);
            obj.generateRefTransformFromGeometryProps('scaleX',val);
        end
        
        function val = get.vidScaleX(obj)
            val = obj.geometryProps.scaleX;
        end
        
        function set.vidScaleY(obj, val)

            if ~isnumeric(val) || isnan(val) || isinf(val) || (val == 0)

                if ~isempty(obj.etScaleY.String) && ~isempty(strtrim(obj.etScaleY.String))
                    most.idioms.warn('The Scale Y value must be a numeric value other than NaN, Inf and 0. Reseting Scale Y to last setting.');
                end
                
                if ~isempty(obj.vidScaleY)
                    val = obj.vidScaleY;
                else
                    val = 1;
                end
            end
            
            val = obj.validatePropArg('vidScaleY',val);
            obj.generateRefTransformFromGeometryProps('scaleY',val);
        end
        
        function val = get.vidScaleY(obj)
            val = obj.geometryProps.scaleY;
        end
        
        function set.vidRotation(obj, val)

            if ~isnumeric(val) || isnan(val) || isinf(val)
                
                if ~isempty(obj.etRotation.String) && ~isempty(strtrim(obj.etRotation.String))
                    most.idioms.warn('The Rotation value must be a numeric value other than NaN and Inf. Reseting Rotation to last setting.');
                end
                
                if ~isempty(obj.vidRotation)
                    val = obj.vidRotation;
                else
                    val = 0;
                end
            end
            
            val = obj.validatePropArg('vidRotation',val);
            obj.generateRefTransformFromGeometryProps('rotation',val);
        end
        
        function val = get.vidRotation(obj)
            val = obj.geometryProps.rotation;
        end
        
        function set.vidShear(obj,val)

            if ~isnumeric(val) || isnan(val) || isinf(val)
                
                if ~isempty(obj.etShear.String) && ~isempty(strtrim(obj.etShear.String))
                    most.idioms.warn('The Shear value must be a numeric value other than NaN and Inf. Reseting Shear to last setting.');
                end
                
                if ~isempty(obj.vidShear)
                    val = obj.vidShear;
                else
                    val = 0;
                end
            end
            
            val = obj.validatePropArg('vidShear',val);
            obj.generateRefTransformFromGeometryProps('shear',val);
        end
        
        function val = get.vidShear(obj)
            val = obj.geometryProps.shear;
        end
        
        function set.videoImToRefImTransform(obj,val)
            obj.videoImToRefImTransform = val;
            [offsetX,offsetY,scaleX,scaleY,rotation,shear] = scanimage.mroi.util.paramsFromTransform(obj.videoImToRefImTransform);
            
            obj.geometryProps.offsetX = offsetX;
            obj.geometryProps.offsetY = offsetY;
            obj.geometryProps.scaleX = scaleX;
            obj.geometryProps.scaleY = scaleY;
            obj.geometryProps.rotation = rotation;
            obj.geometryProps.shear = shear;
            
            obj.updateGeometryPropGui();
            obj.updateReferenceSurfs();
        end
        
        function set.referenceImageColor(obj, val)
            val = obj.validatePropArg('referenceImageColor',val);
            obj.referenceImageColor = val;
            obj.refDirty = true;
            obj.updateFigureImage();
        end
        
        function set.videoStreamColor(obj, val)
            val = obj.validatePropArg('videoStreamColor',val);
            obj.videoStreamColor = val;
            obj.vidDirty = true;
            obj.updateFigureImage();
        end
        
        function set.alignmentSource(obj,v)
            obj.videoData = struct('roiDat',{[]});
            obj.videoStreamSourceChan = [];
            obj.photostimPattern = [];
            obj.testPattern = [];
            
            if ~isempty(obj.hModel.hCameraManager) && ...
                    ~isempty(obj.hModel.hCameraManager.hCameraWrappers)
                cameraNames = cellfun(@(cam)cam.cameraName, obj.hModel.hCameraManager.hCameras, ...
                    'UniformOutput', false);
            else
                cameraNames = {};
            end
            
            if strcmp(v,'Photostimulation')                
                obj.pbPause.Visible = 'off';
                obj.pmVidColor.Visible = 'off';
                obj.stColor.Visible = 'off';
                obj.stPattern.Visible = 'on';
                obj.pmPhotostimPattern.Visible = 'on';
                
                set(obj.hVidIm, 'Visible','off');
                set(obj.hVidImOutline, 'Visible','off');
                set(obj.hControlPoints, 'Visible','off');
                set(obj.hStimPth, 'Visible','on');
                
                if isempty(obj.photostimPattern) && ~isempty(obj.hModel.hPhotostim.stimRoiGroups)
                    obj.photostimPattern = obj.hModel.hPhotostim.stimRoiGroups(1);
                end
                
                obj.hMainContextMenuAEs.Enable = 'off';
                obj.hMainContextMenuAFx.Enable = 'off';
                obj.hMainContextMenuAFr.Enable = 'off';
                
            elseif any(strcmp(v, cameraNames))
                % Do camera specific stuff
                obj.videoStreamSourceChan = obj.hModel.hCameraManager.hCameraWrappers(...
                    strcmp(v, cameraNames));
                obj.pmVidColor.Visible = 'on';
                obj.stColor.Visible = 'on';
                obj.stPattern.Visible = 'off';
                obj.pmPhotostimPattern.Visible = 'off';
                
                obj.vidDirty = true;
                obj.updateFigureImage();
                set(obj.hControlPoints, 'Visible','on');
                set(obj.hStimPth, 'Visible','off');
                
                obj.hMainContextMenuAEs.Enable = 'on';
                obj.hMainContextMenuAFx.Enable = 'on';
                obj.hMainContextMenuAFr.Enable = 'on';
            else
                ch = str2double(regexpi(v,'(?<=^Channel\s)[0-9]*$','match','once'));
                if ~isempty(ch) && ~isnan(ch)
                    assert(ch <= obj.hModel.hChannels.channelsAvailable, 'Invalid alignment source video channel selection.')
                    obj.videoStreamSourceChan = ch;
                    
                    obj.pbPause.Visible = 'on';
                elseif strcmpi(v,'SLM Test Pattern')
                    obj.testPattern = obj.hModel.hSlmScan.testPattern;

                    obj.pbPause.Visible = 'off';
                else
                    assert(false);
                end
                
                obj.pmVidColor.Visible = 'on';
                obj.stColor.Visible = 'on';
                obj.stPattern.Visible = 'off';
                obj.pmPhotostimPattern.Visible = 'off';
                
                obj.vidDirty = true;
                obj.updateFigureImage();
                set(obj.hControlPoints, 'Visible','on');
                set(obj.hStimPth, 'Visible','off');
                
                obj.hMainContextMenuAEs.Enable = 'on';
                obj.hMainContextMenuAFx.Enable = 'on';
                obj.hMainContextMenuAFr.Enable = 'on';
            end
            obj.alignmentSource = v;
        end
        
        function set.photostimPattern(obj,v)
            most.idioms.safeDeleteObj(obj.hStimGroupListener);
            obj.photostimPattern = v;
            if isempty(v)
                obj.clearPhotostimPath();
            else
                obj.hStimGroupListener = most.util.DelayedEventListener(0.5,v,'changed',@obj.loadPhotostimPath);
                obj.loadPhotostimPath();
            end
        end
        
        function set.viewFov(obj,v)
            obj.viewFov = min(v,obj.maxViewFov);
            obj.viewPos = obj.viewPos;
        end
        
        function set.viewPos(obj,v)
            obj.viewPos = sign(v) .* min(abs(v),obj.maxViewFov-obj.viewFov);
            obj.alignmentWindowSize();
        end
    end
    
    %% USER METHODS
    methods
        function createAlignmentRoi(obj, varargin)
            % see if any transforms are not default. Also get default roi
            % sizes and smallest fill fraction
            v = false;
            for hScanner = obj.hModel.hScanners
                val = hScanner{1}.scannerToRefTransform ~= eye(3);
                v = v || any(val(:));
            end
            
            if v
                sel = questdlg('This will enable multiple-ROI imaging and replace your current ROIs with an alignment ROI that can be imaged by all scanners. It is recommended to reset alignment data before performing scanner alignment. Reset now?',...
                    'ScanImage', 'Reset and Continue', 'Continue Without Reset', 'Cancel', 'Cancel');
                switch sel,
                    case 'Reset and Continue',
                        obj.hModel.hRoiManager.resetTransforms();
                    case 'Cancel',
                        return;
                end
            else
                if strcmp(questdlg('This will enable multiple-ROI imaging and replace your current ROIs with an alignment ROI that can be imaged by all scanners.',...
                        'ScanImage', 'Continue', 'Cancel', 'Cancel'),'Cancel')
                    return;
                end
            end
            
            obj.hModel.hRoiManager.roiGroupMroi.clear();
            
            rg = scanimage.mroi.RoiGroup;
            rg.add(scanimage.mroi.Roi);
            rg.rois(1).add(0,scanimage.mroi.scanfield.fields.RotatedRectangle);
            
            rg.rois(1).scanfields(1).pixelResolutionXY = [obj.hModel.hRoiManager.pixelsPerLine obj.hModel.hRoiManager.linesPerFrame];
            
            ff = obj.hModel.hScanners{1}.fillFractionSpatial;
            sz = obj.hModel.hScanners{1}.defaultRoiSize * ff;
            for hScanner = obj.hModel.hScanners(2:end)
                ff = hScanner{1}.fillFractionSpatial;
                sz = min([sz obj.hModel.hScanners{1}.defaultRoiSize*ff]);
            end
            
            rg.rois(1).scanfields(1).sizeXY = [sz sz];
            
            obj.hModel.hRoiManager.roiGroupMroi = rg;
            obj.hModel.hRoiManager.mroiEnable = true;
        end
        
        function generateRefTransformFromGeometryProps(obj,param,val)
            gP = obj.geometryProps;
            gP.(param) = val;
            
            T = scanimage.mroi.util.paramsToTransform(gP.offsetX,gP.offsetY,gP.scaleX,gP.scaleY,gP.rotation,gP.shear);
            obj.videoImToRefImTransform = T;
        end
        
        function resetTransforms(obj,varargin)
            if strcmp(questdlg('This will reset scanner alignment to the default state that assumes perfect alignment between all scanners.',...
                    'ScanImage','Reset','Cancel','Cancel'), 'Reset')
                obj.hModel.hRoiManager.resetTransforms();
                obj.hModel.hCameraManager.resetTransforms();
            end
        end
        
        function guiSaveScannerTransform(obj,varargin)
            try
                if strcmp(questdlg('This will overwrite the alignment data for the current imaging system. Continue?',...
                        'ScanImage','Continue','Cancel','Cancel'), 'Continue')
                    obj.saveScannerTransform();
                end
            catch ME
                warndlg(ME.message,'Generate Transforms');
                most.idioms.warn(ME.message);
            end
        end
        
        function saveScannerTransform(obj)
            if ~isempty(obj.testPattern)
                assert(~isempty(obj.videoData), 'Cannot generate transforms. Video stream is empty.');
                assert(isfield(obj.videoData, 'scanner') && ~isempty(obj.videoData.scanner) && obj.hModel.hScannerMap.isKey(obj.videoData.scanner), 'Not enough information to compute transforms. Video stream was collected from unknown scanner.');
                hTargetScanner = obj.hModel.hScanner(obj.videoData.scanner);
                origXform = obj.videoData.scannerToRefTransform;
                targetProperty = 'testPatternPixelToRefTransform';
            elseif isempty(obj.videoStreamSourceChan)
                assert(~isempty(obj.photostimPattern), 'Cannot generate transforms. Photostim pattern is empty.');
                hTargetScanner = obj.hModel.hPhotostim.hScan;
                origXform = hTargetScanner.scannerToRefTransform;
                targetProperty = 'scannerToRefTransform';
            elseif isa(obj.videoStreamSourceChan, ...
                    'scanimage.components.cameramanager.CameraWrapper')
                hTargetScanner = obj.videoStreamSourceChan;
                targetProperty = 'cameraToRefTransform';
                origXform = obj.videoData.origTransform;
            else
                assert(~isempty(obj.videoData), 'Cannot generate transforms. Video stream is empty.');
                assert(isfield(obj.videoData, 'scanner') && ~isempty(obj.videoData.scanner) && obj.hModel.hScannerMap.isKey(obj.videoData.scanner), 'Not enough information to compute transforms. Video stream was collected from unknown scanner.');
                hTargetScanner = obj.hModel.hScanner(obj.videoData.scanner);
                origXform = obj.videoData.scannerToRefTransform;
                targetProperty = 'scannerToRefTransform';
            end
             
            scannerToRefTransform = obj.videoImToRefImTransform * origXform;
            hTargetScanner.(targetProperty) = scannerToRefTransform;
        end
        
        function copyChannel(obj,channel)
            z = obj.hModel.hDisplay.displayZs;
            assert(numel(z) == 1, 'Reference must be single plane.');
            if ~isempty(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData)
                [tf, index] = ismember(channel, obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.channels);
                if tf
                    obj.referenceData.scanner = obj.hModel.imagingSystem;
                    
                    aveF = 1/obj.hModel.hDisplay.displayRollingAverageFactor;
                    
                    Nroi = numel(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData);
                    obj.referenceData.roiDat(Nroi+1:end) = [];
                    for i = Nroi:-1:1
                        rd = obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{i};
                        roi = rd.hRoi;
                        sf = roi.get(z);
                        
                        [surfMeshXX,surfMeshYY] = sf.meshgridOutline(10);
                        % surf is rotated to avoid transpose later
                        obj.referenceData.roiDat(i).surfMeshXX = surfMeshXX';
                        obj.referenceData.roiDat(i).surfMeshYY = surfMeshYY';
                        obj.referenceData.roiDat(i).pixelToRefTransform = sf.pixelToRefTransform();
                        obj.referenceData.roiDat(i).displayData = rd.imageData{index}{1} * aveF;
                        obj.referenceData.roiDat(i).cornerPts = sf.cornerpoints();
                    end
                    
                    obj.refDirty = true;
                    obj.referenceData.LUT = obj.hModel.hDisplay.(['chan' num2str(channel) 'LUT']);
                    obj.referenceLUT = obj.referenceData.LUT;
                else
                    most.mimics.warning('Channel %d is not set to display in Channels Dialog. Set channel display on to copy.',channel);
                end
            else
                most.mimics.warning('There is no image data to copy. Try focusing or grabbing first.');
            end
        end
        
        function estimateTransform(obj)
             assert(~isempty(obj.videoStreamSourceChan));
             assert(~isempty(obj.videoData), 'Cannot generate transforms. Video stream is empty.');     
     
             ref = obj.referenceData.roiDat(1).displayData';
             refT = obj.referenceData.roiDat(1).pixelToRefTransform;
             vid = obj.videoData.roiDat(1).displayData';
             vidT = obj.videoData.roiDat(1).pixelToRefTransform;
             
             ref = normalizeImage(ref);
             vid = normalizeImage(vid);
             
             nn_match_ratio = 0.8;
             ransacReprojThreshold = 2.5;
             
             try
                [estimatedT,nPoints]= scanimage.mroi.util.openCV.akazeImageRegistration(vid,ref,nn_match_ratio,ransacReprojThreshold,false);
             catch ME
                 msgbox(ME.message, 'Error','error');
                 rethrow(ME);
             end
             
             if nPoints < 50
                msgbox('No match found.', 'Error','error');
                error('No match found');
             end
                          
             %estimatedT = scanimage.mroi.util.openCV.findAffine(vid,ref,single(estimatedT));
             
             %%%%
             % in OpenCV pixel coordinates start at 0, in Matlab we use 1
             % compensate here
             % TODO: move into akazeImageRegistration
             O = eye(3);
             O([7,8]) = 1;
             estimatedT = O * estimatedT * inv(O); %#ok<MINV>
             %%%%
             
             obj.videoImToRefImTransform = double((refT*estimatedT)/vidT);
             
            function im = normalizeImage(im) 
                im = single(im);
                im = im - mean(im(:));
                im = im ./ std(im(:));
                im = im * 100;
            end
        end
        
        function loadReference(obj)
            [filename,pathname] = uigetfile('.mat','Choose file to load reference image',obj.getClassDataVar('lastReferenceFile'));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            obj.setClassDataVar('lastReferenceFile',filename);

            data = load(filename,'-mat','lclReferenceData');
            obj.referenceData = data.lclReferenceData;
            obj.referenceLUT = obj.referenceData.LUT;
            
            obj.refDirty = true;
            obj.updateFigureImage();
        end
        
        function saveReference(obj)
            [filename,pathname] = uiputfile('.mat','Choose filename to save reference image',obj.getClassDataVar('lastReferenceFile'));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            obj.setClassDataVar('lastReferenceFile',filename);
            
            lclReferenceData = obj.referenceData;
            save(filename,'lclReferenceData','-mat');
        end
        
        function resetView(obj)
            obj.viewFov = obj.maxViewFov;
        end
        
        function addControlPoint(obj, fixed)            
            vidPt = obj.getPtAlignmentAxes();
            refPt = scanimage.mroi.util.xformPoints(vidPt,inv(obj.videoImToRefImTransform));
            
            f = false;
            for rd = obj.videoData.roiDat
                cps = rd.cornerPts;
                f = (refPt(1) >= min(cps(:,1))) && (refPt(1) <= max(cps(:,1))) && (refPt(2) > min(cps(:,2))) && (refPt(2) <= max(cps(:,2)));
                if f
                    break
                end
            end
            %refPt = obj.videoImToRefImTransform \ [vidPt 1]';
            %refPt = [refPt(1) refPt(2)];
            
            if ~f
                warndlg('Control point must exist within bounds of video image.','Warning','modal');
                error('Control point must exist within bounds of video image.');
            end
            
            
            obj.hControlPointMenus(end+1) = uicontextmenu('Parent',obj.hAlignmentFig);
            idx = numel(obj.hControlPointMenus);
            
            markerEdgeColor = [1 0 1]; % magenta
            markerFaceColor = 'none';%markerEdgeColor * 0.8;
            
            obj.hControlPoints(idx) = line('XData',vidPt(1),'YData',vidPt(2),'ZData',10,'Parent',obj.hAlignmentAx,'LineStyle','none','Marker','o','MarkerEdgeColor',markerEdgeColor,'MarkerFaceColor',markerFaceColor,'Markersize',10,'LineWidth',1.5,'UIContextMenu',obj.hControlPointMenus(idx));
            obj.controlPointPositions{idx} = refPt;
            obj.controlPointFixed(idx) = false;
            
            hCP = obj.hControlPoints(idx);
            set(hCP,'ButtonDownFcn',@(varargin)obj.cpFunc(hCP,true));
            uimenu('Parent',obj.hControlPointMenus(end),'Label','Fix Control Point','Callback',@(src,evt)obj.toggleControlPointFixState(hCP));
            uimenu('Parent',obj.hControlPointMenus(end),'Label','Remove Control Point','Callback',@(src,evt)obj.clearControlPoint(hCP));
            
            if nargin > 1 && fixed
                obj.toggleControlPointFixState(hCP);
            end
        end
        
        function toggleControlPointFixState(obj, hdl)
            idx = find(obj.hControlPoints == hdl);
            isStim = isempty(idx);
            if isStim
                idx = find(obj.hStimPth == hdl);
                ptsFxd = obj.pathPointFixed;
                assert(numel(idx) == 1, 'Error finding control point index.');
                assert(idx > 0 && numel(obj.hStimPth) >= idx, 'Invalid control point index.');
            else
                ptsFxd = obj.controlPointFixed;
                assert(numel(idx) == 1, 'Error finding control point index.');
                assert(idx > 0 && numel(obj.hControlPoints) >= idx, 'Invalid control point index.');
            end
            
            if ptsFxd(idx)
                ptsFxd(idx) = false;
                mkr = 'o';
                ch = 'off';
                c = [1 0 1];
            else
                if sum(ptsFxd) >= 4
                    warndlg('Only four control points can be fixed.','Warning','modal');
                    error('Only four control points can be fixed.');
                end
                ptsFxd(idx) = true;
                mkr = 's';
                ch = 'on';
                c = [1 0 0];
            end
            
            if isStim
                obj.pathPointFixed = ptsFxd;
                set(obj.hStimPth(idx),'Color',c);
                set(findall(hdl.UIContextMenu,'Label','Fix Stimulus Position'),'Checked',ch);
            else
                obj.controlPointFixed = ptsFxd;
                set(obj.hControlPoints(idx), 'marker', mkr);
                set(findall(obj.hControlPointMenus(idx),'Label','Fix Control Point'),'Checked',ch);
            end
        end
        
        function clearControlPoint(obj, hdl)
            idx = find(obj.hControlPoints == hdl);
            assert(numel(idx) == 1, 'Error finding control point index.');
            assert(idx > 0 && numel(obj.hControlPoints) >= idx, 'Invalid control point index.');
            
            most.idioms.safeDeleteObj(obj.hControlPoints(idx));
            most.idioms.safeDeleteObj(obj.hControlPointMenus(idx));
            obj.hControlPoints(idx) = [];
            obj.hControlPointMenus(idx) = [];
            obj.controlPointPositions(idx) = [];
            obj.controlPointFixed(idx) = [];
        end
        
        function clearAllControlPoints(obj)
            if isempty(obj.videoStreamSourceChan)
                obj.pathPointFixed(:) = false;
                set(obj.hStimPth,'Color',[1 0 1]);
                arrayfun(@(h)set(findall(h.UIContextMenu,'Label','Fix Stimulus Position'),'Checked',false),obj.hStimPth);
            end
            
            most.idioms.safeDeleteObj(obj.hControlPoints);
            obj.hControlPoints = [];
            obj.hControlPointMenus = [];
            obj.controlPointPositions = {};
            obj.controlPointFixed = [];
        end
        
        function resetVideoTransform(obj)
            obj.videoImToRefImTransform = eye(3);
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function updateReferenceSurfs(obj)
            % update the surfs here?
            obj.vidDirty = true;
            obj.updateFigureImage();
            obj.updateCPs();
        end
        
        function updateGeometryPropGui(obj)
            obj.etOffsetX.model2view();
            obj.etOffsetY.model2view();
            obj.etScaleX.model2view();
            obj.etScaleY.model2view();
            obj.etRotation.model2view();
            obj.etShear.model2view();
        end
        
        function frameAcquired(obj, varargin)
            if ~isempty(obj.videoStreamSourceChan)
                obj.updateVideoStream();
                obj.updateFigureImage();
            end
        end
        
        function updateVideoStream(obj)
            z = obj.hModel.hStackManager.zs;
            if obj.showWindow && ~obj.pauseVideo && ~isempty(obj.videoStreamSourceChan) && (numel(z) == 1)
                if isa(obj.videoStreamSourceChan,...
                        'scanimage.components.cameramanager.CameraWrapper')
                    % Use Camera as video stream source.
                    camWrap = obj.videoStreamSourceChan;
                    
                    lastFrame = camWrap.lastFrame;
                    if isempty(lastFrame)
                        return
                    end
                    
                    [xx, yy] = camWrap.getRefMeshgrid();
                    obj.videoData.roiDat(1).surfMeshXX = xx;
                    obj.videoData.roiDat(1).surfMeshYY = yy;
                    obj.videoData.roiDat(1).displayData = lastFrame;
                    obj.videoData.roiDat(1).cornerPts = [xx(:) yy(:)];
                    obj.videoData.roiDat(1).pixelToRefTransform = camWrap.pixelToRefTransform;
                    obj.videoData.channel = [];
                    obj.videoData.origTransform = camWrap.cameraToRefTransform;
                    obj.vidDirty = true;
                else
                    if ~isempty(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData)
                        [tf, index] = ismember(obj.videoStreamSourceChan, obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.channels);
                        obj.videoData.scanner = obj.hModel.imagingSystem;
                        obj.videoData.scannerToRefTransform = obj.hModel.hScan2D.scannerToRefTransform;
                        obj.videoData.channel = obj.videoStreamSourceChan;

                        aveF = 1/obj.hModel.hDisplay.displayRollingAverageFactor;

                        Nroi = numel(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData);
                        obj.videoData.roiDat(Nroi+1:end) = [];
                        for i = Nroi:-1:1
                            rd = obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{i};
                            roi = rd.hRoi;
                            sf = roi.get(z);

                            obj.videoData.roiDat(i).cornerPts = sf.cornerpoints();
                            [surfMeshXXVid,surfMeshYYVid] = sf.meshgridOutline(10);
                            % surf is rotated to avoid transpose later
                            obj.videoData.roiDat(i).surfMeshXX = surfMeshXXVid';
                            obj.videoData.roiDat(i).surfMeshYY = surfMeshYYVid';
                            obj.videoData.roiDat(i).pixelToRefTransform = sf.pixelToRefTransform();
                            if tf
                                obj.videoData.roiDat(i).displayData = rd.imageData{index}{1} * aveF;
                            else
                                obj.videoData.roiDat(i).displayData = [];
                            end
                        end


                        if ~isempty(obj.referenceData) && ~isempty(obj.referenceData.roiDat) && ~isempty(obj.referenceData.roiDat(1))
                            ptsVid = scanimage.mroi.util.xformPoints(obj.videoData.roiDat(1).cornerPts,obj.videoImToRefImTransform);
                            d1Vid = norm(ptsVid(1,:)-ptsVid(3,:));
                            d2Vid = norm(ptsVid(2,:)-ptsVid(4,:));
                            dVid = max(d1Vid,d2Vid);
                            ctrVid = (ptsVid(1,:)+ptsVid(3,:))/2;


                            ptsRef = obj.referenceData.roiDat(1).cornerPts;
                            d1Ref = norm(ptsRef(1,:)-ptsRef(3,:));
                            d2Ref = norm(ptsRef(2,:)-ptsRef(4,:));
                            dRef = max(d1Ref,d2Ref);
                            ctrRef = (ptsRef(1,:)+ptsRef(3,:))/2;

                            if dVid < dRef/70
                                T = eye(3);
                                T([1,5]) = dRef/dVid/2;
                                %T([7,8]) = ctrRef - ctrVid;
                                obj.videoImToRefImTransform = obj.videoImToRefImTransform*T;
                            end
                        end                    

                        obj.vidDirty = true;
                    end
                end
            end
        end
        
        function updateFigureImage(obj, force)
            if nargin > 1 && ~isempty(force)
                obj.refDirty = force;
                obj.vidDirty = force;
            end
            
            if obj.showWindow
                if obj.vidDirty
                    if isempty(obj.videoStreamSourceChan)
                        if ~isempty(obj.hStimPth)
                            path = scanimage.mroi.util.xformPoints(obj.scanPathCache.G,obj.videoImToRefImTransform);
                            for i = 1:numel(obj.hStimPth)
                                hL = obj.hStimPth(i);
                                s = obj.scanPathCacheIds(i,1);
                                e = obj.scanPathCacheIds(i,2);
                                
                                hL.XData = path(s:e,1);
                                hL.YData = path(s:e,2);
                                hL.ZData = hL.ZData(1) * ones(1,e-s+1);
                            end
                        elseif ~isempty(obj.testPattern)
                            obj.videoData = struct();
                            
                            obj.videoData.scanner = obj.hModel.hSlmScan.name;
                            obj.videoData.scannerToRefTransform = eye(3);
                            obj.videoData.channel = [];
                            xres = size(obj.testPattern,2);
                            yres = size(obj.testPattern,1);
                            
                            cornerpoints = [0.5,      0.5;...
                                            xres+0.5, 0.5;...
                                            xres+0.5, yres+0.5;...
                                            0.5,      yres+0.5];
                                        
                            % transpose video data to be consistent
                            obj.videoData.roiDat(1).displayData = obj.testPattern';
                            obj.videoData.roiDat(1).cornerPts = cornerpoints;
                            
                            % surf outline (consistent with cornerpoints)
                            [surfMeshXX,surfMeshYY] = meshgrid(linspace(0.5,xres+0.5,10),linspace(0.5,yres+0.5,10));
                            % surf is rotated to avoid transpose later
                            obj.videoData.roiDat(1).surfMeshXX = surfMeshXX';
                            obj.videoData.roiDat(1).surfMeshYY = surfMeshYY';
                            
                            obj.videoData.roiDat(1).pixelToRefTransform = eye(3);
                        end
                    end
                    
                    if ~isempty(obj.videoData)
                        Nroi = numel(obj.videoData.roiDat);
                        set(obj.hVidIm(Nroi+1:end), 'Visible','off');
                        set(obj.hVidImOutline(Nroi+1:end), 'Visible','off');
                        
                        for i = 1:Nroi
                            if numel(obj.hVidIm) < i
                                obj.hVidIm(i) = surface(ones(2),ones(2),ones(2),'Parent',obj.hAlignmentAx,'Hittest','off',...
                                    'FaceColor','texturemap','EdgeColor','none','FaceLighting','none','FaceAlpha',obj.videoStreamAlpha);
                                
                                obj.hVidImOutline(i) = line(NaN,NaN,NaN,'Parent',obj.hAlignmentAx,'Hittest','off',...
                                    'Color','b');
                            end
                            
                            % surf is rotated to avoid transpose later
                            [surfMeshXX,surfMeshYY] = scanimage.mroi.util.xformMesh(obj.videoData.roiDat(i).surfMeshXX,obj.videoData.roiDat(i).surfMeshYY,obj.videoImToRefImTransform);
                            obj.hVidIm(i).XData = surfMeshXX;
                            obj.hVidIm(i).YData = surfMeshYY;
                            obj.hVidIm(i).ZData = ones(size(surfMeshXX));
                            
                            obj.hVidImOutline(i).XData = meshToOutline(surfMeshXX);
                            obj.hVidImOutline(i).YData = meshToOutline(surfMeshYY);
                            obj.hVidImOutline(i).ZData = ones(5,1);
                            
                            cdata = obj.videoData.roiDat(i).displayData;
                            if isa(obj.videoStreamSourceChan,...
                                    'scanimage.components.cameramanager.CameraWrapper')
                                cdata = scaleAndColorData(cdata, ...
                                    obj.videoStreamColor, obj.videoStreamSourceChan.lut);
                            elseif isempty(obj.videoData.channel)
                                % use Channel 1 LUT slider for SLM test pattern
                                cdata = scaleAndColorData(cdata,obj.videoStreamColor,obj.hModel.hDisplay.chan1LUT);
                            elseif obj.videoData.channel == obj.videoStreamSourceChan && ...
                                    ~isempty(cdata)
                                propname = ['chan' num2str(obj.videoStreamSourceChan) 'LUT'];
                                lut = obj.hModel.hDisplay.(propname);
                                cdata = scaleAndColorData(cdata,obj.videoStreamColor,lut);
                            else
                                cdata = nan;
                            end
                            obj.hVidIm(i).CData = cdata;
                        end
                        
                        set(obj.hVidIm(1:Nroi), 'Visible','on');
                        set(obj.hVidImOutline(1:Nroi), 'Visible','on');
                    end
                end
                
                if obj.refDirty && ~isempty(obj.referenceData)
                    Nroi = numel(obj.referenceData.roiDat);
                    set(obj.hRefIm(Nroi+1:end), 'Visible','off');
                    set(obj.hRefImOutline(Nroi+1:end), 'Visible','off');
                    
                    for i = 1:Nroi
                        if numel(obj.hRefIm) < i
                            obj.hRefIm(i) = surface(ones(2),ones(2),zeros(2),'Parent',obj.hAlignmentAx,'Hittest','off',...
                                'FaceColor','texturemap','EdgeColor','none','FaceLighting','none','FaceAlpha',1);
                            obj.hRefImOutline(i) = line(NaN,NaN,NaN,'Parent',obj.hAlignmentAx,'Hittest','off',...
                                'Color',[0 0 .5]);
                        end
                        
                        obj.hRefIm(i).XData = obj.referenceData.roiDat(i).surfMeshXX;
                        obj.hRefIm(i).YData = obj.referenceData.roiDat(i).surfMeshYY;
                        obj.hRefIm(i).ZData = zeros(size(obj.referenceData.roiDat(i).surfMeshYY));
                        
                        obj.hRefImOutline(i).XData = meshToOutline(obj.referenceData.roiDat(i).surfMeshXX);
                        obj.hRefImOutline(i).YData = meshToOutline(obj.referenceData.roiDat(i).surfMeshYY);
                        obj.hRefImOutline(i).ZData = zeros(5,1);
                        
                        cdata = scaleAndColorData(obj.referenceData.roiDat(i).displayData,obj.referenceImageColor,obj.referenceLUT);
                        obj.hRefIm(i).CData = cdata;
                    end
                    
                    set(obj.hRefIm(1:Nroi), 'Visible','on');
                    set(obj.hRefImOutline(1:Nroi), 'Visible','on');
                end
                
                obj.refDirty = false;
                obj.vidDirty = false;
            end
        
            function scaledColoredData = scaleAndColorData(data,clr,lut)
                lut = single(lut);
                maxVal = single(255);
                scaledData = uint8((single(data) - lut(1)) .* (maxVal / (lut(2)-lut(1))));
                
                switch lower(clr)
                    case 'red'
                        scaledColoredData = zeros([size(scaledData) 3],'uint8');
                        scaledColoredData(:,:,1) = scaledData;
                    case 'green'
                        scaledColoredData = zeros([size(scaledData) 3],'uint8');
                        scaledColoredData(:,:,2) = scaledData;
                    case 'blue'
                        scaledColoredData = zeros([size(scaledData) 2],'uint8');
                        scaledColoredData(:,:,3) = scaledData;
                    case 'gray'
                        scaledColoredData(:,:,:) = repmat(scaledData,[1 1 3]);
                    case 'none'
                        scaledColoredData = zeros([size(scaledData) 3]);
                    otherwise
                        assert(false);
                end
            end
        end
        
        function val = zprvCoerceLutToRange(obj,val)
            val = cast(val,'int16');
            rangeMax = obj.referenceLUTRange(2);
            rangeMin = obj.referenceLUTRange(1);
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
        
        % Alignment Methods
        function resetAlignmentFig(obj,show)
            if nargin < 2 || isempty(show)
                show = true;
            end
            
            if ~most.idioms.isValidObj(obj.hAlignmentFig)
                %Create the figures first.
                obj.hAlignmentFig = most.idioms.figureSquare('Name','Optical Alignment','Visible','off','NumberTitle','off','Menubar','none','Tag','alignment',...
                    'CloseRequestFcn',@obj.lclFigCloseEventHandler,'WindowScrollWheelFcn',@obj.scrollWheelFcn,'SizeChangedFcn',@obj.alignmentWindowSize);
                obj.rendererModeChanged();
                obj.hController.registerGUI(obj.hAlignmentFig);
            end
            
            most.idioms.safeDeleteObj(obj.hControlPoints);
            most.idioms.safeDeleteObj(obj.hControlPointMenus);
            obj.hControlPoints = [];
            obj.hControlPointMenus = [];
            obj.controlPointPositions = {};
            obj.controlPointFixed = [];
            
            most.idioms.safeDeleteObj(obj.hAlignmentAx);
            most.idioms.safeDeleteObj(obj.hMainContextMenu);
            
            obj.hMainContextMenu = uicontextmenu('Parent',obj.hAlignmentFig);
                uimenu('Parent',obj.hMainContextMenu,'Label','Reset View','Callback',@(src,evt)obj.resetView());
                obj.hMainContextMenuAEs = uimenu('Parent',obj.hMainContextMenu,'Label','Auto Estimate Transform','Callback',@(src,evt)obj.estimateTransform());
                obj.hMainContextMenuAFr = uimenu('Parent',obj.hMainContextMenu,'Label','Add Free Control Point','Separator','on','Callback',@(src,evt)obj.addControlPoint(false));
                obj.hMainContextMenuAFx = uimenu('Parent',obj.hMainContextMenu,'Label','Add Fixed Control Point','Callback',@(src,evt)obj.addControlPoint(true));
                uimenu('Parent',obj.hMainContextMenu,'Label','Clear All Control Points','Callback',@(src,evt)obj.clearAllControlPoints());
                uimenu('Parent',obj.hMainContextMenu,'Label','Reset Transform','Callback',@(src,evt)obj.resetVideoTransform());
            
            most.idioms.safeDeleteObj(obj.hAlignmentAx);
            obj.hAlignmentAx = axes('Parent',obj.hAlignmentFig,'Position',[0 0 1 1],'UIContextMenu',obj.hMainContextMenu, ...
                'YDir','reverse','XTick',[],'YTick',[],'ButtonDownFcn',@(varargin)obj.panFcn(true),'Color',.5*ones(1,3),...
                'YTickLabelMode','manual','XTickLabelMode','manual','XTickLabel',[],'YTickLabel',[]);
            obj.viewFov = obj.maxViewFov;
            
            most.idioms.safeDeleteObj(obj.hRefIm);
            most.idioms.safeDeleteObj(obj.hRefImOutline);
            obj.hRefIm = matlab.graphics.primitive.Surface.empty(1,0);
            obj.hRefImOutline = matlab.graphics.primitive.Line.empty(1,0);
            
            most.idioms.safeDeleteObj(obj.hVidIm);
            most.idioms.safeDeleteObj(obj.hVidImOutline);
            obj.hVidIm = matlab.graphics.primitive.Surface.empty(1,0);
            obj.hVidImOutline = matlab.graphics.primitive.Line.empty(1,0);

            if show
                set(obj.hAlignmentFig,'Visible','on');
                obj.updateFigureImage(true);
            end            
        end

        function lclFigCloseEventHandler(obj,~,~)
            obj.showWindow = false;
        end
        
        function rendererModeChanged(obj,~,~)
            val = obj.hModel.hDisplay.renderer;
            if most.idioms.isValidObj(obj.hAlignmentFig)
                switch val
                    case {'auto'}
                        set(obj.hAlignmentFig,'RendererMode','auto');                    
                    case {'painters','opengl'}
                        set(obj.hAlignmentFig,'Renderer',val,'RendererMode','manual');
                end
            end
        end
        
        function videoLutChanged(obj,src,evnt)
            if isempty(obj.videoStreamSourceChan)
                return;
            end
            
            if isa(src, 'scanimage.components.CameraManager')
                sourceChan = evnt.camSource;
            else
                if isempty(obj.testPattern)
                    return;
                end
                sourceChan = str2double(src.Name(5));
            end
            
            if sourceChan == obj.videoStreamSourceChan
                obj.vidDirty = true;
                obj.updateFigureImage();
            end
        end
        
        function scrollWheelFcn(obj, ~, evt)
            mod = get(obj.hAlignmentFig, 'currentModifier');
            
            if isempty(mod)
                op = obj.hAlignmentAx.CurrentPoint(1,1:2);
                
                mv = double(evt.VerticalScrollCount) * 1;
                ovf = obj.viewFov;
                obj.viewFov = ovf * 1.2^mv;
                
                np = obj.hAlignmentAx.CurrentPoint(1,1:2);
                obj.viewPos = obj.viewPos + op - np;
            else
                mv = double(evt.VerticalScrollCount) * 1;%evt.VerticalScrollAmount;
                mv = mv/10;
                obj.videoStreamAlpha = min(max(obj.videoStreamAlpha + mv,0),1);
            end
        end
        
        function panFcn(obj,starting,stopping)
            persistent prevpt;
            
            if starting
                switch get(obj.hAlignmentFig,'SelectionType')
                    case 'normal' % left click
                        prevpt = obj.hAlignmentAx.CurrentPoint(1,1:2);
                        set(obj.hAlignmentFig,'WindowButtonMotionFcn',@(varargin)obj.panFcn(false,false),'WindowButtonUpFcn',@(varargin)obj.panFcn(false,true));
                        waitfor(obj.hAlignmentFig,'WindowButtonMotionFcn',[]);
                end
            elseif stopping
                set(obj.hAlignmentFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            else
                obj.viewPos = obj.viewPos + prevpt - obj.hAlignmentAx.CurrentPoint(1,1:2);
                prevpt = obj.hAlignmentAx.CurrentPoint(1,1:2);
            end
        end
        
        function cpFunc(obj,cpHdl,starting,stopping)
            persistent mode;
            persistent prevpt;
            persistent idx;
            persistent origFxCpPosRef;
            persistent origThisCpPosRef;
            persistent fxCpPos;
            persistent thisCpPos;
            persistent origCtrRef;
            persistent origVxRef;
            persistent origVyRef;
            persistent origRefTransform;
            persistent origMarkerSize;
            persistent origVideoStreamAlpha;
            persistent isStim;
            
            try
            if starting
                if strcmp(get(obj.hAlignmentFig,'SelectionType'), 'normal') % left click
                    idx = find(obj.hControlPoints == cpHdl);
                    isStim = isempty(idx);
                    if isStim
                        idx = find(obj.hStimPth == cpHdl);
                        assert(numel(idx) == 1, 'Error finding control point index.');
                        assert(idx > 0 && numel(obj.hStimPth) >= idx, 'Invalid control point index.');
                    else
                        assert(numel(idx) == 1, 'Error finding control point index.');
                        assert(idx > 0 && numel(obj.hControlPoints) >= idx, 'Invalid control point index.');
                    end
                    
                    if isStim
                        controlPointFixed_ = obj.pathPointFixed;
                        controlPointFixed_(idx) = false;
                        fxCpPos = obj.pathPointPositions(controlPointFixed_ ~= 0);
                        thisCpPos = obj.pathPointPositions{idx};
                    else
                        controlPointFixed_ = obj.controlPointFixed;
                        controlPointFixed_(idx) = false;
                        fxCpPos = obj.controlPointPositions(controlPointFixed_ ~= 0);
                        thisCpPos = obj.controlPointPositions{idx};
                        
                        
                        origMarkerSize = get(cpHdl,'MarkerSize');
                        set(cpHdl,'Markersize',100);
                        origVideoStreamAlpha = obj.videoStreamAlpha;
                    end
                    
                    prevpt = obj.getPtAlignmentAxes();
                    origRefTransform = obj.videoImToRefImTransform;
                    
                    
                    origFxCpPosRef = cellfun(@(pos)scanimage.mroi.util.xformPoints(pos,obj.videoImToRefImTransform),fxCpPos,'UniformOutput',false);
                    origThisCpPosRef = scanimage.mroi.util.xformPoints(thisCpPos,obj.videoImToRefImTransform);
                    
                    origCtrRef = scanimage.mroi.util.xformPoints([0.5,0.5],obj.videoImToRefImTransform);
                    origVxRef = scanimage.mroi.util.xformPoints([1.5,0.5],obj.videoImToRefImTransform) - origCtrRef;
                    origVyRef = scanimage.mroi.util.xformPoints([0.5,1.5],obj.videoImToRefImTransform) - origCtrRef;
                    
                    if sum(controlPointFixed_) == 1
                        mode = 'scaling';
                    elseif sum(controlPointFixed_) == 2
                        mode = 'affine';
                    elseif sum(controlPointFixed_) == 3
                        mode = 'perspective';
                    elseif sum(controlPointFixed_) >= 4
                        mode = 'fixed';
                    else
                        mode = 'translating';
                    end
                    
                    set(obj.hAlignmentFig,'WindowButtonMotionFcn',@(varargin)obj.cpFunc(cpHdl,false,false),'WindowButtonUpFcn',@(varargin)obj.cpFunc(cpHdl,false,true));
                end
            else
                nwpt = obj.getPtAlignmentAxes();
                mv = nwpt - prevpt;
                
                switch mode
                    case 'fixed'
                        %No-Op
                    case 'translating'
                        T = eye(3);
                        T(1:2,3) = mv;
                        obj.videoImToRefImTransform = T*origRefTransform;
                    case 'scaling'                        
                        thisCpPosRef = origThisCpPosRef + mv;
                                                
                        P = scanimage.mroi.util.intersectLines(thisCpPos,[1,0],fxCpPos{1},[0,1]);
                        PRef = scanimage.mroi.util.intersectLines(thisCpPosRef,origVxRef,origFxCpPosRef{1},origVyRef);
                        pts = [[thisCpPos,1];[fxCpPos{1},1];[P,1]];
                        ptsRef = [[thisCpPosRef,1];[origFxCpPosRef{1},1];[PRef,1]];
                        
                        obj.videoImToRefImTransform = ptsRef'/pts';
                    case 'affine'
                        thisCpPosRefNew = nwpt;
                        
                        pts = [[fxCpPos{1},1];[fxCpPos{2},1];[thisCpPos,1]];
                        ptsRef = [[origFxCpPosRef{1},1];[origFxCpPosRef{2},1];[thisCpPosRefNew,1]];
                        
                        obj.videoImToRefImTransform = ptsRef'/pts';
                    case 'overdetermined affine'
                        thisCpPosRefNew = nwpt;
                        
                        pts = zeros(length(fxCpPos)+1,3);
                        ptsRef = zeros(length(fxCpPos)+1,3);
                        
                        for i = 1:length(fxCpPos)
                            pts(i,:) = [fxCpPos{i},1];
                            ptsRef(i,:) = [origFxCpPosRef{i},1];
                        end
                        
                        pts(end,:) = [thisCpPos,1];
                        ptsRef(end,:) = [thisCpPosRefNew,1];
                        
                        obj.videoImToRefImTransform = ptsRef' * pinv(pts');
                    case 'perspective'
                        % inspired by this post:
                        % http://math.stackexchange.com/questions/296794/finding-the-transform-matrix-from-4-projected-points-with-javascript
                        pt1 = [fxCpPos{1},1]';
                        pt2 = [fxCpPos{2},1]';
                        pt3 = [fxCpPos{3},1]';
                        pt4 = [thisCpPos,1]';
                        ptmx = [pt1,pt2,pt3];
                        c = ptmx\pt4;
                        A = [c(1).*pt1,c(2).*pt2,c(3).*pt3];
                        
                        thisCpPosRefNew = nwpt;
                        pt1 = [origFxCpPosRef{1},1]';
                        pt2 = [origFxCpPosRef{2},1]';
                        pt3 = [origFxCpPosRef{3},1]';
                        pt4 = [thisCpPosRefNew,1]';
                        ptmx = [pt1,pt2,pt3];
                        c = ptmx\pt4;
                        B = [c(1).*pt1,c(2).*pt2,c(3).*pt3];
                        
                        obj.videoImToRefImTransform = B/A;
                    otherwise
                        assert(false)
                end
                
                if stopping
                    set(obj.hAlignmentFig,'WindowButtonMotionFcn',[],...
                        'WindowButtonUpFcn',[]);
                    
                    if ~isempty(origMarkerSize)
                        set(cpHdl,'Markersize',origMarkerSize);
                    end
                    
                    if ~isempty(origVideoStreamAlpha)
                        obj.videoStreamAlpha = origVideoStreamAlpha;
                    end
                end
            end

            catch ME
                set(obj.hAlignmentFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                
                if ~isempty(origMarkerSize)
                    set(cpHdl,'Markersize',origMarkerSize);
                end
                
                if ~isempty(origVideoStreamAlpha)
                    obj.videoStreamAlpha = origVideoStreamAlpha;
                end
                
                most.idioms.reportError(ME)
            end
        end
        
        function updateCPs(obj)
            for i = 1:numel(obj.hControlPoints)
                %vidPt = (obj.controlPointPositions{i} - [.5 .5]).*[obj.vidScaleX obj.vidScaleY] + [obj.vidOffsetX obj.vidOffsetY] + [.5 .5];
                vidPt = scanimage.mroi.util.xformPoints(obj.controlPointPositions{i},obj.videoImToRefImTransform);
                set(obj.hControlPoints(i), 'XData', vidPt(1), 'YData', vidPt(2));
            end
        end
        
        function p = getPt(obj,normalized)
            p = hgconvertunits(obj.hAlignmentFig,[0 0 get(obj.hAlignmentFig,'CurrentPoint')],get(obj.hAlignmentFig,'Units'),'pixels',0);
            sz = get(obj.hAlignmentFig,'Position');
            p = [p(3) sz(4)-p(4)];
            if nargin > 1 && normalized
                p = p./sz(3:4);
            end
        end
        
        function p = getPtAlignmentAxes(obj)
            p = get(obj.hAlignmentAx,'CurrentPoint');
            p = p([1,3]);
        end
        
        function selPattern(obj,src,~)
            if isempty(obj.hModel.hPhotostim.stimRoiGroups)
                obj.photostimPattern = [];
            else   
                obj.photostimPattern = obj.hModel.hPhotostim.stimRoiGroups(src.Value);
            end
        end
        
        function clearPhotostimPath(obj)
            most.idioms.safeDeleteObj(obj.hStimPth);
            obj.hStimPth = matlab.graphics.primitive.Line.empty(1,0);
            
            most.idioms.safeDeleteObj(obj.hPathMenus);
            obj.hPathMenus = [];
        end
        
        function loadPhotostimPath(obj,varargin)
            obj.clearPhotostimPath();
            
            Nr = numel(obj.photostimPattern.rois);
            if Nr > 0
                ss = obj.hModel.hPhotostim.stimScannerset;
                
                % ensure uniform sample rate for all scanners
                sampleRate = ss.scanners{1}.sampleRateHz;
                ss.scanners{2}.sampleRateHz = sampleRate;
                if ss.hasBeams
                    ss.beams.sampleRateHz = sampleRate;
                end
                if ss.hasFastZ
                    ss.fastz.sampleRateHz = sampleRate;
                end
                
                %determine best limit for stim function length to optimize gui speed
                maxp = ceil(10000/numel(obj.photostimPattern.rois));
                maxp = max(100,min(maxp,500));
                
                % get scan path
                [obj.scanPathCache,~,~] = obj.photostimPattern.scanStackFOV(ss,0,0,'',0,[],[],[],maxp);
                N = size(obj.scanPathCache.G,1);
                
                %compute the start and end indices for each roi and create the
                %lines
                obj.scanPathCacheIds = ones(Nr,2);
                j = 1;
                for i = 1:Nr
                    if ~isempty(obj.photostimPattern.rois(i).scanfields)
                        T = ss.scanTime(obj.photostimPattern.rois(i).scanfields(1),true);
                        jdur = min(maxp,ss.nsamples(ss.scanners{1},T));
                        obj.scanPathCacheIds(i,:) = [j max(j,j+jdur-1)];
                        j = j+jdur;
                        obj.pathPointPositions{i} = obj.photostimPattern.rois(i).scanfields(1).centerXY;
                        
                        % draw it
                        obj.hStimPth(i) = line(0,0,1,'parent',obj.hAlignmentAx,'linestyle',':','linewidth',2,'color',[1 0 1]);
                        
                        
                        if ~(obj.photostimPattern.rois(i).scanfields.isPause || obj.photostimPattern.rois(i).scanfields.isPark)
                            set(obj.hStimPth(i),'ButtonDownFcn',@(varargin)obj.cpFunc(obj.hStimPth(i),true));
                            set(obj.hStimPth(i),'linestyle','-');
                            set(obj.hStimPth(i),'ZData',2);
                            
                            obj.hPathMenus(end+1) = uicontextmenu('Parent',obj.hAlignmentFig);
                            uimenu('Parent',obj.hPathMenus(end),'Label','Fix Stimulus Position','Callback',@(src,evt)obj.toggleControlPointFixState(obj.hStimPth(i)));
                            set(obj.hStimPth(i),'UIContextMenu',obj.hPathMenus(end));
                            
                            if obj.photostimPattern.rois(i).scanfields.isPoint
                                set(obj.hStimPth(i),'MarkerSize',30,'Marker','.');
                            end
                        end
                    end
                end
                obj.scanPathCacheIds(end,end) = N;
                obj.scanPathCacheIds = min(N,max(1,floor(obj.scanPathCacheIds)));
                obj.pathPointFixed = false(1,N);
                obj.pathPointPositions(N+1:end) = [];
                obj.vidDirty = true;
                obj.updateFigureImage();
            end
        end
        
        function updateMaxViewFov(obj)
            fov = 0;
            for i = 1:numel(obj.hModel.hScanners)
                cp = abs(obj.hModel.hScanners{i}.scannerset.fovCornerPoints);
                fov = max([fov; cp(:)],[],1);
            end
            obj.maxViewFov = fov * 1.1;
        end
        
        function alignmentWindowSize(obj,varargin)
            vp = obj.viewPos;
            vf = obj.viewFov;
            
            p = obj.hAlignmentFig.Position(3:4);
            [~,si] = min(p);
            
            lims = zeros(2);
            lims(si,:) = [-vf vf] + vp(si);
            lims(3-si,:) = [-vf vf]*p(3-si)/p(si) + vp(3-si);
            
            obj.hAlignmentAx.XLim = lims(1,:);
            obj.hAlignmentAx.YLim = lims(2,:);
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct();

    s.referenceLUT = struct('Attributes',{{'numel', 2, 'finite' 'integer'}});
    s.showWindow   = struct('Classes','binaryflex','Attributes','scalar');
    s.vidOffsetX   = struct('Classes','numeric','Attributes',{{'finite'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.vidOffsetY   = struct('Classes','numeric','Attributes',{{'finite'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.vidScaleX    = struct('Classes','numeric','Attributes',{{'positive' 'finite'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.vidScaleY    = struct('Classes','numeric','Attributes',{{'positive' 'finite'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.vidRotation  = struct('Classes','numeric','Attributes',{{'finite' 'scalar'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.vidShear     = struct('Classes','numeric','Attributes',{{'finite' 'scalar'}},'DependsOn',{{'videoImToRefImTransform'}});
    s.videoImToRefImTransform = struct('Classes','numeric','Attributes',{{'finite' 'size',[3,3]}});
    s.videoStreamAlpha   = struct('Classes','numeric','Attributes',{{'scalar','>=',0,'<=',1}});
    s.videoStreamSourceChan = struct('Classes','numeric','Attributes',{{'positive' 'integer'}},'AllowEmpty',true);
    s.referenceImageColor = struct('Options',{{'Red','Green','Blue','Gray','None'}},'AllowEmpty',0);
    s.videoStreamColor = struct('Options',{{'Red','Green','Blue','Gray','None'}},'AllowEmpty',0);
end

function linepts = meshToOutline(mesh)
    linepts = zeros(5,1);
    linepts(1) = mesh(1,1);
    linepts(2) = mesh(1,end);
    linepts(3) = mesh(end,end);
    linepts(4) = mesh(end,1);
    linepts(5) = mesh(1,1);
end


%--------------------------------------------------------------------------%
% AlignmentControls.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
