classdef AlignmentControls < most.Gui & most.HasClassDataFile
    
    %% USER PROPS
    properties (SetObservable)
        showWindow = false;
        pauseVideo = false;
        referenceLUT = [0 100];
        
        referenceImageColor = 'Green';
        videoStreamAlpha = 0.5;
        
        videoStreamSourceChan = 1;
        videoStreamColor = 'Red';
        
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
        hAlignmentIm = [];
        hListeners = [];
        hMainContextMenu = [];
        
        pbCopyChannelN;
        
        hControlPoints = [];
        hControlPointMenus = [];
        controlPointPositions = {};
        controlPointFixed = [];
        
        hRefIm = [];
        hVidIm = [];
    end
    
    
    %% INTERNAL PROPS
    properties (Hidden,SetObservable,Transient)
        referenceData = [];
        videoData = [];
        
        refDirty = false;
        vidDirty = false;
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
            
            obj = obj@most.Gui(hModel, hController, [74.6 15.8461538461539]);
            set(obj.hFig,'Name','ALIGNMENT CONTROLS','Resize','off');
            
            h2 = uipanel(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuipanelFontUnits'),...
                'Units','characters',...
                'Title','Reference Image',...
                'Position',[1.2 0.153846153846154 29.8 13.7692307692308],...
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
                'Position',[1.6 13.7692307692308 30.8 1.76923076923077],...
                'Bindings',{obj 'showWindow' 'Value'},...
                'Tag','cbShowWindow');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Video Stream Source Channel:',...
                'Style','text',...
                'Position',[32.2 13.0769230769231 31 1.07692307692308],...
                'Tag','text5');
            
            obj.pmVideoSource = obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{  '1'; 'Channel 2'; 'Channel 3'; 'Channel 4' },...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[63.2 13 7 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'videoStreamSourceChan' 'Value'},...
                'Tag','pmVideoSource');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String',{  'Green'; 'Red'; 'Blue'; 'Gray' },...
                'Style','popupmenu',...
                'Value',1,...
                'Position',[59.4 11.1538461538462 10.8 1.53846153846154],...
                'BackgroundColor',[1 1 1],...
                'Bindings',{obj 'videoStreamColor' 'Choice'},...
                'Tag','pmVidColor');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Color:',...
                'Style','text',...
                'Position',[53.2 11.2307692307692 5.8 1.07692307692308],...
                'Tag','text8');
            
            obj.etOffsetX = obj.addUiControl(...
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
                'String','Generate Scanner Alignment Transform',...
                'Position',[31.4 2.61538461538462 42.2 1.84615384615385],...
                'Callback',@obj.guiGenerateTransforms,...
                'Tag','pgGenerate');
            
            obj.addUiControl(...
                'Parent',obj.hFig,...
                'FontUnits',get(0,'defaultuicontrolFontUnits'),...
                'Units','characters',...
                'String','Pause Video',...
                'Style','togglebutton',...
                'Position',[33 11.1538461538462 16 1.69230769230769],...
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
            
            obj.resetAlignmentFig(false);
            obj.hListeners = [addlistener(obj.hModel.hDisplay,'renderer','PostSet',@obj.rendererModeChanged);...
                              addlistener(obj.hModel.hDisplay,'chan1LUT','PostSet',@obj.videoLutChanged);...
                              addlistener(obj.hModel.hDisplay,'chan2LUT','PostSet',@obj.videoLutChanged);...
                              addlistener(obj.hModel.hDisplay,'chan3LUT','PostSet',@obj.videoLutChanged);...
                              addlistener(obj.hModel.hDisplay,'chan4LUT','PostSet',@obj.videoLutChanged);...
                              addlistener(obj.hModel.hUserFunctions,'frameAcquired',@(varargin)obj.frameAcquired());...
                              addlistener(obj.hModel,'imagingSystem','PostSet',@(varargin)obj.updateChannelOptions())];
                          
            obj.updateChannelOptions();
            obj.ensureClassDataFile(struct('lastReferenceFile','reference.mat'));
        end
        
        function updateChannelOptions(obj)
            %disable controls if channels don't exist
            for iterChannels = 1:4
                if iterChannels <= obj.hModel.hChannels.channelsAvailable
                    set(obj.pbCopyChannelN(iterChannels),'Enable','on');
                else
                    set(obj.pbCopyChannelN(iterChannels),'Enable','off');
                end
            end
            
            %channel dropdown
            set(obj.pmVideoSource, 'string', cellfun(@num2str,num2cell(1:obj.hModel.hChannels.channelsAvailable),'uniformoutput',false));
            v = min(get(obj.pmVideoSource, 'Value'),obj.hModel.hChannels.channelsAvailable);
            obj.videoStreamSourceChan = v;
        end
        
        
        function changedAlignmentPause(obj,~,~)
            if obj.hModel.hAlignment.pauseVideo
                set(obj.hGUIData.alignmentControlsV5.pbPause,'String','Resume Video');
            else
                set(obj.hGUIData.alignmentControlsV5.pbPause,'String','Pause Video');
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAlignmentIm);
            most.idioms.safeDeleteObj(obj.hAlignmentAx);
            most.idioms.safeDeleteObj(obj.hMainContextMenu);
            most.idioms.safeDeleteObj(obj.hControlPoints);
            most.idioms.safeDeleteObj(obj.hControlPointMenus);
            most.idioms.safeDeleteObj(obj.hAlignmentFig);
            most.idioms.safeDeleteObj(obj.hListeners);
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
            %Set maximum LUT value at 100% of 16 bit range max, 10% min.
            val = int16([((-2^(n-1))*0.1) 2^(n-1)-1]);
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
            obj.updateReferenceSurf();
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
            obj.updateReferenceSurf();
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
            end
        end
        
        function guiGenerateTransforms(obj,varargin)
            try
                obj.generateTransforms();
            catch ME
                warndlg(ME.message,'Generate Transforms');
                most.idioms.warn(ME.message);
            end
        end
        
        function generateTransforms(obj)
            %transform between two scanners is easy. transform between N scanners is a more complex problem
            %through image comparison you are determining scanner to scanner transforms between pairs of
            %scanners. the overall solution may be over or under constrained. should maintain a matrix
            
            assert(~isempty(obj.referenceData), 'Cannot generate transforms. Reference is empty.');
            assert(~isempty(obj.videoData), 'Cannot generate transforms. Video stream is empty.');
            assert(isfield(obj.referenceData, 'scanfieldTransform') && ~isempty(obj.referenceData.scanfieldTransform), 'Not enough information to compute transforms. Reference does not have scanned coordinates.');                
            assert(isfield(obj.videoData, 'scanfieldTransform') && ~isempty(obj.videoData.scanfieldTransform), 'Not enough information to compute transforms. Video stream does not have scanned coordinates.');
            assert(isfield(obj.referenceData, 'scanner') && ~isempty(obj.referenceData.scanner) && obj.hModel.hScannerMap.isKey(obj.referenceData.scanner), 'Not enough information to compute transforms. Reference image was collected from unknown scanner.');
            assert(isfield(obj.videoData, 'scanner') && ~isempty(obj.videoData.scanner) && obj.hModel.hScannerMap.isKey(obj.videoData.scanner), 'Not enough information to compute transforms. Video stream was collected from unknown scanner.');
            assert(isfield(obj.referenceData, 'refToScannerTransform') && ~isempty(obj.referenceData.refToScannerTransform), 'Not enough information to compute transforms. Current reference image scanner transform is unknown.');
            assert(isfield(obj.videoData, 'refToScannerTransform') && ~isempty(obj.videoData.refToScannerTransform), 'Not enough information to compute transforms. Current video stream scanner transform is unknown.');
            assert(~strcmp(obj.referenceData.scanner, obj.videoData.scanner), 'Not enough information to compute transforms. Reference and video stream were captured with the same scanner.');
         
            %solved matrix equation for transform from second scanner to reference
            refSf = obj.referenceData.scanfieldTransform;
            vidSf = obj.videoData.scanfieldTransform;
            
            % calculate correction matrix            
            C = vidSf / (refSf * obj.videoImToRefImTransform);
            
            hRefImScanner = obj.hModel.hScanner(obj.referenceData.scanner);
            hVidImScanner = obj.hModel.hScanner(obj.videoData.scanner);
            
            %hVidImScanner.scannerToRefTransform = inv(inv(hVidImScanner.scannerToRefTransform)*C);
            hVidImScanner.scannerToRefTransform = inv(obj.videoData.refToScannerTransform * C);
            
%             %check ratios and warn user
%             nomRatios = hRefImScanner.angularRange ./ hVidImScanner.angularRange;
%             actRatios = [refImScannerToRefXform(1)/vidImScannerToRefXform(1) refImScannerToRefXform(5)/vidImScannerToRefXform(5)];
%             diff = abs(nomRatios - actRatios) ./ actRatios;
%             if any(diff > .05)
%                 most.idioms.warn(['According to MDF, scanner ''%s'' has angular range of [%.1f %.1f] and scanner ''%s'' has angular range of [%.1f %.1f] '...
%                                   'giving a nominal ratio of [%.1f %.1f]. The generated transforms, however, indicates that the angular range ratio is '...
%                                   '[%.1f %.1f]. This differs from nominal mdf value by [%.1f%% %.1f%%]. Double check MDF settings for accuracy.'], hRefImScanner.name,...
%                                   hRefImScanner.angularRange(1), hRefImScanner.angularRange(2), hVidImScanner.name, hVidImScanner.angularRange(1),...
%                                   hVidImScanner.angularRange(2), nomRatios(1), nomRatios(2), actRatios(1), actRatios(2), diff(1)*100, diff(2)*100);
%             end
%             
        end
        
        function copyChannel(obj,channel)
            [exists,index] = ismember(channel,obj.hModel.hChannels.channelDisplay);
            if exists
                if ~isempty(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData) && index <= numel(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.imageData)
                    obj.referenceData.scanner = obj.hModel.imagingSystem;
                    
                    roi = obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.hRoi;
                    
                    obj.referenceData.scanfieldTransform = roi.get(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.zs).affine();
                    obj.referenceData.refToScannerTransform = obj.hModel.hScan2D.scannerset.refToScannerTransform;
                    
                    obj.referenceData.displayData = (obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.imageData{index}{1})' ./ obj.hModel.hDisplay.displayRollingAverageFactor; %Transpose image data in SI2015.
                    
                    obj.referenceData.LUT = obj.hModel.hDisplay.(['chan' num2str(channel) 'LUT']);
                    obj.referenceLUT = obj.referenceData.LUT;
                    
                    obj.referenceData.imageSize = size(obj.referenceData.displayData);
                    obj.refDirty = true;
                    obj.updateFigureImage();
                else
                    most.mimics.warning('There is no image data in Channel %d. Try focusing or grabbing first.',channel);
                end
            else
                most.mimics.warning('Channel %d is not set to display in Channels Dialog. Set channel display on to copy.',channel);
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
            set(obj.hAlignmentAx,'xlim',[0 1],'ylim',[0 1]);
        end
        
        function addControlPoint(obj, fixed)            
            vidPt = obj.getPtAlignmentAxes();
            refPt = scanimage.mroi.util.xformPoints(vidPt,inv(obj.videoImToRefImTransform));
            %refPt = obj.videoImToRefImTransform \ [vidPt 1]';
            %refPt = [refPt(1) refPt(2)];
            
            if ~(all(refPt >= 0) && all(refPt <= 1))
                warndlg('Control point must exist within bounds of reference image.','Warning','modal');
                error('Control point must exist within bounds of reference image.');
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
            assert(numel(idx) == 1, 'Error finding control point index.');
            assert(idx > 0 && numel(obj.hControlPoints) >= idx, 'Invalid control point index.');
            
            if obj.controlPointFixed(idx)
                obj.controlPointFixed(idx) = false;
                findall(obj.hControlPointMenus(idx),'Label','Fix Control Point');
                mkr = 'o';
                ch = 'off';
            else
                if sum(obj.controlPointFixed) >= 4
                    warndlg('Only three control points can be fixed.','Warning','modal');
                    error('Only three control points can be fixed.');
                end
                obj.controlPointFixed(idx) = true;
                mkr = 's';
                ch = 'on';
            end
            
            set(obj.hControlPoints(idx), 'marker', mkr);
            set(findall(obj.hControlPointMenus(idx),'Label','Fix Control Point'),'Checked',ch);
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
            most.idioms.safeDeleteObj(obj.hControlPoints);
            obj.hControlPoints = [];
            obj.hControlPointMenus = [];
            obj.controlPointPositions = {};
            obj.controlPointFixed = [];
        end
        
        function resetRefTransform(obj)
            obj.videoImToRefImTransform = eye(3);
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden,Access = {?scanimage.interfaces.Class})
    end
    
    
    %% INTERNAL METHODS
    methods (Hidden)
        function updateReferenceSurf(obj)           
            if ~scanimage.mroi.util.isTransformPerspective(obj.videoImToRefImTransform)
                [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(0:1,0:1,2);
            else
                numgridlines = 15;
                [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(linspace(0,1,numgridlines),linspace(0,1,numgridlines),2);
            end

            [imcoordsX,imcoordsY] = scanimage.mroi.util.xformMesh(imcoordsX,imcoordsY,obj.videoImToRefImTransform);
            
            set(obj.hVidIm, 'XData', imcoordsX, 'YData', imcoordsY, 'ZData', imcoordsZ, 'FaceAlpha',obj.videoStreamAlpha);
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
        
        function frameAcquired(obj)
            obj.updateVideoStream();
            obj.updateFigureImage();
        end
        
        function updateVideoStream(obj)
            if obj.showWindow && ~obj.pauseVideo
                [exists,index] = ismember(obj.videoStreamSourceChan,obj.hModel.hChannels.channelDisplay);
                if exists
                    if ~isempty(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData) && index <= numel(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.imageData)
                        obj.videoData.scanner = obj.hModel.imagingSystem;
                        
                        %could consider not doing this but might be a good idea to have this cached
                        roi = obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.hRoi.copy();

                        obj.videoData.scanfieldTransform = roi.get(obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.zs).affine();
                        obj.videoData.refToScannerTransform = obj.hModel.hScan2D.scannerset.refToScannerTransform;
                        
                        obj.videoData.displayData = (obj.hModel.hDisplay.rollingStripeDataBuffer{1}{1}.roiData{1}.imageData{index}{1})' ./ obj.hModel.hDisplay.displayRollingAverageFactor;
                        obj.videoData.imageSize = size(obj.videoData.displayData);
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
            
            if obj.showWindow && (obj.refDirty || obj.vidDirty)
                if obj.vidDirty && ~isempty(obj.videoData)
                    cdata = scaleAndColorData(obj.videoData.displayData,obj.videoStreamColor,obj.hModel.hDisplay.(['chan' num2str(obj.videoStreamSourceChan) 'LUT']));
                    set(obj.hVidIm,'CData',cdata);
                end
                
                if obj.refDirty && ~isempty(obj.referenceData)
                    cdata = scaleAndColorData(obj.referenceData.displayData,obj.referenceImageColor,obj.referenceLUT);
                    set(obj.hRefIm,'CData',cdata);
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
            
            if ~most.idioms.isValidObj(obj.hAlignmentFig);
                %Create the figures first.
                obj.hAlignmentFig = most.idioms.figureSquare('Name','Optical Alignment','Visible','off','NumberTitle','off','Menubar','none','Tag','alignment',...
                    'CloseRequestFcn',@obj.lclFigCloseEventHandler,'WindowScrollWheelFcn',@obj.scrollWheelFcn);
                obj.rendererModeChanged();
%                 obj.hController.registerGUI(obj.hAlignmentFig);
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
                uimenu('Parent',obj.hMainContextMenu,'Label','Add Free Control Point','Separator','on','Callback',@(src,evt)obj.addControlPoint(false));
                uimenu('Parent',obj.hMainContextMenu,'Label','Add Fixed Control Point','Callback',@(src,evt)obj.addControlPoint(true));
                uimenu('Parent',obj.hMainContextMenu,'Label','Clear All Control Points','Callback',@(src,evt)obj.clearAllControlPoints());
                uimenu('Parent',obj.hMainContextMenu,'Label','Reset Reference Image Position','Callback',@(src,evt)obj.resetRefTransform());
            
            obj.hAlignmentAx = axes('Parent',obj.hAlignmentFig,'Position',[0 0 1 1],'UIContextMenu',obj.hMainContextMenu, ...
                'YDir','reverse','XTick',[],'YTick',[],'ButtonDownFcn',@(varargin)obj.panFcn(true),...
                'YTickLabelMode','manual','XTickLabelMode','manual','XTickLabel',[],'YTickLabel',[]);
            lpf = obj.hModel.hRoiManager.linesPerFrame;
            ppl = obj.hModel.hRoiManager.pixelsPerLine;
            set(obj.hAlignmentAx, 'DataAspectRatio',[lpf ppl 1],...
                    'PlotBoxAspectRatioMode','auto',...
                    'DataAspectRatioMode','auto',...
                    'XLim',[0 1],...
                    'YLim',[0 1],...
                    'ALim',[0 1]);
            
            cdata = zeros(lpf,ppl,3,'uint8');
            [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(0:1, 0:1, 1);
            obj.hRefIm  = surface(imcoordsX,imcoordsY,imcoordsZ,...
                'Parent',obj.hAlignmentAx,'Hittest','off',...
                'FaceColor','texturemap',...
                'CData',cdata,...
                'EdgeColor','k',...
                'FaceLighting','none',...
                'FaceAlpha',1);
            [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(linspace(0,1,10),linspace(0,1,10),2);
            [imcoordsX,imcoordsY] = scanimage.mroi.util.xformMesh(imcoordsX,imcoordsY,obj.videoImToRefImTransform);
            imcoordsZ = 2 * imcoordsZ;
            obj.hVidIm  = surface(imcoordsX,imcoordsY,imcoordsZ,...
                'Parent',obj.hAlignmentAx,'Hittest','off',...
                'FaceColor','texturemap',...
                'CData',cdata,...
                'EdgeColor','b',...
                'FaceLighting','none',...
                'FaceAlpha',obj.videoStreamAlpha);

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
        
        function videoLutChanged(obj,src,~)
            scrChan = str2double(src.Name(5));
            if scrChan == obj.videoStreamSourceChan
                obj.vidDirty = true;
                obj.updateFigureImage();
            end
        end
        
        function scrollWheelFcn(obj, ~, evt)
            mod = get(obj.hAlignmentFig, 'currentModifier');
            
            if isempty(mod)
                mv = double(evt.VerticalScrollCount) * 1;%evt.VerticalScrollAmount;
                % find old range and center
                xlim = get(obj.hAlignmentAx,'xlim');
                ylim = get(obj.hAlignmentAx,'ylim');
                rg = xlim(2) - xlim(1);
                ctr = 0.5*[sum(xlim) sum(ylim)];

                % calc and constrain new half range
                nrg = min(2.3703,rg*.75^-mv);
                nrg = max(0.0078125,nrg);
                nhrg = nrg/2;

                %calc new center based on where mouse is
                pt = obj.getPt(true)*rg + [xlim(1) ylim(1)];%normalized point
                odfc = pt - ctr; %original distance from center
                ndfc = odfc * (nrg/rg); %new distance from center
                nctr = pt - [ndfc(1) ndfc(2)];

                % new lims
                xlim = [-nhrg nhrg] + nctr(1);
                ylim = [-nhrg nhrg] + nctr(2);
                set(obj.hAlignmentAx,'xlim',xlim,'ylim',ylim);
            else
                mv = double(evt.VerticalScrollCount) * 1;%evt.VerticalScrollAmount;
                mv = mv/10;
                obj.videoStreamAlpha = min(max(obj.videoStreamAlpha + mv,0),1);
            end
        end
        
        function panFcn(obj,starting,stopping)
            persistent prevpt;
            persistent org;
            persistent ohrg;
            
            if starting
                switch get(obj.hAlignmentFig,'SelectionType');
                    case 'normal' % left click
                        prevpt = obj.getPt(true);
                        
                        xlim = get(obj.hAlignmentAx,'xlim');
                        org = xlim(2) - xlim(1);
                        ohrg = org/2;
                        
                        set(obj.hAlignmentFig,'WindowButtonMotionFcn',@(varargin)obj.panFcn(false,false),'WindowButtonUpFcn',@(varargin)obj.panFcn(false,true));
                        waitfor(obj.hAlignmentFig,'WindowButtonMotionFcn',[]);
                end
            else
                % find prev center
                xlim = get(obj.hAlignmentAx,'xlim');
                ylim = get(obj.hAlignmentAx,'ylim');
                octr = 0.5*[sum(xlim) sum(ylim)];
                
                % calc new center
                nwpt = obj.getPt(true);
                nctr = octr - (nwpt - prevpt) .* org;
                
                nxlim = nctr(1) + [-ohrg ohrg];
                nylim = nctr(2) + [-ohrg ohrg];
                
                set(obj.hAlignmentAx,'xlim',nxlim);
                set(obj.hAlignmentAx,'ylim',nylim);

                prevpt = nwpt;
                
                if stopping
                    set(obj.hAlignmentFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
                end
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
            
            try
            if starting
                switch get(obj.hAlignmentFig,'SelectionType');
                    case 'normal' % left click
                        idx = find(obj.hControlPoints == cpHdl);
                        assert(numel(idx) == 1, 'Error finding control point index.');
                        assert(idx > 0 && numel(obj.hControlPoints) >= idx, 'Invalid control point index.');
                        
                        origMarkerSize = get(cpHdl,'MarkerSize');
                        set(cpHdl,'Markersize',100);
                        
                        origVideoStreamAlpha = obj.videoStreamAlpha;
                        
                        prevpt = obj.getPtAlignmentAxes();
                        
                        origRefTransform = obj.videoImToRefImTransform;

                        controlPointFixed_ = obj.controlPointFixed;
                        controlPointFixed_(idx) = false;
                        fxCpPos = obj.controlPointPositions(controlPointFixed_ ~= 0);
                        thisCpPos = obj.controlPointPositions{idx};
                        
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
%                           mode = 'overdetermined affine';
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
                        T = origRefTransform;
                        origX = origRefTransform(1,3);
                        origY = origRefTransform(2,3);
                        T([7,8]) = [origX+mv(1),origY+mv(2)];
                        obj.videoImToRefImTransform = T;
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
    s.videoStreamSourceChan = struct('Classes','numeric','Attributes',{{'positive' 'integer'}});
    s.referenceImageColor = struct('Options',{{'Red','Green','Blue','Gray','None'}},'AllowEmpty',0);
    s.videoStreamColor = struct('Options',{{'Red','Green','Blue','Gray','None'}},'AllowEmpty',0);
end


%--------------------------------------------------------------------------%
% AlignmentControls.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
