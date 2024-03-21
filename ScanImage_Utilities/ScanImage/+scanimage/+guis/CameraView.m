classdef CameraView < most.Gui
    properties(SetObservable)
        live = 0;
        refreshRate = 20;   % in Hertz
        enableRois = false; % toggle for ROI viewing
        enableCrosshair = false; %toggle for camera surface crosshair
        estimateMotion = false;
    end
    
    properties(SetObservable, Hidden)
        hCameraWrapper;     % Handle to current CameraWrapper
        refUndocked = false;
    end
    
    properties(SetObservable, Dependent)
        blackLevel;
        whiteLevel;
        roiAlpha;
        refAlpha;
    end
    
    properties(Hidden)
        channelIdx;         % ROI Channel Index
        hAxes;              % Handle to figure Axes
        hCameraOutline;     % Handle to Camera Surface Outline
        hCameraRefGroup;    % Handle to group holding ref surface and ref xHairRef
        hCameraSurf;        % Handle to Camera Surface
        hCameraRefColor;    % Handle to Camera Reference Color Selection
        hCameraRefFig;      % Handle to Camera Reference Figure
        hCameraRefSurf = matlab.graphics.primitive.Surface.empty(0,1); % Handle to Reference Camera Surface
        hCameraRefSel;      % Handle to Camera Reference Selection
        hCameraRefDockToggle; % Handle to Camera Reference Dock/Undock Toggle
        hMotionEntries;
        hListeners = event.listener.empty;
        hLiveHistograms = scanimage.mroi.LiveHistogram.empty;       % Handle to live histograms
        hLiveHistogramListeners = event.listener.empty;             %listeners to histogram lut
        hLiveToggle;        % Handle to live togglebutton control
        hRefSpace;          % Handle to RefSpace dropdown uicontrol
        hRefTogglable = most.gui.uicontrol.empty(0,1);              % list of handles dependent on hCameraRefSel
        hRoiOutline = matlab.graphics.primitive.Line.empty(0,1);    % Handle to Roi outline
        hRoiSurface = matlab.graphics.primitive.Surface.empty(0,1); % Handle to Roi Surface
        hRoiTogglable = most.gui.uicontrol.empty(0,1);              % list of handles dependent on enableRois
        hStatusBar = most.gui.uicontrol.empty(0,1);
        hTable;             % uitable
        refImg;             % Reference Image Data
        scaleRefImg = true; % specifies if reference image is scaled with lut
        refSpace;           % should be a value in REFSPACE
        zRoi;               % Roi Z position Index
        hXhair;            % Handle array for crosshair on camera surface
        hXhairRef;         % Handle array for crosshair on reference surface
        hXhairMenu;         % Handle to menu toggling crosshair on camera surface
        hFlipHMenu;         % Handle to menu flipping view horizontally
        hFlipVMenu;         % Handle to menu flipping view vertically
        hRotateMenu;        % Handle to menu rotating view
        hMotionEstimator;   % Handle to motion estimator for reference data
        hDummyRoi;          % Dummy Roi used for motion estimator
        displayToRefTransform = eye(3);
    end
    
    properties(Hidden, SetAccess=private)
        fovPos_Ref;
        panPos_Ref = [0 0]; % current camera pan location
        fovFit_Ref;
        posFit_Ref;
        refSelPrevIdx = 1;
    end
    
    properties(Constant, Access=private)
        LUT_AUTOSCALE_SATURATION_PERCENTILE = [.1 .01];
        REFSPACES = {'Camera' 'ROI'};
        COLORSELECT = {'Gray' 'Red' 'Green' 'Blue'};
        ZOOMSCALE = 1.2; %scaling constant used for zoom calculation
        REFSELEXTRA = {'None';'Browse...'};
    end
    
    %% LIFECYCLE
    methods
        function obj = CameraView(hModel, hController, hWrapper)
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            size = [800 600];
            obj = obj@most.Gui(hModel, hController,size);
            
            if nargin < 3
                hWrapper = [];
            end
            
            obj.hCameraWrapper = hWrapper;
            obj.hCameraRefSurf = [];
            obj.channelIdx = 1;
            obj.zRoi = 1;
            obj.refSpace = 'Camera';
            
            obj.hDummyRoi = scanimage.mroi.Roi();
            scanfield = scanimage.mroi.scanfield.fields.RotatedRectangle();
            scanfield.pixelResolutionXY = obj.hCameraWrapper.hDevice.resolutionXY;
            obj.hDummyRoi.add(0,scanfield);
            
            obj.hListeners = [...
                addlistener(obj,'live','PostSet',@(varargin)obj.refreshToggled);...
                addlistener(obj,'refreshRate','PostSet',@(~,~)obj.updateRefreshRate());...
                addlistener(obj.hCameraWrapper,'lut', 'PostSet', ...
                    @(~,evt)obj.cameraLutUpdated(evt));...
                addlistener(obj.hCameraWrapper,{'flipH','flipV','rotate'}, 'PostSet', ...
                    @(~,~)obj.updateXforms())];
            
            if ~isempty(obj.hModel) && ~isempty(obj.hController)
                obj.hListeners = [obj.hListeners;...
                    addlistener(obj.hModel.hRoiManager,'imagingRoiGroupChanged',...
                    @(~,~)obj.refreshRois());...
                    addlistener(obj.hModel.hUserFunctions,'frameAcquired',...
                    @(~,~)obj.frameAcquired());...
                    addlistener(obj.hModel.hDisplay,'chan1LUT','PostSet',@(~,~)obj.roiLutChanged(1));...
                    addlistener(obj.hModel.hDisplay,'chan2LUT','PostSet',@(~,~)obj.roiLutChanged(2));...
                    addlistener(obj.hModel.hDisplay,'chan3LUT','PostSet',@(~,~)obj.roiLutChanged(3));...
                    addlistener(obj.hModel.hDisplay,'chan4LUT','PostSet',@(~,~)obj.roiLutChanged(4));...
                    addlistener(obj.hModel.hDisplay,'displayRollingAverageFactor','PostSet',@(~,~)obj.roiLutChanged());...
                    addlistener(obj.hCameraWrapper,'cameraToRefTransform',...
                    'PostSet',@(~,~)obj.updateXforms)];
                
                obj.initGUI();
                obj.refreshRois();
                obj.resetView();
                set(obj.hFig, ...
                    'WindowScrollWheelFcn', @(~,data)obj.scrollWheelCallback(data),...
                    'WindowButtonMotionFcn',@obj.hover);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hCameraRefFig);
            most.idioms.safeDeleteObj(obj.hTable);
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hLiveHistograms);
            most.idioms.safeDeleteObj(obj.hLiveHistogramListeners);
        end
    end
    
    %% GUI
    methods
        function val = get.roiAlpha(obj)
            val = obj.hCameraWrapper.roiAlpha;
        end
        
        function set.roiAlpha(obj, val)
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.roiAlpha = val;
            obj.roiLutChanged(obj.channelIdx);
        end
        
        function val = get.refAlpha(obj)
            val = obj.hCameraWrapper.refAlpha;
        end
        
        function set.refAlpha(obj, val)
            if ischar(val)
                val = str2double(val);
            end
            
            obj.hCameraWrapper.refAlpha = val;
            if ~isempty(obj.hCameraRefSurf) && ~obj.refUndocked
                obj.hCameraRefSurf.FaceAlpha = val;
            end
        end
        
        function val = get.blackLevel(obj)
            val = obj.hCameraWrapper.lut(1);
        end
        
        function set.blackLevel(obj, val)
            if obj.whiteLevel <= val
                return;
            end
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.lut(1) = val;
            obj.updateHistogramLut();
        end
        
        function buttonDownCallback(obj)
            if strcmp(obj.hFig.SelectionType, 'normal')
                obj.startPan();
            end
        end
        
        function startPan(obj)
            lastPt_Ref = obj.axPtToSpace(obj.hAxes.CurrentPoint(1,1:2));
            WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            WindowButtonUpFcn = obj.hFig.WindowButtonMotionFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abort;
            
            function move(varargin)
                try
                    obj.panPos_Ref = obj.panPos_Ref + lastPt_Ref - obj.axPtToSpace(obj.hAxes.CurrentPoint(1,1:2));
                    obj.updateView();
                    lastPt_Ref =  obj.axPtToSpace(obj.hAxes.CurrentPoint(1,1:2));
                catch ME
                    abort();
                    rethrow(ME);
                end
            end
            
            function abort(varargin)
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn;
                obj.hFig.WindowButtonMotionFcn = WindowButtonUpFcn;
            end
        end
        
        function [ref_pt,pixel_pt] = axPtToSpace(obj,pt)
            ref_pt = scanimage.mroi.util.xformPoints(pt,obj.displayToRefTransform);
            pixel_pt = scanimage.mroi.util.xformPoints(ref_pt,obj.hCameraWrapper.pixelToRefTransform,true);
        end
        
        function cameraFrameAcq(obj, img)
            if nargin < 2 || isempty(img)
                return;
            end
            obj.hCameraSurf.CData = img;
            
            % garbage collect deleted live histograms
            obj.hLiveHistograms = obj.hLiveHistograms(isvalid(obj.hLiveHistograms));
            
            if obj.estimateMotion && ~isempty(obj.hMotionEstimator)
                roiData = obj.imToRoiData(img);
                result = obj.hMotionEstimator.estimateMotion(roiData);
                timeout_s = 0;
                assert(result.wait(timeout_s),'Cannot use an asynchronous motion estimator for camera motion');
                dr = result.fetch();
                %confidence = result.confidence(1:2);
                dxstr = num2str(dr(1));
                dystr = num2str(dr(2));
            else
                dxstr = '';
                dystr = '';
            end
            
            obj.hMotionEntries(3).String = dxstr;
            obj.hMotionEntries(5).String = dystr;
            
            for i=1:length(obj.hLiveHistograms)
                obj.hLiveHistograms(i).updateData(img);
            end
        end
        
        function cameraLutUpdated(obj, ~)
            set(obj.hAxes, 'CLim', obj.hCameraWrapper.lut);
            if ~isempty(obj.hCameraRefSurf)
                obj.hCameraRefSurf.CData = obj.refSurfDisplay();
            end
        end
        
        function cameraRefSelect(obj, src)
            %None
            if src.Value == 1
                obj.refImg = [];
                obj.hCameraRefSurf.CData = [];
                set(obj.hRefTogglable, 'Enable', 'off');
                obj.refSelPrevIdx = 1;
                return;
            end
            
            %Browse
            if src.Value == length(obj.hCameraRefSel.String)
                [f, path] = uigetfile({'*.tiff;*.tif;*.png'},...
                    'Select a Reference Image File');
                if f == 0
                    src.Value = obj.refSelPrevIdx;
                    return;
                end
                fullpath = fullfile(path, f);
                obj.hCameraWrapper.referenceImages = vertcat(fullpath,obj.hCameraWrapper.referenceImages);
                
                %reference image list self corrects so there's no guarantee that
                % the file we put in actually exists
                idx = strcmp(obj.hCameraWrapper.referenceImages, fullpath);
                if any(idx)
                    src.Value = find(idx,1) + 1;
                    obj.updateRefSelect();
                else
                    src.Value = 1;
                    obj.refImg = [];
                    obj.hCameraRefSurf.CData = [];
                    obj.refSelPrevIdx = 1;
                    set(obj.hRefTogglable, 'Enable', 'off');
                    obj.updateRefSelect();
                    return;
                end
            end
            
            imgpath = obj.hCameraWrapper.referenceImages{src.Value-1};
            refImg_ = imread(imgpath);
            assert(size(refImg_,3)==1,'Color images are not supported.');
            
            if obj.hCameraWrapper.hDevice.isTransposed
                obj.refImg = refImg_.';
            else
                obj.refImg = refImg_;
            end
            
            [~,~,fileextension] = fileparts(imgpath);
            switch lower(fileextension)
                case {'.tiff','.tif'}
                    obj.scaleRefImg = true;
                otherwise
                    obj.scaleRefImg = false;
            end
            obj.hCameraRefSurf.CData = obj.refSurfDisplay();
            set(obj.hRefTogglable, 'Enable', 'on');
            obj.refSelPrevIdx = src.Value;
        end
        
        function close(obj)
            %figure is not killed when closed
            set(obj.hFig, 'Visible', 'off');
            if obj.live
                obj.live = false;
                obj.refreshToggled();
            end
        end
        
        function set.enableCrosshair(obj, val)
            if val
                obj.hXhairMenu.Label = 'Hide Crosshair';
                visibility = 'on';
            else
                obj.hXhairMenu.Label = 'Show Crosshair';
                visibility = 'off';
            end
            set([obj.hXhair, obj.hXhairRef], 'Visible', visibility);
            obj.enableCrosshair = val;
        end
        
        function set.enableRois(obj, val)
            if val
                enable = 'on';
            else
                enable = 'off';
            end
            set(obj.hRoiTogglable, 'Enable', enable);
            obj.enableRois = val;
            obj.refreshRois();
        end
        
        function frameAcquired(obj)
            if ~obj.enableRois
                return;
            end
%             roidata = obj.hModel.hDisplay.getAveragedRoiDatas();
            roidata = obj.hModel.hDisplay.rollingStripeDataBuffer{obj.zRoi}{1}.roiData;
            for i=1:length(roidata)
                if obj.hModel.hStackManager.zs(obj.zRoi) == roidata{i}.zs &&...
                        obj.channelIdx == roidata{i}.channels
                    surf = obj.hRoiSurface(i);
                    surf.AlphaData = roidata{i}.imageData{obj.zRoi}{1};
                end
            end
        end
        
        function cm = getColor(obj, idx, data)
            switch lower(obj.COLORSELECT{idx})
                case 'gray'
                    zeroIdx = [];
                case 'red'
                    zeroIdx = 2:3;
                case 'green'
                    zeroIdx = [1,3];
                case 'blue'
                    zeroIdx = 1:2;
                otherwise
                    error('Unknown color: %s',obj.COLORSELECT{idx});
            end
            
            if nargin < 3
                cm = gray();
                cm(:,zeroIdx) = 0;
            else
                assert(ismatrix(data));
                cm = repmat(data, [1 1 3]);
                cm(:,:,zeroIdx) = 0;
            end
        end
        
        function histLutChanged(obj, val)
            obj.blackLevel = val(1);
            obj.whiteLevel = val(2);
        end
        
        function hover(obj,varargin)
            [inAxes,pt] = most.gui.isMouseInAxes(obj.hAxes);
            if ~inAxes
                return
            end
            
            [ref_pt,pixel_pt] = obj.axPtToSpace(pt);
            pixel_pt = round(pixel_pt);
            
            pixRes = obj.hCameraWrapper.hDevice.resolutionXY;
            
            pixelVal = 0;
            if pixel_pt(1)>=1 && pixel_pt(1)<=pixRes(1) && ...
                    pixel_pt(2)>=1 && pixel_pt(2)<=pixRes(2)
                if obj.hCameraWrapper.hDevice.isTransposed
                    frameIdxs = pixel_pt;
                else
                    frameIdxs = flip(pixel_pt);
                end
                
                if ~isempty(obj.hCameraWrapper.lastFrame)
                    pixelVal = obj.hCameraWrapper.lastFrame(frameIdxs(1),frameIdxs(2));
                end
            end
            
            %             pixelStr = fprintf('X: %d, Y: %d\n',pixel_pt(1),pixel_pt(2));
            %             refStr = fprintf('Angles: [%d, %d]\n',ref_pt(1),ref_pt(2));
            %             valStr = fprintf('Pixel Value: %d\n',pixelVal);
            
            statusStr = sprintf('Pixel: (%+d, %+d)    Angles: [%+.4f, %+.4f]    Value: %d',...
                pixel_pt(1), pixel_pt(2), ref_pt(1), ref_pt(2), pixelVal);
            
            set(obj.hStatusBar, 'String', statusStr);
        end
        
        function hRoiData = imToRoiData(obj,im)
            hRoiData = scanimage.mroi.RoiData();
            hRoiData.hRoi = obj.hDummyRoi;
            hRoiData.channels = 1;
            hRoiData.zs = 0;
            hRoiData.transposed = obj.hCameraWrapper.hDevice.isTransposed;
            hRoiData.imageData{1}{1} = im;
        end
        
        function initGUI(obj)
            hCamera = obj.hCameraWrapper.hDevice;
            
            obj.hFig.Name = ['CAMERA [' upper(hCamera.cameraName) ']'];
            obj.hFig.CloseRequestFcn = @(~,~)obj.close();
            
            %root
            rootFlowMargin = 4; %copied from MotionDisplay
            rootContainer = most.gui.uiflowcontainer( ...
                'Parent', obj.hFig, ...
                'FlowDirection', 'LeftToRight', ...
                'Margin', rootFlowMargin);
            
            %sidebar
            sidebarFlowmargin = 4;
            sidebar = most.gui.uiflowcontainer( ...
                'Parent', rootContainer, ...
                'FlowDirection', 'TopDown', ...
                'WidthLimits', [300 300], ...
                'Margin', sidebarFlowmargin);
            
            %sidebar pane
            sidebarPane = uipanel('Parent', sidebar, ...
                'Title', 'Settings', ...
                'Units', 'pixels');
            
            dtMax = intmax(hCamera.datatype);
            
            labelW = 97;
            elemW = 185;
            height = 20;
            bwEntrySliderW = [50;109]; %space for autolut
            entrySliderW = [50;132];
            colmargin = 3;
            rowmargin = 5;
            topmargin = 40;
            
            %regular row items
            elems = [...
                struct('label', 'Reference Space',...
                'ctrl',obj.addUiControl('Style','popupmenu',...
                'String',obj.REFSPACES,...
                'Callback', @(src, ~)obj.setReferenceSpace(src)...
                ),'width', elemW,'bind',{{'hRefSpace'}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Exposure',...
                'ctrl',obj.addUiControl('Style','edit',...
                'TooltipString','Set Camera Exposure' ...
                ,'Bindings', {hCamera 'cameraExposureTime' 'value'}...
                ),'width',elemW,'bind',{{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'White','ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj 'whiteLevel' 'value'})...
                ;obj.addUiControl('Style', 'slider',...
                'TooltipString', 'Set White LUT',...
                'Bindings', {obj 'whiteLevel' 'value'},'Min', 0, 'Max', dtMax...
                )],'width',bwEntrySliderW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label','Black',...
                'ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj 'blackLevel' 'value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'TooltipString', 'Set Black LUT',...
                'Bindings', {obj 'blackLevel' 'value'},'Min', 0, 'Max', dtMax...
                )], 'width',bwEntrySliderW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Color Scale',...
                'ctrl', obj.addUiControl('Style', 'popupmenu',...
                'String', obj.COLORSELECT, ...
                'Callback', @(src,~)colormap(obj.hAxes, obj.getColor(src.Value))...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Reference Image',...
                'ctrl',[...
                obj.addUiControl('Style', 'popupmenu',...
                'String', '',...
                'Callback', @(src, ~)obj.cameraRefSelect(src));...
                obj.addUiControl('Style', 'togglebutton',...
                'String', 'View',... %up arrow from base
                'HorizontalAlignment', 'center',...
                'FontSize', 10,...
                'ToolTip', 'Dock/Undock Reference Image',...
                'Bindings', {obj 'refUndocked' 'value'})],...
                'width', [122;60], 'bind', {{'hCameraRefSel';'hCameraRefDockToggle'}},...
                'roitoggle', false,'reftoggle', false);...
                
                struct('label', 'Reference Color',...
                'ctrl',obj.addUiControl('Style', 'popupmenu','String',obj.COLORSELECT, ...
                'Callback',@(~,~)set(obj.hCameraRefSurf,'CData',obj.refSurfDisplay()), ...
                'Value',3 ...
                ), 'width', elemW, 'bind', {{'hCameraRefColor'}},...
                'roitoggle', false, 'reftoggle', true);...
                
                struct('label', 'Reference Alpha',...
                'ctrl', [...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj,'refAlpha','value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'Bindings', {obj,'refAlpha','value'},'Min', 0, 'Max', 1 ...
                )], 'width',entrySliderW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', true);...
                
                struct('label', 'Estimate Motion',...
                'ctrl', [...
                obj.addUiControl('Style', 'checkbox',...
                'Bindings', {obj, 'estimateMotion', 'value'});
                obj.addUiControl('Style', 'text', 'String', 'dx:');...
                obj.addUiControl('Style', 'edit');...
                obj.addUiControl('Style', 'text', 'String', 'dy:');...
                obj.addUiControl('Style', 'edit')], 'width', [17;18;56;18;56],...
                'bind', {{'hMotionEntries'}}, 'roitoggle', false,...
                'reftoggle', true);
                
                struct('label', 'Enable ROIs',...
                'ctrl', obj.addUiControl('Style', 'checkbox', ...
                'Bindings', {obj 'enableRois' 'value'}...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', false,...
                'reftoggle', false);...
                
                struct('label', 'Channels',...
                'ctrl', obj.addUiControl('Style', 'popupmenu',...
                'Bindings', {obj.hModel.hChannels 'channelName' 'Choices'},...
                'Callback', @(src, ~)obj.updateChan(src)...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false);...
                
                struct('label', 'Zs', 'ctrl', obj.addUiControl('Style', 'popupmenu', ...
                'Bindings', {obj.hModel.hStackManager 'zs' 'Choices'}, ...
                'Callback', @obj.updateZed...
                ), 'width', elemW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false);...
                
                struct('label', 'ROI Alpha',...
                'ctrl',[...
                obj.addUiControl('Style', 'edit',...
                'Bindings', {obj,'roiAlpha','value'}...
                );...
                obj.addUiControl('Style', 'slider',...
                'Bindings', {obj,'roiAlpha','value'},...
                'Min', 0, 'Max', 1 ...
                )], 'width',entrySliderW, 'bind', {{}}, 'roitoggle', true,...
                'reftoggle', false)...
                ];
            nrows = length(elems);
            
            hlim = topmargin + (nrows-1)*height + nrows*rowmargin;
            sidebarPane.HeightLimits = [hlim hlim];
            for i=1:nrows
                rowpos = topmargin + (i-1)*(rowmargin + height);
                e = elems(i);
                label = obj.addUiControl('Parent', sidebarPane ...
                    , 'Style', 'text' ...
                    , 'String', e.label ...
                    , 'HorizontalAlignment', 'right' ...
                    , 'Units', 'pixels' ...
                    , 'RelPosition', [0 rowpos labelW height]);
                set(e.ctrl, 'Parent', sidebarPane);
                set(e.ctrl, 'Units', 'pixels');
                for j=1:length(e.ctrl)
                    xOffset = labelW + sum(e.width(1:j-1)) + j*colmargin;
                    e.ctrl(j).RelPosition = [xOffset rowpos e.width(j) height];
                end
                
                if ~isempty(e.bind)
                    assert(iscellstr(e.bind),'`bind` must be cell array of strings');
                    numBinds = numel(e.bind);
                    for j=1:numBinds-1
                        obj.(e.bind{j}) = e.ctrl(j);
                    end
                    if numBinds <= numel(e.ctrl)
                        obj.(e.bind{end}) = e.ctrl(numBinds:end);
                    end
                end
                
                if all(e.roitoggle)
                    obj.hRoiTogglable = [obj.hRoiTogglable;label;e.ctrl];
                else
                    obj.hRoiTogglable = [obj.hRoiTogglable;e.ctrl(e.roitoggle)];
                end
                
                if all(e.reftoggle)
                    obj.hRefTogglable = [obj.hRefTogglable;label;e.ctrl];
                else
                    obj.hRefTogglable = [obj.hRefTogglable;e.ctrl(e.reftoggle)];
                end
            end
            set([obj.hRoiTogglable;obj.hRefTogglable], 'Enable', 'off');
            obj.updateRefSelect();
            
            % auto lut button
            alutRel = elems(strcmp({elems.label}, 'Black'));
            alutRelSliderPos = alutRel.ctrl(2).RelPosition;
            xOffset = alutRelSliderPos(1) + alutRelSliderPos(3) + colmargin;
            topOffset = alutRelSliderPos(2);
            obj.addUiControl('Parent', sidebarPane ...
                , 'Units', 'pixels' ...
                , 'Style', 'pushbutton' ...
                , 'String', char(8597) ... %up-down arrow
                , 'HorizontalAlignment', 'center' ...
                , 'FontSize', 16 ...
                , 'Callback', @(~,~)obj.lutAutoScale() ...
                , 'RelPosition', [xOffset topOffset 20 (2*height)+rowmargin]);
            
            %Optional Settings
            userProps = hCamera.getUserPropertyList();
            mask = strcmpi(userProps,'cameraExposureTime'); % there is a separate ui control for cameraExposureTime
            userProps = userProps(~mask);
            
            userPropVals = cell(size(userProps));
            for idx=1:numel(userProps)
                propName = userProps{idx};
                userPropVals{idx} = dat2str(hCamera.(propName));
            end
            
            userProp = horzcat(userProps(:), userPropVals(:));
            
            if isempty(userProp)
                uipanel('Parent', sidebar,...
                    'Visible', 'on',...
                    'BorderType', 'none',...
                    'Units', 'pixels');
            else
                obj.hTable = uitable('Parent', sidebar ...
                    , 'Data', userProp ...
                    , 'ColumnName', {'Property Names' 'Property Values'} ...
                    , 'RowName', {} ...
                    , 'ColumnEditable', [false true] ...
                    , 'CellEditCallback', @obj.updateTable ...
                    , 'Units', 'pixels');
            end
            
            %live toggle
            obj.hLiveToggle = most.gui.uicontrol('Parent', sidebar ...
                ,'Style', 'togglebutton' ...
                ,'String', 'LIVE' ...
                ,'Bindings', {obj 'live' 'value'} ...
                ,'HeightLimits', [50 50] ...
                );
            
            %camera view
            camFlow = most.gui.uiflowcontainer( ...
                'Parent', rootContainer, ...
                'FlowDirection', 'TopDown', ...
                'Margin', 5);
            camPane = uipanel('parent', camFlow, 'bordertype','none');
            obj.hAxes = axes('parent', camPane, ...
                'box','off', ...
                'Color','k', ...
                'xgrid','off','ygrid','off', ...
                'units','normalized', ...
                'position',[0 0 1 1], ...
                'GridColor',.9*ones(1,3), ...
                'GridAlpha',.25, ...
                'DataAspectRatio', [1 1 1], ...
                'XTick',[],'XTickLabel',[], ...
                'YTick',[],'YTickLabel',[], ...
                'XLim', [-.5 .5], ...
                'YLim', [-.5 .5],...
                'CLim', obj.hCameraWrapper.lut, ...
                'ALim', [0 intmax('int16')], ...
                'ButtonDownFcn', @(~,~)obj.buttonDownCallback(), ...
                'UIContextMenu', uicontextmenu(obj.hFig));
            uimenu('Parent',obj.hAxes.UIContextMenu,'Label','Reset View',...
                'Callback',@(~,~)obj.resetView());
            obj.hXhairMenu = uimenu('Parent',obj.hAxes.UIContextMenu,...
                'Label','Show Crosshair',...
                'Callback',@(~,~)set(obj, 'enableCrosshair', ~obj.enableCrosshair));
            uimenu('Parent', obj.hAxes.UIContextMenu, 'Label', 'View Histograms', ...
                'Callback', @(~,~)obj.showHistogram());
            
            obj.hFlipHMenu = uimenu('Parent', obj.hAxes.UIContextMenu, 'Label', 'Flip Horizontally', 'Separator', 'on',...
                'Callback', @(~,~)flipView('H'));
            obj.hFlipVMenu = uimenu('Parent', obj.hAxes.UIContextMenu, 'Label', 'Flip Vertically', ...
                'Callback', @(~,~)flipView('V'));
            obj.hRotateMenu = uimenu('Parent', obj.hAxes.UIContextMenu, 'Label', 'Rotation', ...
                'Callback', @(~,~)flipView('R'));
            
            uimenu('Parent', obj.hAxes.UIContextMenu, 'Separator', 'on', ...
                'Label','Save Current Viewport',...
                'Callback', @(~,~)obj.saveView2Png());
            
            uimenu('Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Save Current Frame',...
                'Callback', @(~,~)obj.saveFrame2Png());
            
            saveframe = uimenu('Parent', obj.hAxes.UIContextMenu,...
                'Label', 'Save Raw Frame...');
            uimenu('Parent', saveframe, 'Label', 'to Workspace', ...
                'Callback',@(~,~)obj.saveFrame2Workspace());
            uimenu('Parent', saveframe, 'Label', 'to TIFF',...
                'Callback',@(~,~)obj.saveFrame2Tiff());
            
            %Statusbar
            statusPane = uipanel('Parent', camFlow, ...
                'Title', '', ...
                'Units', 'pixels',...
                'BorderType', 'line',...
                'HighlightColor', [0.7 0.7 0.7]);
            statusPane.HeightLimits = [17 17];
            obj.hStatusBar = obj.addUiControl('parent', statusPane,'style', 'text',...
                'HorizontalAlignment', 'left', 'Units', 'Normalized',...
                'Position', [0 0 1 1]);
            
            colormap(obj.hAxes, gray);
            
            view(obj.hAxes,0,-90);
            
            %due to view change.
            obj.hCameraSurf = surface('parent', obj.hAxes, ...
                'FaceColor','texturemap','EdgeColor','none','HitTest','off', 'PickableParts', 'none',...
                'XData',[],'YData',[],'ZData',[], 'CData', '', 'AlphaData', inf);
            
            obj.hCameraRefGroup = hggroup('Parent', obj.hAxes);
            
            obj.hCameraRefSurf = surface('parent', obj.hCameraRefGroup, ...
                'FaceColor','texturemap','EdgeColor','none','HitTest','off', 'PickableParts', 'none',...
                'XData',[],'YData',[],'ZData',[], 'CData', obj.refSurfDisplay(), ...
                'FaceAlpha', obj.refAlpha);
            
            obj.hCameraOutline = line(NaN,NaN,NaN,'Parent',obj.hAxes,...
                'HitTest','off','PickableParts','none','Color','y', 'XData', [],...
                'YData', [], 'ZData', []);
            
            obj.hXhair = line(NaN,NaN,NaN,'Parent',obj.hAxes,...
                'HitTest','off','PickableParts','none','Color','w', 'XData', [],...
                'YData', [], 'ZData', [], 'LineWidth', 1, 'Visible', 'off');
            
            obj.hXhairRef = line(NaN,NaN,NaN,'Parent',obj.hCameraRefGroup,...
                'HitTest','off','PickableParts','none','Color','w', 'XData', [],...
                'YData', [], 'ZData', [], 'LineWidth', 1, 'Visible', 'off');
            
            function flipView(type)
                switch type
                    case 'H'
                        obj.hCameraWrapper.flipH = ~obj.hCameraWrapper.flipH;
                    case 'V'
                        obj.hCameraWrapper.flipV = ~obj.hCameraWrapper.flipV;
                    case 'R'
                        obj.hCameraWrapper.rotate = obj.hCameraWrapper.rotate + 90;
                end
            end
        end
        
        function lutAutoScale(obj)
            pxGradient = sort(obj.hCameraWrapper.lastFrame(:));
            if isempty(pxGradient)
                return;
            end
            npx = numel(pxGradient);
            newlut = ceil(npx .* obj.LUT_AUTOSCALE_SATURATION_PERCENTILE);
            newlut(2) = npx - newlut(2); %invert white idx
            
            obj.blackLevel = pxGradient(newlut(1));
            obj.whiteLevel = pxGradient(newlut(2));
        end
        
        function set.refUndocked(obj,val)
            if val
                obj.hCameraRefDockToggle.String = 'Dock';
                
                if isempty(obj.hCameraRefFig) || ~isvalid(obj.hCameraRefFig)
                    obj.hCameraRefFig = figure('NumberTitle','off',...
                        'Name','Reference Image',...
                        'Menubar','none',...
                        'DeleteFcn',@(~,~)set(obj, 'refUndocked', false));
                    hAx = axes('Parent', obj.hCameraRefFig, 'Visible', 'off');
                    hAx.DataAspectRatio = [1 1 1];
                    hAx.XTick = [];
                    hAx.YTick = [];
                    hAx.LooseInset = [1,1,1,1]*0.02;
                    view(hAx,0,-90);
                end
                obj.hCameraRefGroup.Parent = obj.hCameraRefFig.CurrentAxes;
                obj.hCameraRefSurf.FaceAlpha = 1;
            else
                obj.hCameraRefDockToggle.String = 'View';
                obj.hCameraRefGroup.Parent = obj.hAxes;
                if isvalid(obj.hCameraWrapper)
                    obj.hCameraRefSurf.FaceAlpha = obj.refAlpha;
                end
                if ~isempty(obj.hCameraRefFig)
                    if isvalid(obj.hCameraRefFig)
                        close(obj.hCameraRefFig);
                    end
                    obj.hCameraRefFig = [];
                end
            end
            obj.refUndocked = val;
        end
        
        function set.refImg(obj,val)
            if ~isempty(val)
                expectedRes = flip(obj.hCameraWrapper.hDevice.resolutionXY);
                if obj.hCameraWrapper.hDevice.isTransposed
                    expectedRes = flip(expectedRes);
                end
                validateattributes(val,{'numeric'},{'size',expectedRes},...
                    'The reference image has the wrong resolution.');
            end
            
            obj.refImg = val;
            
            if isempty(obj.refImg)
                most.idioms.safeDeleteObj(obj.hMotionEstimator);
                obj.hMotionEstimator = [];
            else
                refRoiData = obj.imToRoiData(obj.refImg);
                obj.hMotionEstimator = scanimage.components.motionEstimators.SimpleMotionEstimator(refRoiData);
                obj.hMotionEstimator.phaseCorrelation = false;
            end
        end
        
        function refreshRois(obj)
            if ~isempty(obj.hRoiSurface)
                delete(obj.hRoiSurface);
                obj.hRoiSurface = matlab.graphics.primitive.Surface.empty(0,1);
            end
            
            if ~isempty(obj.hRoiOutline)
                delete(obj.hRoiOutline);
                obj.hRoiOutline = matlab.graphics.primitive.Line.empty(0,1);
            end
            
            if obj.enableRois
                numRg = numel(obj.hModel.hRoiManager.currentRoiGroup.rois);
            else
                numRg = 0;
            end
            
            for i=1:numRg
                obj.hRoiSurface(i) = surface('parent', obj.hAxes, 'HitTest', 'off',...
                    'PickableParts', 'none', 'FaceColor','texturemap',...
                    'EdgeColor','none','FaceAlpha', 'texturemap',...
                    'XData',[],'YData',[],'ZData',[]);
                obj.hRoiOutline(i) = line(NaN,NaN,NaN,'Parent',obj.hAxes,...
                    'HitTest','off','PickableParts','none',...
                    'Color','b','XData',[],'YData',[],'ZData',[]);
            end
            
            %reset transforms
            obj.updateXforms();
            
            obj.frameAcquired();
        end
        
        function refreshToggled(obj)
            acquiring = obj.hCameraWrapper.hDevice.videoTimerActive;
            if obj.live
                obj.hLiveToggle.String = 'ABORT';
                obj.hLiveToggle.hCtl.BackgroundColor = [1 0.4 0.4];
                obj.hLiveToggle.hCtl.ForegroundColor = 'w';
                if ~acquiring
                    obj.hCameraWrapper.hDevice.startLiveMode(@obj.cameraFrameAcq,...
                        1/obj.refreshRate);
                end
            else
                obj.hLiveToggle.String = 'LIVE';
                obj.hLiveToggle.hCtl.BackgroundColor = [.94 .94 .94];
                obj.hLiveToggle.hCtl.ForegroundColor = 'k';
                if acquiring
                    obj.hCameraWrapper.hDevice.abortLiveMode();
                end
            end
        end
        
        function cdata = refSurfDisplay(obj,colorIdx)
            if nargin < 2 || isempty(colorIdx)
                colorIdx = obj.hCameraRefColor.Value;
            end
            
            if obj.scaleRefImg
                lut = obj.hCameraWrapper.lut;
            else
                refImgClass = class(obj.refImg);
                lut = [intmin(refImgClass),intmax(refImgClass)];
            end
            
            cdata = obj.scaleLut(obj.refImg, lut);
            cdata = obj.getColor(colorIdx,cdata);
        end
        
        function resetView(obj)
            obj.panPos_Ref = obj.posFit_Ref;
            obj.fovPos_Ref = obj.fovFit_Ref;
            obj.updateView();
        end
        
        function roiLutChanged(obj, srcIdx)
            if obj.enableRois && (nargin < 2 || srcIdx == obj.channelIdx)
                if ~isempty(obj.hRoiSurface) && any(isscalar([obj.hRoiSurface.AlphaData]))
                    for i=1:length(obj.hRoiSurface)
                        obj.hRoiSurface(i).AlphaData = repmat(intmin('int16'),...
                            size(obj.hRoiSurface(i).ZData));
                    end
                end
                lut = obj.hModel.hDisplay.(...
                    ['chan' num2str(obj.channelIdx) 'LUT']);
                lut = double(lut) * obj.hModel.hDisplay.displayRollingAverageFactor;
                
                lut(2) = lut(1)+diff(lut)/obj.roiAlpha;
                obj.hAxes.ALim = lut;
            end
        end
        
        function saveFrame2Png(obj)
            img = obj.hCameraWrapper.lastFrame;
            assert(~isempty(img), 'No frame available for saving.');
            if obj.hCameraWrapper.hDevice.isTransposed
                img = img .';
            end
            
            [file, path] = uiputfile({'*.png'},...
                'Select Save Destination',...
                [obj.hCameraWrapper.hDevice.cameraName '_frame']);
            if file == 0
                return;
            end
            
            img = obj.scaleLut(img, obj.hCameraWrapper.lut);
            
            s = most.json.savejson(obj.hCameraWrapper.saveProps());
            %tab -> spaces.  imwrite complains
            s = strrep(s, char(9), '    ');
            imwrite(img, fullfile(path, file),'Comments',s);
        end
        
        function saveFrame2Tiff(obj)
            img = obj.hCameraWrapper.lastFrame;
            
            assert(~isempty(img), 'No frame available for saving.');
            
            if obj.hCameraWrapper.hDevice.isTransposed
                img = img .';
            end
            
            [file, path] = uiputfile({'*.tiff;*.tif'},...
                'Select Save Destination',...
                [obj.hCameraWrapper.hDevice.cameraName '_frame']);
            if file == 0
                return;
            end
            
            s = most.json.savejson(obj.hCameraWrapper.saveProps());
            imwrite(img, fullfile(path, file),'Description',s);
        end
        
        function saveFrame2Workspace(obj)
            cimg = obj.hCameraWrapper.lastFrame;
            if obj.hCameraWrapper.hDevice.isTransposed
                cimg = cimg';
            end
            assignin('base', 'cameraImage', cimg);
            fprintf(['Snapshot from "%s" assigned to ' ...
                '<a href="matlab: ' ...
                'figure(''Colormap'',gray());imagesc(cameraImage);axis(''image'');' ...
                'fprintf(''>> size(cameraImage)\\n'');size(cameraImage)">' ...
                'cameraImage</a> in workspace ''base''\n'], ...
                obj.hCameraWrapper.hDevice.cameraName);
        end
        
        function saveView2Png(obj)
            [img, ~] = frame2im(getframe(obj.hAxes));
            [file, path] = uiputfile({'.png'},...
                'Select Save Destination',...
                [obj.hCameraWrapper.hDevice.cameraName '_view']);
            if file == 0
                return;
            end
            s = most.json.savejson(obj.hCameraWrapper.saveProps());
            %tab -> spaces.  imwrite complains
            s = strrep(s, char(9), '    ');
            imwrite(img, fullfile(path, file),'Comments',s);
        end
        
        function scaledData = scaleLut(obj, data, lut)
            % this function is necessary because individual surfaces cannot set CLim
            % so we manually scale the data ourselves.
            dt = obj.hCameraWrapper.hDevice.datatype;
            lut = single(lut);
            ratio = single(intmax(dt)) / diff(lut);
            scaledData = cast((single(data) - lut(1)) .* ratio, dt);
        end
        
        function scrollWheelCallback(obj, data)
            obj.scrollAxes(data);
        end
        
        function scrollAxes(obj, data)
            if ~most.gui.isMouseInAxes(obj.hAxes)
                return
            end
            
            scrollCnt = double(data.VerticalScrollCount);
            if isempty(get(obj.hFig, 'currentModifier'))
                oldPtPos_Ref = scanimage.mroi.util.xformPoints(obj.hAxes.CurrentPoint(1,1:2),obj.displayToRefTransform);
                
                obj.fovPos_Ref = obj.fovPos_Ref * realpow(obj.ZOOMSCALE, scrollCnt);
                obj.updateView();
                
                ptPos_Ref = scanimage.mroi.util.xformPoints(obj.hAxes.CurrentPoint(1,1:2),obj.displayToRefTransform);
                obj.panPos_Ref = obj.panPos_Ref + oldPtPos_Ref - ptPos_Ref;
                obj.updateView();
            else
                scrollCnt = scrollCnt / 10;
                obj.roiAlpha = min(max(obj.roiAlpha + scrollCnt,0),1);
            end
        end
        
        function showHistogram(obj)
            hHist = scanimage.mroi.LiveHistogram(obj.hModel);
            hHist.title = [obj.hCameraWrapper.hDevice.cameraName ' Histogram'];
            dt = obj.hCameraWrapper.hDevice.datatype;
            hHist.dataRange = [intmin(dt) intmax(dt)];
            hHist.lut = obj.hCameraWrapper.lut;
            hHist.viewRange = mean(hHist.lut) + [-1.5 1.5] .* diff(hHist.lut) ./ 2;
            hHist.updateData(obj.hCameraWrapper.lastFrame);
            obj.hLiveHistograms = [obj.hLiveHistograms; hHist];
            obj.hLiveHistogramListeners = [obj.hLiveHistogramListeners; ...
                addlistener(hHist, 'lutUpdated', @(src,~)obj.histLutChanged(src.lut))];
        end
        
        function setReferenceSpace(obj, src)
            obj.refSpace = obj.REFSPACES{src.Value};
            obj.updateXforms();
            obj.updateView();
        end
        
        function updateChan(obj, src)
            %update video stream
            obj.channelIdx = sscanf(src.String{src.Value}, 'Channel %d');
            obj.frameAcquired();
        end
        
        function updateFit(obj)
            allX = obj.hCameraOutline.XData;
            allY = obj.hCameraOutline.YData;
            if ~isempty(obj.hRoiOutline)
                allX = [allX [obj.hRoiOutline.XData]];
                allY = [allY [obj.hRoiOutline.YData]];
            end
            
            all_ = [allX(:) allY(:)];
            all_Ref = scanimage.mroi.util.xformPoints(all_,obj.displayToRefTransform);
            
            maxX_Ref = max(all_Ref(:,1));
            maxY_Ref = max(all_Ref(:,2));
            minX_Ref = min(all_Ref(:,1));
            minY_Ref = min(all_Ref(:,2));
            origin = [(maxX_Ref - minX_Ref) (maxY_Ref - minY_Ref)] ./ 2;
            %fovMax should be one tick above the maximum bounds
            obj.posFit_Ref = [maxX_Ref maxY_Ref] - origin;
            obj.fovFit_Ref = max(origin) * obj.ZOOMSCALE;
        end
        
        function updateHistogramLut(obj)
            %clean invalid histograms in the meantime
            invalidHistIdx = ~isvalid(obj.hLiveHistograms);
            obj.hLiveHistograms(invalidHistIdx) = [];
            delete(obj.hLiveHistogramListeners(invalidHistIdx));
            obj.hLiveHistogramListeners(invalidHistIdx) = [];
            
            for i=1:numel(obj.hLiveHistograms)
                obj.hLiveHistograms(i).lut = obj.hCameraWrapper.lut;
            end
        end
        
        function updateRefreshRate(obj)
            if obj.live
                stop(obj.refreshTimer);
            end
            obj.refreshTimer.Period = round(1/obj.refreshRate,3);
            if obj.live
                start(obj.refreshTimer);
            end
        end
        
        function updateRefSelect(obj)
            refPaths = obj.hCameraWrapper.referenceImages;
            refFiles = cell(size(refPaths));
            for i=1:length(refPaths)
                [~,file,ext] = fileparts(refPaths{i});
                refFiles{i} = [file ext];
            end
            obj.hCameraRefSel.String = [obj.REFSELEXTRA(1);...
                refFiles;obj.REFSELEXTRA(2)];
        end
        
        function updateTable(obj, src, data)
            row = data.Indices(1);
            propname = obj.hTable.Data{row, 1};
            try
                obj.hCameraWrapper.hDevice.(propname) = eval(data.NewData);
            catch ME
                most.idioms.reportError(ME);
            end
            src.Data{row,2} = dat2str(obj.hCameraWrapper.hDevice.(propname));
        end
        
        function updateView(obj)
            bounds_ref = obj.panPos_Ref + obj.fovPos_Ref * [-1 -1;-1 1;1 1;1 -1];
            
            panPos = scanimage.mroi.util.xformPoints(obj.panPos_Ref,obj.displayToRefTransform,true);
            bounds = scanimage.mroi.util.xformPoints(bounds_ref,obj.displayToRefTransform,true);
            xfov = diff([min(bounds(:,1)),max(bounds(:,1))]);
            yfov = diff([min(bounds(:,2)),max(bounds(:,2))]);
            fov = max(xfov,yfov) / 2;
            
            set(obj.hAxes, ...
                'XLim', fov * [-1 1] + panPos(1), ...
                'YLim', fov * [-1 1] + panPos(2));
        end
        
        function updateXforms(obj)
            switch obj.refSpace
                case 'Camera'            
                    obj.displayToRefTransform = obj.hCameraWrapper.cameraToRefTransform /(obj.hCameraWrapper.displayTransform);
                    set([obj.hFlipHMenu,obj.hFlipVMenu,obj.hRotateMenu],'Enable','on');
                case 'ROI'
                    obj.displayToRefTransform = eye(3);
                    set([obj.hFlipHMenu,obj.hFlipVMenu,obj.hRotateMenu],'Enable','off');
            end
            
            % update camera+ref xforms
            [xx, yy] = obj.hCameraWrapper.getRefMeshgrid();
            [xx, yy] = scanimage.mroi.util.xformMesh(xx, yy, obj.displayToRefTransform, true);
            set(obj.hCameraSurf, 'XData', xx, 'YData', yy, 'ZData', ones(size(xx)));
            if ~isempty(obj.hCameraRefSurf)
                set(obj.hCameraRefSurf, 'XData', xx, 'YData', yy,...
                    'ZData', zeros(size(xx)));
            end
            
            xx = mesh2Outline(xx);
            yy = mesh2Outline(yy);
            set(obj.hCameraOutline, 'XData', xx, 'YData', yy, 'ZData', ones(size(xx)));
            
            % xx and yy should now be lines indices
            zz = zeros(1,2);
            horzX = [xx(1)+xx(4) xx(2)+xx(3)] / 2;
            horzY = [yy(1)+yy(4) yy(2)+yy(3)] / 2;
            
            vertX = [xx(1)+xx(2) xx(3)+xx(4)] / 2;
            vertY = [yy(1)+yy(2) yy(3)+yy(4)] / 2;
            
            xx = [horzX NaN vertX];
            yy = [horzY NaN vertY];
            zz = [zz NaN zz];
            set([obj.hXhair obj.hXhairRef],'XData', xx,'YData', yy,'ZData', zz);
            
            % update roi xforms
            rg = obj.hModel.hRoiManager.currentRoiGroup.rois;
            for i=1:length(obj.hRoiSurface)
                [xx, yy] = rg(i).get(obj.hModel.hStackManager.zs(obj.zRoi)).meshgrid();
                [xx, yy] = scanimage.mroi.util.xformMesh(xx, yy, obj.displayToRefTransform, true);
                xx = xx .';
                yy = yy .';
                set(obj.hRoiSurface(i), 'XData', xx, ...
                    'YData', yy, 'ZData', repmat(-1,size(xx)), ...
                    'CData', repmat(intmax('uint8'), [size(xx) 3]));
                
                xx = mesh2Outline(xx);
                yy = mesh2Outline(yy);
                set(obj.hRoiOutline(i), 'XData', xx, ...
                    'YData', yy, 'ZData', repmat(-1,size(xx)));
            end
            
            %update luts
            obj.roiLutChanged(obj.channelIdx);
            
            %update max fov to fit new rois
            obj.updateFit();
            
            
            obj.hFlipHMenu.Checked = most.idioms.ifthenelse(obj.hCameraWrapper.flipH,'on','off');
            obj.hFlipVMenu.Checked = most.idioms.ifthenelse(obj.hCameraWrapper.flipV,'on','off');
            obj.hRotateMenu.Text = sprintf('Rotation: %d°',obj.hCameraWrapper.rotate);
            
            function linepts = mesh2Outline(mesh)
                linepts = [...
                    mesh(1,1);...
                    mesh(1,end);...
                    mesh(end,end);...
                    mesh(end,1);...
                    mesh(1,1)];
            end
        end
        
        function updateZed(obj, src, ~)
            %update z level
            obj.zRoi = src.Value;
            obj.refreshRois();
        end
        
        function val = get.whiteLevel(obj)
            val = obj.hCameraWrapper.lut(2);
        end
        
        function set.whiteLevel(obj, val)
            if obj.blackLevel >= val
                return;
            end
            if ischar(val)
                val = str2double(val);
            end
            obj.hCameraWrapper.lut(2) = val;
            obj.updateHistogramLut();
        end
    end
end
function str = dat2str(dat)
if ischar(dat)
    str = ['''' dat ''''];
elseif isnumeric(dat) || islogical(dat)
    str = mat2str(dat);
else
    str = '<cannot render>';
end
end

%--------------------------------------------------------------------------%
% CameraView.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
