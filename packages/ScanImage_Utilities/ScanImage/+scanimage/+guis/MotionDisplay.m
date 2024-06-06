classdef MotionDisplay < most.Gui
    properties (SetObservable)
        currentZ = 0;
        selectedEstimator = [];
        plotTimeLimit = 2; % in seconds
        alpha = 0.6; % value between 0 and 1 controlling transparency
        liveViewFov = 30;
        liveViewPosition = [0 0];
        displayUpdateRate = 20; % in Hz
    end
    
    properties (Access = private)
        lastDisplayUpdate = tic();
        
        estimatorInfoTable;
        estimatorTable;
        hTextMotionCorrection;
        hTextMotionCorrector;
        
        hCorrectorInfoTable;
        
        hXPlotAxes;
        hYPlotAxes;
        hZPlotAxes;
        
        hXPlotLine;
        hYPlotLine;
        hZPlotLine;
        
        xyzUnits;
        
        hXYCorrectionAxes;
        hZCorrectionAxes;
        
        hXYCorrectionLine;
        hXYCorrectionBoundsLine;
        
        hZCorrectionLine;
        hZCorrectionBoundsLine;
        hZCorrectionZeroLine;
        
        hLiveViewAxes;
        hMotionMarkerLine;
        
        hZCursorAxes;
        hZAxes;
        hZAxesTicks;
        
        hLiveViewOutline;
        
        hCorrelationLineX;
        hCorrelationLineY;
        hCorrelationLineZ;
        hCorrelationLineZSelected;
        
        hZLines;
        hZLinesDashed;
        hZCursorLine;
        hZCursorText;
        hZCursorTextRect;
        
        hZOutOfBoundMarkerUp;
        hZOutOfBoundMarkerDown;
        
        hZCursor;
        hZCursorPatch;
        
        sfDisp;
        
        liveViewFovLim = 30;
        
        interestingZs = [];
        surfStorage = matlab.graphics.primitive.Surface.empty(1,0);
        motionSurfStorage = struct('hgTransform',{},'hSurface',{});
    end
    
    properties (Access = private)        
        hMotionEstimatorsListener
        hMotionHistoryListener
        hMotionCorrectionListeners
        hMotionCorrectedListener;
        hZseriesListener
        hMotionCorrectorChangedListener
        hMotionMarkersListener
        hLutListener
        hImagingSystemListener
        
        plotsXTT = [];
        plotsXLim = [];
        plotsXY_YLim = [];
        plotsZ_YLim = [];
    end
    
    %% Lifecycle
    methods
        function obj = MotionDisplay(hModel, hController)
            %% main figure
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            size = [200,50];
            obj = obj@most.Gui(hModel,hController,size,'characters');
            
            obj.initGUI();
            obj.hFig.Name = 'Motion Display';
            obj.hFig.WindowScrollWheelFcn = @obj.windowScrollWheelFcn;
            
            % Hovering degrades performance. Deactivate for now
            %obj.hFig.WindowButtonMotionFcn = @obj.hover;
            
            obj.hMotionHistoryListener = addlistener(obj.hModel.hMotionManager,'newMotionEstimateAvailable',@(varargin)obj.motionHistoryChanged);
            obj.motionHistoryChanged();
            obj.hMotionCorrectionListeners = addlistener(obj.hModel.hMotionManager,'motionCorrectionVector','PostSet',@(varargin)obj.motionCorrectionChanged);
            obj.hMotionCorrectionListeners(end+1) = addlistener(obj.hModel.hMotionManager,'correctionBoundsXY','PostSet',@(varargin)obj.motionCorrectionChanged);
            obj.hMotionCorrectionListeners(end+1) = addlistener(obj.hModel.hMotionManager,'correctionBoundsZ','PostSet',@(varargin)obj.motionCorrectionChanged);
            obj.hMotionCorrectedListener = addlistener(obj.hModel.hUserFunctions,'motionCorrected',@(varargin)obj.motionCorrected);
            obj.hMotionMarkersListener = addlistener(obj.hModel.hMotionManager,'motionMarkersXY','PostSet',@(varargin)obj.motionMarkersXYChanged);
            obj.hLutListener = most.util.DelayedEventListener(0.3,obj.hModel.hChannels,'channelLUT','PostSet',@(varargin)obj.channelLutChanged());
            obj.hImagingSystemListener = addlistener(obj.hModel,'imagingSystem','PostSet',@(varargin)obj.imagingSystemChanged);
            
            obj.visibleChangedHook();
            
            obj.motionCorrectionChanged();
            obj.motionCorrectorChanged();
            obj.motionMarkersXYChanged();
            obj.imagingSystemChanged();
            
            obj.hZseriesListener = addlistener(obj.hModel.hStackManager,'zs','PostSet',@(varargin)obj.setupZAxis);
            obj.setupZAxis();
            obj.currentZ = obj.currentZ;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hMotionEstimatorsListener);
            most.idioms.safeDeleteObj(obj.hMotionHistoryListener);
            most.idioms.safeDeleteObj(obj.hMotionCorrectionListeners);
            most.idioms.safeDeleteObj(obj.hZseriesListener);
            most.idioms.safeDeleteObj(obj.hMotionCorrectorChangedListener);
            most.idioms.safeDeleteObj(obj.hMotionMarkersListener);
            most.idioms.safeDeleteObj(obj.hMotionCorrectedListener);
            most.idioms.safeDeleteObj(obj.hLutListener);
            most.idioms.safeDeleteObj(obj.hImagingSystemListener);
        end
    end
    
    %% GUI init methods
    methods
        function initGUI(obj)
            flowMargin = 4;
            topFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','Margin',flowMargin);
                leftFlow = most.gui.uiflowcontainer('Parent',topFlow,'FlowDirection','TopDown','WidthLimits',[230 230],'Margin',flowMargin);
                    generalSettingsPanel = uipanel('parent',leftFlow,'Title','Motion Detection Settings');
                    obj.initGeneralSettingsPanel(generalSettingsPanel);
                    
                    tableButtonsPanel = uipanel('parent',leftFlow,'Title','Motion Estimators');
                    obj.initTableButtonsPanel(tableButtonsPanel);
                    
                    obj.initTable(leftFlow);
                    
                    motionEstimatorInfoPanel = uipanel('parent',leftFlow,'Title','Selected Motion Estimators');
                    obj.initMotionEstimatorInfoPanel(motionEstimatorInfoPanel);
                    
                    motionCorrectionConfigPanel = uipanel('parent',leftFlow,'Title','Motion Correction');
                    obj.initMotionCorrectionConfigPanel(motionCorrectionConfigPanel);
                    
                rightFlow = most.gui.uiflowcontainer('Parent',topFlow,'FlowDirection','TopDown','Margin',flowMargin);
                    liveViewPanel = uipanel('parent',rightFlow,'Title','Motion Live View');
                    obj.initLiveViewPanel(liveViewPanel);
                    
                    bottomRightFlow = most.gui.uiflowcontainer('Parent',rightFlow,'FlowDirection','LeftToRight','Margin',flowMargin);
                    set(bottomRightFlow,'HeightLimits',[200 200]);
                        
                        correctionPlotsPanel = uipanel('parent',bottomRightFlow,'Title','Correction Plots');
                        obj.initCorrectionPlotsPanel(correctionPlotsPanel);
                        
                        plotsPanel = uipanel('parent',bottomRightFlow,'Title','Motion Plots');
                        obj.initPlotsPanel(plotsPanel);
        end
        
        function initGeneralSettingsPanel(obj,hParent)
            set(hParent,'HeightLimits',[120 120]);
            h = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'checkbox', ...
                'String', 'Enable Motion Detection', ...
                'TooltipString', 'Enables/Disables motion detection.', ...
                'Bindings',{{obj.hModel.hMotionManager 'enable' 'value'}},...
                'Units', 'pixels', ...
                'RelPosition', [10 40 200 15]);
            
            h = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'text', ...
                'String', 'History Length', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', ...
                'RelPosition', [10 65 75 15]);
            
            h = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'edit', ...
                'String', 'History Length', ...
                'Units', 'pixels', ...
                'TooltipString', 'Sets number of motion estimates to be kept in memory.', ...
                'Bindings',{{obj.hModel.hMotionManager 'motionHistoryLength' 'value'}}, ...
                'RelPosition', [90 67 50 20]);
            
            h = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'pushbutton', ...
                'String', 'Select Estimator', ...
                'HorizontalAlignment', 'right', ...
                'TooltipString', 'The default estimator class. Estimators created from the channel display will be of this class.', ...
                'Units', 'pixels', ...
                'Callback', @(varargin)obj.hModel.hMotionManager.selectEstimatorClass, ...
                'RelPosition', [2 90 85 20]);
            
            most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'edit', ...
                'String', '', ...
                'Units', 'pixels', ...
                'TooltipString', 'The default estimator class. Estimators created from the channel display will be of this class.', ...
                'Bindings',{{obj.hModel.hMotionManager 'estimatorClassName' 'callback' @updateEstimatorClassName}}, ...
                'Enable', 'inactive', ...
                'ButtonDownFcn', @(varargin)edit(obj.hModel.hMotionManager.estimatorClassName),...
                'RelPosition', [90 90 120 20]);
            
             h = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'pushbutton', ...
                'String', 'Select Corrector', ...
                'HorizontalAlignment', 'right', ...
                'TooltipString', 'The corrector class.', ...
                'Units', 'pixels', ...
                'Callback', @(varargin)obj.hModel.hMotionManager.selectCorrectorClass, ...
                'RelPosition', [2 110 85 20]);
            
            obj.hTextMotionCorrector = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'edit', ...
                'String', '', ...
                'Units', 'pixels', ...
                'TooltipString', 'The corrector class.', ...
                'Bindings',{{obj.hModel.hMotionManager 'hMotionCorrector' 'callback' @(varargin)obj.motionCorrectorChanged}}, ...
                'Enable', 'inactive', ...
                'ButtonDownFcn', @(varargin)edit(obj.hModel.hMotionManager.correctorClassName),...
                'RelPosition', [90 110 120 20]);
            
            function updateEstimatorClassName(hCtrl)
                classname = obj.hModel.hMotionManager.estimatorClassName;
                classname = regexp(classname,'[^\.]*$','match','once'); % abbreviate package name
                hCtrl.String = classname;
            end
        end
        
        function initTableButtonsPanel(obj,hParent)
            set(hParent,'HeightLimits',[100 100]);
            
            flow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
            flow1 = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','Margin',2);
            h = most.gui.uicontrol(...
                'parent', flow1, ...
                'Style', 'pushbutton', ...
                'String', 'Load', ...
                'TooltipString', 'Loads a Tiff fileor a Motion Estimator as the motion correction reference.', ...
                'Callback',@(src,evt)obj.hModel.hMotionManager.loadTiffOrMotionEstimatorFromFile() );
            
            h = most.gui.uicontrol(...
                'parent', flow1, ...
                'Style', 'pushbutton', ...
                'String', 'Save', ...
                'TooltipString', 'Saves the selected Motion Estimator to file.', ...
                'Callback',@(src,evt)saveSelectedME());
            
            h = most.gui.uicontrol(...
                'parent', flow1, ...
                'Style', 'pushbutton', ...
                'String', 'Save All', ...
                'TooltipString', 'Saves all Motion Estimators to file.', ...
                'Callback',@(src,evt)obj.hModel.hMotionManager.saveManagedEstimators());
            
            flow2 = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','Margin',2);
            
            h = most.gui.uicontrol(...
                'parent', flow2, ...
                'Style', 'pushbutton', ...
                'String', 'Reprocess Estimators / Corrector', ...
                ... %'WidthLimits',[120 120],...
                'TooltipString', sprintf('Reprocess the motion estimators and motion corrector.\nUse this function after the motion estimator class or the motion corrector class is edited.'), ...
                'Callback',@(src,evt)obj.hModel.hMotionManager.reprocessEstimatorsAndCorrector() );
            
            flow3 = most.gui.uiflowcontainer('Parent',flow,'FlowDirection','LeftToRight','Margin',2);

            h = most.gui.uicontrol(...
                'parent', flow3, ...
                'Style', 'pushbutton', ...
                'String', 'Enable All', ...
                'TooltipString', 'Enables all roi estimators', ...
                'Callback',@(src,evt)obj.enableAllEstimators(true) );
            
            h = most.gui.uicontrol(...
                'parent', flow3, ...
                'Style', 'pushbutton', ...
                'String', 'Disable All', ...
                'TooltipString', 'Disables all roi estimators.', ...
                'Callback',@(src,evt)obj.enableAllEstimators(false) );
            
            h = most.gui.uicontrol(...
                'parent', flow3, ...
                'Style', 'pushbutton', ...
                'String', 'Clear', ...
                'TooltipString', 'Deletes all roi estimators.', ...
                'WidthLimits',[35 35],...
                'Callback',@(src,evt)obj.hModel.hMotionManager.clearEstimators() );
            
            h = most.gui.uicontrol(...
                'parent', flow3, ...
                'Style', 'pushbutton', ...
                'String', 'Delete', ...
                'WidthLimits',[40 40],...
                'TooltipString', 'Deletes the selected roi estimator.', ...
                'Callback',@(src,evt)deleteSelectedEstimator);
            
            %%% local function
            function deleteSelectedEstimator()
                if ~isempty(obj.selectedEstimator)
                    obj.hModel.hMotionManager.removeEstimator(obj.selectedEstimator);
                end
            end
            
            function saveSelectedME()
                if isempty(obj.selectedEstimator)
                    most.idioms.warn('No Motion Estimator for saving selected.');
                else
                    obj.hModel.hMotionManager.saveEstimators(obj.selectedEstimator);
                end
            end
        end
        
        function initMotionEstimatorInfoPanel(obj,hParent)
            set(hParent,'HeightLimits',[100 100]);
            flowCtr = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
            
            obj.estimatorInfoTable = uitable('Parent',flowCtr,'Units','characters');
            obj.estimatorInfoTable.ColumnName = {};
            obj.estimatorInfoTable.ColumnEditable = [false true];
            obj.estimatorInfoTable.ColumnFormat = {'char' 'char'};
            obj.estimatorInfoTable.ColumnWidth = {135 'auto'};
            obj.estimatorInfoTable.CellEditCallback = @obj.editMotionEstimatorInfoTable;
            obj.estimatorInfoTable.RowName = {};
            
            obj.updateMotionEstimatorInfoPanel();
        end
        
        function initTable(obj,parent)
            obj.estimatorTable = uitable('Parent',parent,'Units','characters');
            obj.estimatorTable.ColumnName = {'Sel' 'Enable' 'ROI Name' '#z' 'Chan'};
            obj.estimatorTable.ColumnEditable = [true true false false false];
            obj.estimatorTable.ColumnFormat = {'logical' 'logical' 'char' 'char' 'char'};
            obj.estimatorTable.ColumnWidth = {25 45 70 30 50};
            obj.estimatorTable.CellEditCallback = @obj.editTable;
            obj.estimatorTable.RowName = {};
            obj.hMotionEstimatorsListener = most.util.DelayedEventListener(0.1,obj.hModel.hMotionManager,'motionEstimatorsChanged',@(varargin)obj.motionEstimatorsChanged());
            obj.updateTable();
            obj.setupScanfieldView();
        end
        
        function initLiveViewPanel(obj,hParent)
            set(hParent,'SizeChangedFcn',@resizeAxes,'Units','pixel');
            
            color_orange = [0.9412 0.5098 0.2353];
            color_gray = 0.9 * ones(1,3);
            color_pink = [1 0 1];
            color_red = [1 0 0];
            colormap_red = bsxfun(@times,gray(),color_red);
            
            obj.hLiveViewAxes = axes('Parent',hParent,'DataAspectRatio',[1 1 1],'box','on','Units','pixel','XLimMode','manual','XLimMode','manual','XLim',[-10 10],'YLim',[-10 10],'ButtonDownFcn',@(varargin)obj.moveLiveViewAxes,'Color','black','GridColor',color_gray,'XGrid','on','YGrid','on');
            xlabel(obj.hLiveViewAxes,'X [deg]');
            ylabel(obj.hLiveViewAxes,'Y [deg]');
            colormap(obj.hLiveViewAxes,colormap_red);
            
          	obj.hMotionMarkerLine = line('Parent',obj.hLiveViewAxes,'XData',[],'YData',[],'LineStyle','none','Marker','+','MarkerSize',8,'LineWidth',1.5,'Color',color_pink);
            
            view(obj.hLiveViewAxes,0,-90);
            obj.hZCursorAxes = axes('Parent',hParent,'box','on','Units','pixel','XLim',[0 1],'YLim',[-100 100],'Visible','off');
            view(obj.hZCursorAxes,0,-90);
            obj.hZAxes = axes('Parent',hParent,'box','on','Units','pixel','XLim',[0 1],'YLim',[-100 100],'ButtonDownFcn',@(varargin)obj.moveZAxes,'YAxisLocation','right','XTick',[],'YTick',[],'Color','black');
            obj.hZAxesTicks = axes('Parent',hParent,'box','on','Units','pixel','XLim',[0 1],'YLim',[-100 100],'HitTest','off','YAxisLocation','right','XTick',[],'Color','none');
            view(obj.hZAxes,0,-90);
            view(obj.hZAxesTicks,0,-90);
            
            obj.hLiveViewOutline = line('Parent',obj.hLiveViewAxes,'XData',[],'YData',[],'HitTest','off','PickableParts','none','LineWidth',3,'Color',color_orange);
            obj.liveViewFov = obj.liveViewFovLim;
            obj.liveViewPosition = [0,0];
            
            obj.hZLinesDashed = line('Parent',obj.hZAxes,'XData',[],'YData',[],'HitTest','off','PickableParts','none','Color','white','LineStyle',':');
            obj.hZLines = line('Parent',obj.hZAxes,'XData',[],'YData',[],'HitTest','off','PickableParts','none','Color','white','LineWidth',1.5);
            obj.hZCursorLine = line('Parent',obj.hZAxes,'XData',[],'YData',[],'HitTest','off','PickableParts','none','LineWidth',3,'Color',color_orange,'Clipping','off');
            obj.hZCursorPatch = patch('Parent',obj.hZCursorAxes,'Faces',[],'Vertices',zeros(0,2),'HitTest','off','PickableParts','none','EdgeColor',color_orange,'FaceColor',color_orange*0.25,'linewidth',3,'Clippin','off');
            obj.hZCursor = line('Parent',obj.hZCursorAxes,'XData',[],'YData',[],'markersize',15,'Marker','>','MarkerFaceColor',color_orange,'color','black','LineWidth',2,'ButtonDownFcn',@(varargin)obj.moveZCursor(),'Clipping','off');
            obj.hZCursorTextRect = rectangle('Parent',obj.hZCursorAxes,'EdgeColor',color_orange,'FaceColor','black','ButtonDownFcn',@(src,evt)obj.selectZDialog,'Clipping','off');
            obj.hZCursorText = text('Parent',obj.hZCursorAxes,'HorizontalAlignment','right','VerticalAlignment','middle','Color',color_orange,'HitTest','off','PickableParts','none','Clipping','off');
            obj.updateZCursor();
            obj.setZAxesYLim([-100 100]);
            
            obj.hZOutOfBoundMarkerUp   = line('Parent', obj.hZAxes, 'XData', NaN, 'YData', NaN, 'Marker','^','Markersize',10,'MarkerFaceColor',color_pink,'color','black','LineWidth',1,'ButtonDownFcn',@(varargin)obj.coerceZRange);
            obj.hZOutOfBoundMarkerDown = line('Parent', obj.hZAxes, 'XData', NaN, 'YData', NaN, 'Marker','v','Markersize',10,'MarkerFaceColor',color_pink,'color','black','LineWidth',1,'ButtonDownFcn',@(varargin)obj.coerceZRange);
            
            obj.hCorrelationLineX = line('Parent',obj.hLiveViewAxes,'XData',[],'YData',[],'Color',color_pink,'LineWidth',2,'HitTest','off','PickableParts','none');
            obj.hCorrelationLineY = line('Parent',obj.hLiveViewAxes,'XData',[],'YData',[],'Color',color_pink,'LineWidth',2,'HitTest','off','PickableParts','none');
            obj.hCorrelationLineZ = line('Parent',obj.hZAxes,'XData',[],'YData',[],'Color',color_gray,'LineWidth',1,'HitTest','off','PickableParts','none');
            obj.hCorrelationLineZSelected = line('Parent',obj.hZAxes,'XData',[],'YData',[],'Color',color_pink,'LineWidth',2,'HitTest','off','PickableParts','none');
            
            resizeAxes();
            
            function resizeAxes(varargin)
                parentSz = hParent.Position(3:4);
                
                padding = 50;
                auxWidth = 100;
                
                maxSizeX = parentSz(1)-2*50;
                maxSizeY = parentSz(2);
                size = max(100,min([maxSizeX maxSizeY])-2*padding);
                viewPosition = [parentSz(1)/2-auxWidth-size/2 parentSz(2)/2-size/2 size size];
                
                obj.hLiveViewAxes.Position = viewPosition;
                obj.hZCursorAxes.Position = [viewPosition(1)+viewPosition(3) viewPosition(2) auxWidth size];
                obj.hZAxes.Position = [viewPosition(1)+viewPosition(3)+auxWidth viewPosition(2) auxWidth size];
                obj.hZAxesTicks.Position = obj.hZAxes.Position;
                
                obj.updateZCursor(); % this is to resize the size of hZCursorTextRect
            end
        end
        
        function initMotionCorrectionConfigPanel(obj,hParent)
            set(hParent,'HeightLimits',[200 200]);
            
            hFlow = most.gui.uiflowcontainer('Parent',hParent,'FlowDirection','TopDown');
            
            hPanel = uipanel('parent',hFlow);
            set(hPanel,'HeightLimits',[95 95],'BorderType','none');
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'checkbox', ...
                'String', 'Reset at end of Acquisition', ...
                'TooltipString', sprintf('Reset correction values after each acquisition\n OR persist values between acquisitions'), ...
                'Bindings',{{obj.hModel.hMotionManager 'resetCorrectionAfterAcq' 'value'}},...
                'Units', 'pixels', ...
                'RelPosition', [5 18 155 15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Reset', ...
                'TooltipString', 'Reset motion correction to dr = [0 0 0].', ...
                'Units', 'pixels', ...
                'RelPosition', [162 20 40 20], ...
                'Callback', @(varargin)obj.hModel.hMotionManager.resetMotionCorrection);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'text', ...
                'String', 'Manual/Auto', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', ...
                'RelPosition', [3    42    70    15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'text', ...
                'String', 'Device', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', ...
                'RelPosition', [3    65    70    15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'text', ...
                'String', 'Bounds', ...
                'HorizontalAlignment', 'right', ...
                'Units', 'pixels', ...
                'RelPosition', [3 88 70 15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'pushbutton', ...
                'String', 'XY', ...
                'TooltipString', 'Performs a manual lateral motion correction.', ...
                'Units', 'pixels', ...
                'RelPosition', [80 42 30 20], ...
                'Callback', @(varargin)obj.hModel.hMotionManager.manualCorrectXY, ...
                'Enable', 'on');
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'checkbox', ...
                'String', '', ...
                'TooltipString', 'Enables/Disables lateral motion correction.', ...
                'Bindings',{{obj.hModel.hMotionManager 'correctionEnableXY' 'value'}},...
                'Units', 'pixels', ...
                'RelPosition', [115 40 15 15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Z', ...
                'TooltipString', 'Performs a manual axial motion correction.', ...
                'Units', 'pixels', ...
                'RelPosition', [140 42 30 20], ...
                'Callback', @(varargin)obj.hModel.hMotionManager.manualCorrectZ, ...
                'Enable', 'on');
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'checkbox', ...
                'String', '', ...
                'TooltipString', 'Enables/Disables axial motion correction.', ...
                'Bindings',{{obj.hModel.hMotionManager 'correctionEnableZ' 'value'}},...
                'Units', 'pixels', ...
                'RelPosition', [175 40 15 15]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'popupmenu', ...
                'String', {'galvos' 'motor'}, ...
                'TooltipString', 'Selects the correction device for lateral alignment', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{obj.hModel.hMotionManager 'correctionDeviceXY' 'choice'},...
                'RelPosition', [80 65 60 20]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'popupmenu', ...
                'String', {'fastz' 'motor'}, ...
                'TooltipString', 'Selects the correction device for axial alignment', ...
                'HorizontalAlignment', 'left', ...
                'Units', 'pixels', ...
                'Bindings',{obj.hModel.hMotionManager 'correctionDeviceZ' 'choice'},...
                'RelPosition', [140 65 60 20]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'edit', ...
                'Units', 'pixels', ...
                'TooltipString', 'Sets the bounds for lateral motion correction', ...
                'Bindings',{{obj.hModel.hMotionManager 'correctionBoundsXY' 'value'}}, ...
                'RelPosition', [80 90 60 20]);
            
            h = most.gui.uicontrol(...
                'parent', hPanel, ...
                'Style', 'edit', ...
                'Units', 'pixels', ...
                'TooltipString', 'Sets the bounds for axial motion correction', ...
                'Bindings',{{obj.hModel.hMotionManager 'correctionBoundsZ' 'value'}}, ...
                'RelPosition', [140 90 60 20]);
            
            obj.hCorrectorInfoTable = uitable('Parent',hFlow,'Units','characters');
            obj.hCorrectorInfoTable.ColumnName = {};
            obj.hCorrectorInfoTable.ColumnEditable = [false true];
            obj.hCorrectorInfoTable.ColumnFormat = {'char' 'char'};
            obj.hCorrectorInfoTable.ColumnWidth = {135 'auto'};
            obj.hCorrectorInfoTable.CellEditCallback = @obj.editCorrectorInfoTable;
            obj.hCorrectorInfoTable.RowName = {};
            
            obj.updateCorrectorInfoTable();
        end
        
        function initPlotsPanel(obj,hParent)
            hParent.SizeChangedFcn = @resizePlots;
            hParent.Units = 'pixel';
            
            obj.hXPlotAxes = axes('Parent',hParent,'Units','pixel','box','on','xgrid','on','ygrid','on','XLim',[-1 0],'YLim',[-1 1]);
            title(obj.hXPlotAxes,'X motion [deg]','FontWeight','normal');
            obj.hYPlotAxes = axes('Parent',hParent,'Units','pixel','box','on','xgrid','on','ygrid','on','XLim',[-1 0],'YLim',[-1 1]);
            view(obj.hYPlotAxes,0,-90); % be consistent with image coordinate system
            xlabel(obj.hYPlotAxes,'time [s]');
            title(obj.hYPlotAxes,'Y motion [deg]','FontWeight','normal');
            obj.hZPlotAxes = axes('Parent',hParent,'Units','pixel','box','on','xgrid','on','ygrid','on','XLim',[-1 0],'YLim',[-1 1]);
            view(obj.hZPlotAxes,0,-90);
            title(obj.hZPlotAxes,'Z motion [um]','FontWeight','normal');
            
            obj.hXPlotLine = line('Parent',obj.hXPlotAxes,'XData',[],'YData',[]);
            obj.hYPlotLine = line('Parent',obj.hYPlotAxes,'XData',[],'YData',[]);
            obj.hZPlotLine = line('Parent',obj.hZPlotAxes,'XData',[],'YData',[]);
            
            resizePlots();
            
            %%% local function
            function resizePlots(src,evt)
                szParent = hParent.Position(3:4);
                spacing = 30;
                leftPad = 30;
                rightPad = 10;
                bottomPad = 45;
                topPad = 45;
                
                axisSize = [(szParent(1)-spacing*2-leftPad-rightPad)/3 szParent(2)-35-topPad];
                axisSize(1) = coerceValue(axisSize(1),[10 Inf]);
                axisSize(2) = coerceValue(axisSize(2),[10 Inf]);
                
                obj.hXPlotAxes.Visible = 'on';
                obj.hXPlotAxes.Position = [leftPad bottomPad axisSize];
                
                obj.hYPlotAxes.Visible = 'on';
                obj.hYPlotAxes.Position = [axisSize(1)+spacing+leftPad bottomPad axisSize];
                
                obj.hZPlotAxes.Visible = 'on';
                obj.hZPlotAxes.Position = [axisSize(1)*2+spacing*2+leftPad bottomPad axisSize];
            end
        end
        
        function initCorrectionPlotsPanel(obj,hParent)
            set(hParent,'WidthLimits',[300 300]);
            
            obj.hXYCorrectionAxes = axes('Parent',hParent,'Units','pixel','box','on','DataAspectRatio',[1 1 1],'XLim',[-1 1],'YLim',[-1 1]);
            obj.hXYCorrectionAxes.Position = [50 45 130 130];
            xlabel(obj.hXYCorrectionAxes,'X Correction [deg]');
            ylabel(obj.hXYCorrectionAxes,'Y Correction [deg]');
            view(obj.hXYCorrectionAxes,0,-90);
            
            obj.hXYCorrectionLine = line('Parent',obj.hXYCorrectionAxes,'Marker','o','XData',[],'YData',[],'MarkerEdgeColor',[1 0 0],'MarkerFaceColor',[1 0.8 0.8]);
            line('Parent',obj.hXYCorrectionAxes,'Marker','+','Color','black','XData',0,'YData',0);
            obj.hXYCorrectionBoundsLine = line('Parent',obj.hXYCorrectionAxes,'XData',[],'YData',[],'LineStyle','--');
            
            obj.hZCorrectionAxes = axes('Parent',hParent,'Units','pixel','box','on','XLim',[0 1],'YLim',[-1 1],'XTick',[],'YAxisLocation','right');
            obj.hZCorrectionAxes.Position = [195 45 50 130];
            ylabel(obj.hZCorrectionAxes,'Z Correction [um]');
            view(obj.hZCorrectionAxes,0,-90);
            
            obj.hZCorrectionZeroLine = line('Parent',obj.hZCorrectionAxes,'XData',[0 1],'YData',[0 0]);
            obj.hZCorrectionLine = line('Parent',obj.hZCorrectionAxes,'XData',[],'YData',[],'LineWidth',2,'Color','red');
            obj.hZCorrectionBoundsLine = line('Parent',obj.hZCorrectionAxes,'XData',[],'YData',[],'LineStyle','--');
            
            obj.hTextMotionCorrection = most.gui.uicontrol(...
                'parent', hParent, ...
                'Style', 'text', ...
                'String', 'Correction Vector\n ', ...
                'HorizontalAlignment', 'center', ...
                'Units', 'pixels', ...
                'RelPosition', [190 190 100 30]);
        end
    end
    
    %% Internal methods
    methods        
        function editTable(obj,src,evt)
            idx = evt.Indices;
            hMEs = obj.getMotionEstimators();
            hME = hMEs(idx(1));
            
            % select motion estimator
            if idx(2) == 1
                if evt.NewData
                    obj.selectMotionEstimator(hME);
                else
                    obj.selectMotionEstimator([]);
                end
            end
            
            % enable/disable motion estimator
            if idx(2) == 2
                hME.enable = evt.NewData;
            end
        end
        
        function motionEstimatorsChanged(obj)
            obj.setupScanfieldView();
            obj.selectMotionEstimator(obj.selectedEstimator); % this updates table implicitly
            obj.setupZAxis();
        end
        
        function hMotionEstimators = getMotionEstimators(obj)
            hMotionEstimators = obj.hModel.hMotionManager.hMotionEstimators;
        end
        
        function selectMotionEstimator(obj,hME)
            [idx,hME] = obj.getMotionEstimatorIdx(hME); % ensure motion estimator is available
            obj.selectedEstimator = hME;
            obj.updateTable();
            obj.updateMotionEstimatorInfoPanel();
            obj.updateMotionEstimatorSelectionDisplay();
            
            % update plots
            forceTraverseEntireHistory = true;
            obj.updateView(forceTraverseEntireHistory);
        end
        
        function updateMotionEstimatorSelectionDisplay(obj)
            if isempty(obj.sfDisp)
                return
            end
            
            if isempty(obj.selectedEstimator)
                selectedMask = false(size(obj.sfDisp.estimatorUuiduint64s));
            else 
                selectedMask = obj.sfDisp.estimatorUuiduint64s == obj.selectedEstimator.uuiduint64;
            end
            
            set(obj.sfDisp.hRefImSurfaces(~selectedMask),'EdgeColor',obj.sfDisp.notSelectedColor);
            set([obj.sfDisp.hLiveImSurfaces(~selectedMask).hSurface],'EdgeColor',obj.sfDisp.notSelectedColor);
            
            set(obj.sfDisp.hRefImSurfaces(selectedMask),'EdgeColor',obj.sfDisp.isSelectedColor);
            set([obj.sfDisp.hLiveImSurfaces(selectedMask).hSurface],'EdgeColor',obj.sfDisp.isSelectedColor);
            
            obj.resetCorrelationPlots();
        end
        
        function [idx,hME] = getMotionEstimatorIdx(obj,hME)
            hMEs = obj.getMotionEstimators();
            if isempty(hME) || isempty(hMEs)
                idx = [];
                hME = [];
            else                
                idx = find([hMEs.uuiduint64] == hME.uuiduint64);
                if isempty(idx)
                    hME = [];
                else
                    hME = hMEs(idx);
                end
            end
        end
        
        function updateTable(obj)
            hMEs = obj.getMotionEstimators();
            
            % table format is
            % {selected enable name #z channels}
            tableData = cell(length(hMEs),4);
            
            for idx = 1:length(hMEs)
                hME = hMEs(idx);
                tableData{idx,1} = false;
                tableData{idx,2} = hME.enable;
                tableData{idx,3} = hME.roiData.hRoi.name;
                tableData{idx,4} = numel(hME.roiData.zs);
                tableData{idx,5} = mat2str(hME.channels);
            end
            
            
            selectionIdx = obj.getMotionEstimatorIdx(obj.selectedEstimator);
            tableData(selectionIdx,1) = {true};
            
            obj.estimatorTable.Data = tableData;
        end
        
        function updateMotionEstimatorInfoPanel(obj)
            hPanel = obj.estimatorInfoTable.Parent.Parent;
            if isempty(obj.selectedEstimator)
                hPanel.Visible = 'off';
                return
            end
            
            hPanel.Visible = 'on';
            classname = class(obj.selectedEstimator);
            classname = regexp(classname,'[^\.]*$','match','once'); % abbreviate package name
            infoString = sprintf('Classname: %s',classname);
            
            hPanel.Title = infoString;
            
            userProps = obj.selectedEstimator.getUserPropertyList();
            mask = ~strcmp(userProps,'enable'); % filter out property 'enable'
            userProps = userProps(mask);
            tableData = cellfun(@(propname)dat2str(obj.selectedEstimator.(propname)),userProps,'UniformOutput',false);
            tableData = [userProps' tableData'];
            
            obj.estimatorInfoTable.Data = tableData;
            obj.estimatorInfoTable.UserData = obj.selectedEstimator;
        end
        
        function editMotionEstimatorInfoTable(obj,src,evt)      
            idx = evt.Indices;
            
            hME = obj.estimatorInfoTable.UserData;
            propName = obj.estimatorInfoTable.Data{idx(1),1};
            
            try
                newData = eval(evt.NewData);
                hME.(propName) = newData;            
            catch ME
                obj.updateMotionEstimatorInfoPanel();
                rethrow(ME);
            end
            
            obj.updateMotionEstimatorInfoPanel();
        end
        
        function enableAllEstimators(obj,tf)
            hMEs = obj.getMotionEstimators();
            for idx = 1:length(hMEs)
                try
                    hMEs.enable = tf;
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
        
        function estimatorClassChanged(obj)
            classname = obj.hModel.hMotionManager.estimatorClassName;
            classname = regexp(classname,'[^\.]*$','match','once'); % abbreviate package name
            obj.etEstimatorClass.String = classname;
        end
        
        function motionHistoryChanged(obj)
            timeToUpdate = toc(obj.lastDisplayUpdate) > 1/obj.displayUpdateRate;
            
            if obj.Visible && timeToUpdate
                obj.updateView();
            end
        end
        
        function updateView(obj,forceTraverseEntireHistory)
            if nargin < 2 || isempty(forceTraverseEntireHistory)
                forceTraverseEntireHistory = false;
            end
            obj.updatePlots();
            obj.updateScanfieldView(forceTraverseEntireHistory);
            obj.lastDisplayUpdate = tic();
        end
        
        function updatePlots(obj)
            motionHistory = obj.hModel.hMotionManager.motionHistory;
            motionHistoryIsEmpty = isempty(motionHistory);
            mask = true(size(motionHistory));
            
            selectedEstimator_ = obj.selectedEstimator; % buffer for performance
            
            % filter history by selected motion estimator
            showSingleMotionEstimator = false;
            
            if motionHistoryIsEmpty
                hMEsUuiduint64 = uint64.empty();
            else
                hMEsUuiduint64 = [motionHistory.hMotionEstimatorUuiduint64];
            end

            if ~isempty(selectedEstimator_) && ~motionHistoryIsEmpty
                mask = mask & (hMEsUuiduint64==selectedEstimator_.uuiduint64);
                showSingleMotionEstimator = true;
            end
            
            % filter history by current z
            if ~isempty(obj.currentZ) && ~motionHistoryIsEmpty
                zs = [motionHistory.z];
                mask = mask & zs==obj.currentZ;
            end
            
            if ~motionHistoryIsEmpty
                tt_motionHistory = [motionHistory.frameTimestamp];
            else
                tt_motionHistory = [];
            end

            % filter by plotTimeLimit
            if ~isempty(obj.plotTimeLimit) && ~motionHistoryIsEmpty
                mask = mask & tt_motionHistory > tt_motionHistory(end)-obj.plotTimeLimit;
            end
            
            xyzUnits_new = {'deg','deg','um'}; %default
            
            if ~any(mask)
                dr = zeros(0,3);
                tt = [];
            else
                if showSingleMotionEstimator
                    dr = {motionHistory(mask).drPixel};
                    xyzUnits_new = {'pixel','pixel','um'};
                else
                    dr = {motionHistory(mask).drRef};
                    xyzUnits_new = {'deg','deg','um'};
                end
                
                dr = vertcat(dr{:});
                
                tt = tt_motionHistory(mask);
                tt = tt - tt(end);
                tt = tt(:);
                
                % detangle multiple estimator time traces
                if ~showSingleMotionEstimator && ~isempty(tt)
                    meUuiduint64s = hMEsUuiduint64(mask);
                    [meUuiduint64s,idxs] = sort(meUuiduint64s);
                    tt = tt(idxs);
                    dr = dr(idxs,:);
                    
                    d = diff(meUuiduint64s); % this unsinged diff is allowed because input is sorted
                    d = logical(d(:));
                    d = [false; d];

                   % sacrifice one timepoint for spacing lines
                    tt(d) = NaN;
                    dr(d,:) = NaN;
                end
            end
            
            if ~isequal(obj.xyzUnits,xyzUnits_new)
                title(obj.hXPlotAxes,sprintf('X motion [%s]',xyzUnits_new{1}),'FontWeight','normal');
                title(obj.hYPlotAxes,sprintf('Y motion [%s]',xyzUnits_new{2}),'FontWeight','normal');
                title(obj.hZPlotAxes,sprintf('Z motion [%s]',xyzUnits_new{3}),'FontWeight','normal');
                obj.xyzUnits = xyzUnits_new;
            end
            
            dx = dr(:,1);
            dy = dr(:,2);
            dz = dr(:,3);
            
            tt = round(tt,3);
            if ~isequal(obj.plotsXTT,tt)
                obj.hXPlotLine.XData = tt;
                obj.hYPlotLine.XData = tt;
                obj.hZPlotLine.XData = tt;
                obj.plotsXTT = tt;
            end
            
            obj.hXPlotLine.YData = dx;
            obj.hYPlotLine.YData = dy;
            obj.hZPlotLine.YData = dz;
            
            if ~isempty(tt)
                XLim = [-obj.plotTimeLimit 0];
                if diff(XLim) <= 0
                    XLim = [tt(1)-1 tt(1)+1]; % guard against invalid XLim
                end
                
                XY_YLim = max([max(abs(dx)) max(abs(dy))]);
                XY_YLim = XY_YLim * 1.2;
                XY_YLim = 2^ceil(log2(XY_YLim)); % avoid axes jumping too much
                XY_YLim = coerceValue(XY_YLim,[0.25,Inf]);
                XY_YLim = [-XY_YLim XY_YLim];
                
                Z_YLim = max([abs(min(dz)) abs(max(dz))]);
                Z_YLim = 2^ceil(log2(Z_YLim)); % avoid axes jumping too much
                Z_YLim = coerceValue(Z_YLim,[0.25,Inf]);
                Z_YLim = [-Z_YLim Z_YLim] * 1.1;
                
                if ~isequal(obj.plotsXLim, XLim)
                    obj.hXPlotAxes.XLim = XLim;
                    obj.hYPlotAxes.XLim = XLim;
                    obj.hZPlotAxes.XLim = XLim;
                    obj.plotsXLim = XLim;
                end
                
                if ~isequal(obj.plotsXY_YLim, XY_YLim)
                    obj.hXPlotAxes.YLim = XY_YLim;
                    obj.hYPlotAxes.YLim = XY_YLim;
                    obj.plotsXY_YLim = XY_YLim;
                end
                
                if ~isequal(obj.plotsZ_YLim, Z_YLim)
                    obj.hZPlotAxes.YLim = Z_YLim;
                    obj.plotsZ_YLim = Z_YLim;
                end
            end
            
            %%% plot Z correlations
            if motionHistoryIsEmpty || isempty(obj.sfDisp) || isempty(obj.sfDisp.estimatorUuiduint64s)
                obj.hCorrelationLineZ.XData = [];
                obj.hCorrelationLineZ.YData = [];
                obj.hCorrelationLineZSelected.XData = [];
                obj.hCorrelationLineZSelected.YData = [];
            else
                mask = tt_motionHistory == tt_motionHistory(end);
                z = [motionHistory(mask).z];
                mask(mask) = obj.currentZ == z;
                
                if any(mask)
                    correlations = {motionHistory(mask).correlation};
                    zs = {motionHistory(mask).zs};
                    meUuidunit64s = [motionHistory(mask).hMotionEstimatorUuiduint64];
                    
                    validmask = false(size(correlations));
                    maxCorrelation = zeros(size(correlations),'single');
                    for idx = 1:length(correlations)
                        [validmask(idx),correlations{idx},maxCorrelation(idx)] = validateZCorrelation(correlations{idx},zs{idx});
                    end
                    correlations = correlations(validmask);
                    zs = zs(validmask);
                    meUuidunit64s = meUuidunit64s(validmask);
                    maxCorrelation = max(maxCorrelation,[],'omitnan');
                    
                    %correlations = cellfun(@(c)normalizeCorrelation(c,maxCorrelation),correlations,'UniformOutput',false);
                    for idx = 1:numel(correlations)
                        correlations{idx} = normalizeCorrelation(correlations{idx},maxCorrelation);
                    end
                    
                    selectedCorrelation = [];
                    selectedZs = [];
                    if ~isempty(selectedEstimator_)
                        meIdx = find(selectedEstimator_.uuiduint64 == meUuidunit64s,1);
                        if ~isempty(meIdx)
                            selectedCorrelation = correlations{meIdx};
                            selectedZs = zs{meIdx};
                        end
                    end
                    obj.hCorrelationLineZSelected.XData = selectedCorrelation;
                    obj.hCorrelationLineZSelected.YData = selectedZs;
                    
                    zs = cellfun(@(zs)zs(:),zs,'UniformOutput',false);
                    zs = reshape(zs,1,[]);
                    zs(2,:) = {NaN};
                    zs = vertcat(zs{:});
                    
                    correlations = reshape(correlations,1,[]);
                    correlations(2,:) = {NaN};
                    correlations = vertcat(correlations{:});
                    
                    obj.hCorrelationLineZ.XData = correlations;
                    obj.hCorrelationLineZ.YData = zs;
                end
            end
                
            function [tf,c,maxC] = validateZCorrelation(c,zs)
                if numel(c)>=3 && iscell(c)
                    c = c{3};
                    tf = isvector(c) && numel(c)== numel(zs) && isnumeric(c) && isreal(c);
                    c = c(:);
                    maxC = max(c);
                else
                    tf = false;
                    maxC = NaN;
                end
            end
            
            function c = normalizeCorrelation(c,maxC)
                if maxC > 0
                    c = c ./ maxC;
                end
            end
        end
        
        function motionCorrectionChanged(obj)
            obj.updateCorrectionPlots();
        end
        
        function motionCorrected(obj)
            if obj.Visible
                most.gui.Transition(0,obj.hXYCorrectionAxes,'Color',[1 0 0]); % stops any previous transition and sets the Color to red
                most.gui.Transition(1,obj.hXYCorrectionAxes,'Color',[1 1 1],'expOut');
                
                most.gui.Transition(0,obj.hZCorrectionAxes,'Color',[1 0 0]);
                most.gui.Transition(1,obj.hZCorrectionAxes,'Color',[1 1 1],'expOut');
            end
        end
        
        function updateCorrectionPlots(obj)
            v = obj.hModel.hMotionManager.motionCorrectionVector;
            boundsXY = obj.hModel.hMotionManager.correctionBoundsXY;
            boundsZ = obj.hModel.hMotionManager.correctionBoundsZ;
            
            obj.hXYCorrectionLine.XData = v(1);
            obj.hXYCorrectionLine.YData = v(2);
            obj.hXYCorrectionBoundsLine.XData = boundsXY([1 2 2 1 1]);
            obj.hXYCorrectionBoundsLine.YData = boundsXY([1 1 2 2 1]);
            
            XYLim = max(abs(boundsXY));
            XYLim = XYLim * 1.2;
            XYLim = 2^ceil(log2(XYLim));
            XYLim = [-XYLim XYLim];
            
            obj.hXYCorrectionAxes.XLim = XYLim;
            obj.hXYCorrectionAxes.YLim = XYLim;
            
            obj.hZCorrectionLine.XData = [0 1];
            obj.hZCorrectionLine.YData = v([3 3]);
            obj.hZCorrectionBoundsLine.XData = [0 1 NaN 0 1];
            obj.hZCorrectionBoundsLine.YData = [boundsZ([1 1]) NaN boundsZ([2 2])];
            
            ZLim = max(abs(boundsZ));
            ZLim = ZLim * 1.2;
            ZLim = 2^ceil(log2(ZLim));
            ZLim = [-ZLim ZLim];
            
            obj.hZCorrectionAxes.XLim = [0 1];
            obj.hZCorrectionAxes.YLim = ZLim;
            
            obj.hTextMotionCorrection.String = sprintf('Correction Vector\n%s',mat2str(v,2));
        end
        
        function windowScrollWheelFcn(obj,src,evt)
            obj.scrollPlotTimeLimit(src,evt);
            obj.scrollZAxis(src,evt);
            obj.scrollLiveViewAxis(src,evt);
        end
        
        function scrollPlotTimeLimit(obj,src,evt)
            tf =       most.gui.isMouseInAxes(obj.hXPlotAxes);
            tf = tf || most.gui.isMouseInAxes(obj.hYPlotAxes);
            tf = tf || most.gui.isMouseInAxes(obj.hZPlotAxes);
            
            if tf
                srollDirection = sign(evt.VerticalScrollCount);
                newPlotTimeLimit = diff(obj.hXPlotAxes.XLim) * 2^srollDirection;
                newPlotTimeLimit = coerceValue(newPlotTimeLimit,[2 1000]);
                obj.plotTimeLimit = newPlotTimeLimit;
            end
        end
        
        function scrollZAxis(obj,src,evt)
            tf =       most.gui.isMouseInAxes(obj.hZCursorAxes);
            tf = tf || most.gui.isMouseInAxes(obj.hZAxes);
            
            if tf
                scrollDirection = sign(evt.VerticalScrollCount);
                pt = obj.hZAxes.CurrentPoint(1,2);
                
                YLim = obj.hZCursorAxes.YLim;
                newYLim = (YLim-pt) * 1.2^scrollDirection + pt;
                obj.setZAxesYLim(newYLim);
            end
        end
        
        function scrollLiveViewAxis(obj,src,evt)
            if ~most.gui.isMouseInAxes(obj.hLiveViewAxes)
                return
            end
            
            modifiers = obj.hFig.CurrentModifier;
            scrollDirection = sign(evt.VerticalScrollCount);
            
            if isequal(modifiers,{'shift'})
                % traverse zs
                zs = obj.getAllZs();
                dzs = zs-obj.currentZ;
                dzs = dzs * scrollDirection;
                dzs(dzs<=0) = NaN;
                [z,idx] = min(dzs);
                
                if ~isempty(z) && ~isnan(z)
                    obj.currentZ = zs(idx);
                end
                
            elseif isequal(modifiers,{'control'})
                % change alpha
                newAlpha = obj.alpha + 0.05*scrollDirection;
                newAlpha = coerceValue(newAlpha,[0 1]);
                obj.alpha = newAlpha;                
            else
                % zoom axes
                oldpt = obj.hLiveViewAxes.CurrentPoint(1,1:2);
                
                obj.liveViewFov = obj.liveViewFov * 1.5^scrollDirection;
                obj.liveViewPosition = obj.liveViewPosition + oldpt - obj.hLiveViewAxes.CurrentPoint(1,1:2);
            end
        end
        
        function motionMarkersXYChanged(obj)
            if ~isempty(obj.sfDisp)
                pts = -obj.hModel.hMotionManager.motionMarkersXY;
                
                pts_sf = cell(0,1);
                
                for idx = 1:size(obj.sfDisp.centerXY,1)
                    pts_sf{idx} = bsxfun(@plus,obj.sfDisp.centerXY(idx,:),pts);
                end
                
                pts_sf = vertcat(pts_sf{:});
                
                if isempty(pts_sf)
                    pts_sf = [NaN NaN];
                end
                
                obj.hMotionMarkerLine.XData = pts_sf(:,1);
                obj.hMotionMarkerLine.YData = pts_sf(:,2);
                obj.hMotionMarkerLine.ZData = zeros(size(pts_sf,1),1);
            end            
        end
        
        function channelLutChanged(obj)
            obj.setupScanfieldView();
        end
        
        function imagingSystemChanged(obj)
            obj.liveViewFovLim = max(obj.hModel.hScan2D.scannerset.angularRange) * 1.8;
        end
        
        function clearScanfieldView(obj,resetPlots)
            if nargin < 2 || isempty(resetPlots)
                resetPlots = true;
            end
            
            if ~isempty(obj.sfDisp)
                obj.checkInSurface(obj.sfDisp.hRefImSurfaces);
                obj.checkInMotionSurface(obj.sfDisp.hLiveImSurfaces);
                obj.sfDisp = [];
            end
            
            if resetPlots
                obj.resetCorrelationPlots();
            end
        end
        
        function resetCorrelationPlots(obj)
            obj.hCorrelationLineX.XData = [];
            obj.hCorrelationLineX.YData = [];
            obj.hCorrelationLineY.XData = [];
            obj.hCorrelationLineY.YData = [];
            obj.hCorrelationLineZ.XData = [];
            obj.hCorrelationLineZ.YData = [];
            obj.hCorrelationLineZSelected.XData = [];
            obj.hCorrelationLineZSelected.YData = [];
        end
        
        function setupScanfieldView(obj) 
            obj.clearScanfieldView();
            
            if ~obj.Visible
                return
            end
            
            hMEs = obj.getMotionEstimators();
            
            sfDisp_ = struct();
            sfDisp_.historyIdx = 0;
            sfDisp_.singleChannelLutMode = []; % if false, the live images will need to be resampled to a lut space of [0 1]
            sfDisp_.singleChannelLutChannel = [];
            sfDisp_.z = obj.currentZ;
            sfDisp_.refImColor = single([0 1 0]); % green
            sfDisp_.liveImColor = single([1 0 0]); % red
            sfDisp_.isSelectedColor = [0 1 0]; % green
            sfDisp_.notSelectedColor = [1 0 0]; % red
            sfDisp_.hME = {};
            sfDisp_.estimatorUuiduint64s = uint64.empty(0,1);
            sfDisp_.roiUuiduint64s = uint64.empty(0,1);
            sfDisp_.channels = {};
            sfDisp_.channelLuts = {};
            sfDisp_.hRefImSurfaces = matlab.graphics.primitive.Surface.empty(0,1);
            sfDisp_.hLiveImSurfaces = struct('hgTransform',{},'hSurface',{});
            sfDisp_.affine = {};
            sfDisp_.imcoordsX = {};
            sfDisp_.imcoordsY = {};
            sfDisp_.centerXY = zeros(0,2);
            sfDisp_.zs = {};
            
            try
                for idx = 1:length(hMEs)
                    hME = hMEs(idx);
                    if hME.enable
                        sf = hME.roiData.hRoi.get(sfDisp_.z);
                        if ~isempty(sf)
                            sfDisp_.hME{end+1} = hME;
                            sfDisp_.estimatorUuiduint64s(end+1) = hME.uuiduint64;
                            sfDisp_.roiUuiduint64s(end+1) = hME.roiUuiduint64;
                            sfDisp_.zs{end+1} = hME.zs;
                            
                            [imcoordsX,imcoordsY,imcoordsZ] = meshgrid(0:1,0:1,1);
                            if hME.roiData.transposed
                                imcoordsX = imcoordsX';
                                imcoordsY = imcoordsY';
                            end
                            
                            [imcoordsX,imcoordsY] = sf.transform(imcoordsX,imcoordsY);
                            sfDisp_.imcoordsX{end+1} = imcoordsX;
                            sfDisp_.imcoordsY{end+1} = imcoordsY;
                            sfDisp_.affine{end+1} = sf.affine;
                            sfDisp_.centerXY(end+1,:) = sf.centerXY;
                            
                            % does the z match?
                            zMask = obj.currentZ == hME.zs;
                            if any(zMask)
                                % use the first channel for now
                                channelIdx = 1;
                                channel = sort(hME.roiData.channels(channelIdx)); % for sanity
                                refIm = hME.roiData.imageData{channelIdx}{zMask};
                                sfDisp_.channels{end+1} = hME.roiData.channels;
                                sfDisp_.channelLuts{end+1} = obj.hModel.hChannels.channelLUT{channel};
                            else
                                refIm = [];
                                sfDisp_.channels{end+1} = [];
                                sfDisp_.channelLuts{end+1} = [];
                            end
                            
                            isselected = hME.isequal(obj.selectedEstimator);
                            if isselected
                                edgeColor = sfDisp_.isSelectedColor;
                            else
                                edgeColor = sfDisp_.notSelectedColor;
                            end
                            
                            %%% reference image
                            hSurf = obj.checkOutSurface();
                            sfDisp_.hRefImSurfaces(end+1) = hSurf;
                            
                            hSurf.XData = imcoordsX;
                            hSurf.YData = imcoordsY;
                            hSurf.ZData = imcoordsZ*2;
                            hSurf.EdgeColor = edgeColor;
                            hSurf.ButtonDownFcn = @(src,evt)obj.clickSelectMotionEstimator(src,evt,hME);
                            
                            if isempty(refIm)
                                hSurf.FaceColor = 'none';
                                hSurf.CData = [];
                            else
                                lut = single(obj.hModel.hChannels.channelLUT{channel});
                                refIm = single(refIm);
                                refIm = refIm - lut(1);
                                color = reshape(sfDisp_.refImColor,1,1,[]) ./ diff(lut);
                                CData = bsxfun(@times,refIm,color);
                                hSurf.CData = CData;
                                hSurf.FaceColor = 'texturemap';
                            end
                            
                            %%% live image                            
                            motionSurf = obj.checkOutMotionSurface();
                            sfDisp_.hLiveImSurfaces(end+1) = motionSurf;                            
                            motionSurf.hSurface.XData = imcoordsX;
                            motionSurf.hSurface.YData = imcoordsY;
                            motionSurf.hSurface.ZData = imcoordsZ*1;
                            motionSurf.hSurface.EdgeColor = edgeColor;
                            motionSurf.hSurface.FaceAlpha = obj.alpha;
                        end
                    end
                end
            catch ME
                %most.idioms.safeDeleteObj(sfDisp_.hHGGroups);
                rethrow(ME);
            end
            
            isemptyMask = cellfun(@(lut)isempty(lut),sfDisp_.channels);
            allChannels = vertcat(sfDisp_.channels{~isemptyMask});
            allLuts = vertcat(sfDisp_.channelLuts{~isemptyMask});
            
            if ~isempty(allLuts) && isscalar(unique(allChannels))
                sfDisp_.singleChannelLutMode = true;
                sfDisp_.singleChannelLutChannel = allChannels(1);
                obj.hLiveViewAxes.CLim = allLuts(1,:);
            else
                sfDisp_.singleChannelLutMode = false;
                obj.hLiveViewAxes.CLim = [0 1];
            end
            
            obj.sfDisp = sfDisp_;
            
            forceTraverseEntireHistory = true;
            obj.updateScanfieldView(forceTraverseEntireHistory);
            obj.motionMarkersXYChanged();
        end
        
        function hSurf = checkOutSurface(obj)
            if isempty(obj.surfStorage)
                hSurf = surface('Parent',obj.hLiveViewAxes,'CData',NaN);
                hSurf.CDataMapping = 'scaled';
                hSurf.FaceLighting = 'none';
                hSurf.LineStyle = ':';
                hSurf.HitTest = 'on';
                hSurf.PickableParts = 'visible';
            else
                hSurf = obj.surfStorage(end);
                obj.surfStorage(end) = [];
                if ~isvalid(hSurf)
                    hSurf = obj.checkOutSurface();
                end
                hSurf.Visible = 'on';
            end
        end
        
        function checkInSurface(obj,hSurfs)
            if ~isempty(hSurfs)
                set(hSurfs,'Visible','off');
                obj.surfStorage = horzcat(obj.surfStorage,hSurfs(:)');
            end
        end
        
        function motionSurf = checkOutMotionSurface(obj)
            if isempty(obj.motionSurfStorage)
                motionSurf = struct();
                motionSurf.hgTransform = hgtransform('Parent',obj.hLiveViewAxes,'HitTest','off','PickableParts','none');
                motionSurf.hSurface = surface(...
                    'Parent',motionSurf.hgTransform,...
                    'XData',NaN,...
                    'YData',NaN,...
                    'ZData',NaN,...
                    'CData',zeros(4,'single'),...
                    'FaceColor','texturemap',...
                    'CDataMapping','scaled',...
                    'FaceLighting','none',...
                    'LineStyle','-',...
                    'HitTest','off',...
                    'PickableParts','none',...
                	'Visible','off');
            else
                motionSurf = obj.motionSurfStorage(end);
                obj.motionSurfStorage(end) = [];
                if ~isvalid(motionSurf.hgTransform) || ~isvalid(motionSurf.hSurface)
                    most.idioms.safeDeleteObj(motionSurf.hgTransform);
                    most.idioms.safeDeleteObj(motionSurf.hSurface);
                    motionSurf = obj.checkOutMotionSurface();
                end
            end
        end
        
        function checkInMotionSurface(obj,motionSurf)
            if ~isempty(motionSurf)
                set([motionSurf.hgTransform],'Matrix',eye(4));
                set([motionSurf.hSurface],'Visible','off');
                obj.motionSurfStorage = horzcat(obj.motionSurfStorage,motionSurf(:)');
            end
        end
        
        function updateScanfieldView(obj,forceTraverseEntireHistory)     
            if nargin<2 || isempty(forceTraverseEntireHistory)
                forceTraverseEntireHistory = false;                
            end
            
            motionHistory = obj.hModel.hMotionManager.motionHistory;
            
            if isempty(obj.sfDisp) || isempty(motionHistory)
                return
            end
            
            if forceTraverseEntireHistory
                % traverse through entire history
                startIdx = 1;
            else
                % pick up from where we stopped during last call to updateScanfieldView
                historyIdxs = [motionHistory.historyIdx];
                startIdx = find(historyIdxs > obj.sfDisp.historyIdx,1,'first');
            end
            
            obj.sfDisp.historyIdx = motionHistory(end).historyIdx; % update pointer for next call to updateScanfieldView
            
            sfDispUpdated = false(1,numel(obj.sfDisp.estimatorUuiduint64s));
            
            selectedEstimator_ = obj.selectedEstimator;
            
            % work through history in refverse order
            % i.e. display newest items first
            for histIdx = numel(motionHistory):-1:startIdx
                if all(sfDispUpdated)
                    % already updated all sfDisp. Stop traversing through
                    % history
                    break;
                end
                
                if motionHistory(histIdx).z ~= obj.sfDisp.z
                    continue % don't draw stuff that's not on the current z
                end
                
                sfDispIdx = find(obj.sfDisp.estimatorUuiduint64s == motionHistory(histIdx).hMotionEstimatorUuiduint64,1);
                if isempty(sfDispIdx)
                    continue % this should never happen
                end
                
                sfDispUpdated(sfDispIdx) = true;
                
                roiData = motionHistory(histIdx).roiData;
                
                if issorted(roiData.channels) % for sanity
                    % use ismembc2 for performance
                    chMask = ismembc2(roiData.channels,obj.sfDisp.channels{sfDispIdx}); % obj.sfDisp.channels is sorted in setupScanfieldView
                else
                    chMask = ismember(roiData.channels,obj.sfDisp.channels{sfDispIdx});
                end
                chIdx = find(chMask,1,'first');
                
                if isempty(chIdx)
                    continue % this should never happen
                end
                
                drRefXY = motionHistory(histIdx).drRef(1:2);
                if ~any(isnan(drRefXY))
                    % performance problem: this call needs to query hHGTransform.Matrix first, then update it.
                    % this requires refreshing the display first
                    %obj.sfDisp.hHGTransforms(sfDispIdx).Matrix(13:14) = -drRefXY;
                    
                    % instead set entire matrix
                    matrix3D = eye(4);
                    matrix3D(13:14) = -drRefXY;
                    obj.sfDisp.hLiveImSurfaces(sfDispIdx).hgTransform.Matrix = matrix3D; % this call seems slower than it should be

%                    % this code is even slower:
%                     matrix2D = eye(3);
%                     matrix2D(7:8) = -drRefXY;
%                     XX = obj.sfDisp.imcoordsX{sfDispIdx};
%                     YY = obj.sfDisp.imcoordsY{sfDispIdx};
%                     [XX,YY] = scanimage.mroi.util.xformMesh(XX,YY,matrix2D);
%                     hSurf = obj.sfDisp.hLiveImSurfaces(sfDispIdx);
%                     hSurf.XData = XX;
%                     hSurf.YData = YY;
                end
                
                imageData = roiData.imageData{chIdx}{1};
                
                if ~obj.sfDisp.singleChannelLutMode
                    % need to resample imageData into unity lut
                    lut = single(obj.sfDisp.channelLuts{sfDispIdx});
                    imageData = (single(imageData) - lut(1))./diff(lut);
                end
                obj.sfDisp.hLiveImSurfaces(sfDispIdx).hSurface.CData = imageData;
                obj.sfDisp.hLiveImSurfaces(sfDispIdx).hSurface.Visible = 'on';

                % update correlation plots
                if ~isempty(selectedEstimator_) && obj.sfDisp.estimatorUuiduint64s(sfDispIdx) == selectedEstimator_.uuiduint64
                    % update xy correlation plot
                    correlations = motionHistory(histIdx).correlation;
                    
                    resXY = size(roiData.imageData{chIdx}{1});
                    affine = obj.sfDisp.affine{sfDispIdx};
                    
                    correlationScale = 1/4 ;
                    
                    % corrleations are user provided. better do proper validation
                    if ~isempty(correlations) && iscell(correlations) && numel(correlations)>=1 && ...
                       ~isempty(correlations(1)) && isvector(correlations{1}) && ...
                       numel(correlations{1})== resXY(1) && isnumeric(correlations{1}) && isreal(correlations{1})
                        
                        correlation = correlations{1};
                        correlation = correlation(:);
                        normalizationFactor = max(abs(correlation));
                        if normalizationFactor > 0
                            correlation = correlation / normalizationFactor; % normalize
                        end
                        
                        xx = linspace(1,0,numel(correlation));
                        if drRefXY(2) < 0
                            yy = correlation * -correlationScale;
                        else
                            yy = correlation * correlationScale + 1;
                        end
                        
                        [xx,yy] = scanimage.mroi.util.xformPointsXY(xx,yy,affine);
                        
                        obj.hCorrelationLineX.XData = xx;
                        obj.hCorrelationLineX.YData = yy;
                    else
                        obj.hCorrelationLineX.XData = [];
                        obj.hCorrelationLineX.YData = [];
                    end
                    
                    if ~isempty(correlations) && iscell(correlations) && numel(correlations)>=2 && ...
                       ~isempty(correlations(2)) && isvector(correlations{2}) && ...
                       numel(correlations{2})== resXY(2) && isnumeric(correlations{2}) && isreal(correlations{2})
                   
                        correlation = correlations{2};
                        normalizationFactor = max(abs(correlation));
                        if normalizationFactor > 0
                            correlation = correlation / normalizationFactor; % normalize
                        end
                        
                        yy = linspace(1,0,numel(correlation));
                        if drRefXY(1) < 0
                            xx = correlation * -correlationScale;
                        else
                            xx = correlation * correlationScale + 1;
                        end
                        
                        [xx,yy] = scanimage.mroi.util.xformPointsXY(xx,yy,affine);

                        obj.hCorrelationLineY.XData = xx;
                        obj.hCorrelationLineY.YData = yy;
                    else
                        obj.hCorrelationLineY.XData = [];
                        obj.hCorrelationLineY.YData = [];
                    end
                end
            end
        end
        
        function setupZAxis(obj)
            zs = obj.hModel.hStackManager.zs;
            numZs = numel(zs);
            
            xx = repmat([0; 1; NaN],1,numZs);
            yy = [zs(:)'; zs(:)'; nan(1,numZs)];
            
            obj.hZLines.XData = xx(:);
            obj.hZLines.YData = yy(:);
            
            if isempty(obj.selectedEstimator)
                hMEs = obj.getMotionEstimators();
            else
                hMEs = obj.selectedEstimator;
            end
            
            if isempty(hMEs)
                xxMEs = [];
                yyMEs = [];
                zsMEs = [];
            else
                zsMEs = {hMEs.zs};
                zsMEs = cellfun(@(zs_)reshape(zs_,1,[]),zsMEs,'UniformOutput',false); % reshape to row vector
                zsMEs = unique(horzcat(zsMEs{:}));
                numZsMEs = numel(zsMEs);
                
                xxMEs = repmat([0; 1; NaN],1,numZsMEs);
                yyMEs = [zsMEs; zsMEs; nan(1,numZsMEs)];
            end
            
            obj.hZLinesDashed.XData = xxMEs(:);
            obj.hZLinesDashed.YData = yyMEs(:);
            
            obj.interestingZs = [zs(:); zsMEs(:)];
            obj.updateZOutOfBoundMarkers();
        end
        
        function updateZCursor(obj)
            obj.hZCursorLine.XData = [0 1];
            obj.hZCursorLine.YData = [obj.currentZ obj.currentZ];
            obj.hZCursor.XData = 0.85;
            obj.hZCursor.YData = obj.currentZ;
            
            YLim = obj.hZCursorAxes.YLim;
            
            xx = linspace(0,0.85,100);
            yy1 = spline(xx([1 end]),[0 YLim(1) obj.currentZ (obj.currentZ-YLim(1))/2],xx);
            yy2 = spline(xx([1 end]),[0 YLim(2) obj.currentZ (obj.currentZ-YLim(2))/2],xx);
            
            patchVertices = [        xx(:) ,        yy1(:) ;
                              flipud(xx(:)), flipud(yy2(:)) ];
            
            obj.hZCursorPatch.Vertices = patchVertices;
            obj.hZCursorPatch.Faces = 1:size(patchVertices,1);
            
            textHeight = diff(obj.hZCursorAxes.YLim) / obj.hZCursorAxes.Position(4) * 20;
            position = [0.05 obj.currentZ-textHeight/2 0.7 textHeight];
            obj.hZCursorTextRect.Position = position;
            
            obj.hZCursorTextRect.Curvature = [0.2 1];
            
            obj.hZCursorText.HorizontalAlignment = 'center';
            obj.hZCursorText.VerticalAlignment = 'middle';
            obj.hZCursorText.Position = [0.4 obj.currentZ];
            
            z_meter = obj.currentZ / 1e6;
            obj.hZCursorText.String = most.idioms.engineersStyle(z_meter,'m','%.1f');
            
            obj.updateZOutOfBoundMarkers
        end
        
        function updateZOutOfBoundMarkers(obj)
            zBounds = obj.hZCursorAxes.YLim;
            
            allZs = [obj.currentZ; obj.interestingZs];

            if any(allZs < zBounds(1))
                obj.hZOutOfBoundMarkerUp.XData = 0.5;
                obj.hZOutOfBoundMarkerUp.YData = zBounds(1);
            else
                obj.hZOutOfBoundMarkerUp.XData = NaN;
                obj.hZOutOfBoundMarkerUp.YData = NaN;
            end
            
            if any(allZs > zBounds(2))
                obj.hZOutOfBoundMarkerDown.XData = 0.5;
                obj.hZOutOfBoundMarkerDown.YData = zBounds(2);
            else
                obj.hZOutOfBoundMarkerDown.XData = NaN;
                obj.hZOutOfBoundMarkerDown.YData = NaN;
            end
        end
        
        function coerceZRange(obj)
            allZs = [obj.currentZ; obj.interestingZs];
            zLims(1) = min(allZs);
            zLims(2) = max(allZs);
            
            dz = diff(zLims);
            if dz <= 0
                dz = 60;
            end
            
            extension = 0.4;
            zLims(1) = floor(zLims(1) - dz * extension/2);
            zLims(2) = ceil(zLims(2) + dz * extension/2);
            
            obj.setZAxesYLim(zLims);
        end
        
        function selectZDialog(obj)
            answer = num2str(obj.currentZ);
            answer = inputdlg('Enter a new Z in microns','Select Z',1,{answer});
            if ~isempty(answer)
                answer = answer{1};
                answer = str2double(answer);
                validateattributes(answer,{'numeric'},{'scalar','nonnan','finite','real'})
                obj.currentZ = answer;
            end
        end
        
        function hover(obj,varargin)
            obj.hoverSelectMotionEstimator();
        end
        
        function hoverSelectMotionEstimator(obj)
            [inAx,pt_2D] = most.gui.isMouseInAxes(obj.hLiveViewAxes);
            if ~inAx
                return
            end
            
            if ~isempty(obj.sfDisp) && ~isempty(obj.sfDisp.imcoordsX)
                for idx = 1:numel(obj.sfDisp.imcoordsX)
                    hME = obj.sfDisp.hME{idx};
                    xx = obj.sfDisp.imcoordsX{idx};
                    yy = obj.sfDisp.imcoordsY{idx};
                    
                    hitME = inpolygon(pt_2D(1),pt_2D(2),xx(:),yy(:));
                    if hitME && ~isequal(obj.selectedEstimator,hME)
                        obj.selectMotionEstimator(hME);
                        return % Done searching
                    end
                end
            end
        end
        
        function clickSelectMotionEstimator(obj,src,evt,hME)
            persistent lastClick
            if isempty(lastClick)
                lastClick = uint64(0);
            end
            
            doubleClickDelay = 0.5;
            
            if toc(lastClick) < doubleClickDelay
                % double click
                if isequal(hME,obj.selectedEstimator)
                    obj.selectMotionEstimator([]);
                else
                    obj.selectMotionEstimator(hME);
                end
            end
            
            obj.moveLiveViewAxes();
            
            lastClick = tic();
        end
        
        function windowButtonMotionFcn(obj,motionFcn,stopFcn)
            if nargin < 3 || isempty(stopFcn)
                stopFcn = [];
            end
            
            validateattributes(motionFcn,{'function_handle'},{'scalar'});
            if ~isempty(stopFcn)
                validateattributes(stopFcn,{'function_handle'},{'scalar'});
            end            
            
            WindowButtonUpFcn_old = obj.hFig.WindowButtonUpFcn;
            WindowButtonMotionFcn_old = obj.hFig.WindowButtonMotionFcn;
            
            obj.hFig.WindowButtonMotionFcn = @(src,evt)move(src,evt,motionFcn,stopFcn);
            obj.hFig.WindowButtonUpFcn = @(src,evt)endMove(src,evt,stopFcn);
            
            function move(src,evt,motionFcn,stopFcn)
                try
                    motionFcn(src,evt);
                catch ME
                    endMove(src,evt,stopFcn);
                    rethrow(ME);
                end
            end
            
            function endMove(src,evt,stopFcn)
                obj.hFig.WindowButtonUpFcn = WindowButtonUpFcn_old;
                obj.hFig.WindowButtonMotionFcn = WindowButtonMotionFcn_old;
                
                if ~isempty(stopFcn)
                    stopFcn(src,evt);
                end
            end
        end
        
        function moveZCursor(obj)
            obj.windowButtonMotionFcn(@(src,evt)move);
            
            function move()
                pt = obj.hZCursorAxes.CurrentPoint(1,1:2);
                z = pt(2);
                
                % snap to zs
                zs = obj.getAllZs();
                
                [~,idx] = min(abs(z-zs));
                nearestZ = zs(idx);
                
                tolerancePixels = 5; %snapping tolerance
                toleranceZSpace = diff(obj.hZCursorAxes.YLim)/obj.hZCursorAxes.Position(4)*tolerancePixels;
                
                if abs(nearestZ-z) <= toleranceZSpace
                   z = nearestZ; 
                end
                
                if z ~= obj.currentZ
                    obj.currentZ = z;
                end
            end
        end
        
        function moveZAxes(obj)            
            pt = obj.hZAxes.CurrentPoint(1,1:2);
            startZ = pt(2);
            
            obj.windowButtonMotionFcn(@(src,evt)move(startZ));
            
            function move(startZ)
                pt = obj.hZAxes.CurrentPoint(1,1:2);
                z = pt(2);
                dz = z-startZ;
                newYLim = obj.hZAxes.YLim - dz;
                obj.setZAxesYLim(newYLim);
            end
        end
        
        function moveLiveViewAxes(obj)
            previousPt = obj.hLiveViewAxes.CurrentPoint(1,1:2);
            obj.windowButtonMotionFcn(@(src,evt)move());
            
            function move()
                currentPt = obj.hLiveViewAxes.CurrentPoint(1,1:2);
                d = currentPt-previousPt;
                obj.liveViewPosition = obj.liveViewPosition-d;
                previousPt = obj.hLiveViewAxes.CurrentPoint(1,1:2);
            end
        end
        
        function setZAxesYLim(obj,YLim)
            obj.hZCursorAxes.YLim = YLim;
            obj.hZAxes.YLim = YLim;
            
            [~,prefix,exponent] = most.idioms.engineersStyle(max(abs(YLim))*1e-6,'m');
            obj.hZAxesTicks.YLim = YLim.*1e-6 ./ 10^exponent;
            ylabel(obj.hZAxesTicks,['Z [' prefix 'm]']);
            
            obj.updateZCursor();
            obj.updateZOutOfBoundMarkers();
        end
        
        function updateLiveViewPosition(obj)
            XLim = obj.liveViewPosition(1) + [-obj.liveViewFov obj.liveViewFov]/2;
            YLim = obj.liveViewPosition(2) + [-obj.liveViewFov obj.liveViewFov]/2;
            obj.hLiveViewAxes.XLim = XLim;
            obj.hLiveViewAxes.YLim = YLim;
            obj.hLiveViewOutline.XData = XLim([1 1 2 2 1]);
            obj.hLiveViewOutline.YData = YLim([1 2 2 1 1]);
        end
        
        function editCorrectorInfoTable(obj,src,evt)
            idx = evt.Indices;
            
            hCorrector = obj.hCorrectorInfoTable.UserData;
            propName = obj.hCorrectorInfoTable.Data{idx(1),1};
            
            try
                newData = eval(evt.NewData);
                hCorrector.(propName) = newData;            
            catch ME
                obj.updateCorrectorInfoTable();
                rethrow(ME);
            end
            
            obj.updateCorrectorInfoTable();
        end
        
        function updateCorrectorInfoTable(obj)            
            hCorrector = obj.hModel.hMotionManager.hMotionCorrector;
            if isempty(hCorrector)
                tableData = {};
            else
                userProps = hCorrector.getUserPropertyList();
                tableData = cellfun(@(propname)dat2str(hCorrector.(propname)),userProps,'UniformOutput',false);
                tableData = [userProps',tableData'];
            end
            
            obj.hCorrectorInfoTable.Data = tableData;
            obj.hCorrectorInfoTable.UserData = hCorrector;
        end
        
        function motionCorrectorChanged(obj)
            most.idioms.safeDeleteObj(obj.hMotionCorrectorChangedListener);
            obj.hMotionCorrectorChangedListener = [];
            
            hCorrector = obj.hModel.hMotionManager.hMotionCorrector;
            
            if ~isempty(hCorrector)
                obj.hMotionCorrectorChangedListener = addlistener(hCorrector,'changed',@(varargin)obj.updateCorrectorInfoTable);
                classname = regexp(class(hCorrector),'[^\.]*$','match','once'); % abbreviate package name
                obj.hTextMotionCorrector.String = classname;
            else
                obj.hTextMotionCorrector.String = '';
            end
            
            obj.updateCorrectorInfoTable();
        end
        
        function zs = getAllZs(obj)
            zs = obj.hModel.hStackManager.zs;
            
            if isempty(obj.selectedEstimator)
                hMEs = obj.getMotionEstimators();
                if ~isempty(hMEs)
                    enableMask = [hMEs.enable];
                    hMEs = hMEs(enableMask);
                end
            else
                hMEs = obj.selectedEstimator;
            end
            
            if ~isempty(hMEs)
                zsMEs = {hMEs.zs};
                zsMEs = cellfun(@(zs_)reshape(zs_,1,[]),zsMEs,'UniformOutput',false); % reshape to row vector
                zsMEs = unique(horzcat(zsMEs{:}));
                zs = horzcat(zs(:)',zsMEs);
            end
        end
    end
    
    %% Overloaded methods from most.Gui
    methods (Hidden,Access=protected)
        function visibleChangedHook(obj)
            if obj.Visible
                obj.setupScanfieldView();
            end
        end
    end
    
    %% Property Getter/Setter
    methods
        function val = get.selectedEstimator(obj)
            if ~most.idioms.isValidObj(obj.selectedEstimator)
                obj.selectedEstimator = [];
            end
            
            val = obj.selectedEstimator;
        end
        
        function set.displayUpdateRate(obj,val)            
            obj.displayUpdateRate = val;
        end
        
        function set.plotTimeLimit(obj,val)
            obj.plotTimeLimit = val;
            obj.updatePlots();
        end
        
        function set.currentZ(obj,val)
            obj.currentZ = val;
            obj.setupScanfieldView();
            obj.updateZCursor();
        end
        
        function set.alpha(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnan','>=',0,'<=',1});
            oldVal = obj.alpha;
            obj.alpha = val;
            
            if oldVal ~= val && ~isempty(obj.sfDisp)
                set([obj.sfDisp.hLiveImSurfaces.hSurfaces],'FaceAlpha',obj.alpha);
            end
        end
        
        function set.liveViewFov(obj,v)
            obj.liveViewFov = max(min(obj.liveViewFovLim,v),2^-8);
            obj.liveViewPosition = obj.liveViewPosition;
        end
        
        function set.liveViewPosition(obj,v)
            mxPos = (obj.liveViewFovLim-obj.liveViewFov)/2;
            obj.liveViewPosition = max(min(v,mxPos),-mxPos);
            obj.updateLiveViewPosition();
        end
    end
end

%% Local functions
function val = coerceValue(val,bounds)
    val = min(max(val,bounds(1)),bounds(2));
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
% MotionDisplay.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
