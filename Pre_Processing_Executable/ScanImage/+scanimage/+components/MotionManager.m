classdef MotionManager < scanimage.interfaces.Component
    % MotionManager Module
    %   contains functionality to detect, correct and display motion in live images
    
    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 1;
    end

    properties (Constant, Hidden)
        COMPONENT_NAME = 'MotionManager';       % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};       % Cell array of strings specifying properties that can be set while focusing
        PROP_TRUE_LIVE_UPDATE = {'enable','referenceZ','referenceRoi','lut','transparency','referenceImage','motionHistoryLength','showMotionDisplay','markerPositionsXY'}; % Cell array of strings specifying properties that can be set while the component is active
        DENY_PROP_LIVE_UPDATE = {'gpuAcceleration','detectMotionFcn','referenceImagePreprocessFcn'};             % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};          % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};    % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};          % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'referenceRoi','referenceImage','transparency','lut'};
    end
    
    %%% Class properties    
    properties (SetObservable)
        motionHistoryLength = 30;               % (numeric) Motion history in number of samples 
        detectMotionFcn = [];                   % Function handle pointing to motion detection function
        referenceImagePreprocessFcn = [];       % Function handle pointing to reference image preprocessing function
        
        gpuAcceleration = false;                % (logical) If built-in motion detection functions are used, switch GPU acceleration on/off (if GPU acceleration is available)
    end
    
    properties (SetObservable,Transient)
        enable = false;                         % (logical) enable/disable motion correction
        referenceRoi;                           % (scanimage.mroi.Roi) handle to imaging Roi, which is the reference for motion correction
        referenceZ = 0;                         % (numeric) z-slice on which the motion correction is applied
        referenceChannel = 1;                   % (numeric) channel on which the motion correction is applied
        referenceImage = [];                    % (NxM numeric matrix) reference image for the motion correction. Note: ScanImage stores images in column-major order. (i.e. images in the standard Matlab coordinate system need to be transposed)
        showMotionDisplay = false;              % (logical) show/hide the motion correction visualization window
    end
    
    properties (Constant,Hidden)
        FCN_BASE_PATH = '+scanimage\+components\+motionCorrection';
    end
    
    properties (Dependent, Hidden, Transient)
        transparency;                           % transparency in the motion display
        lut;                                    % lut in the motion display
        loggingEnabled;
    end
    
    properties (Hidden)
        markerPositionsXY = [];
    end
    
    properties (SetAccess = private,Hidden)
        csv_fid;
        viewDefaults = struct();
        hFig;
        hContainers;
        hControls;
        hAxes;
        hHistoryLine;
        hHistoryLineMarker;
        hLineCenter;
        hRefSurf;
        hImSurf;
        hText;
        hMarkerLine;
        hHgImTransform;
        hXProjectionAxes;
        hXProjectionLine;
        hXProjectionMarker;
        hYProjectionAxes;
        hYProjectionLine;
        hYProjectionMarker;
        hContextMenu;
        
        motionHistoryPt = [0,0];
        motionHistory;
        roisParsedMap;
        referenceImagePreprocessed = [];
        refDisplayImage = [];
        
        referenceBuffer = [];
        lastEstimatedMotion = eye(4);
        lastEstimatedOffset = [0,0];
    end
    
    %% Lifecycle
    methods (Hidden)
        function obj = MotionManager(hSI)
            obj@scanimage.interfaces.Component(hSI);
            obj.referenceRoi = scanimage.mroi.Roi.empty(1,0);
            
            obj.resetMotionHistory();
            
            projectionSizePx = 100;
            obj.hFig = handle(most.idioms.figureSquare('Name','Motion Correction Display','Visible','off','NumberTitle','off','Menubar','none','CloseRequestFcn',@obj.figCloseEventHandler,'WindowScrollWheelFcn',@obj.mouseWheelFcn));
            obj.hContainers.td1 = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                obj.hContainers.lr2_1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.td1,'FlowDirection','LeftToRight');
                    obj.hContainers.td3_1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.lr2_1,'FlowDirection','TopDown');
                    obj.hContainers.td3_1.WidthLimits = [projectionSizePx projectionSizePx];
                    obj.hContainers.td3_2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.lr2_1,'FlowDirection','TopDown');
                obj.hContainers.lr2_2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.td1,'FlowDirection','LeftToRight');
                    obj.hContainers.lr2_2.HeightLimits = [projectionSizePx projectionSizePx];
                    obj.hContainers.td3_3 = most.idioms.uiflowcontainer('Parent',obj.hContainers.lr2_2,'FlowDirection','TopDown');
                    obj.hContainers.td3_3.WidthLimits = [projectionSizePx projectionSizePx];
                        obj.hContainers.panel = uipanel('Parent',obj.hContainers.td3_3);
                            obj.hContainers.td4_1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.panel,'FlowDirection','TopDown');
                    obj.hContainers.td3_4 = most.idioms.uiflowcontainer('Parent',obj.hContainers.lr2_2,'FlowDirection','TopDown');
            
            obj.hContextMenu = uicontextmenu('Parent',obj.hFig,'Callback',@obj.contextMenuOpen);
                uimenu('Parent',obj.hContextMenu,'Label','Reset View','Callback',@(varargin)obj.resetView);
                uimenu('Parent',obj.hContextMenu,'Label','Correct motion with stage','Tag','uiMenuCorrectMotionWithStage','Callback',@(varargin)obj.correctMotionWithStage);
                    
            makeAxes(obj.hContainers.td3_2);
            makeXProjectionAxes(obj.hContainers.td3_1);
            makeYProjectionAxes(obj.hContainers.td3_4);
            
            obj.hControls.cbEnable = uicontrol('Parent',obj.hContainers.td4_1,'Style','checkbox','String','Enable','Value',false,'Callback',@(varargin)obj.toggleEnable);
            uicontrol('Parent',obj.hContainers.td4_1,'String','Configure','Callback',@(varargin)obj.hSI.hController{1}.showGUI('motionCorrectionControls'));
            uicontrol('Parent',obj.hContainers.td4_1,'String','Load Image','Callback',@(varargin)obj.loadReferenceImageFromFile);
            
            obj.transparency = 0.5;
            
            obj.detectMotionFcn = obj.detectMotionFcn;
            obj.referenceImagePreprocessFcn = obj.referenceImagePreprocessFcn;
            
            [gpuAvailable,gpu] = most.util.gpuComputingAvailable;
            if gpuAvailable
                obj.gpuAcceleration = true;
                fprintf('Motion detection: Using GPU %s for acceleration.\n',gpu.Name);
            end
            
            function makeAxes(container)
                tracecolor = [1 0 1];
                obj.hContainers.mainAxesCtr = uicontainer('Parent',container);
                obj.hAxes = handle(axes('Parent',obj.hContainers.mainAxesCtr,'Box','off','DataAspectRatio',[1 1 1],'Color','black',...
                    'YDir','reverse','ZDir','reverse','XTick',[],'YTick',[],'ZTick',[],'LooseInset',[0 0 0 0],...
                    'XTickLabel',[],'YTickLabel',[],'ZTickLabel',[],...
                    'ButtonDownFcn',@obj.buttonDownFcn,'UIContextMenu',obj.hContextMenu));
                obj.hRefSurf = handle(surface('Parent',obj.hAxes,'FaceColor','texturemap','EdgeColor','b','LineStyle',':','HitTest','off','PickableParts','none','XData',nan(2,2),'YData',nan(2,2),'ZData',nan(2,2),'CData',nan(2,2)));
                obj.hHgImTransform = handle(hgtransform('Parent',obj.hAxes));                
                obj.hHistoryLine = handle(line('Parent',obj.hAxes,'Color',tracecolor*0.5,'HitTest','off','PickableParts','none','XData',NaN,'YData',NaN));
                obj.hLineCenter = handle(line('Parent',obj.hAxes,'Color','w','Marker','+','MarkerSize',20,'HitTest','off','PickableParts','none','XData',NaN,'YData',NaN));  
                obj.hHistoryLineMarker = handle(line('Parent',obj.hAxes,'Color',tracecolor,'Marker','+','MarkerSize',15,'HitTest','off','PickableParts','none','XData',NaN,'YData',NaN));
                
                obj.hMarkerLine = handle(line('Parent',obj.hAxes,'Visible','off','Color',tracecolor,'LineStyle','none','Marker','x','HitTest','off','PickableParts','none'));
                obj.hText = handle(text('Parent',obj.hAxes,'String','','LineStyle','none','Color',[1 1 1],'HorizontalAlignment','right','VerticalAlignment','top','HitTest','off','PickableParts','none'));                
                
                obj.hImSurf = handle(surface('Parent',obj.hHgImTransform,'FaceColor','texturemap','FaceAlpha','texturemap','EdgeColor','b','HitTest','off','PickableParts','none','XData',nan(2,2),'YData',nan(2,2),'ZData',nan(2,2),'CData',nan(2,2)));
            end
            
            function makeXProjectionAxes(container)
                markercolor = [1 0 1];
                obj.hContainers.xProjectionAxesCtr = uicontainer('Parent',container);
                obj.hXProjectionAxes = handle(axes('Parent',obj.hContainers.xProjectionAxesCtr,...
                    'Box','on','Color','black','XColor','w','YColor','w','GridAlpha',1,'XGrid','on','GridColor','w','XMinorGrid','on','MinorGridAlpha',1,'MinorGridColor','w',...
                    'XTick',0,'YTick',[],'ZTick',[],'XTickLabel',[],'YTickLabel',[],'ZTickLabel',[],'LooseInset',[0 0 0 0]));
                obj.hXProjectionLine = line('Parent',obj.hXProjectionAxes,'Color','white','XData',NaN,'YData',NaN);
                obj.hXProjectionMarker = line('Parent',obj.hXProjectionAxes,'Color',markercolor,'Marker','o','XData',NaN,'YData',NaN);
                view(obj.hXProjectionAxes,90,-90);
            end
            
            function makeYProjectionAxes(container)
                markercolor = [1 0 1];
                obj.hContainers.yProjectionAxesCtr = uicontainer('Parent',container);
                obj.hYProjectionAxes = handle(axes('Parent',obj.hContainers.yProjectionAxesCtr,...
                    'Box','on','Color','black','XColor','w','YColor','w','GridAlpha',1,'XGrid','on','GridColor','w','XMinorGrid','on','MinorGridAlpha',1,'MinorGridColor','w',...
                    'XTick',0,'YTick',[],'ZTick',[],'XTickLabel',[],'YTickLabel',[],'ZTickLabel',[],'LooseInset',[0 0 0 0]));
                obj.hYProjectionLine = line('Parent',obj.hYProjectionAxes,'Color','white','XData',NaN,'YData',NaN);
                obj.hYProjectionMarker = line('Parent',obj.hYProjectionAxes,'Color',markercolor,'Marker','o','XData',NaN,'YData',NaN);
                view(obj.hYProjectionAxes,180,-90);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hContextMenu);
            most.idioms.safeDeleteObj(obj.hFig);
            obj.closeLoggingFile();
        end
    end
    
    %% User Functions
    methods
        function activateMotionCorrectionSimple(obj,channel)
            % Uses the last acquired image to set up and activate motion correction
            % If input 'channel' is omitted, the first available channel is used
            %
            % Usage
            %   obj.activateMotionCorrectionSimple()
            %   obj.activateMotionCorrectionSimple(channel)
            
            stripeData = obj.hSI.hDisplay.lastStripeData;
            roiData = stripeData.roiData{1};
            
            if nargin > 1 && ~isempty(channel)
                [tf,chIdx] = ismember(channel,roiData.channels);
                assert(tf,'Channel %d is currently not imaged',channel);
            else
                chIdx = 1; % use the first available channel
            end
            
            zIdx = 1;  % use the first available z            
            
            obj.referenceRoi = roiData.hRoi;
            obj.referenceChannel = roiData.channels(chIdx);
            obj.referenceZ = roiData.zs(zIdx);
            obj.referenceImage = roiData.imageData{chIdx}{zIdx};
            obj.enable = true;
            obj.raiseMotionDisplay();
        end
        
        function loadReferenceImageFromFile(obj,tifPath)
            % Shows a dialogLoads a reference image from a Tiff file. If
            % the Tiff file contains multiple frames, a dialog is shown
            % that allows to average multiple frames
            %
            % Usage
            %   obj.loadReferenceImageFromFile()  opens a file dialog to select a Tif file
            %   obj.loadReferenceImageFromFile(TifFilePath)
            
            if nargin < 2 || isempty(tifPath)
                [filename,pathname] = uigetfile('*.tif','Select a tif file for the reference image');
                if isequal(filename,0)
                    return %file dialog cancelled by user
                end
                tifPath = fullfile(pathname,filename);
            end
            
            try
                wasEnabled = obj.enable;
                obj.enable = false;
                
                tifInfo = imfinfo(tifPath);
                numFrames = length(tifInfo);
                selectedFrames = 1;
                
                if numFrames > 1
                    buttonPressed = questdlg('The selected Tif file contains more than one frame.','Multi frame tif detected',...
                        'Load first frame','Select frames to average','Average all frames','Load first frame');
                    
                    switch buttonPressed
                        case 'Load first frame'
                            selectedFrames = 1;
                        case 'Select frames to average'
                            inpt = inputdlg({'Select frames to average. Example: ''1 5:8 10'''},'Select frames',1,{sprintf('1:%d',numFrames)});
                            if isempty(inpt); return; end
                            selectedFrames = eval(sprintf('[%s]',inpt{1}));
                            assert(min(selectedFrames)>0 && max(selectedFrames)<=numFrames,'Selected Input exceeds number of frames in Tif');
                        case 'Average all frames'
                            selectedFrames = 1:numFrames;
                        otherwise
                            return
                    end
                end
                
                
                hTif = Tiff(tifPath,'r');
                refImData = [];
                
                % start averaging selected frames
                for frameIdx = selectedFrames
                    hTif.setDirectory(frameIdx);
                    frameData = double(hTif.read());
                    
                    %%%%% ImageJ workaround %%%%%
                    % ImageJ converts int16 data into uint16 by adding 2^15
                    % the offset is written into the ImageDescription ('c0=...')
                    % check if file was written by ImageJ and convert back
                    % to int16
                    if ismember('ImageDescription',hTif.getTagNames)
                        try
                            imDesc = hTif.getTag('ImageDescription');
                            imageJversion = regexpi(imDesc,'(?<=ImageJ=)\S*','match','once');
                            imageJoffset  = regexpi(imDesc,'(?<=c0=)\S*','match','once');
                            
                            if ~isempty(imageJversion) && ~isempty(imageJoffset)
                                frameData = double(frameData);
                                imageJoffset = str2double(imageJoffset);
                                frameData = frameData + imageJoffset;
                            end
                        catch
                            % In case the image description cannot be
                            % retrieved
                        end
                    end
                    %%%%% end workaround %%%%%
                    
                    frameData =  frameData ./ length(selectedFrames);
                    if isempty(refImData)
                        refImData = frameData;
                    else
                        refImData = refImData + frameData;
                    end
                end
                
                hTif.close();
                
                
                assert(~isempty(obj.hSI.hRoiManager.currentRoiGroup.rois),'Cannot set reference image when current Roi Group is empty');
                assert(~isempty(obj.hSI.hStackManager.zs),'Cannot set reference z if no zs are selected for imaging');
                assert(~isempty(obj.referenceChannel),'Cannot set reference channel if no channels are selected for imaging');
                
                if isempty(obj.referenceRoi) || ~ismember(obj.referenceRoi.uuiduint64,[obj.hSI.hRoiManager.currentRoiGroup.rois.uuiduint64]);
                    obj.referenceRoi = obj.hSI.hRoiManager.currentRoiGroup.rois(1);
                end
                
                if isempty(obj.referenceZ) || ~ismember(obj.referenceZ,obj.hSI.hStackManager.zs);
                    obj.referenceZ = obj.hSI.hStackManager.zs(1);
                end
                
                if isempty(obj.referenceChannel) || ~ismember(obj.referenceChannel,obj.hSI.hChannels.channelsActive);
                    obj.referenceChannel = obj.hSI.hChannels.channelsActive(1);
                end
                
                referenceRoiSelection();
                
                obj.referenceImage = refImData'; % ScanImage stores images transposed
                
                obj.enable = wasEnabled;
            catch ME
                if exist('hTif','var') && isvalid(hTif)
                    hTif.close();
                end
                
                most.idioms.reportError(ME);
            end
            
            function referenceRoiSelection()
                try
                    hFig_ = figure('Name','Choose Reference Roi','MenuBar','none','ToolBar','none','NumberTitle','off','Visible','off');
                    hFig_.Position([3,4]) = [400 150];
                    movegui(hFig_,'center');
                    containers.top = most.idioms.uiflowcontainer('Parent',hFig_,'FlowDirection','TopDown');
                        containers.roi = most.idioms.uiflowcontainer('Parent',containers.top,'FlowDirection','LeftToRight');
                            containers.roi.HeightLimits = [30 30];
                            [~,idx] = ismember(obj.referenceRoi.uuiduint64,[obj.hSI.hRoiManager.currentRoiGroup.rois.uuiduint64]);
                            h = uicontrol('Parent',containers.roi,'Style', 'text', 'String', 'Reference ROI','HorizontalAlignment','right');
                            h.WidthLimits = [100,100];
                            uicontrol('Parent',containers.roi, 'Style', 'popup','String', {obj.hSI.hRoiManager.currentRoiGroup.name},'Callback', @setRoi, 'Value', idx);
                        containers.z = most.idioms.uiflowcontainer('Parent',containers.top,'FlowDirection','LeftToRight');
                            containers.z.HeightLimits = [30 30];
                            [~,idx] = ismember(obj.referenceZ,obj.hSI.hStackManager.zs);
                            h = uicontrol('Parent',containers.z,'Style', 'text', 'String', 'Reference Z','HorizontalAlignment','right');
                            h.WidthLimits = [100,100];
                            uicontrol('Parent',containers.z, 'Style', 'popup','String', arrayfun(@(z)sprintf('Z = %.3f',z),obj.hSI.hStackManager.zs,'UniformOutput',false),'Callback', @setZ, 'Value', idx);
                        containers.chan = most.idioms.uiflowcontainer('Parent',containers.top,'FlowDirection','LeftToRight');
                            containers.chan.HeightLimits = [30 30];
                            [~,idx] = ismember(obj.referenceChannel,obj.hSI.hChannels.channelsActive);
                            h = uicontrol('Parent',containers.chan,'Style', 'text', 'String', 'Reference Channel','HorizontalAlignment','right');
                            h.WidthLimits = [100,100];
                            uicontrol('Parent',containers.chan, 'Style', 'popup','String', arrayfun(@(ch)sprintf('Channel %d',ch),obj.hSI.hChannels.channelsActive,'UniformOutput',false),'Callback', @setChannel, 'Value', idx);
                        containers.ok = most.idioms.uiflowcontainer('Parent',containers.top,'FlowDirection','LeftToRight');
                            %containers.ok.HeightLimits = [40 40];
                            uicontrol('Parent',containers.ok,'String','Ok','Callback',@(varargin)delete(hFig_));
                    hFig_.Visible = 'on';
                    uiwait(hFig_);
                catch ME
                    hFig_.delete();
                    rethrow(ME);
                end
            end
            
            function setRoi(src,~)
                obj.referenceRoi = obj.hSI.hRoiManager.currentRoiGroup.rois(src.Value);
            end
            
            function setZ(src,~)
                obj.referenceZ = obj.hSI.hStackManager.zs(src.Value);
            end
            
            function setChannel(src,~)
                obj.referenceChannel = obj.hSI.hChannels.channelsActive(src.Value);
            end
        end
        
        function resetLastEstimatedMotion(obj)
            % Resets the last estimated motion correction
            %
            % Usage
            %     obj.resetLastEstimatedMotion()
            
            obj.lastEstimatedMotion = eye(4);
            obj.lastEstimatedOffset = [0,0];
        end
        
        function correctMotionWithStage(obj)
            % Moves the stage to correct for the detected motion offset
            %
            % Usage
            %   obj.correctMotionWithStage()
            
            [x,y] = obj.getMotionMotorOffset();
            assert(~isnan(x) && ~isnan(y),'motorRoRefTransform is invalid. Perform motor calibration first.');
            
            if x==0 && y==0
                return
            end
            
            motorPosition = obj.hSI.hMotors.motorPosition;
            motorPosition(1:2) = motorPosition(1:2) + [x,y];
            obj.hSI.hMotors.motorPosition = motorPosition;
        end
        
        function [x,y] = getMotionMotorOffset(obj)
            % Calculates the x,y offset in motor (stage) coordinates due to
            % motion
            %
            % Usage:
            %   [x,y] = getMotionMotorOffset
            
            if ~obj.hSI.hMotors.motorToRefTransformValid
                x = NaN;
                y = NaN;
                return
            end
            
            if isempty(obj.lastEstimatedMotion) || iseye(obj.lastEstimatedMotion)
                x = 0;
                y = 0;
                return
            end
            
            refPt = [0,0,0];
            refMotorPt = scanimage.mroi.util.xformPoints(refPt(1:2),obj.hSI.hMotors.motorToRefTransform,true);
            
            motionPt = scanimage.mroi.util.xformPoints(refPt,obj.lastEstimatedMotion,true);
            motionMotorPt = scanimage.mroi.util.xformPoints(motionPt(1:2),obj.hSI.hMotors.motorToRefTransform,true);
            
            d = motionMotorPt-refMotorPt;
            
            x = d(1);
            y = d(2);
            
            function tf = iseye(A)
                tf = isdiag(A) && all(diag(A)==1);
            end
        end
        
        function resetReferenceImage(obj)
            % Resets the reference image to an empty matrix
            %
            % Usage
            %   obj.resetReferenceImage()
            
            obj.referenceImage = [];
            obj.resetLastEstimatedMotion();
            obj.resetMotionHistory();
        end
        
        function resetMotionHistory(obj)
            % Resets the motion history array
            %
            % Usage
            %   obj.resetMotionHistory()
            
            obj.motionHistory = NaN(obj.motionHistoryLength,2);
            obj.updateMotionHistoryDisplay();
        end
        
        function resetView(obj)
            % Resets the view in the motion history display
            %
            % Usage
            %   obj.resetView()
            
            if isstruct(obj.viewDefaults) && isfield(obj.viewDefaults,'XLim') && isfield(obj.viewDefaults,'YLim')
                obj.hAxes.XLim = obj.viewDefaults.XLim;
                obj.hAxes.YLim = obj.viewDefaults.YLim;
                obj.updateTextPosition();
            end
        end
        
        function raiseMotionDisplay(obj)
            % sets showMotionDisplay to true and raises the motion display
            % window to top
            %
            % Usage
            %   obj.raiseMotionDisplay();
            
            if ~obj.showMotionDisplay
                obj.showMotionDisplay = true;
            end
            
            figure(obj.hFig);
        end
    end
    
    %% Internal Functions
    methods (Hidden)
        function estimateMotion(obj,stripeData)
            if (~obj.enable && ~obj.showMotionDisplay) || isempty(obj.referenceRoi)
                return
            end
            
            if isempty(stripeData.roiData)
                return
            end
            
            roiDatas = [stripeData.roiData{:}];
            roidatasRois = [roiDatas.hRoi];
            [tf,idx] = ismember(obj.referenceRoi.uuiduint64,[roidatasRois.uuiduint64]);
            if tf
                roiData = stripeData.roiData{idx};
                chanidx = ismembc2(obj.referenceChannel,roiData.channels);
                zidx = ismembc2(obj.referenceZ,roiData.zs);
                if chanidx ~= 0 && zidx ~= 0
                    imageData = roiData.imageData{chanidx}{zidx};
                    imageDataTransposed = roiData.transposed;
                    
                    if ~obj.enable && obj.showMotionDisplay
                        if stripeData.startOfFrame && stripeData.endOfFrame
                            obj.hImSurf.AlphaData = imageData;
                        end
                        return
                    end
                else
                    stripeData.motionMatrix = obj.lastEstimatedMotion;
                    return
                end
            else
                stripeData.motionMatrix = obj.lastEstimatedMotion;
                return
            end
            
            if isempty(obj.referenceImage) || isempty(obj.referenceBuffer)
                return
            end
            
            if ~(stripeData.startOfFrame && stripeData.endOfFrame)
                most.idioms.warn('Motion correction cannot be activated when striping display is used.');
                obj.enable = false;
                return
            end
            
            try
                [success,ijOffset,quality,cii,cjj] = obj.detectMotionFcn(obj.referenceImagePreprocessed,imageData);
            catch ME
                obj.enable = false;
                most.idioms.reportError(ME);
                most.idioms.warn('Error in detectMotionFcn. Disabling motion correction.');
                return
            end
            
            if success
                if imageDataTransposed
                    xPixOff = ijOffset(1);
                    yPixOff = ijOffset(2);
                else
                    xPixOff = ijOffset(2);
                    yPixOff = ijOffset(1);
                end
                obj.lastEstimatedOffset = [xPixOff,yPixOff];
            else
                xPixOff = obj.lastEstimatedOffset(1);
                yPixOff = obj.lastEstimatedOffset(2);
            end
            
            pixSfT = eye(3);
            pixSfT(1,3) = xPixOff;
            pixSfT(2,3) = yPixOff;
            T = obj.referenceBuffer.scanfieldPixelToRefTransform * pixSfT / obj.referenceBuffer.scanfieldPixelToRefTransform;
            
            obj.motionHistory = circshift(obj.motionHistory,-1,1);
            obj.motionHistory(end,:) = scanimage.mroi.util.xformPoints(obj.motionHistoryPt,T);
            
            obj.lastEstimatedMotion = scanimage.mroi.util.affine2Dto3D(T);
            
            stripeData.motionMatrix = obj.lastEstimatedMotion;
            obj.calculateRoiPixelOffsets(stripeData); % fill out the roidata motionOffset property
            
            if obj.loggingEnabled
                if ~obj.isLoggingFileOpen()
                    obj.initLoggingFile();
                end
                
                fprintf(obj.csv_fid, '%f,%d,%d,%f,%s,%s,%s,%f,%d\r\n',...
                    stripeData.frameTimestamp,...
                    stripeData.frameNumberAcqMode,...
                    success,...
                    quality,...
                    mat2str([xPixOff yPixOff]),...
                    obj.referenceRoi.name,...
                    mat2str(obj.lastEstimatedMotion),...
                    obj.referenceZ,...
                    obj.referenceChannel);
            end
            
            if obj.showMotionDisplay
                obj.hImSurf.AlphaData = imageData;
                [xMotorOff,yMotorOff] = obj.getMotionMotorOffset();
                if isnan(xMotorOff) || isnan(yMotorOff)
                    obj.hText.String = sprintf('Pixel Offset x: %d y: %d ',xPixOff,yPixOff);
                else
                    obj.hText.String = sprintf('Pixel Offset x: %d y: %d \nMotor Offset x: %.3f y: %.3f '...
                        ,xPixOff,yPixOff,xMotorOff,yMotorOff);
                end
                obj.updateMotionHistoryDisplay();
                obj.updateProjectionViews(xPixOff,yPixOff,cii,cjj);
            end
        end
        
        function calculateRoiPixelOffsets(obj,stripeData)
            for idx = 1:length(stripeData.roiData)
                roiData = stripeData.roiData{idx};
                roiData.motionOffset = zeros(2,length(roiData.zs));
                
                s = obj.roisParsedMap(roiData.hRoi.uuiduint64);
                zidx = ismembc2(roiData.zs,s.zs);
                
                
                for jdx = 1:length(zidx)
                    pixelToRefTransform = s.pixelToRefTransforms{zidx(jdx)};
                    T = (stripeData.motionMatrix * pixelToRefTransform) \ pixelToRefTransform;
                    roiData.motionOffset(:,jdx) = [T(1,4);T(2,4)];
                end
            end
        end
        
        function updateMotionHistoryDisplay(obj)            
            obj.hHistoryLine.XData = obj.motionHistory(:,1);
            obj.hHistoryLine.YData = obj.motionHistory(:,2);
            
            obj.hHistoryLineMarker.XData = obj.motionHistory(end,1);
            obj.hHistoryLineMarker.YData = obj.motionHistory(end,2);
            obj.hHistoryLineMarker.ZData = -2;
        end
        
        function updateProjectionViews(obj,xPixOff,yPixOff,cii,cjj)
            if nargin < 2 || isempty(xPixOff)
                xPixOff = 0;
            end
            
            if nargin < 3 || isempty(yPixOff)
                yPixOff = 0;
            end
            
            if nargin < 4 || isempty(cii);
                cii = [];
            end
            
            if nargin < 5 || isempty(cjj)
                cjj = [];
            end
            
            yy = cjj(:);
            xx = linspace(-floor(length(yy)./2),ceil(length(yy)./2)-1,length(yy))';
            obj.hXProjectionLine.XData = xx;
            obj.hXProjectionLine.YData = yy(:);
            if ~isempty(xx)
                obj.hXProjectionAxes.XLim = [xx(1) xx(end)];
                idx = find(xx==-yPixOff,1);
                obj.hXProjectionMarker.XData = xx(idx);
                obj.hXProjectionMarker.YData = yy(idx);
            else
                obj.hXProjectionMarker.XData = NaN;
                obj.hXProjectionMarker.YData = NaN;
            end
            
            yy = cii(:);
            xx = linspace(-floor(length(yy)./2),ceil(length(yy)./2)-1,length(yy))';
            obj.hYProjectionLine.XData = xx;
            obj.hYProjectionLine.YData = yy(:)';
            if ~isempty(xx)
                obj.hYProjectionAxes.XLim = [xx(1) xx(end)];
                idx = find(xx==-xPixOff,1);
                obj.hYProjectionMarker.XData = xx(idx);
                obj.hYProjectionMarker.YData = yy(idx);
            else
                obj.hYProjectionMarker.XData = NaN;
                obj.hYProjectionMarker.YData = NaN;
            end
        end
        
        function figCloseEventHandler(obj,src,evt)
            if isvalid(obj)
                obj.showMotionDisplay = false;
            else
                delete(src);
            end                
        end
        
        function updateReferenceBuffer(obj)
            buffer = [];
            if ~isempty(obj.referenceRoi) && isvalid(obj.referenceRoi)
                sf = obj.referenceRoi.get(obj.referenceZ);
                if ~isempty(sf)
                    buffer.sf = sf;
                    buffer.scanfieldTransform = sf.affine;
                    buffer.scanfieldPixelToRefTransform = sf.pixelToRefTransform;
                    buffer.resolution = sf.pixelResolution;
                    buffer.centerXY = sf.centerXY;
                end
            end
            obj.referenceBuffer = buffer;            
        end
        
        function checkReferenceConfiguration(obj)
            if isempty(obj.referenceRoi)
                most.idioms.warn('Motion Correction: No reference ROI is selected');
            elseif ~ismember(obj.referenceRoi.uuiduint64,[obj.hSI.hRoiManager.currentRoiGroup.rois.uuiduint64])
                
                most.idioms.warn('Motion Correction: Reference ROI is currently not imaged');
            end
            
            if isempty(obj.referenceImage)
                most.idioms.warn('Motion Correction: Reference Image is empty');
            end
            
            if isempty(obj.referenceZ) || ~ismember(obj.referenceZ,obj.hSI.hStackManager.zs)
                most.idioms.warn('Motion Correction: Reference z-slice is not imaged');
            end
            
            if isempty(obj.referenceChannel) || ~ismember(obj.referenceChannel,obj.hSI.hChannels.channelsActive)
                most.idioms.warn('Motion Correction: Reference channel is not imaged');
            end
        end
        
        function parseRois(obj)
            obj.roisParsedMap = containers.Map('KeyType','uint64','ValueType','any');
            zs = sort(obj.hSI.hStackManager.zs); % sorting is required for ismembc2
            imagingRoiGroup = obj.hSI.hRoiManager.currentRoiGroup;
            
            for roi = imagingRoiGroup.rois
                if isempty(roi.scanfields)
                    continue
                end
                
                s = struct(...
                    'zs',[],...
                    'pixelToRefTransforms',{{}});
                
                for z = zs
                    sf = roi.get(z);
                    if ~isempty(sf)
                        s.zs(end+1) = z;
                        s.pixelToRefTransforms{end+1} = scanimage.mroi.util.affine2Dto3D(sf.pixelToRefTransform);
                    end
                end
                
                obj.roisParsedMap(roi.uuiduint64) = s;
            end
        end
        
        function buttonDownFcn(obj,src,evt)
            obj.pan();
        end
        
        function updateTextPosition(obj)
            obj.hText.Position = [obj.hAxes.XLim(2),obj.hAxes.YLim(1)];
        end
        
        function pan(obj,mode)
            if nargin<2 || isempty(mode)
                mode = 'start';
            end
            
            persistent dragData
            persistent originalConfig
            
            try
                switch lower(mode)
                    case 'start'
                        dragData = struct();
                        dragData.startPoint = axPt(obj.hAxes);
                        dragData.startXLim = obj.hAxes.XLim;
                        dragData.startYLim = obj.hAxes.YLim;
                        
                        originalConfig = struct();
                        originalConfig.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        originalConfig.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.pan('move');
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.pan('stop');
                    case 'move'
                        currentPoint = axPt(obj.hAxes);
                        currentXLim = obj.hAxes.XLim;
                        currentYLim = obj.hAxes.YLim;
                        
                        d(1) = currentPoint(1) - currentXLim(1) + dragData.startXLim(1);
                        d(2) = currentPoint(2) - currentYLim(1) + dragData.startYLim(1);
                        
                        d = d - dragData.startPoint;
                        
                        newxlim = dragData.startXLim-d(1);
                        newylim = dragData.startYLim-d(2);
                        
                        obj.hAxes.XLim = newxlim;
                        obj.hAxes.YLim = newylim;
                    
                        obj.updateTextPosition();
                    case 'stop'
                        abort();
                    otherwise
                        assert(false);
                end
            catch ME
                abort();
                rethrow(ME);
            end
            
            %%% local function
            function abort()
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonMotionFcn');
                    obj.hFig.WindowButtonMotionFcn = originalConfig.WindowButtonMotionFcn;
                else
                    obj.hFig.WindowButtonMotionFcn = [];
                end
                
                if isstruct(originalConfig) && isfield(originalConfig,'WindowButtonUpFcn');
                    obj.hFig.WindowButtonUpFcn = originalConfig.WindowButtonUpFcn;
                else
                    obj.hFig.WindowButtonUpFcn = [];
                end
                
                startPoint = [];
                originalConfig = struct();
            end
        end
        
        function mouseWheelFcn(obj,src,evt)
            mod = get(obj.hFig, 'currentModifier');
            
            if isempty(mod)
                currentPoint = axPt(obj.hAxes);
                xlim = obj.hAxes.XLim;
                ylim = obj.hAxes.YLim;
                
                % check if currentPoint is within axes
                ptWithinAx = (currentPoint(1) > xlim(1)) && (currentPoint(1) < xlim(2)) && (currentPoint(2) > ylim(1)) && (currentPoint(2) < ylim(2));
                if ~ptWithinAx
                    return
                end
                
                zoomSpeedFactor = 2;
                maxZoom = 129; % pick 2^x + 1 to account for floating point inaccuracy
                
                doubleVerticalScrollCount = double(evt.VerticalScrollCount);
                scroll = zoomSpeedFactor ^ doubleVerticalScrollCount;
                
                % center zoom around current mouse position
                newxlim = (xlim - currentPoint(1)) * scroll + currentPoint(1);
                newylim = (ylim - currentPoint(2)) * scroll + currentPoint(2);
                
                %enforce boundaries
                if ~(isfield(obj.viewDefaults,'XLim') && isfield(obj.viewDefaults,'YLim'))
                    return
                end
                
                if newxlim(1) <= obj.viewDefaults.XLim(1) || newxlim(2) >= obj.viewDefaults.XLim(2) || ...
                        newylim(1) <= obj.viewDefaults.YLim(1) || newylim(2) >= obj.viewDefaults.YLim(2)
                    
                    obj.resetView();
                    return
                end
                
                if diff([0 1])/diff(newxlim) > maxZoom
                    return
                end
                
                obj.hAxes.XLim = newxlim;
                obj.hAxes.YLim = newylim;
                
                obj.updateTextPosition();
            else
                scrollSpeedFactor = 0.1;
                
                doubleVerticalScrollCount = double(evt.VerticalScrollCount);
                scroll = doubleVerticalScrollCount * scrollSpeedFactor;
                
                obj.transparency = min(max(obj.transparency + scroll,0),1);
            end
        end
        
        function toggleEnable(obj)
            obj.enable = ~obj.enable;
        end
        
        function contextMenuOpen(obj,src,evt)
            if obj.hSI.hMotors.motorToRefTransformValid
                status = 'on';
            else
                status = 'off';
            end
            set(findall(src,'Tag','uiMenuCorrectMotionWithStage'),'Enable',status);
        end
    end
    
    %%% ABSTRACT METHOD IMPLEMENTATONS (scanimage.interfaces.Component)
    methods (Hidden, Access = protected)
        function componentStart(obj)
            obj.resetMotionHistory();
            if obj.enable
                obj.checkReferenceConfiguration();
                obj.parseRois();
            end
        end
        
        function componentAbort(obj)
            obj.closeLoggingFile();
        end
    end
    
    methods (Hidden, Access = private)
        function initLoggingFile(obj)
            if obj.hSI.hChannels.loggingEnable && obj.enable
                obj.csv_fid = fopen(fullfile(obj.hSI.hScan2D.logFilePath, ...
                    [obj.hSI.hScan2D.logFileStem '_Motion_' sprintf('%05d', obj.hSI.hScan2D.logFileCounter) '.csv'] ),'W');
                fprintf(obj.csv_fid, 'timestamp,frameNumber,success,quality,xyMotion,roiUuid,motionMatrix,z,channel\r\n');
            end
        end
        
        function val = isLoggingFileOpen(obj)
            val = ~isempty(obj.csv_fid) && obj.csv_fid > 0;            
        end
        
        function closeLoggingFile(obj)
            if obj.isLoggingFileOpen
                fclose(obj.csv_fid);
            end
            obj.csv_fid = [];
        end
        
        function refreshReferenceImageDisplay(obj)
            refcolor = [0 255 0];
            
            lut_ = double(obj.lut);
            
            obj.hAxes.CLim = lut_;
            obj.hAxes.ALim = lut_;
            
            imdata = min(max(double(obj.refDisplayImage),lut_(1)),lut_(2));
            imdata = (imdata - lut_(1))./lut_(2);
            cdata = repmat(reshape(refcolor,1,1,[]),size(imdata));
            
            for idx = 1:size(cdata,3)
                cdata(:,:,idx) = cdata(:,:,idx) .* imdata;
            end
            cdata = uint8(cdata);
            
            obj.hRefSurf.CData = cdata;
            
            imcolor = uint8([255 0 0]);
            obj.hImSurf.CData = repmat(reshape(imcolor,1,1,[]),size(obj.refDisplayImage));
            obj.hImSurf.AlphaData = -inf(size(obj.refDisplayImage));
        end
    end
    
    %% Property getter/setter
    methods
        function set.gpuAcceleration(obj,val)
            val = obj.validatePropArg('gpuAcceleration',val);
            
            if obj.componentUpdateProperty('gpuAcceleration',val)                
                if val
                    assert(most.util.gpuComputingAvailable, 'MotionManager: Gpu computing is not available');
                end
                
                oldVal = obj.gpuAcceleration;
                obj.gpuAcceleration = logical(val);
                
                if oldVal ~= val
                    obj.detectMotionFcn = [];
                    obj.referenceImagePreprocessFcn = [];
                end
            end
        end
        
        function set.detectMotionFcn(obj,val)
            if isempty(val)
                if obj.gpuAcceleration
                    val = @scanimage.components.motionCorrection.fftCorrGpu_detectMotionFcn;
                else
                    val = @scanimage.components.motionCorrection.fftCorr_detectMotionFcn;
                end
            end
            
            val = obj.validatePropArg('detectMotionFcn',val);
            
            if obj.componentUpdateProperty('detectMotionFcn',val)                
                obj.detectMotionFcn = val;
            end
        end
        
        function set.referenceImagePreprocessFcn(obj,val)
            if isempty(val)
                if obj.gpuAcceleration
                    val = @scanimage.components.motionCorrection.fftCorrGpu_preprocessFcn;
                else
                    val = @scanimage.components.motionCorrection.fftCorr_preprocessFcn;
                end
            end
            
            val = obj.validatePropArg('referenceImagePreprocessFcn',val);
            
            if obj.componentUpdateProperty('referenceImagePreprocessFcn',val)                
                obj.referenceImagePreprocessFcn = val;
                obj.referenceImage = obj.referenceImage; % reprocess reference Image with referenceImagePreprocessFcn
            end
        end
        
        function set.referenceZ(obj,val)
            val = obj.validatePropArg('referenceZ',val);
            
            if obj.componentUpdateProperty('referenceZ',val)
                obj.referenceZ = val;
                obj.updateReferenceBuffer();
            end
        end
        
        function set.referenceRoi(obj,val)
            if isempty(val)
                val = scanimage.mroi.Roi.empty(1,0);
            end
            
            val = obj.validatePropArg('referenceRoi',val);
            
            if obj.componentUpdateProperty('referenceRoi',val)
                obj.referenceRoi = val;
                obj.updateReferenceBuffer();
                obj.resetLastEstimatedMotion();
                obj.resetMotionHistory();
                obj.markerPositionsXY = [];
                
                obj.hText.String = '';
                
                if ~isempty(obj.referenceBuffer)
                    [xx,yy,zz] = meshgrid([0,1],[0,1],1);
                    [xx,yy] = scanimage.mroi.util.xformMesh(xx,yy,obj.referenceBuffer.scanfieldTransform);
                    xx = xx';
                    yy = yy';
                    
                    obj.hRefSurf.XData = xx;
                    obj.hRefSurf.YData = yy;
                    obj.hRefSurf.ZData = 2*zz;
                    
                    obj.hImSurf.XData = xx;
                    obj.hImSurf.YData = yy;
                    obj.hImSurf.ZData = 1*zz;
                    
                    xspan = [min(xx(:)),max(xx(:))];
                    yspan = [min(yy(:)),max(yy(:))];
                    
                    span = max(diff(xspan),diff(yspan));
                    obj.viewDefaults.XLim = [mean(xspan)-span, mean(xspan)+span];
                    obj.viewDefaults.YLim = [mean(yspan)-span, mean(yspan)+span];
                    
                    obj.resetView();
                    obj.updateProjectionViews();
                    obj.updateTextPosition();
                    
                    ctrPt = [sum(xspan),sum(yspan)]./2;
                    obj.motionHistoryPt = ctrPt;
                    
                    obj.hLineCenter.XData = ctrPt(1);
                    obj.hLineCenter.YData = ctrPt(2);
                    obj.hLineCenter.ZData = -1;
                end
            end
        end
        
        function set.lut(obj,val)
            if obj.componentUpdateProperty('lut',val)
                obj.refreshReferenceImageDisplay();
            end
        end
        
        function val = get.lut(obj)
            val = [0 100];
            if ~isempty(obj.referenceChannel)
                try
                    prop = sprintf('chan%dLUT',obj.referenceChannel);
                    val = double(obj.hSI.hDisplay.(prop));
                catch
                end
            end
        end
        
        function val = get.loggingEnabled(obj)
            val = obj.hSI.hChannels.loggingEnable && obj.enable;
        end
        
        function set.transparency(obj,val)
            val = obj.validatePropArg('transparency',val);
            if obj.componentUpdateProperty('transparency',val)
                obj.hFig.Alphamap = linspace(0,val,64);
            end
        end
        
        function val = get.transparency(obj)
            val = obj.hFig.Alphamap(end);
        end
        
        function set.referenceImage(obj,val)
            if isempty(val)
                obj.refDisplayImage = [];
                obj.referenceImagePreprocessed = [];
            else
                [obj.refDisplayImage,obj.referenceImagePreprocessed] = obj.referenceImagePreprocessFcn(val);
            end
            
            if obj.componentUpdateProperty('referenceImage',val)
                obj.refreshReferenceImageDisplay();
                obj.referenceImage = val;
            end
        end
        
        function set.motionHistoryLength(obj,val)
            val = obj.validatePropArg('motionHistoryLength',val);
            if obj.componentUpdateProperty('motionHistoryLength',val)
                obj.motionHistoryLength = val;
                obj.resetMotionHistory();
            end
        end
        
        function set.enable(obj,val)
            val = obj.validatePropArg('enable',val);
            
            if obj.componentUpdateProperty('enable',val)
                obj.enable = val;
                
                if ~obj.enable
                    obj.resetLastEstimatedMotion();
                    obj.hText.String = '';
                    obj.updateProjectionViews();
                end
                
                if obj.enable && obj.active
                    obj.checkReferenceConfiguration();
                    obj.parseRois();
                end
                
                obj.resetMotionHistory();
                obj.hControls.cbEnable.Value = obj.enable;
            end
        end
        
        function set.showMotionDisplay(obj,val)
            val = obj.validatePropArg('showMotionDisplay',val);
            
            if obj.componentUpdateProperty('showMotionDisplay',val)
                if val
                    obj.hFig.Visible = 'on';
                    obj.updateMotionHistoryDisplay();
                else
                    obj.hFig.Visible = 'off';
                end
                
                obj.showMotionDisplay = val;
            end
        end
        
        function set.markerPositionsXY(obj,val)
            if isempty(val)
                val = double.empty(0,2);
            end
            
            val = obj.validatePropArg('markerPositionsXY',val);
            
            if obj.componentUpdateProperty('markerPositionsXY',val)
                obj.markerPositionsXY = val;
                
                if isempty(val)
                    obj.hMarkerLine.XData = [];
                    obj.hMarkerLine.YData = [];
                    obj.hMarkerLine.ZData = [];
                    obj.hMarkerLine.Visible = 'off';
                else
                    %ptsSf = scanimage.mroi.util.xformPoints(val,obj.referenceBuffer.scanfieldTransform,true);
                    obj.hMarkerLine.XData = val(:,1);
                    obj.hMarkerLine.YData = val(:,2);
                    obj.hMarkerLine.ZData = 2*ones(size(val,1),1);
                    obj.hMarkerLine.Visible = 'on';
                end
            end
        end
        
        function set.lastEstimatedMotion(obj,val)
            obj.lastEstimatedMotion = val;
            obj.hHgImTransform.Matrix = val;
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s.enable = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.showMotionDisplay = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.detectMotionFcn = struct('Classes','function_handle','Attributes',{{'scalar'}});
    s.referenceImagePreprocessFcn = struct('Classes','function_handle','Attributes',{{'scalar'}});
    s.gpuAcceleration = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.referenceRoi = struct('Classes','scanimage.mroi.Roi','Attributes',{{}},'AllowEmpty',1);
    s.referenceZ = struct('Classes','numeric','Attributes',{{'scalar','nonnan','finite'}});
    s.lut = struct('DependsOn',{{'hSI.hDisplay.chan1LUT','hSI.hDisplay.chan2LUT','hSI.hDisplay.chan3LUT','hSI.hDisplay.chan4LUT'}});
    s.transparency = struct('Classes','numeric','Attributes',{{'scalar','nonnan','nonnegative','>=',0,'<=',1}});
    s.motionHistoryLength = struct('Classes','numeric','Attributes',{{'scalar','nonnan','nonnegative','finite','integer'}});
    s.markerPositionsXY = struct('Classes','numeric','Attributes',{{'ncols',2}},'AllowEmpty',1);
end

function pt = axPt(hAx)
    cp = hAx.CurrentPoint;
    pt = cp(1,1:2);
end

%--------------------------------------------------------------------------%
% MotionManager.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
