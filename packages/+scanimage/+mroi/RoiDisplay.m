classdef RoiDisplay < handle
    properties
        zs   = [0];             % [numeric] array of zs that are viewed in this object     
        chan = [];              % [numeric] scalar channel being displayed in this Axes object
        showCrosshair = false;  % [boolean] show/hide crosshair in display
        debugEnabled = false;   % [boolean] show/hide roiData debug in the ROI label.
        transposeImage = true;  % roiData.imageData stores images transposed
        parent;                 % parent graphic handle
        dataMultiplier = 1;
        CLim = [0,100];
        projectionsVisible = false;
        zSpacing = 10;        % [numeric] scalar used to control scanfield Z-spacing in 3D display.
        motionMatrix = eye(4);
        stabilizeDisplay = false;
        tfMap = containers.Map({true false}, {'on' 'off'});
        lastClickedSurfPoint;
    end
    
    properties (Hidden)
        hLinePhotostimMonitor;
    end

    properties (SetAccess = private, Hidden)
        hSI;
        hAxes;
        hMotionContainer;
        hMotionContainerOnTop;
        hInverseMotionContainer;
        hSurfs;
        hMainSurfs;
        roiMap;
        labelMap;
        hCrossHair;
        hUicMain;
        hAnnotationAx;
        hUicFlowMain;
        hSurfContextMenu;
        hAxesContextMenu;
        hAnnotationMenu;
        hCursor;
        hOnTopGroup;
        hHighlightGroup;
        hLiveHistograms = [];
        hMeasureGroup;
        hPatchMeasure;
        hLineMeasure;
        hTextMeasure;
        hUicFlowProjections;
        hZSpacingSlider;
        hAxesProjectionX;
        hMotionContainerProjectionX;
        hAxesProjectionY;
        hMotionContainerProjectionY;
%         is3dview;
        is3dview = false;
        isCurrentView;
        isTiledView;
        isMaxProjView;
        lastDrawnZSurfs = matlab.graphics.chart.primitive.Surface.empty;
        hBackSurfs = matlab.graphics.chart.primitive.Surface.empty;
        lastDrawnZ = nan;
        
        zSurfs = {};
        zSurfProps = {};
        currPos = [0 0];
        currFov = 10;
        maxXrg;
        maxYrg;
    end
    
    properties (SetAccess = private, Hidden, Dependent)
        hFig;
    end
    
    properties (Constant, Hidden)
        graphics2014b = most.idioms.graphics2014b(); % cache this for performance
        transparency3d = true;
    end
    
    % Dependent Properties
    properties (Dependent)
        cameraProps;     % struct containing camera properties for 3D view.
    end
    
    methods
        function obj = RoiDisplay(hSI,parent,chan)
            if nargin < 1 || isempty(parent)
                parent = figure();
            end
            
            obj.hSI = hSI;
            rg = hSI.hRoiManager.refAngularRange;
            obj.maxXrg = [-.5 .5] * rg(1);
            obj.maxYrg = [-.5 .5] * rg(2);
            
            obj.hUicMain = handle(uicontainer('Parent',parent,'DeleteFcn',@(src,evt)most.idioms.safeDeleteObj(obj)));
            obj.parent = parent;
            obj.chan = chan;
            
            obj.hFig.WindowButtonMotionFcn = @obj.hover;
            
            obj.hSurfContextMenu = handle(uicontextmenu('Parent',obj.hFig,'Callback',@obj.contextMenuOpen));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Autoscale Contrast','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.autoRoiContrast));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Histogram','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.showSurfHistogram));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Image Stats','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.surfImageStats));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Pixel Value','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.pixelValue));
                uimenu('Parent',obj.hSurfContextMenu,'Separator','on','Label','Reset View','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.resetview));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Center Stage','Tag','uiMenuCenterStage','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.centerStage));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Measure','Tag','uiMenuMeasure','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.measure));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Hide Cursor / Measurement','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.hideCursor));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Show Crosshair','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.toggleCrosshair));
                hAnMenu = uimenu('Parent',obj.hSurfContextMenu,'Label','Annotation');
                    uimenu('Parent',hAnMenu,'Label','Clear Annotations','Callback',@obj.clearAnnotations);
                    uimenu('Parent',hAnMenu,'Label','Draw Oval','Callback',@(varargin)obj.startAnnotation('oval'));
                    uimenu('Parent',hAnMenu,'Label','Draw Rectangle','Callback',@(varargin)obj.startAnnotation('rectangle'));
                    uimenu('Parent',hAnMenu,'Label','Draw Line','Callback',@(varargin)obj.startAnnotation('line'));
                uimenu('Parent',obj.hSurfContextMenu,'Separator','on','Label','Assign image data in base','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.imageAssigninBase));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Save to Tiff','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.saveSurfToTiff));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Add to Scanfield Display window','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.addToSfDisp));
                uimenu('Parent',obj.hSurfContextMenu,'Separator','on','Label','Set roi as motion correction ref','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.setMotionReferenceThisRoi));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Add roi as motion correction ref','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.addMotionReferenceThisRoi));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Set roi slice as motion correction ref','Callback',@(src,evt)obj.surfContextMenuCallback(@obj.setMotionReferenceThisRoiSlice));
                uimenu('Parent',obj.hSurfContextMenu,'Label','Enable motion correction','Tag','uiMenuMotionCorrectionEnabled','Callback',@(src,evt)obj.toggleEnableMotionCorrection);
                
            obj.hAxesContextMenu = handle(uicontextmenu('Parent',obj.hFig,'Callback',@obj.contextMenuOpen));
                uimenu('Parent',obj.hAxesContextMenu,'Label','Autoscale Contrast','Callback',@(src,evt)obj.autoChanContrast());
                uimenu('Parent',obj.hAxesContextMenu,'Label','Show Volume Histogram','Callback',@(src,evt)obj.showVolumeHistogram());
                uimenu('Parent',obj.hAxesContextMenu,'Label','Volume Stats','Callback',@(src,evt)obj.volumeImageStats());
                uimenu('Parent',obj.hAxesContextMenu,'Separator','on','Label','Reset View','Callback',@obj.resetview);
                uimenu('Parent',obj.hAxesContextMenu,'Label','Top View','Callback',@(src,evt)obj.resetview('top'));
                uimenu('Parent',obj.hAxesContextMenu,'Label','Show Crosshair','Callback',@obj.toggleCrosshair);
                uimenu('Parent',obj.hAxesContextMenu,'Label','Hide Cursor / Measurement','Callback',@obj.hideCursor);
                hAnMenu = uimenu('Parent',obj.hAxesContextMenu,'Label','Annotation');
                    uimenu('Parent',hAnMenu,'Label','Clear Annotations','Callback',@obj.clearAnnotations);
                    uimenu('Parent',hAnMenu,'Label','Draw Oval','Callback',@(varargin)obj.startAnnotation('oval'));
                    uimenu('Parent',hAnMenu,'Label','Draw Rectangle','Callback',@(varargin)obj.startAnnotation('rectangle'));
                    uimenu('Parent',hAnMenu,'Label','Draw Line','Callback',@(varargin)obj.startAnnotation('line'));
                uimenu('Parent',obj.hAxesContextMenu,'Separator','on','Label','Set vol as motion correction ref','Callback',@(src,evt)obj.setMotionReferenceThisVolume);
                uimenu('Parent',obj.hAxesContextMenu,'Separator','off','Label','Align and set vol as motion correction ref','Callback',@(src,evt)obj.alignAndSetMotionReferenceThisVolume);
                uimenu('Parent',obj.hAxesContextMenu,'Separator','on','Label','Enable motion correction','Tag','uiMenuMotionCorrectionEnabled','Callback',@(src,evt)obj.toggleEnableMotionCorrection);
                
            obj.hAxes = handle(obj.prepareAxes('Parent',obj.hUicMain,'ButtonDownFcn',@obj.selectdrag,'UIContextMenu',obj.hAxesContextMenu));
            obj.hMotionContainer = handle(hgtransform('Parent',obj.hAxes,'Matrix',obj.motionMatrix));
            
            obj.hUicMain.SizeChangedFcn = @obj.reSize;
            
            obj.hCursor = handle(line('Parent',obj.hMotionContainer,'Visible','off','LineStyle','none',...
                'Marker','+','MarkerSize',10,'MarkerEdgeColor','r','LineWidth',1,'HitTest','off'));
            
            
            measureColor = [1 0 1];
            measureAlpha = 0.2;
            obj.hMeasureGroup = handle(hggroup('Parent',obj.hAxes,'Hittest','off','Visible','off'));
            obj.hPatchMeasure = handle(patch('Parent',obj.hMeasureGroup,'HitTest','off','PickableParts','none','LineStyle','none','FaceColor',measureColor,'FaceAlpha',measureAlpha,'Marker','none','PickableParts','none'));
            obj.hLineMeasure = handle(line('Parent',obj.hMeasureGroup,'HitTest','off','PickableParts','none','MarkerSize',10,'LineWidth',2,'MarkerEdgeColor',measureColor,'Color',measureColor,'Marker','o'));
            obj.hTextMeasure = handle(text('Parent',obj.hMeasureGroup,'HitTest','off','PickableParts','none','String','','VerticalAlignment','bottom','Color',measureColor,'FontWeight','bold'));
            
            obj.hOnTopGroup = handle(hgtransform('Parent',obj.hAxes,'Hittest','off'));
            if obj.graphics2014b
                obj.hOnTopGroup.PickableParts = 'none';
            end
            obj.hMotionContainerOnTop = handle(hgtransform('Parent',obj.hOnTopGroup,'Matrix',obj.motionMatrix));
            obj.hLinePhotostimMonitor.patch  = handle(patch('Parent',obj.hMotionContainerOnTop,'Visible','off','FaceColor','none','EdgeColor','interp','LineWidth',2,'HitTest','off'));
            obj.hLinePhotostimMonitor.endMarker = handle(line('Parent',obj.hMotionContainerOnTop,'Visible','off','LineStyle','none','Marker','*','MarkerSize',10,'MarkerEdgeColor','r','LineWidth',1.5,'HitTest','off'));
            obj.hLinePhotostimMonitor.endMarkerSlm = handle(line('Parent',obj.hMotionContainerOnTop,'Visible','off','LineStyle','none','Marker','*','MarkerSize',10,'MarkerEdgeColor','r','LineWidth',1.5,'HitTest','off'));
            
            obj.hCrossHair = handle(hggroup('Parent',obj.hOnTopGroup,'Visible','off','HitTest','off'));
            line('XData',20*obj.maxXrg,'YData',zeros(1,2),...
                'Parent',obj.hCrossHair,'Color','white','LineWidth',1);
            line('XData',zeros(1,2),'YData',20*obj.maxYrg,...
                'Parent',obj.hCrossHair,'Color','white','LineWidth',1);
            obj.showCrosshair = obj.showCrosshair; % Set Visibility of cross hair according to obj.showCrosshair
            
            obj.hInverseMotionContainer = handle(hgtransform('Parent',obj.hAxes,'Matrix',eye(4)));
            obj.hHighlightGroup = handle(hggroup('Parent',obj.hInverseMotionContainer,'Visible','off','Hittest','off'));
            if obj.graphics2014b
                obj.hHighlightGroup.PickableParts = 'none';
            end
            
            obj.hAnnotationMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hAnnotationMenu,'Label','Delete','Callback',@obj.deleteAnnotation);
            
            hAnnotationContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',hAnnotationContextMenu,'Label','Cancel','Callback',@obj.cancelAnnotation);
                
            obj.hAnnotationAx = axes('parent',obj.hUicMain,'units','normalized','position',[0 0 1 1],'XLim',[0 1],'YLim',[0 1],'ButtonDownFcn',@obj.annotationFunc,...
                'Color','none','XTick',[],'YTick',[],'ZTick',[],'XTickLabelMode','manual','YTickLabelMode','manual','hittest','off','XColor','none','YColor','none',...
                'ZTickLabelMode','manual','XTickLabel',[],'YTickLabel',[],'ZTickLabel',[],'UIContextMenu',hAnnotationContextMenu);
            
            obj.axesSelectedByUser(obj.hAxes);
            obj.CLim = obj.CLim;
        end
        
        function delete(obj)
            obj.projectionsVisible = false; % resize figure window
            most.idioms.safeDeleteObj(obj.hAxesProjectionX);
            most.idioms.safeDeleteObj(obj.hAxesProjectionY);
            most.idioms.safeDeleteObj(obj.hZSpacingSlider);
            most.idioms.safeDeleteObj(obj.hUicFlowProjections);
            most.idioms.safeDeleteObj(obj.hSurfContextMenu);
            most.idioms.safeDeleteObj(obj.hAxesContextMenu);
            most.idioms.safeDeleteObj(obj.hUicMain);
            most.idioms.safeDeleteObj(obj.hAxes);
            most.idioms.safeDeleteObj(obj.roiMap);
            most.idioms.safeDeleteObj(obj.labelMap);
            most.idioms.safeDeleteObj(obj.hCrossHair);
            most.idioms.safeDeleteObj(obj.hUicMain);
            most.idioms.safeDeleteObj(obj.hUicFlowMain);
            most.idioms.safeDeleteObj(obj.hLiveHistograms);
        end
        
        function initialize(obj,zs,displayMode,specialView)
            obj.is3dview = strcmpi('3d',displayMode);
            if obj.is3dview
                obj.prepareSideProjections();
            end
            
            obj.isMaxProjView = strcmpi(specialView,'max');
            obj.isCurrentView = obj.isMaxProjView | strcmpi(specialView,'current');
            obj.isTiledView = strcmpi(specialView,'tiled');

            obj.hAxes.PlotBoxAspectRatio = [1 1 1];
            
            obj.zs = zs;
            obj.zSurfs = repmat({matlab.graphics.primitive.Surface.empty},numel(zs),1);
            zSurfProp = struct('hRoi',{},'hScanfield',{},'cornerpoints',{},'pixelToRefTransform',{});
            obj.zSurfProps = repmat({zSurfProp},numel(zs),1);
            
            if isempty(obj.zs) || any(isnan(obj.zs))
                obj.setCrossHairZ(0-1e-6);
            else
                obj.setCrossHairZ(min(obj.zs)-1e-6);
            end
            
            delete(obj.hSurfs); % clear all existing surfaces in axis

            if obj.graphics2014b
                obj.hSurfs = gobjects(1,0);
                obj.hMainSurfs = gobjects(1,0);
            else
                obj.hSurfs = [];
                obj.hMainSurfs = [];
            end
            obj.roiMap = containers.Map('KeyType','uint64','ValueType','any');
            obj.labelMap = containers.Map('KeyType','uint64','ValueType','any');
            
            xs = zeros(2,2,0);
            ys = zeros(2,2,0);
            for roi = obj.hSI.hRoiManager.currentRoiGroup.displayRois
                roiUuiduint64 = roi.uuiduint64;
                zSurfMap = containers.Map('KeyType','double','ValueType','any');
                zLabelMap = containers.Map('KeyType','double','ValueType','any');
                
                tmpzs = obj.zs;
                if any(isnan(tmpzs))
                    assert(numel(tmpzs) == 1, 'A roi display with an indeterminate z plane can only have one z level.')
                    tmpzs = 0;
                end
                
                scanFields = arrayfun(@(z)roi.get(z),tmpzs,'UniformOutput',false);
                mask = cellfun(@(sf)isempty(sf),scanFields);
                scanFields(mask) = [];
                tmpzs(mask) = [];
                
                %Surface handles for Roi
                for idx = 1:length(tmpzs)
                    z = tmpzs(idx);
                                   
                    scanField = scanFields{idx};
                    
                    [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(0:1,0:1,z);

                    if obj.transposeImage
                        imcoordsX = imcoordsX';
                        imcoordsY = imcoordsY';
                    end
                    
                    [imcoordsX,imcoordsY] = scanField.transform(imcoordsX,imcoordsY);
                    
                    %%% this code does not work with rotated ROIs
                    %imcoordsX = fixZero(imcoordsX')';
                    %imcoordsY = fixZero(imcoordsY);
                    
                    xs(:,:,end+1) = imcoordsX;
                    ys(:,:,end+1) = imcoordsY;

                    imData = NaN; %Unused if mroi disabled

                    surfs = struct();
                    [surfs.hSurf,centerpoint] = prepareSurface(imcoordsX,imcoordsY,imcoordsZ,imData,'Parent',obj.hMotionContainer,'EdgeColor',obj.hSI.hDisplay.roiDisplayEdgeColor,'EdgeAlpha',obj.hSI.hDisplay.roiDisplayEdgeAlpha,'Visible',obj.tfMap(~obj.isCurrentView));
                    set(surfs.hSurf,'HitTest','on','ButtonDownFcn',@(src,evt)obj.clickedsurf(centerpoint,src,evt));
                    
                    if obj.is3dview && obj.transparency3d
                        set(surfs.hSurf,'AlphaData',imData,'AlphaDataMapping','scaled','FaceAlpha','texturemap');
                    end
                    
                    %add roi and z info
                    set(surfs.hSurf,'UserData',struct('roi',roi,'scanField',scanField,'z',z,'origPos',struct('XData',surfs.hSurf.XData,'YData',surfs.hSurf.YData),'offset',[0 0]));
                    
                    obj.zSurfs{z==zs}(end+1) = surfs.hSurf;
                    
                    zSurfProp(1).hRoi = roi;
                    zSurfProp(1).hScanfield = scanField;
                    zSurfProp(1).cornerpoints = scanField.cornerpoints();
                    zSurfProp(1).pixelToRefTransform = scanField.pixelToRefTransform;
                    obj.zSurfProps{z==zs}(end+1) = zSurfProp;
                    
                    obj.hSurfs = [obj.hSurfs surfs.hSurf];
                    obj.hMainSurfs = [obj.hMainSurfs surfs.hSurf];
                    
                    if obj.is3dview
                        nextz = 1;
                        if idx < length(tmpzs)
                            nextz = tmpzs(idx+1);
                        elseif idx == length(tmpzs) && length(tmpzs) > 1
                            nextz = 2*z-tmpzs(idx-1);
                        end
                        
                        surfs.hSurfProjectionX = prepareSurface([imcoordsX(1,:);imcoordsX(1,:)],imcoordsY,[z z;nextz nextz],imData,'Parent',obj.hMotionContainerProjectionX,...
                            'EdgeColor',obj.hSI.hDisplay.roiProjectionDisplayEdgeColor,'EdgeAlpha',obj.hSI.hDisplay.roiProjectionDisplayEdgeAlpha);
                        surfs.hSurfProjectionY = prepareSurface(imcoordsX,[imcoordsY(:,1),imcoordsY(:,1)],[z z;nextz nextz]',imData,'Parent',obj.hMotionContainerProjectionY,...
                            'EdgeColor',obj.hSI.hDisplay.roiProjectionDisplayEdgeColor,'EdgeAlpha',obj.hSI.hDisplay.roiProjectionDisplayEdgeAlpha);
                        obj.hSurfs(end+1) = surfs.hSurfProjectionY;
                        obj.hSurfs(end+1) = surfs.hSurfProjectionX;
                    end

                    zSurfMap(z) = surfs;

                    %Roi Names
%                         hLabel = text(imcoordsX(1)+0.01,imcoordsY(1),imcoordsZ(1),roi.name,...
%                             'Parent',obj.hAxes,...
%                             'FontWeight','normal',...
%                             'Color','Yellow',...
%                             'FontSize',7,...
%                             'HorizontalAlignment','Left',...
%                             'VerticalAlignment','Top');
%                         zLabelMap(z) = hLabel;

                end
                obj.roiMap(roiUuiduint64) = zSurfMap;
                obj.labelMap(roiUuiduint64) = zLabelMap;
            end
            
            if strcmpi(displayMode,'no_transform') && ~isempty(xs)
                obj.maxXrg = [min(xs(:)),max(xs(:))];
                obj.maxYrg = [min(ys(:)),max(ys(:))];
            end
            
            obj.resetview();
            obj.CLim = obj.CLim;
            
            obj.resetZSpacing();
            
            % nested functions
%             function lims = fixZero(lims)
%                 if all(lims(:,1) == lims(:,2))
%                     lims(:,1) = lims(:,1) - obj.viewAngularRange * 0.01;
%                     lims(:,2) = lims(:,2) + obj.viewAngularRange * 0.01;
%                 end
%             end
            
            function [hSurf,centerpoint] = prepareSurface(imcoordsX,imcoordsY,imcoordsZ,imData,varargin)
                hSurf = handle(surface(imcoordsX,imcoordsY,imcoordsZ,imData,...
                    'FaceColor','texturemap',...
                    'CDataMapping','scaled',...
                    'FaceLighting','none',...
                    'UIContextMenu',obj.hSurfContextMenu,...
                    varargin{:}));
                
                centerpoint = [(imcoordsX(1,1) + imcoordsX(2,2))/2,...
                              (imcoordsY(1,1) + imcoordsY(2,2))/2,...
                              (imcoordsZ(1,1) + imcoordsZ(2,2))/2];
            end
        end
        
        function reSize(obj,varargin)
            if ~obj.is3dview
                obj.hAxes.Parent.Units = 'pixels';
                s = obj.hAxes.Parent.Position([3 4]);
                obj.hAxes.Parent.Units = 'normalized';
                
                windowAsp = s(1)/s(2);
                canvasAsp = diff(obj.maxXrg) / diff(obj.maxYrg);
                
                if obj.isTiledView
                    % determine best tiling based on aspect ratio of FOV
                    % and aspect ratio of window
                    N = numel(obj.zs);
                    cols = max(min(round((N*windowAsp/canvasAsp)^.5),N),1);
                    rows = ceil(N/cols);
                    
                    canvasAsp = canvasAsp * cols / rows;
                else
                    rows = 1;
                    cols = 1;
                end
                
                margin = 0.05;
                
                if windowAsp > canvasAsp
                    marginY = margin*diff(obj.maxYrg);
                    yrg = [obj.maxYrg(1) (obj.maxYrg(2) + (diff(obj.maxYrg)+marginY) * (rows-1))] + (rows>1)*marginY*[-.5 .5];
                    xrg = [obj.maxXrg(1) (obj.maxXrg(1) + diff(yrg) * windowAsp)];
                    
                    o = diff(xrg)/cols - diff(obj.maxXrg);
                    xrg = xrg - o/2;
                else
                    marginX = margin*diff(obj.maxXrg);
                    xrg = [obj.maxXrg(1) (obj.maxXrg(2) + (diff(obj.maxXrg)+marginX) * (cols-1))] + (cols>1)*marginX*[-.5 .5];
                    yrg = [obj.maxYrg(1) (obj.maxYrg(1) + diff(xrg) / windowAsp)];
                    
                    o = diff(yrg)/rows - diff(obj.maxYrg);
                    yrg = yrg - o/2;
                end
                
                obj.hAxes.XLim = xrg;
                obj.hAxes.YLim = yrg;
                obj.hAxes.Color = .94*ones(1,3);
                obj.hAxes.XColor = 'none';
                obj.hAxes.YColor = 'none';
                
                if obj.isTiledView %&& false
                    xsz = diff(xrg) / cols;
                    ysz = diff(yrg) / rows;
                    
                    % move surfaces
                    for i = 1:numel(obj.zs)
                        x = mod(i-1,cols);
                        y = floor((i-1)/cols);
                        
                        xoff = xsz * x;
                        yoff = ysz * y;
                        
                        for j = 1:numel(obj.zSurfs{i})
                            s = obj.zSurfs{i}(j);
                            p = s.UserData.origPos;
                            s.XData = p.XData + xoff;
                            s.YData = p.YData + yoff;
                            s.UserData.offset = [xoff yoff];
                        end
                        
                        enoughBackSurfs(i);
                        obj.hBackSurfs(i).XData = repmat(obj.maxXrg + xoff,2,1);
                        obj.hBackSurfs(i).YData = repmat(obj.maxYrg' + yoff,1,2);
                        obj.hBackSurfs(i).ZData = (max(obj.zs)+1)*ones(2);
                    end
                else
                    enoughBackSurfs(1);
                    obj.hBackSurfs(1).XData = repmat(obj.maxXrg,2,1);
                    obj.hBackSurfs(1).YData = repmat(obj.maxYrg',1,2);
                    obj.hBackSurfs(1).ZData = (max(obj.zs)+1)*ones(2);
                end
                
                obj.scrollWheelFcn(obj.hAxes,[],struct('VerticalScrollCount',0));
            end
            
            function enoughBackSurfs(N)
                while numel(obj.hBackSurfs) < N
                    obj.hBackSurfs(end+1) = surface(nan,nan,nan,'parent',obj.hAxes,'facecolor','k','edgecolor','k','hittest','off');
                end
            end
        end
        
        function resetview(obj,option,varargin)
            if nargin < 2 || ~ischar(option)
                option = '';
            end
            
            obj.reSize();
            obj.hAxes.CameraViewAngleMode = 'auto';
            
            if obj.hSI.hDisplay.needsReset
                % user initiated reset; do not restore the camera props
                obj.hSI.hDisplay.resetActiveDisplayFigs(false);
            elseif isempty(obj.zs) || length(obj.zs) == 1 || any(isnan(obj.zs))
                if isempty(obj.zs) || any(isnan(obj.zs))
                    z = 0;
                else
                    z = obj.zs(1);
                end
                
                camtarget(obj.hAxes,[mean(obj.hAxes.XLim),mean(obj.hAxes.YLim),z]);
                obj.hOnTopGroup.Matrix = makehgtform('translate',[0 0 z-1e-6]);
                obj.hAxes.ZLim = [z-2 z+2];
                drawnow(); % order of operation is important here: first move the axis view to center, then set view angle
                view(obj.hAxes,0,-90);
            else
                warnStruct = warning();
                warning('off','MATLAB:Axes:UpVector');
                if obj.isCurrentView || obj.isTiledView || strcmp(option,'top')
                    camtarget(obj.hAxes,[mean(obj.hAxes.XLim),mean(obj.hAxes.YLim),min(obj.zs)]);
                    drawnow(); % order of operation is important here: first move the axis view to center, then set view angle
                    view(obj.hAxes,0,-90);
                else
                    camtarget(obj.hAxes,[mean(obj.hAxes.XLim),mean(obj.hAxes.YLim),(max(obj.zs)-min(obj.zs))/2]);
                    drawnow(); % order of operation is important here: first move the axis view to center, then set view angle
                    view(obj.hAxes,-135,-45);
                    camup(obj.hAxes,[0,0,-1]);
                end
                obj.hOnTopGroup.Matrix = makehgtform('translate',[0 0 min(obj.zs)-1e-6]);
                obj.hAxes.ZLim = [min(obj.zs)-2 max(obj.zs)+2];
                warning(warnStruct);
            end
        end
        
        function resetZSpacing(obj)
            % figure the default z spacing from the auto aspect ratio
            aRatio = obj.hAxes.DataAspectRatio;
            aRatio = aRatio / aRatio(1);
            obj.zSpacing = obj.hSI.objectiveResolution / aRatio(3);
        end
        
        
        function drawRoiData(obj,roiDatas)
            if isempty(roiDatas)
                return
            end
                        
            if ~iscell(roiDatas)
                roiDatas = {roiDatas};
            end
            
            for i = 1:numel(roiDatas)
                roiData = roiDatas{i};
                if roiData.hRoi.display && any(roiData.channels == obj.chan)
                    try % this try catch statement is faster than using obj.roiMap.isKey
                        zSurfMap = obj.roiMap(roiData.hRoi.uuiduint64);
                    catch
%                         most.mimics.warning('roiMap value for this roi ID is not valid.');
                        continue
                    end
                    
                    %zLabelMap = obj.labelMap(roiData.hRoi.uuid);
                    for zIdx = 1:numel(roiData.zs)
                        if isnan(obj.zs)
                            z = 0;
                        else
                            z = roiData.zs(zIdx);
                        end
                        
                        try % this try catch statement is faster than using obj.roiMap.isKey
                            surfs = zSurfMap(z); % get the right surface handle
                            
                            if obj.isCurrentView
                                if obj.lastDrawnZ ~= z && ~isempty(obj.lastDrawnZSurfs)
                                    set(obj.lastDrawnZSurfs, 'Visible', 'off');
                                    obj.lastDrawnZSurfs = matlab.graphics.chart.primitive.Surface.empty;
                                end
                                
                                obj.lastDrawnZ = z;
                                obj.lastDrawnZSurfs(end+1) = surfs.hSurf;
                                obj.lastDrawnZSurfs(end).Visible = 'on';
                            end
                        catch
%                             most.mimics.warning('roiData has an encoded z value of %.2f, but this is not a display key in RoiDisplay. Roidata ID: %s\n', z, roiData.hRoi.uuid(1:8));
                            continue
                        end
                        
%                             hLabel = zLabelMap(z); % get the handle to the ROI label.
                        
                        imData = roiData.imageData{roiData.channels == obj.chan}{zIdx};
                        
                        if obj.is3dview && obj.transparency3d
                            surfSetAlphaData(surfs.hSurf,imData);
                        end
                        
                        surfSetCdata(surfs.hSurf,imData);
                        
                        if obj.is3dview && obj.projectionsVisible
                            surfSetCdata(surfs.hSurfProjectionX,max(imData,[],1));
                            surfSetCdata(surfs.hSurfProjectionY,max(imData,[],2));
                        end
                        
                        if isfield(surfs,'hHist')
                            if ~isempty(surfs.hHist) && isvalid(surfs.hHist)
                                if obj.dataMultiplier ~= 1;
                                    imData = imData(:)./cast(obj.dataMultiplier,'like',imData);
                                end
                                surfs.hHist.updateData(imData);
                            else
                                surfs = rmfield(surfs,'hHist');
                                zSurfMap(z) = surfs;
                            end
                        end

                        if obj.debugEnabled
                            %display debug information on ROI
%                             labelString = [ num2str(roiData.zs) ' ' ...
%                                             num2str(roiData.frameTimestamp) ' ' ...
%                                             num2str(roiData.frameNumberAcq) ' ' ...
%                                             num2str(roiData.frameNumberAcqMode) ];
%                                 set(hLabel,'String',labelString);
                        end
                    end
                end
            end
            
            function surfSetCdata(hSurf,cData)
                if obj.graphics2014b
                    hSurf.CData = cData;
                else
                    if isa(cData,'uint8')
                        hSurf.CData = cData;
                    else
                        cDataDbl = double(cData);
                        hSurf.CData = cDataDbl;
                    end
                end
            end
            
            function surfSetAlphaData(hSurf,alphaData)
                if size(alphaData,3) > 1
                    % RGB merge display cannot be used with transparency
                    % deactivate FaceAlpha by seting surf to opaque
%                     hSurf.FaceAlpha = 1;
%                     return
                    alphaData = max(alphaData,[],3);
                end
                
                if obj.graphics2014b
                    hSurf.AlphaData = alphaData;
                else
                    if isa(alphaData,'uint8')
                        % todo: handle merge!
                        hSurf.AlphaData = alphaData;
                    else
                        cDataDbl = double(alphaData);
                        hSurf.AlphaData = cDataDbl;
                    end
                end
            end
        end
        
        function prepareSideProjections(obj)
            hUicFlow = uiflowcontainer('v0','Parent',obj.hUicMain,'FlowDirection','LeftToRight');
                obj.hUicFlowProjections = handle(uiflowcontainer('v0','Parent',hUicFlow,'FlowDirection','TopDown'));
                    textMaxProj = uicontrol('Parent',obj.hUicFlowProjections,'Style','text','String','Max Projections','FontWeight','bold');
                    set(textMaxProj,'HeightLimits',[15 15]);
                                
                    hUicFlowProjectionsBottom = uiflowcontainer('v0','Parent',obj.hUicFlowProjections,'FlowDirection','LeftToRight');
                        hUicZLabel = uiflowcontainer('v0','Parent',hUicFlowProjectionsBottom,'FlowDirection','TopDown');
                        set(hUicZLabel,'WidthLimits',[15 15]);
                            uicontainer('Parent',hUicZLabel); % placeholder for centering textz
                            textz = uicontrol('Parent',hUicZLabel,'Style','text','String','z');
                                set(textz,'HeightLimits',[15 15]);
                            uicontainer('Parent',hUicZLabel); % placeholder for centering textz

                        hUicProjectionX = uiflowcontainer('v0','Parent',hUicFlowProjectionsBottom,'FlowDirection','TopDown');
                            hUicAxesX = uicontainer('Parent',hUicProjectionX);
                                obj.hAxesProjectionX = obj.prepareAxes('Parent',hUicAxesX,'DataAspectRatioMode','auto','XLimMode','auto','YLimMode','auto','ZLimMode','auto');
                                obj.hMotionContainerProjectionX = hgtransform('Parent',obj.hAxesProjectionX,'Matrix',obj.motionMatrix);
                                view(obj.hAxesProjectionX,-90,0);
                                camup([0 0 -1]);

                            textx = uicontrol('Parent',hUicProjectionX,'Style','text','String','y');
                            set(textx,'HeightLimits',[15 15]);

                        hUicProjectionY = uiflowcontainer('v0','Parent',hUicFlowProjectionsBottom,'FlowDirection','TopDown');
                            hUicAxesY = uicontainer('Parent',hUicProjectionY);
                                obj.hAxesProjectionY = obj.prepareAxes('Parent',hUicAxesY,'DataAspectRatioMode','auto','XLimMode','auto','YLimMode','auto','ZLimMode','auto');
                                obj.hMotionContainerProjectionY = hgtransform('Parent',obj.hAxesProjectionY,'Matrix',obj.motionMatrix);
                                view(obj.hAxesProjectionY, 180,0);
                                camup([0 0 -1]);

                            texty = uicontrol('Parent',hUicProjectionY,'Style','text','String','x');
                            set(texty,'HeightLimits',[15 15]);

                obj.hUicFlowMain = handle(uiflowcontainer('v0','Parent',hUicFlow,'FlowDirection','TopDown'));
                    hUicFlowTop = uiflowcontainer('v0','Parent',obj.hUicFlowMain,'FlowDirection','LeftToRight');
                    set(hUicFlowTop,'HeightLimits',[25 25]);
                        hButton = uicontrol('Parent',hUicFlowTop,'Style','pushbutton','String','Projections','Callback',@toggleProjectionsVisible,...
                            'TooltipString','Show/hide side projections');
                        set(hButton,'WidthLimits',[60 60]);
                        hButton = uicontrol('Parent',hUicFlowTop,'Style','pushbutton','String','Reset View','Callback',@obj.resetview,...
                            'TooltipString','Reset 3D View');
                        set(hButton,'WidthLimits',[60 60]);
                        text = uicontrol('Parent',hUicFlowTop,'Style','text','String',' slice spacing','FontSize',12);
                        set(text,'WidthLimits',[100 100]);
                        obj.hZSpacingSlider = uicontrol('Parent',hUicFlowTop,'Style','Slider','Value',obj.zSpacing,'Min',0.01,'Max',1000,'SliderStep',[0.01 0.1],'Callback',@changeZSpacing,...
                            'TooltipString','Change view spacing of slices');
                    hUic3dView = uicontainer('Parent',obj.hUicFlowMain);
                        set(obj.hAxes,'Parent',hUic3dView);
                        set(obj.hAnnotationAx,'Parent',hUic3dView);
            
                
            obj.projectionsVisible = obj.projectionsVisible;
            
            function toggleProjectionsVisible(src,evt)
                obj.projectionsVisible = ~obj.projectionsVisible;
            end
            
            function changeZSpacing(src,evt)
                obj.zSpacing = get(src,'Value');
            end
        end
        
        function hAx = prepareAxes(obj,varargin)
            hAx = handle(axes(...
                'Box','off',...
                'NextPlot','add',...
                'XLimMode','manual',...
                'YLimMode','manual',...
                'ZLimMode','manual',...
                'DataAspectRatio',[1 1 1],...
                'XLim',obj.maxXrg,...
                'YLim',obj.maxYrg,...
                'ZLim',[-Inf Inf],...
                'Color','black',...
                'Position',[0 0 1 1],...
                'XTick',[],'YTick',[],'ZTick',[],...
                'XTickLabelMode','manual','YTickLabelMode','manual','ZTickLabelMode','manual',...
                'XTickLabel',[],'YTickLabel',[],'ZTickLabel',[],...
                'CLim',[0 1],...
                'Projection','orthographic',...
                varargin{:}));
        end
    end
    
    methods        
        function val = get.hFig(obj)
            val = ancestor(obj.hUicMain,'figure');
        end
        
        function set.parent(obj,val)
           set(obj.hUicMain,'Parent',val);
        end
        
        function set.motionMatrix(obj,val)
            % Not used at the moment
            obj.motionMatrix = eye(4);
            
%             if size(val,1) == 3 && size(val,2) == 3
%                 val = scanimage.mroi.util.affine2Dto3D(val);
%             end
%             
%             if ~isequal(val,obj.motionMatrix)
%                 if obj.stabilizeDisplay
%                     obj.hMotionContainer.Matrix = val;
%                     obj.hMotionContainerOnTop.Matrix = val;
%                     obj.hMotionContainerProjectionX.Matrix = val;
%                     obj.hMotionContainerProjectionY.Matrix = val;
%                 else
%                     obj.hInverseMotionContainer.Matrix = inv(val);
%                 end
%                 obj.motionMatrix = val;
%             end
        end
        
        function set.stabilizeDisplay(obj,val)
            oldVal = obj.stabilizeDisplay;
            obj.stabilizeDisplay = val;
            
            if val~=oldVal
                % first reset all containers
                obj.hMotionContainer.Matrix = eye(4);
                obj.hMotionContainerOnTop.Matrix = eye(4);
                obj.hMotionContainerProjectionX.Matrix = eye(4);
                obj.hMotionContainerProjectionY.Matrix = eye(4);
                obj.hInverseMotionContainer.Matrix = eye(4);
                
                % then apply motion matrix
                motionMatrix_ = obj.motionMatrix;
                obj.motionMatrix = eye(4);
                obj.motionMatrix = motionMatrix_; % force update by changing matrix
            end
        end
        
        function set.projectionsVisible(obj,val)
            if obj.is3dview
                if val
                    vis = 'on';
                else
                    vis = 'off';
                end
                
                if ishghandle(obj.hUicFlowProjections)
                    obj.hUicFlowProjections.Visible = vis;
                end
                
                if ishghandle(obj.hFig)
                    pos = obj.hFig.Position;
                    if val ~= obj.projectionsVisible
                        if val
                            obj.hFig.Position = [pos(1)-pos(3),pos(2),2*pos(3),pos(4)];
                        else
                            obj.hFig.Position = [pos(1)+pos(3)/2,pos(2),pos(3)/2,pos(4)];
                        end
                    end
                end
            end
            
            obj.projectionsVisible = val;
        end
        
        function val = get.cameraProps(obj)
            try
                if isempty(obj.hAnnotationAx.Children)
                    annotations = {[]};
                else
                    annotations = {arrayfun(@(h){h.XData h.YData},obj.hAnnotationAx.Children,'UniformOutput', false)};
                end
                
                val = struct(...
                    'is3dview',        obj.is3dview,...
                    'CameraTarget',    obj.hAxes.CameraTarget,...
                    'CameraPosition',  obj.hAxes.CameraPosition,...
                    'CameraViewAngle', obj.hAxes.CameraViewAngle,...
                    'CameraUpVector',  obj.hAxes.CameraUpVector,...
                    'projectionsVisible', obj.projectionsVisible,...
                    'zSpacing',        obj.zSpacing,...
                    'stabilizeDisplay',obj.stabilizeDisplay,...
                    'annotations',annotations);
            catch
                val = struct();
            end
        end
        
        function set.cameraProps(obj,val)
            % only restore if camera props if 3dview configuration matches
            if obj.is3dview == val.is3dview
                obj.hAxes.CameraTarget = val.CameraTarget;
                obj.hAxes.CameraPosition = val.CameraPosition;
                obj.hAxes.CameraViewAngle = val.CameraViewAngle;
                obj.hAxes.CameraUpVector = val.CameraUpVector;
                obj.projectionsVisible = val.projectionsVisible;
                obj.zSpacing = val.zSpacing;
                
                if ~isempty(val.annotations)
                    for i = 1:numel(val.annotations)
                        line('parent',obj.hAnnotationAx,'xdata',val.annotations{i}{1},'ydata',val.annotations{i}{2},'color',[1 0 1],'linewidth',2,'UIContextMenu',obj.hAnnotationMenu);
                    end
                end
                
                obj.coerceView();
            end
            obj.stabilizeDisplay = val.stabilizeDisplay;
        end

        function resetScanFields(obj)
            % sets all scanFields back to black            
            for hSurf = obj.hSurfs
                hSurf.AlphaData = NaN;
                hSurf.CData = NaN;
            end
        end
        
        function setCrossHairZ(obj,z)
           hLines = obj.hCrossHair.Children;
           for hLine = hLines(:)'
               zData = hLine.ZData;
               hLine.ZData = ones(size(zData)).*z;
           end
        end
    end
    
    methods
        function set.zSpacing(obj,val)
            if obj.is3dview
                aRatio = [1 1 obj.hSI.objectiveResolution/val];
                obj.hAxes.DataAspectRatio = aRatio;
                if ~isempty(obj.hZSpacingSlider)
                    obj.hZSpacingSlider.Min = min(obj.hZSpacingSlider.Min,val);
                    obj.hZSpacingSlider.Value = val;
                    obj.hZSpacingSlider.Max = max(obj.hZSpacingSlider.Max,val);
                end
                obj.zSpacing = val;
            end
        end
        
        function set.dataMultiplier(obj,val)
            obj.dataMultiplier = double(val);
            obj.CLim = obj.CLim;
        end
        
        function set.CLim(obj,val) 
            correctedVal = double(val) .* obj.dataMultiplier;
            obj.hAxes.CLim = correctedVal;
            
            if obj.is3dview
                obj.hAxes.ALim = [correctedVal(1) correctedVal(1)+1];
                obj.hAxesProjectionX.CLim = correctedVal;
                obj.hAxesProjectionY.CLim = correctedVal;
            end
            
            obj.CLim = val;
            
            mask = false(length(obj.hLiveHistograms),1);
            for idx = 1:length(obj.hLiveHistograms)
                hHist = obj.hLiveHistograms(idx);
                if isvalid(hHist)
                    mask(idx) = true;
                    hHist.lut = obj.CLim;
                end
            end
            % delete invalid hHist
            obj.hLiveHistograms(~mask) = [];
        end
        
        function set.showCrosshair(obj,val)
            if val
                visibleOnOff = 'on';
            else
                visibleOnOff = 'off';
            end
            
            if ~isempty(obj.hCrossHair) && ishandle(obj.hCrossHair)
                obj.hCrossHair.Visible = visibleOnOff;
				if ~obj.graphics2014b
                    % workaround for Matlab<2014b to hide crosshair
                    set(obj.hCrossHair.Children,'Visible',visibleOnOff);
                end
                
                % check / uncheck menu item
                mnu = findall(obj.hSurfContextMenu,'Label','Show Crosshair');
                mnu = [mnu findall(obj.hAxesContextMenu,'Label','Show Crosshair')];
                set(mnu,'Checked',visibleOnOff);
            end
            
            obj.showCrosshair = val;
        end
    end
    
    %% 3d mouse navigation functions 
    methods
        function axesSelectedByUser(obj,hAx)
            obj.hFig.WindowScrollWheelFcn = @(src,evt)obj.scrollWheelFcn(hAx,src,evt);
        end
        
        function scrollWheelFcn(obj,hAx,~,evt)
            zoomSpeedFactor = 1.1;
            cAngle = hAx.CameraViewAngle;
            scroll = zoomSpeedFactor ^ double(evt.VerticalScrollCount);
            cAngle = cAngle * scroll;
            
            if ~obj.is3dview
                % limit max angle
                maxViewOPct = .01;
                maxViewPct = 1 + maxViewOPct;
                maxCamAngle = atand(min(diff(hAx.XLim),diff(hAx.YLim))*maxViewPct / abs(hAx.CameraPosition(3) - hAx.CameraTarget(3)));
                cAngle = min(cAngle, maxCamAngle);
                
            end
            
            cp = hAx.CurrentPoint([1 3]);
            hAx.CameraViewAngle = cAngle;
            
            if ~obj.is3dview
                % dolly to keep mouse over same point
                dff = cp - hAx.CurrentPoint([1 3]);
                camdolly(obj.hAxes,dff(1),dff(2),0,'movetarget','data');
                
                % dolly to keep view within range
                viewportHalfSize = abs(abs(hAx.CameraPosition(3) - hAx.CameraTarget(3))*tand(obj.hAxes.CameraViewAngle)) / 2;
                camPos =  obj.hAxes.CameraPosition([1 2]);
                
                % the calculated viewport size applies to the smaller one when window is not square
                lims = [obj.hAxes.XLim; obj.hAxes.YLim] + maxViewOPct * [-.5 .5; -.5 .5] .* repmat([diff(obj.hAxes.XLim); diff(obj.hAxes.YLim)],1,2);
                primAxis = 2 - (diff(lims(2,:)) > diff(lims(1,:)));
                camPos(primAxis) = min(max(camPos(primAxis),lims(primAxis,1) + viewportHalfSize), lims(primAxis,2) - viewportHalfSize);
                
                secAxis = 3 - primAxis;
                viewportHalfSize = viewportHalfSize * diff(lims(secAxis,:)) / diff(lims(primAxis,:));
                camPos(secAxis) = min(max(camPos(secAxis),lims(secAxis,1) + viewportHalfSize), lims(secAxis,2) - viewportHalfSize);
                
                obj.hAxes.CameraPosition([1 2]) = camPos;
                obj.hAxes.CameraTarget([1 2]) = camPos([1 2]);
            end
        end
        
        function coerceView(obj)
            obj.scrollWheelFcn(obj.hAxes,[],struct('VerticalScrollCount',0));
        end
        
        function pt = getPoint(obj)
            pt = hgconvertunits(obj.hFig,[0 0 obj.hFig.CurrentPoint],...
				obj.hFig.Units,'pixels',0);
            pt = pt(3:4);
        end
        
        function clickedsurf(obj,surfcenter,src,evt)
            hAx = ancestor(src,'axes');
            
            obj.lastClickedSurfPoint = evt.IntersectionPoint;
            
            switch obj.hFig.SelectionType
                case 'open'   % double click
                    if obj.is3dview
                        hAx.CameraTarget = surfcenter;
                    else
                        obj.resetview();
                    end
                otherwise
                    modKey = obj.hFig.CurrentModifier;
                    if iscellstr(modKey) && isscalar(modKey) && strcmpi(modKey{1},'control')
                        obj.dragStage(src,'start');
                    else
                        obj.selectdrag(src,evt);
                    end
            end
            obj.axesSelectedByUser(hAx);
        end
        
        function selectdrag(obj,src,evt)
            obj.axesSelectedByUser(obj.hAxes);

           switch obj.hFig.SelectionType;
               case 'normal' % left click
                   obj.startdrag(@obj.dolly);
               case 'alt'    % right click
                   % reserved for context menu
               case 'open'   % double click
               case 'extend' % scroll wheel click
                   obj.startdrag(@obj.orbit);
           end
        end
        
        function startdrag(obj,dragtype)
            pt = obj.getPoint();
            dragdata = struct(...
                'figStartPoint',pt,...
                'figLastPoint',pt,...
                'WindowButtonMotionFcn',obj.hFig.WindowButtonMotionFcn,...
                'WindowButtonUpFcn',obj.hFig.WindowButtonUpFcn);
            obj.hFig.WindowButtonMotionFcn = @(src,evt)motion(dragtype,src,evt);
            obj.hFig.WindowButtonUpFcn = @stopdrag;
            
            function motion(dragtype,varargin)
                pt = obj.getPoint();
                deltaPix = pt - dragdata.figLastPoint;
                dragdata.figLastPoint = pt;
                dragtype(deltaPix);
            end
            
            function stopdrag(varargin)
                obj.hFig.WindowButtonMotionFcn = dragdata.WindowButtonMotionFcn;
                obj.hFig.WindowButtonUpFcn = dragdata.WindowButtonUpFcn;
            end
        end
        
        function pan(obj,deltaPix)
            panxy = -deltaPix*camva(obj.hAxes)/500;
            campan(obj.hAxes,panxy(1),panxy(2),'camera',[0 0 1]);
        end
        
        function orbit(obj,deltaPix)
            if obj.is3dview
                camorbit(obj.hAxes,deltaPix(1),-deltaPix(2),'data',[0 0 1])
            end
        end
        
        function dolly(obj,deltaPix)
            obj.hAxes.CameraViewAngleMode = 'manual';
            camdolly(obj.hAxes,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
            obj.coerceView();
        end        
        
        function hover(obj,src,evt)
            if ~most.gui.isMouseInAxes(obj.hAxes)
                return
            end
            
            if ~isempty(obj.hFig.CurrentModifier)
                return
            end
            
            roiUnderMouse = obj.getRoiUnderMouse();
            obj.hSI.hDisplay.mouseHoverInfo = roiUnderMouse;
        end
        
        function roiUnderMouse = getRoiUnderMouse(obj)
            roiUnderMouse = [];
            
            mousePt = obj.hAxes.CurrentPoint;
            ptLn = mousePt(1,:);
            vLn  = diff(mousePt);
            vPn  = [0 0 1];
            pts = arrayfun(@(z)scanimage.mroi.util.intersectLinePlane(ptLn,vLn,[0 0 z],vPn),obj.zs,'UniformOutput',false);
            pts = vertcat(pts{:});
            pts(:,3) = obj.zs; % avoid rounding errors
            pts(any(isnan(pts),2),:) = [];
            
            d = bsxfun(@minus,ptLn,pts);
            d = sqrt(sum(d.^2,2));
            [~,sortIdxs] = sort(d);
            pts = pts(sortIdxs,:);
            
            for idx = 1:size(pts,1)
                pt = pts(idx,:);
                surfProps = obj.zSurfProps{obj.zs==pt(3)};
                surfCornerPts = {surfProps.cornerpoints};
                mask = cellfun(@(cpts)inpolygon(pt(1),pt(2),cpts(:,1),cpts(:,2)),surfCornerPts);
                if any(mask)
                    surfProp = surfProps(find(mask,1,'first'));
                    pixel = scanimage.mroi.util.xformPoints(pt,surfProp.pixelToRefTransform,true);
                    pixel = round(pixel);
                    surfProp.pixel = pixel;
                    surfProp.z = pt(3);
                    surfProp.channel = obj.chan;
                    roiUnderMouse = surfProp;
                    return
                end
            end
        end
    end
    
    %% Surf UI Context Menu Callbacks
    methods
        function contextMenuOpen(obj,src,evt)
            if obj.hSI.hMotionManager.enable
                motionEnableStatus = 'on';
            else
                motionEnableStatus = 'off';
            end
            set(findall(src,'Tag','uiMenuMotionCorrectionEnabled'),'Checked',motionEnableStatus);
            
            if obj.hSI.hMotors.motorToRefTransformValid
                status = 'on';
            else
                status = 'off';
            end
            set(findall(src,'Tag','uiMenuCenterStage'),'Enable',status);
        end
        
        function surfContextMenuCallback(obj,fcn)
            hSurf = gco(obj.hFig);
            if ~isempty(hSurf) && strcmpi(hSurf.Type,'surface')
                fcn(hSurf);
            end
            
            if isvalid(obj) % when axes is reset by fcn, obj might get deleted
                obj.axesSelectedByUser(obj.hAxes);
            end
        end
        
        function setMotionReferenceThisVolume(obj)
            roiDatas = obj.hSI.hDisplay.getAveragedRoiDatas();
            assert(~isempty(roiDatas),'No Roi Data found. Acquire a volume first, then retry');

            % only use this channel
            arrayfun(@(roiData)roiData.onlyKeepChannels(obj.chan),roiDatas);
            isemptyChMask = arrayfun(@(roiData)isempty(roiData.channels),roiDatas);
            
            assert(~any(isemptyChMask),'Roi image data is empty for selected channel');
            
            obj.hSI.hMotionManager.clearEstimators();
            arrayfun(@(roiData)obj.hSI.hMotionManager.addEstimator(roiData),roiDatas,'UniformOutput',false);
            
            if ~isempty(obj.hSI.hController)
                hSICtl = obj.hSI.hController{1};
                hSICtl.showGUI('MotionDisplay');
                hSICtl.raiseGUI('MotionDisplay');
            end
        end
        
        function alignAndSetMotionReferenceThisVolume(obj)
            roiDatas = obj.hSI.hDisplay.getRoiDataArray();
            arrayfun(@(rd)rd.onlyKeepChannels(obj.chan),roiDatas);
            
            nRois = size(roiDatas,1);
            bufferSize = size(roiDatas,2);
            
            % first dimension is roi index, second dimension is buffer index
            fprintf('Aligning %d stacks.\n',bufferSize);
            obj.hSI.hMotionManager.clearEstimators();
            for roiIdx = 1:nRois
                alignedRoiData = obj.hSI.hMotionManager.alignZStack(roiDatas(roiIdx,:));
                obj.hSI.hMotionManager.addEstimator(alignedRoiData);
            end
        end
        
        function setMotionReferenceThisRoi(obj,hSurf,clearAll)
            if nargin < 3 || isempty(clearAll)
                clearAll = true;
            end
            
            ud = hSurf.UserData;
            hRoi = ud.roi;
            
            roiDatas = obj.hSI.hDisplay.getAveragedRoiDatas();
            assert(~isempty(roiDatas),'No Roi Data found. Acquire a volume first, then retry');
            
            hRois = [roiDatas.hRoi];
            roiMask = ismember([hRois.uuiduint64],hRoi.uuiduint64);
            
            roiData = roiDatas(roiMask);
            assert(~isempty(roiData),'No matching roi data found');
            
            % only use this channel
            roiData.onlyKeepChannels(obj.chan);
            assert(~isempty(roiData.channels),'No matching roi data found');
            
            if clearAll
                obj.hSI.hMotionManager.clearEstimators();
            end
            obj.hSI.hMotionManager.addEstimator(roiData);
            
            if ~isempty(obj.hSI.hController)
                hSICtl = obj.hSI.hController{1};
                hSICtl.showGUI('MotionDisplay');
                hSICtl.raiseGUI('MotionDisplay');
            end
        end
        
        function addMotionReferenceThisRoi(obj,hSurf)
            clearAll = false;
            obj.setMotionReferenceThisRoi(hSurf,clearAll);
        end
        
        function setMotionReferenceThisRoiSlice(obj,hSurf)
            ud = hSurf.UserData;
            hRoi = ud.roi;
            z = ud.z;
            
            roiDatas = obj.hSI.hDisplay.getAveragedRoiDatas();
            assert(~isempty(roiDatas),'No Roi Data found. Acquire a volume first, then retry');
            
            hRois = [roiDatas.hRoi];
            roiMask = ismember([hRois.uuiduint64],hRoi.uuiduint64);
            
            roiData = roiDatas(roiMask);
            assert(~isempty(roiData),'No matching roi data found');
            
            % only use this channel
            roiData.onlyKeepChannels(obj.chan);
            roiData.onlyKeepZs(z);
            
            assert(~isempty(roiData.channels),'RoiData does not contain any channels');
            assert(~isempty(roiData.zs),'RoiData does not contain any zs');
            
            obj.hSI.hMotionManager.clearEstimators();
            obj.hSI.hMotionManager.addEstimator(roiData);
            
            if ~isempty(obj.hSI.hController)
                hSICtl = obj.hSI.hController{1};
                hSICtl.showGUI('MotionDisplay');
                hSICtl.raiseGUI('MotionDisplay');
            end
        end
        
        function toggleEnableMotionCorrection(obj,hSurf)
            obj.hSI.hMotionManager.enable = ~obj.hSI.hMotionManager.enable;
        end
        
        function showSurfHistogram(obj,hSurf)
            userData = hSurf.UserData;
            roi = userData.roi;
            z   = userData.z;
            data = obj.getSurfCData(hSurf);
            zSurfMap = obj.roiMap(roi.uuiduint64);
            surfs = zSurfMap(z); % get the right surface handle 
            surfs.hHist = obj.showHistogram(data,sprintf('Roi %s, Channel %d, z=%f',roi.name,obj.chan,z));
            zSurfMap(z) = surfs;
        end
        
        function showVolumeHistogram(obj)
            data = obj.getVolumeData();
            obj.showHistogram(data,'Volume Histogram Snapshot');
        end
        
        function hHist = showHistogram(obj,data,title)
            if ~isempty(data)                
                hHist = scanimage.mroi.LiveHistogram(obj.hSI);
                hHist.channel = obj.chan;
                hHist.title = title;
                res = obj.hSI.hScan2D.channelsAdcResolution;
                hHist.dataRange = [-(2^(res-1)),2^(res-1)-1];
                hHist.lut = obj.CLim;
                hHist.viewRange = mean(obj.CLim) + [-1.5 1.5].*double(diff(obj.CLim))./2;
                hHist.updateData(data);
                obj.hLiveHistograms = [obj.hLiveHistograms hHist];
            end
        end
        
        function dragStage(obj,hSurf,mode)
            persistent init
            
            if ~obj.hSI.hMotors.motorToRefTransformValid
                return
            end
            
            try
                pointXY = getMouseSurfPixel(obj,hSurf);
                switch mode
                    case 'start'
                        init = struct();
                        init.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        init.WindowButtonUpFcn = obj.hFig.WindowButtonDownFcn;
                        init.startPoint = pointXY;
                        
                        color = [0 1 0];
                        init.hDragLine = line('Parent',obj.hMotionContainer,'HitTest','off','PickableParts','none','MarkerSize',10,'LineWidth',2,'MarkerEdgeColor',color,'Color',color,'Marker','o');
                        init.hDragText = text('Parent',obj.hMotionContainer,'HitTest','off','PickableParts','none','String','','VerticalAlignment','bottom','Color',color,'FontWeight','bold');
                        
                        init.motorToRefTransform = obj.hSI.hMotors.motorToRefTransform; % cache this
                        
                        obj.hFig.WindowButtonMotionFcn = @(src,evt)obj.dragStage(hSurf,'update');
                        obj.hFig.WindowButtonUpFcn = @(src,evt)obj.dragStage(hSurf,'stop');
                        
                        obj.dragStage(hSurf,'update');
                    case 'update'
                        p1 = init.startPoint;
                        p2 = pointXY;
                        
                        p1motor = scanimage.mroi.util.xformPoints(p1(1:2),init.motorToRefTransform,true);
                        p2motor = scanimage.mroi.util.xformPoints(p2(1:2),init.motorToRefTransform,true);
                        r = norm(p2-p1);
                        rmotor = norm(p2motor-p1motor);
                        
                        zOffset = -1e-3;
                        
                        init.hDragLine.XData = [p1(1),p2(1)];
                        init.hDragLine.YData = [p1(2),p2(2)];
                        init.hDragLine.ZData = [p1(3),p2(3)] + zOffset;
                        
                        str = sprintf('Move Motor\n%.3f°\n%.3fum\n',r,rmotor);
                        init.hDragText.Position = p2 + [0 0 zOffset];
                        init.hDragText.String = str;
                        
                        if isempty(obj.hFig.CurrentModifier)
                            % user released modifier. abort operation
                            obj.dragStage(hSurf,'abort');
                        end
                    case 'stop' 
                        obj.dragStage(hSurf,'abort');
                        
                        try
                            if isempty(obj.hFig.CurrentModifier)
                                % user released modifier. do not perform move
                            else
                                p1 = init.startPoint;
                                p2 = pointXY;
                                
                                p1motor = scanimage.mroi.util.xformPoints(p1(1:2),init.motorToRefTransform,true);
                                p2motor = scanimage.mroi.util.xformPoints(p2(1:2),init.motorToRefTransform,true);
                                
                                moveVector = p2motor-p1motor;
                                currentPosition = obj.hSI.hMotors.motorPosition;
                                obj.hSI.hMotors.moveStartRelative([currentPosition(1:2) - moveVector,currentPosition(3:end)]);
                            end
                        catch ME
                            most.idioms.reportError(ME);
                        end
                    case 'abort'
                        if ~isempty(init)
                            if isfield(init,'WindowButtonMotionFcn')
                                obj.hFig.WindowButtonMotionFcn = init.WindowButtonMotionFcn;
                            end
                            if isfield(init,'WindowButtonUpFcn')
                                obj.hFig.WindowButtonUpFcn = init.WindowButtonUpFcn;
                            end
                            
                            if isfield(init,'hDragLine')
                                most.idioms.safeDeleteObj(init.hDragLine);
                            end
                            
                            if isfield(init,'hDragText')
                                most.idioms.safeDeleteObj(init.hDragText);
                            end
                        end

                        init.WindowButtonMotionFcn = [];
                        init.WindowButtonUpFcn = [];  
                    otherwise
                        assert(false);
                end
            catch ME
                if ~strcmpi(mode,'abort') % avoid recursion
                    obj.dragStage(hSurf,'abort');
                end
                rethrow(ME);
            end
        end
        
        function centerStage(obj,hSurf)
            point = getClickedSurfPixel(obj,hSurf);
            
            userdata = hSurf.UserData;
            roi = userdata.roi;
            z = userdata.z;
            sf = roi.get(z);
            
            assert(obj.hSI.hMotors.motorToRefTransformValid,'Motor to Reference space transform is invalid. Perform calibration first.');
            newPositionXY = point(1:2)-sf.centerXY;
            newPositionXY = scanimage.mroi.util.xformPoints(newPositionXY,obj.hSI.hMotors.motorToRefTransformAbsolute,true);
            currentPosition = obj.hSI.hMotors.motorPosition;
            obj.hSI.hMotors.moveStartRelative([newPositionXY,currentPosition(3:end)]);
        end
        
        function measure(obj,hSurf,varargin)
            persistent init
            
            if isempty(varargin)
                mode = 'start';
            else
                mode = varargin{1};
            end
            
            try
                [~,pointWithMotion] = getMouseSurfPixel(obj,hSurf);
                switch mode
                    case 'start'
                        init = struct();
                        init.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        init.WindowButtonDownFcn = obj.hFig.WindowButtonDownFcn;
                        init.startPoint = pointWithMotion;
                        
                        init.motorToRefTransform = obj.hSI.hMotors.motorToRefTransform; % cache this
                        
                        init.R_motor = [];
                        init.R_angle = [];
                        
                        obj.hFig.WindowButtonMotionFcn = @(src,evt)obj.measure(hSurf,'update');
                        obj.hFig.WindowButtonDownFcn = @(src,evt)obj.measure(hSurf,'stop');
                    case 'update'
                        p1 = init.startPoint;
                        p2 = pointWithMotion;
                        
                        zOffset = -1e-3;
                        
                        r = norm(p2-p1);
                        rmotor = [];
                        
                        if any(isnan(init.motorToRefTransform(:)))
                            obj.hPatchMeasure.Visible = 'off';
                        else
                            p1motor = scanimage.mroi.util.xformPoints(p1(1:2),init.motorToRefTransform,true);
                            p2motor = scanimage.mroi.util.xformPoints(p2(1:2),init.motorToRefTransform,true);
                            rmotor = norm(p2motor-p1motor);
                        
                            numPts = 100;
                        
                            xx = sin(linspace(0,2*pi,numPts)')*rmotor + p1motor(1);
                            yy = cos(linspace(0,2*pi,numPts)')*rmotor + p1motor(2);
                            [xx,yy] = scanimage.mroi.util.xformPointsXY(xx,yy,init.motorToRefTransform);
                            zz = repmat(p2(3),numPts,1) + zOffset;
                        
                            obj.hPatchMeasure.XData = xx;
                            obj.hPatchMeasure.YData = yy;
                            obj.hPatchMeasure.ZData = zz;
                            obj.hPatchMeasure.Visible = 'on';
                        end
                        
                        obj.hLineMeasure.XData = [p1(1),p2(1)];
                        obj.hLineMeasure.YData = [p1(2),p2(2)];
                        obj.hLineMeasure.ZData = [p1(3),p2(3)] + zOffset;
                        
                        if isempty(rmotor)
                            text = sprintf('%.3f°\n',r);
                        else
                            text = sprintf('%.3f°\n%.3fum\n',r,rmotor);
                        end
                        obj.hTextMeasure.Position = p2 + [0 0 zOffset];
                        obj.hTextMeasure.String = text;
                        
                        init.R_motor = rmotor;
                        init.R_angle = r;
                        
                        obj.hMeasureGroup.Visible = 'on';
                    case 'stop'                        
                        measurement = struct();
                        measurement.R_angle = init.R_angle;
                        measurement.R_motor = init.R_motor;
                        
                        assignin('base','measurement',measurement);
                        evalin('base','measurement');
                        
                        obj.measure(hSurf,'abort');
                    case 'abort'
                        obj.hFig.WindowButtonMotionFcn = init.WindowButtonMotionFcn;
                        obj.hFig.WindowButtonDownFcn = init.WindowButtonDownFcn;
                        init.WindowButtonMotionFcn = [];
                        init.WindowButtonDownFcn = [];                        
                    otherwise
                        assert(false);
                end
            catch ME
                if ~strcmpi(mode,'abort') % avoid recursion
                    obj.measure(hSurf,'abort');
                end
                rethrow(ME);
            end            
        end
        
        function pixelValue(obj,hSurf)            
            [actualPointXYZ,pointXYZWithMotion,pixelXY,pixelVal,axesPointXYZ] = obj.getClickedSurfPixel(hSurf);

            if ~isempty(actualPointXYZ) && ~isempty(pixelXY) && ~isempty(pixelVal)      
                s = struct();
                s.pixelXY = pixelXY;
                s.pointXYZ = actualPointXYZ(:)';
                s.pointXYZWithMotion = pointXYZWithMotion(:)';
                s.value = pixelVal(:)';
                
                if any(isnan(obj.hSI.hMotors.motorToRefTransform(:)))
                    s.motorPosition = [NaN,NaN];
                else
                    s.motorPosition = scanimage.mroi.util.xformPoints(actualPointXYZ(1:2), obj.hSI.hMotors.motorToRefTransformAbsolute,true);
                end
            
                assignin('base','Pixel',s);
                evalin('base','Pixel');
                
                obj.hCursor.Parent = ancestor(hSurf,'hgtransform');
                obj.hCursor.XData = axesPointXYZ(1);
                obj.hCursor.YData = axesPointXYZ(2);
                obj.hCursor.ZData = axesPointXYZ(3)-1e-6;
                obj.hCursor.Visible = 'on';
            end
        end
        
        function surfImageStats(obj,hSurf)
            data = obj.getSurfCData(hSurf);
            obj.imageStats(data);
        end
        
        function volumeImageStats(obj)
            data = obj.getVolumeData();
            obj.imageStats(data);
        end
        
        function imageStats(obj,data)
            if isempty(data)
                return
            end
            
            data = double(data); % std requires floating point type
            
            s = struct();
            s.mean = mean(data(:));
            s.std = double(std(data(:)));
            s.max = max(data(:));
            s.min = min(data(:));
            s.size = size(data);
            
            assignin('base','ImageStats',s);
            evalin('base','ImageStats');
        end
        
        function hideCursor(obj,varargin)
            obj.hCursor.Visible = 'off';
            obj.hMeasureGroup.Visible = 'off';
        end
        
        function imageAssigninBase(obj,hSurf)            
            assignin('base','ImageData',obj.getSurfCData(hSurf));
            fprintf('Assigned <a href="matlab: figure(''Colormap'',gray());imagesc(ImageData);axis(''image'');fprintf(''>> size(ImageData)\\n'');size(ImageData)">ImageData</a> in workspace ''base''\n');
        end
        
        function saveSurfToTiff(obj,hSurf,filename)
            imgdata = obj.getSurfCData(hSurf);
            
            if nargin < 3 || isempty(filename)
                [filename,pathname] = uiputfile('.tif','Choose path to save tif','image.tif');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            if isa(imgdata,'uint8') && size(imgdata,3)==3
                photometric = Tiff.Photometric.RGB;
                sampleFormat = Tiff.SampleFormat.UInt;
                samplesPerPixel = 3;
                bitsPerSample = 8;
            else
                imgdata = int16(imgdata);
                photometric = Tiff.Photometric.MinIsBlack;
                sampleFormat = Tiff.SampleFormat.Int;
                samplesPerPixel = 1;
                bitsPerSample = 16;
            end
            
            hTif = Tiff(filename,'w');
            try
                tagstruct.ImageLength = size(imgdata,1);
                tagstruct.ImageWidth = size(imgdata,2);
                tagstruct.Photometric = photometric;
                tagstruct.BitsPerSample = bitsPerSample;
                tagstruct.SamplesPerPixel = samplesPerPixel;
                tagstruct.SampleFormat = sampleFormat;
                tagstruct.RowsPerStrip = 16;
                tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                tagstruct.Software = 'ScanImage';
                hTif.setTag(tagstruct);

                hTif.write(imgdata);
            catch ME
                most.idioms.reportError(ME);
                hTif.close();
            end
            hTif.close();
        end
        
        function autoRoiContrast(obj,hSurf)
            cd = hSurf.CData;
            if ~isempty(obj.chan) && ~isempty(cd)
                obj.hSI.hDisplay.channelAutoScale(obj.chan,single(cd)./obj.dataMultiplier);
            end
        end
        
        function autoChanContrast(obj,~)
            cd = obj.getVolumeData();
            if ~isempty(obj.chan) && ~isempty(cd)
                obj.hSI.hDisplay.channelAutoScale(obj.chan,cd);
            end
        end
        
        function addToSfDisp(obj,hSurf)
            ud = hSurf.UserData;
            rois = obj.hSI.hRoiManager.roiGroupMroi.rois;
            ids = {rois.uuid};
            [tf, idx] = ismember(ud.roi.uuid, ids);
            if tf
                hSDC = obj.hSI.hController{1}.hScanfieldDisplayControls;
                hSDC.addDisp(rois(idx).name, obj.chan, idx, ud.z);
                obj.hSI.hDisplay.enableScanfieldDisplays = true;
            end
        end
        
        function toggleCrosshair(obj,varargin)
            obj.showCrosshair = ~obj.showCrosshair;
        end
        
        function CData = getSurfCData(obj,hSurf,correctTranspose)
            if nargin < 3 || isempty(correctTranspose)
                correctTranspose = true;
            end
            
            CData = hSurf.CData;
            
            if isempty(CData) || (isscalar(CData) && isnan(CData))
                CData = [];
                return
            end
            
            CData = CData ./ cast(obj.dataMultiplier,'like',CData);
            if obj.transposeImage && correctTranspose
                CData = permute(CData,[2,1,3]);
            end
        end
        
        function data = getVolumeData(obj)
           CDatas = arrayfun(@(hSurf)obj.getSurfCData(hSurf),obj.hMainSurfs,'UniformOutput',false);
           CDatas = cellfun(@(CData)CData(:),CDatas,'UniformOutput',false);
           data = vertcat(CDatas{:});
        end
        
        function [pointXYZ,pointWithMotionXYZ,pixelXY,pixelVal,axesPointXYZ] = getClickedSurfPixel(obj,hSurf,coerceToPixel)
            if nargin < 4 || isempty(coerceToPixel)
                coerceToPixel = true;
            end
            
            axesPointXYZ = obj.lastClickedSurfPoint;
            pointXYZ = axesPointXYZ - [hSurf.UserData.offset 0];
            pointWithMotionXYZ = scanimage.mroi.util.xformPoints(pointXYZ,obj.motionMatrix,true);
            
            sf = hSurf.UserData.scanField;
            pixelToRefTransform = scanimage.mroi.util.affine2Dto3D(sf.pixelToRefTransform);
            pixelXY = scanimage.mroi.util.xformPoints(pointWithMotionXYZ,pixelToRefTransform,true);
            pixelXY = pixelXY([1 2]);
            
            if coerceToPixel
                pixelXY = min(max(round(pixelXY),[1 1]),sf.pixelResolutionXY);
                pointWithMotionXYZ = scanimage.mroi.util.xformPoints([pixelXY hSurf.UserData.z],pixelToRefTransform,false);
                pointXYZ = scanimage.mroi.util.xformPoints(pointWithMotionXYZ,obj.motionMatrix,false);
                axesPointXYZ = pointXYZ + [hSurf.UserData.offset 0];
            end
            
            data = obj.getSurfCData(hSurf);
            if coerceToPixel && all(pixelXY>=1) && all(pixelXY<=size(data))
                pixelVal = data(pixelXY(2),pixelXY(1),:);
            else
                pixelVal = [];
            end
        end
        
        function [pointXY,pointWithMotionXY] = getMouseSurfPixel(obj,hSurf)
            
            pointXY = [];
            
            hAx = ancestor(hSurf,'axes');
            r = hAx.CurrentPoint';
            %r = scanimage.mroi.util.xformPoints(r',obj.motionMatrix,true)';
            
            xx = hSurf.XData;
            yy = hSurf.YData;
            zz = hSurf.ZData;
            
            if obj.transposeImage
                xx = xx';
                yy = yy';
                zz = zz';
            end
            
            pp = [xx(1,1);yy(1,1);zz(1,1)];
            v1 = [xx(1,1)-xx(2,1);yy(1,1)-yy(2,1);zz(1,1)-zz(2,1)];
            v2 = [xx(1,1)-xx(1,2);yy(1,1)-yy(1,2);zz(1,1)-zz(1,2)];
            n = -cross(v1,v2);
            
            pl = r(:,1);
            l = r(:,1) - r(:,2);
            
            if dot(l,n) ~= 0
                d = dot(pp-pl,n)/dot(l,n);
                pointXY = d*l+pl;
                pointXY = pointXY(:)';
                pointWithMotionXY = scanimage.mroi.util.xformPoints(pointXY,obj.motionMatrix);
            else
                return % surface and view plane are perpendicular
            end
        end
        
        function clearAnnotations(obj,varargin)
            delete(obj.hAnnotationAx.Children);
        end
        
        function startAnnotation(obj,type)
            % prepare A matirx
            %
            % pts = A * endPts
            %
            % pts : final list of points (Nx2) [x1 y1]
            %                                  [x2 y2]
            %                                  [...  ]
            %                                  [xN yN]
            %
            % endPts : matrix containing start and end points of mouse drag (4x2) [startX  0     ]
            %                                                                     [deltaX  0     ]
            %                                                                     [0       startY]
            %                                                                     [0       deltaY]
            %
            % A : transformation matrix (Nx4) [x1FromStartX x1FromDeltaX y1FromStartY y1FromDeltaY]
            %                                 [x2FromStartX x2FromDeltaX y2FromStartY y2FromDeltaY]
            %                                 [...                                                ]
            %                                 [xNFromStartX xNFromDeltaX yNFromStartY yNFromDeltaY]
            
            switch(lower(type))
                case 'oval'
                    ths =linspace(0,2*pi,500);
                    A = ones(500,4);
                    A(:,2) = 0.5 + 0.5*cos(ths);
                    A(:,4) = 0.5 + 0.5*sin(ths);
                case 'rectangle'
                    A = [1 0 1 0; 1 1 1 0; 1 1 1 1; 1 0 1 1; 1 0 1 0];
                case 'line'
                    A = [1 0 1 0; 1 1 1 1];
                otherwise
                    return;
            end
            obj.hAnnotationAx.HitTest = 'on';
            obj.annotationFunc(A,struct('EventName','SetA'));
        end
        
        function cancelAnnotation(obj,varargin)
            obj.hAnnotationAx.HitTest = 'off';
        end
        
        function deleteAnnotation(obj,varargin)
            delete(gco(obj.hFig));
        end
        
        function annotationFunc(obj,newA,evt)
            persistent A
            persistent endPts
            persistent startPt
            persistent hLine
            persistent init
            
            switch(evt.EventName)
                case 'SetA'
                    A = newA;
                case 'Hit'
                    if evt.Button == 1
                        init = struct();
                        init.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        init.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        obj.hFig.WindowButtonMotionFcn = @obj.annotationFunc;
                        obj.hFig.WindowButtonUpFcn = @obj.annotationFunc;
                    end
                    endPts = zeros(4,2);
                    startPt = obj.hAnnotationAx.CurrentPoint([1 3]);
                    endPts([1,7]) = startPt;
                    pts = A * endPts;
                    
                    hLine = line('parent',obj.hAnnotationAx,'xdata',pts(:,1),'ydata',pts(:,2),'color',[1 0 1],'linewidth',2,'UIContextMenu',obj.hAnnotationMenu);
                    
                case 'WindowMouseMotion'
                    newPt = obj.hAnnotationAx.CurrentPoint([1 3]);
                    endPts([2,8]) = newPt - startPt;
                    
                    pts = A * endPts;
                    hLine.XData = pts(:,1);
                    hLine.YData = pts(:,2);
                    
                case 'WindowMouseRelease'
                        obj.hFig.WindowButtonMotionFcn = init.WindowButtonMotionFcn;
                        obj.hFig.WindowButtonUpFcn = init.WindowButtonUpFcn;
                        obj.hFig.WindowButtonMotionFcn = [];
                        obj.hFig.WindowButtonUpFcn = [];
                        init = [];
                        obj.cancelAnnotation();
            end
        end
    end
end


%--------------------------------------------------------------------------%
% RoiDisplay.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
