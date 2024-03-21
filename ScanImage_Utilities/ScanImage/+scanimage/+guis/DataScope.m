classdef DataScope < most.Gui    
    properties (SetObservable)
        hDataScope;
        showPowerSpectrum = true;
        showTriggers = NaN;
        fftCursorValue = [];
    end
        
    properties (Hidden,SetAccess = private)
        hPlotAx;
        hPlotLine;
        hPlotCursor;
        hTrigAx;
        hTrigLines = struct();
        hTrigCursor;
        hFftAx;
        hFftCursor;
        hFftCursorPt;
        hPowerLine;
        hFftFlow;
        hBrush;
        brushLim;
        
        data;
        
        hListeners;
        hControls;
        powerSpectrumReference;
        
        colorOrder = get(0,'defaultAxesColorOrder');
    end
    
    methods
        function obj = DataScope(hModel, hController)
            %% main figure
            if nargin < 1
                hModel = [];
            end
            
            if nargin < 2
                hController = [];
            end
            
            size = [180,50];
            obj = obj@most.Gui(hModel,hController,size,'characters');
            
            obj.initGui();
            obj.refreshGui();
            
            obj.hFig.Name = 'Data Scope';
            obj.hFig.WindowScrollWheelFcn = @obj.windowScrollWheelFcn;            
            obj.hFig.CloseRequestFcn = @(src,evt)set(src,'Visible','off');
            obj.hFig.WindowButtonMotionFcn = @obj.hover;
            
            obj.showTriggers = false;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
        end
    end
    
    % Internal methods
    methods (Hidden, Access=protected)
        function visibleChangedHook(obj,varargin)
            if ~obj.Visible && ~isempty(obj.hDataScope) && isvalid(obj.hDataScope) && obj.hDataScope.active
                obj.hDataScope.abort();
            end
        end
    end
    
    methods (Access = private)
        function initGui(obj)
            flowMargin = 0.1;
            topFlow = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','Margin',flowMargin);
                leftPanelFlow = most.gui.uiflowcontainer('Parent',topFlow,'FlowDirection','TopDown','Margin',flowMargin,'WidthLimits',[178 178]);
                rightFlow = most.gui.uiflowcontainer('Parent',topFlow,'FlowDirection','TopDown','Margin',flowMargin);
                    timeTraceFlow = most.gui.uiflowcontainer('Parent',rightFlow,'FlowDirection','LeftToRight','Margin',flowMargin);
                        hTimeTracePanel = uipanel('parent',timeTraceFlow,'Title','Time Plot');
                            obj.hControls.hTimeTracePanelGrid = uigridcontainer('v0','Parent',hTimeTracePanel,'GridSize',[2,1],'VerticalWeight',[2,1]);
                    obj.hFftFlow = most.gui.uiflowcontainer('Parent',rightFlow,'FlowDirection','LeftToRight','Margin',flowMargin);
                    
            obj.initSidePanel(leftPanelFlow);
            obj.initTimeTracePlot(obj.hControls.hTimeTracePanelGrid);
            obj.initTriggerPlot(obj.hControls.hTimeTracePanelGrid);
            obj.initFftPlot(obj.hFftFlow);
        end
        
        function initSidePanel(obj,hParent)
            hSidePanel = uipanel('parent',hParent,'Title','Settings');
            
            obj.hControls.pbStart = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'pbStart', ...
                'Style', 'pushbutton', ...
                'String', 'Start Oscilloscope', ...
                'TooltipString', 'Starts/Aborts the Oscilloscope.', ...
                'Callback', @(varargin)obj.startAbort, ...
                'Units', 'pixels', ...
                'RelPosition', [10 48 150 30]);
            
            obj.hControls.lbChannelSelect = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbChannelSelect', ...
                'Style', 'text', ...
                'String', 'Channel', ...
                'Units', 'pixels', ...
                'RelPosition', [-30 72 200 15]);
            
            obj.hControls.pmChannelSelect = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'pmChannelSelect', ...
                'Style', 'popupmenu', ...
                'String', {''}, ...
                'TooltipString', 'Select the channel to display in the the oscilloscope', ...
                'Callback', @(varargin)obj.channelChangedCallback, ...
                'Units', 'pixels', ...
                'RelPosition', [100 71 60 20]);
            
            obj.hControls.cbShowFft = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'cbShowFft', ...
                'Style', 'checkbox', ...
                'String', 'Show Power Spectrum', ...
                'TooltipString', 'Shows / Hides the power spectrum.', ...
                'Bindings',{{obj 'showPowerSpectrum' 'value'}},...
                'Units', 'pixels', ...
                'RelPosition', [26 168 200 30]);
            
            obj.hControls.lbFftUnit = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbFftUnit', ...
                'Style', 'text', ...
                'String', 'Power Unit', ...
                'Units', 'pixels', ...
                'RelPosition', [13 196 100 26]);
            
            obj.hControls.pmFftUnitSelect = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'pmFftUnitSelect', ...
                'Style', 'popupmenu', ...
                'String', {'dBV','dBmV','dBuV'}, ...
                'TooltipString', 'Selects the unit for the power spectrum.', ...
                'Callback', @obj.fftUnitChanged, ...
                'Units', 'pixels', ...
                'RelPosition', [100 195 60 30]);
            
            obj.hControls.lbTrigger = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbTrigger', ...
                'Style', 'text', ...
                'String', 'Trigger', ...
                'Units', 'pixels', ...
                'RelPosition', [22 95 100 15]);
            
            obj.hControls.pmTrigger = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'pmTrigger', ...
                'Style', 'popupmenu', ...
                'String', {''}, ...
                'TooltipString', 'Selects the trigger for the oscilloscope', ...
                'Callback', @(varargin)obj.triggerChanged, ...
                'Units', 'pixels', ...
                'RelPosition', [100 96 60 20]);
            
            obj.hControls.lbSliceNumber = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbSliceNumber', ...
                'Style', 'text', ...
                'String', 'SliceNumber', ...
                'Units', 'pixels', ...
                'RelPosition', [-40 118 200 15]);
            
            obj.hControls.etSliceNumber = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'etSliceNumber', ...
                'Style', 'edit', ...
                'String', '', ...
                'TooltipString', 'Slice Number to be triggered off', ...
                'Units', 'pixels', ...
                'Callback', @(varargin)obj.sliceNumberChanged, ...
                'RelPosition', [100 120 60 20]);
            
            obj.hControls.lbLineNumber = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbLineNumber', ...
                'Style', 'text', ...
                'String', 'Line Number', ...
                'Units', 'pixels', ...
                'RelPosition', [-40 139 200 15]);
            
            obj.hControls.etLineNumber = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'etLineNumber', ...
                'Style', 'edit', ...
                'String', '', ...
                'TooltipString', 'Line Number to be triggered off', ...
                'Units', 'pixels', ...
                'Callback', @(varargin)obj.lineNumberChanged, ...
                'RelPosition', [100 142 60 20]);
            
            obj.hControls.lbInfo = most.gui.uicontrol(...
                'parent', hSidePanel, ...
                'Tag', 'lbInfo', ...
                'Style', 'text', ...
                'String', '', ...
                'TooltipString', 'Sample Rate (MHz)', ...
                'Units', 'pixels', ...
                'RelPosition', [9 340 147 50], ...
                'HorizontalAlignment', 'left');
            
            obj.hControls.triggerTable = most.gui.uicontrol(...
                'Parent',hSidePanel,...
                'Tag','triggerTable',...
                'Style','table',...
                'ColumnName',{'' 'Trigger Display'},...
                'ColumnEditable',[true false],...
                'ColumnFormat',{'logical' 'char'},...
                'ColumnWidth',{25 113},...
                'RowName',{},...
                'RelPosition', [8 283 160 90]);
        end
        
        function initTimeTracePlot(obj,hParent)
            obj.hPlotAx = axes('Parent',hParent,'ButtonDownFcn',@obj.startMove,'box','on','Hittest','on','PickableParts','visible');
            obj.hPlotAx.XLim = [0 1e-3];
            xlabel(obj.hPlotAx,'time [s]');
            ylabel(obj.hPlotAx,'digitizer input [V]');
            grid(obj.hPlotAx,'on');
            
            c = uicontextmenu('Parent',obj.hFig);
            m1 = uimenu('Parent',c,'Label','Assign data in base workspace','Callback',@obj.assignDataInBase);
            
            color_gray = ones(1,3) * 0.3;
            color = obj.colorOrder(1,:);
            obj.hBrush = patch('Parent',obj.hPlotAx,'FaceColor',color_gray,'EdgeAlpha',.3,'EdgeColor',color_gray,'FaceAlpha',.3,'Hittest','off','PickableParts','none','Visible','off','Vertices',repmat([0 0],4,1),'Faces',1:4);
            obj.hPlotLine = line('Parent',obj.hPlotAx,'XData',[],'YData',[],'Color',color,'LineWidth',1,'Hittest','on','ButtonDownFcn',@obj.startMove);
            obj.hPlotLine.UIContextMenu = c;
            obj.hPlotCursor = line('Parent',obj.hPlotAx,'XData',[],'YData',[],'Color','red','LineWidth',1,'Hittest','off','PickableParts','none');
            
            obj.updateScopeTiming();
        end
        
        function initTriggerPlot(obj,hParent)
            obj.hTrigAx = axes('Parent',hParent,'ButtonDownFcn',@obj.startMove,'box','on','Hittest','on','PickableParts','visible');
            obj.hTrigAx.LooseInset(4) = 0;
            obj.hTrigAx.YTickLabel = [];
            xlabel(obj.hTrigAx,'time [s]');
            ylabel(obj.hTrigAx,'logic level');
            grid(obj.hTrigAx,'on');
            obj.hTrigAx.XLim = [0 1e-3];
            obj.hTrigAx.YLim = [0 1];
            obj.hTrigCursor = line('Parent',obj.hTrigAx,'XData',[],'YData',[],'Color','red','LineWidth',1,'Hittest','off','PickableParts','none');
            linkaxes([obj.hPlotAx obj.hTrigAx],'x');
        end
        
        function initFftPlot(obj,hParent)
            hPanel = uipanel('parent',hParent,'Title','Power Spectrum');
            obj.hFftAx = axes('Parent',hPanel,'box','on');
            obj.hFftAx.XScale = 'log';
            xlabel(obj.hFftAx,'Frequency [Hz]');
            ylabel(obj.hFftAx,'dBV');
            grid(obj.hFftAx,'on');
            obj.hFftAx.YLim = [-100 20];
            
            obj.hFftCursor = line('Parent',obj.hFftAx,'XData',[],'YData',[],'Color','red','LineWidth',1,'Hittest','off','PickableParts','none');
            obj.hFftCursorPt = line('Parent',obj.hFftAx,'XData',[],'YData',[],'Color','red','LineStyle','none','Marker','o','Hittest','off','PickableParts','none');
            
            color = obj.colorOrder(1,:);
            obj.hPowerLine = line('Parent',obj.hFftAx,'XData',[],'YData',[],'Color',color,'LineWidth',1,'Hittest','off','PickableParts','none');
        end
        
        function startMove(obj,src,evt)
            if ~(evt.Button == 1 && strcmpi(evt.EventName,'Hit'))
                return
            end
            
            hAx = ancestor(src,'axes');
            startPoint = hAx.CurrentPoint(1,1:2);
            windowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
            windowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
            
            obj.hFig.WindowButtonMotionFcn = @move;
            obj.hFig.WindowButtonUpFcn = @abortMove;
            
            function move(varargin)
                try
                pt = hAx.CurrentPoint(1,1:2);
                d = pt-startPoint;
                newXLim = hAx.XLim - d(1);
                dLim = diff(newXLim);
                
                limits = [0 Inf];
                if newXLim(1)<limits(1) 
                    newXLim = [limits(1) limits(1)+dLim];
                elseif newXLim(2)>limits(2)
                    newXLim = [limits(2)-dLim limits(2)+dLim];
                end
                
                hAx.XLim = newXLim;
                obj.updateBrush();
                obj.updateScopeTiming();
                catch ME
                    abortMove();
                    rethrow(ME);
                end
            end
                
            function abortMove(varargin)
                obj.hFig.WindowButtonMotionFcn = windowButtonMotionFcn;
            	obj.hFig.WindowButtonUpFcn = windowButtonUpFcn;
            end
        end
        
        function windowScrollWheelFcn(obj,varargin)
            obj.scrollPlotTrigAx(varargin{:});
            obj.scrollFftAx(varargin{:});
        end
        
        function scrollPlotTrigAx(obj,src,evt)
            inPlotAx = most.gui.isMouseInAxes(obj.hPlotAx);
            inTrigAx = most.gui.isMouseInAxes(obj.hTrigAx);

            if ~(inPlotAx || inTrigAx)
                return
            end
            
            direction = sign(evt.VerticalScrollCount);
            factor = 2;
            limits = [0 Inf];
            if inPlotAx
                scrollXAxes(obj.hPlotAx,direction,factor,limits);
            else
                scrollXAxes(obj.hTrigAx,direction,factor,limits);
            end
            obj.updateBrush();
            obj.updateScopeTiming();
        end
        
        function updateScopeTiming(obj,xLim)
            if nargin < 2 || isempty(xLim)
                xLim = obj.hPlotAx.XLim;
            end
            
            if ~isempty(obj.hDataScope)
                xLim(1) = max(0,xLim(1));
                xLim(2) = max(xLim(1)+1e-9,xLim(2));
                obj.hDataScope.acquisitionTime = diff(xLim);
                obj.hDataScope.triggerHoldOffTime = xLim(1);
                if obj.hDataScope.active
                    obj.hDataScope.restart();
                end
            end
            
            xGrid = obj.hPlotAx.XTick;
            if ~isempty(xGrid) && numel(xGrid)>=2
                xGridSpacing = xGrid(2)-xGrid(1);
                xGridSpacingStr = most.idioms.engineersStyle(xGridSpacing,'s');
            else
                xGridSpacingStr = '';
            end
            
            timeSpan = diff(xLim);
            timeSpanStr = most.idioms.engineersStyle(timeSpan,'s');
            titleStr = sprintf('Timespan: %s, X-Grid spacing: %s',timeSpanStr,xGridSpacingStr);
            title(obj.hPlotAx,titleStr,'FontWeight','normal');
        end
        
        function scrollFftAx(obj,src,evt)
            [inAxes,pt] = most.gui.isMouseInAxes(obj.hFftAx);
            if ~inAxes
                return
            end
            
            % don't allow scrolling at this point
            %direction = evt.VerticalScrollCount;
            %scrollXAxes(obj.hFftAx,direction);
        end
        
        function startAbort(obj)
            if ~most.idioms.isValidObj(obj.hDataScope)
                return
            end
            
            if obj.hDataScope.active
                obj.hDataScope.abort();
            else
                obj.hDataScope.callbackFcn = @obj.dataScopeCallback;
                obj.updateScopeTiming();
                obj.hDataScope.startContinuousAcquisition();
            end
            
            obj.refreshGui();
        end
        
        function channelChangedCallback(obj)
            if isempty(obj.hDataScope)
                return
            end
            
            try
                channel = obj.hControls.pmChannelSelect.Value;
                obj.hDataScope.channel = channel;
            catch ME
                obj.refreshGui();
                rethrow(ME);
            end
            
            obj.refreshGui();
        end
        
        function triggerChanged(obj)
            if isempty(obj.hDataScope)
                return
            end
            
            try
                trigIdx = obj.hControls.pmTrigger.Value;
                trigStr = obj.hControls.pmTrigger.String;
                trigStr = trigStr{trigIdx};
                obj.hDataScope.trigger = trigStr;
            catch ME
                obj.refreshGui();
                rethrow(ME);                
            end
            
            obj.refreshGui();
        end
        
        function fftUnitChanged(obj,varargin)
            idx = obj.hControls.pmFftUnitSelect.Value;
            obj.powerSpectrumReference = 10^-((idx-1)*3);
            ylabel(obj.hFftAx,obj.hControls.pmFftUnitSelect.String{idx});
            obj.updatePowerSpectrum();
        end
        
        function sliceNumberChanged(obj)
            if isempty(obj.hDataScope)
                return
            end
            
            try
                sliceNumber = str2double(obj.hControls.etSliceNumber.String);
                obj.hDataScope.triggerSliceNumber = sliceNumber;
            catch ME
                obj.refreshGui();
                rethrow(ME);
            end
            
            obj.refreshGui();
        end
        
        function lineNumberChanged(obj)
            if isempty(obj.hDataScope)
                return
            end
            
            try
                lineNumber = str2double(obj.hControls.etLineNumber.String);
                obj.hDataScope.triggerLineNumber = lineNumber;
            catch ME
                obj.refreshGui();
                rethrow(ME);
            end
        end
    end
    
    methods
        function dataScopeCallback(obj,src,evt)
            data_ = evt.data;
            data_volts = evt.settings.adc2VoltFcn(data_);
            sampleRate = evt.settings.sampleRate;
            triggerHoldOffTime = evt.settings.triggerHoldOffTime;
            
            triggers = obj.selectTriggers(evt.triggers);
            obj.updatePlot(sampleRate,data_volts,triggers,triggerHoldOffTime);
        end
        
        function triggers = selectTriggers(obj,triggers)
            hTable = obj.hControls.triggerTable.hCtl;
            tbdata = hTable.Data;
            
            triggerNames = fieldnames(triggers);
            if isempty(tbdata) || ~isequal(triggerNames(:),tbdata(:,2))
                tbdata = [repmat({false},numel(triggerNames),1),triggerNames(:)];
                hTable.Data = tbdata;
            end
            
            triggerMask = tbdata(:,1);
            triggerMask = horzcat(triggerMask{:});
            triggers = rmfield(triggers,triggerNames(~triggerMask));
            
            obj.showTriggers = any(triggerMask);
        end
        
        function updatePlot(obj,sampleRate,data,triggers,triggerHoldOffTime)
            t = 0:(numel(data)-1);
            t = t ./ sampleRate;
            t = t + triggerHoldOffTime;
            
            obj.data = struct();
            obj.data.sampleRate = sampleRate;
            obj.data.time = t;
            obj.data.voltage = data;
            obj.hPlotLine.XData = t;
            obj.hPlotLine.YData = data;
            
            triggerNames = fieldnames(triggers);
            triggerLineNames = fieldnames(obj.hTrigLines);
            linePadding = 0.6;
            
            if ~isequal(triggerLineNames,triggerNames)
                toDelete = setdiff(triggerLineNames,triggerNames);                
                cellfun(@(tD)most.idioms.safeDeleteObj(obj.hTrigLines.(tD)),toDelete);
                obj.hTrigLines = rmfield(obj.hTrigLines,toDelete);
                
                toAdd = setdiff(triggerNames,triggerLineNames);
                for idx = 1:length(toAdd)
                    hLine = line('Parent',obj.hTrigAx,'XData',[],'YData',[],'Hittest','off','PickableParts','none');
                    obj.hTrigLines.(toAdd{idx}) = hLine;
                end
                
                triggerLineNames = fieldnames(obj.hTrigLines);
                
                % set colors
                for idx = 1:length(triggerLineNames)
                    colorIdx = mod(idx-1,size(obj.colorOrder,1))+1;
                    obj.hTrigLines.(triggerLineNames{idx}).Color = obj.colorOrder(colorIdx,:);
                end
                
                if isempty(triggerLineNames)
                    legend(obj.hTrigAx,'off');
                else
                    allLines = cellfun(@(n)obj.hTrigLines.(n),triggerLineNames,'UniformOutput',false);
                    allLines = horzcat(allLines{:});
                    legend(obj.hTrigAx,allLines,triggerLineNames);
                end
                
                numTriggers = numel(triggerLineNames);
                obj.hTrigAx.YTick = (0:numTriggers-1)/numTriggers + (1-linePadding)/2/numTriggers;
            end
            
            numTriggers = numel(triggerLineNames);
            for idx = 1:numTriggers
                trigData = triggers.(triggerLineNames{idx});
                hLine = obj.hTrigLines.(triggerLineNames{idx});
                hLine.XData = t;
                hLine.YData = single(trigData)*linePadding/numTriggers + (numTriggers-idx)/numTriggers + (1-linePadding)/2/numTriggers;
            end
            
            yLim = [min(data) max(data)];
            if diff(yLim) > 0
                dYLim = diff(yLim);
                r = floor(log10(dYLim));
                yLim = [floor(yLim(1),r) ceil(yLim(2),r)];
            else
                yLim = yLim(1) + [-1 1];
            end
            
            obj.hPlotAx.YLim = yLim;
            
            obj.updateBrush();
            obj.updateCursor();
            
            sampleRateStr = most.idioms.engineersStyle(sampleRate,'Hz');
            trigHoldOffStr = most.idioms.engineersStyle(triggerHoldOffTime,'s');
            obj.hControls.lbInfo.hCtl.String = ...
                sprintf('Sample rate: %s\nTrigger Holdoff Time: %s',sampleRateStr,trigHoldOffStr);
            obj.updatePowerSpectrum();
        end
        
        function updatePowerSpectrum(obj)
            if obj.showPowerSpectrum
                if isempty(obj.data) || numel(obj.data.voltage) < 10
                    obj.clearPowerSpectrum();
                else
                    data_fft = fft(obj.data.voltage);
                    [dB,f] = scanimage.util.fftTodB(data_fft,obj.data.sampleRate,obj.powerSpectrumReference);
                    obj.data.powerSpectrumFrequencies = f(:);
                    obj.data.powerSpectrum = dB(:);
                    obj.data.powerSpectrumReference = obj.powerSpectrumReference;
                    
                    obj.hPowerLine.XData = f;
                    obj.hPowerLine.YData = dB;
                    
                    xLim1CutoffIdx = 10;
                    xLim1CutoffIdx = min(numel(f),xLim1CutoffIdx);
                    xLim1 = 10 ^ ceil( log10( f(xLim1CutoffIdx) ) );
                    xLim2 = f(end);
                   
                    xLim1 = max(xLim1,10);
                    
                    if xLim1 >= xLim2
                        xLim1 = 0;
                    end
                    obj.hFftAx.XLim = [xLim1 xLim2];
                end
                
                obj.updateFftCursorValue();
            end
        end
        
        function clearPlot(obj)
            obj.data = [];
            
            obj.hPlotLine.XData = [];
            obj.hPlotLine.YData = [];
            
            obj.clearPowerSpectrum();
        end
        
        function clearPowerSpectrum(obj)
            obj.hPowerLine.XData = [];
            obj.hPowerLine.YData = [];
            obj.fftCursorValue = [];
        end
        
        function reinitDataScope(obj)
            most.idioms.safeDeleteObj(obj.hListeners);
            obj.hListeners = event.proplistener.empty(1,0);
            obj.clearPlot();
            
            if isempty(obj.hDataScope)
                obj.refreshGui();
                return
            else
                obj.hListeners(end+1) = addlistener(obj.hDataScope,'trigger','PostSet',@obj.refreshGui);
                obj.hListeners(end+1) = addlistener(obj.hDataScope,'triggerLineNumber','PostSet',@obj.refreshGui);
                obj.hListeners(end+1) = addlistener(obj.hDataScope,'triggerSliceNumber','PostSet',@obj.refreshGui);
                obj.hListeners(end+1) = addlistener(obj.hDataScope,'channel','PostSet',@obj.refreshGui);
                obj.hListeners(end+1) = addlistener(obj.hDataScope,'active','PostSet',@obj.dataScopeStatusChanged);
                
                obj.hListeners(end+1) = addlistener(obj.hDataScope.hScan2D.hSI.hDisplay,'mouseHoverInfo','PostSet',@obj.brush);
                
                obj.hControls.pmChannelSelect.String = arrayfun(@(c)sprintf('Ch %d',c),1:obj.hDataScope.channelsAvailable,'UniformOutput',false);
                
                obj.updateScopeTiming();
            end
            
            obj.refreshGui();
        end
        
        function brush(obj,varargin)
            if isempty(obj.hDataScope) || ~obj.hDataScope.active || ~strcmpi(obj.hDataScope.trigger,'line')
                obj.brushLim = [];
                return
            end
            
            info = obj.hDataScope.mouseHoverInfo2Pix();
            
            if isempty(info)
                obj.brushLim = [];
                return
            end
            
            currentXLim = obj.hPlotAx.XLim;
            currentXD = diff(currentXLim);
            newBrush = sort([info.pixelStartTime info.pixelEndTime]);
            newBrushMidPoint = sum(newBrush)/2;
            
            if currentXD > info.lineDuration
                newXLim = [0 info.lineDuration];
            elseif currentXLim(1)+currentXD*0.1 > newBrush(1) || currentXLim(2)-currentXD*0.1 < newBrush(2)
                newXLim = newBrushMidPoint + [-1 1] * currentXD / 2;
            else
                newXLim = currentXLim;
            end
            
            if newXLim(1) < 0
                newXLim = [0 currentXD];
            end
            
            if obj.hDataScope.channel ~= info.channel
                obj.hDataScope.channel = info.channel;
            end
            
            if obj.hDataScope.triggerLineNumber ~= info.pixelLine
                obj.hDataScope.triggerLineNumber = info.pixelLine;
            end
            
            if obj.hDataScope.triggerSliceNumber ~= info.zIdx
                obj.hDataScope.triggerSliceNumber = info.zIdx;
            end
            
            if ~isequal(newXLim,currentXLim)
                obj.updateScopeTiming(newXLim);
                obj.hPlotAx.XLim = newXLim;
            end
            
            if ~isequal(newBrush,obj.brushLim)
                obj.brushLim = newBrush;
            end
        end
        
        function updateBrush(obj)
            if isempty(obj.brushLim)
                return
            end
            
            xLim = obj.hPlotAx.XLim;
            yLim = obj.hPlotAx.YLim;
            
            obj.hBrush.Vertices = ...
                [obj.brushLim(1) yLim(1); ...
                 obj.brushLim(1) yLim(2); ...
                 obj.brushLim(2) yLim(2); ...
                 obj.brushLim(2) yLim(1)];
             
            dBrushLim = diff(obj.brushLim);
            dXLim = diff(xLim);
            
            if dXLim/dBrushLim > 300
                obj.hBrush.LineStyle = '-';
                obj.hBrush.LineWidth = 2;
            else
                obj.hBrush.LineStyle = 'none';
            end
        end
        
        function hover(obj,varargin)
            obj.updateCursor(varargin);
            obj.updateFftCursor(varargin);
        end
        
        function updateCursor(obj,varargin)
            [inPlotAx,ptPlotAx] = most.gui.isMouseInAxes(obj.hPlotAx);
            [inTrigAx,ptTrigAx] = most.gui.isMouseInAxes(obj.hTrigAx);
            
            if ~(inPlotAx || inTrigAx)  
                obj.hPlotCursor.Visible = 'off';
                obj.hTrigCursor.Visible = 'off';
                return;
            end
            
            pt = most.idioms.ifthenelse(inPlotAx,ptPlotAx,ptTrigAx);
            
            plotYLim = obj.hPlotAx.YLim;
            obj.hPlotCursor.XData = [pt(1) pt(1)];
            obj.hPlotCursor.YData = [plotYLim(1) plotYLim(2)];
            obj.hPlotCursor.Visible = 'on';

            if obj.showTriggers
                trigYLim = obj.hTrigAx.YLim;
                obj.hTrigCursor.XData = [pt(1) pt(1)];
                obj.hTrigCursor.YData = [trigYLim(1) trigYLim(2)];
                obj.hTrigCursor.Visible = 'on';
            else
                obj.hTrigCursor.Visible = 'off';
            end
        end
        
        function updateFftCursor(obj,varargin)
            [inAx,axPt] = most.gui.isMouseInAxes(obj.hFftAx);
            if ~inAx || isempty(obj.data) || ~isfield(obj.data,'powerSpectrum')
                obj.fftCursorValue = [];
            else
                obj.fftCursorValue = obj.hFftAx.CurrentPoint(1,1);
            end
        end
        
        function updateFftCursorValue(obj,varargin)
            if ~isempty(obj.fftCursorValue)
                obj.hFftAx.Units = 'Pixel';
                axWidthPix = obj.hFftAx.Position(3);
                obj.hFftAx.Units = 'Normalized';
                axXLimLog = log10(obj.hFftAx.XLim);
                
                mouseWindowPixWidth = 6;
                deltaLog = mouseWindowPixWidth/2 * diff(axXLimLog)/axWidthPix;
                cursorLog = log10(obj.fftCursorValue);
                windowLog = cursorLog + [-deltaLog deltaLog];
                
                window = real(10.^windowLog);
                
                mask = obj.data.powerSpectrumFrequencies >= window(1) & obj.data.powerSpectrumFrequencies <= window(2);
                f = obj.data.powerSpectrumFrequencies(mask);
                powerSpectrum = obj.data.powerSpectrum(mask);
                
                [power,idx] = max(powerSpectrum);
                f = f(idx);
                
                if isempty(f)
                    % find the closest match instead
                    fsLog = log10(obj.data.powerSpectrumFrequencies);
                    [~,idx] = min(abs(cursorLog-fsLog));
                    
                    f = obj.data.powerSpectrumFrequencies(idx);
                    power = obj.data.powerSpectrum(idx);
                end
                
                
                obj.hFftCursorPt.XData = f;
                obj.hFftCursorPt.YData = power;
                
                if isempty(f)
                    yLim = [-100 20];
                else
                    yLim = [];
                end
                
                obj.hFftCursor.XData = [f f];
                obj.hFftCursor.YData = [-100 20];
                
                [~,prefix] = most.idioms.engineersStyle(obj.powerSpectrumReference);
                [fStr] = most.idioms.engineersStyle(f,'Hz','%.3f');
                title(obj.hFftAx,sprintf('%.2fdB%sV @ %s',power,prefix,fStr),'FontWeight','normal');
            end
        end

        function dataScopeStatusChanged(obj,varargin)
            obj.refreshGui();
        end
        
        function refreshGui(obj,varargin)
            if isempty(obj.hDataScope)
                enableStr = 'off';
                sliceTriggerConfigEnableStr = 'off';
                lineTriggerConfigEnableStr = 'off';
            else               
                obj.hControls.pmChannelSelect.Value = obj.hDataScope.channel;
                obj.hControls.etSliceNumber.String = num2str(obj.hDataScope.triggerSliceNumber);
                obj.hControls.etLineNumber.String = num2str(obj.hDataScope.triggerLineNumber);
                
                availableTriggers = obj.hDataScope.triggerAvailable;
                obj.hControls.pmTrigger.String = availableTriggers;
                mask = strcmpi(availableTriggers,obj.hDataScope.trigger);
                idx = find(mask,1);
                obj.hControls.pmTrigger.Value = idx;
                
                switch lower(obj.hDataScope.trigger)
                    case 'line'
                        sliceTriggerConfigEnableStr = 'on';
                        lineTriggerConfigEnableStr = 'on';
                    case 'slice'
                        sliceTriggerConfigEnableStr = 'on';
                        lineTriggerConfigEnableStr = 'off';
                    otherwise
                        sliceTriggerConfigEnableStr = 'off';
                        lineTriggerConfigEnableStr = 'off';
                end
                
                obj.hControls.pbStart.String = most.idioms.ifthenelse(obj.hDataScope.active,'Abort','Start');
                
                enableStr = 'on';
            end
            
            obj.hControls.pbStart.Enable = enableStr;
            obj.hControls.pmChannelSelect.Enable = enableStr;
            obj.hControls.etSliceNumber.Enable = sliceTriggerConfigEnableStr;
            obj.hControls.etLineNumber.Enable = lineTriggerConfigEnableStr;
            obj.hControls.pmTrigger.Enable = enableStr;
            
            obj.fftUnitChanged();
        end
        
        function assignDataInBase(obj,varargin)
            if ~isempty(obj.data)
                assignin('base','dataScope',obj.data);
                fprintf('Assigned ''dataScope'' in base workspace.\n');
                evalin('base','dataScope')
            end
        end
    end
    
    methods
        function set.hDataScope(obj,val)
            if ~isequal(val,obj.hDataScope)
                if ~isempty(val)
                    assert(isa(val,'scanimage.components.scan2d.interfaces.DataScope'));
                end
                
                if ~isempty(obj.hDataScope) && obj.hDataScope.active
                    obj.hDataScope.abort();
                end
                obj.hDataScope = val;
                obj.reinitDataScope();
            end
        end
        
        function set.showPowerSpectrum(obj,val)
            oldVal = obj.showPowerSpectrum;
            
            validateattributes(val,{'numeric','logical'},{'scalar'});
            obj.showPowerSpectrum = logical(val);
            
            if obj.showPowerSpectrum ~= oldVal
                if obj.showPowerSpectrum
                    obj.hFftFlow.Visible = 'on';
                    obj.hFig.Position(2) = obj.hFig.Position(2) - obj.hFig.Position(4);
                    obj.hFig.Position(4) = 2*obj.hFig.Position(4);
                    obj.updatePowerSpectrum();
                else
                    obj.hFftFlow.Visible = 'off';
                    obj.hFig.Position(4) = obj.hFig.Position(4)/2;
                    obj.hFig.Position(2) = obj.hFig.Position(2) + obj.hFig.Position(4);
                    obj.clearPowerSpectrum();
                end
            end
        end
        
        function set.brushLim(obj,val)
            if ~isequal(obj.brushLim,val)
                obj.brushLim = sort(val);
                
                if isempty(val)
                    obj.hBrush.Visible = 'off';
                else
                    obj.hBrush.Visible = 'on';
                    obj.updateBrush();
                end
            end
        end
        
        function set.showTriggers(obj,val)
            if isequal(obj.showTriggers,val)
                return
            end
            
            obj.showTriggers = val;
            
            if obj.showTriggers
                obj.hPlotAx.XTickLabel = [];
                obj.hPlotAx.LooseInset(2) = 0;
                xlabel(obj.hPlotAx,[]);
                obj.hControls.hTimeTracePanelGrid.VerticalWeight = [2 1];
                obj.hTrigAx.Visible = 'on';
            else
                obj.hPlotAx.XTickLabelMode = 'auto';
                obj.hPlotAx.LooseInset = get(0,'DefaultAxesLooseInset');
                xlabel(obj.hPlotAx,'time [s]');
                obj.hControls.hTimeTracePanelGrid.VerticalWeight = [2 0.1];
                obj.hTrigAx.Visible = 'off';
            end
        end
        
        function set.fftCursorValue(obj,val)
            oldVal = obj.fftCursorValue;
            
            obj.fftCursorValue = val;
            
            if isempty(val) && ~isequal(oldVal,val)
                title(obj.hFftAx,'');
                obj.hFftCursorPt.XData = [];
                obj.hFftCursorPt.YData = [];
                
                obj.hFftCursor.XData = [];
                obj.hFftCursor.YData = [];
            end
            
            if ~isempty(val)
                obj.updateFftCursorValue();
            end
        end
    end
end

function newXLim = scrollXAxes(hAx,direction,factor,limits)
    if nargin < 3 || isempty(factor)
        factor = 2;
    end
    
    if nargin < 4 || isempty(limits)
        limits = [-Inf Inf];
    end
    
    pt = hAx.CurrentPoint(1,1:2);
    xLim = hAx.XLim;
    d = diff(xLim);
    a = (pt(1)-xLim(1))/d;
    b = 1-a;
    newD = d*factor^direction;
    newXLim = pt(1) + [-a b] * newD;
    
    newXLim(1) = max(newXLim(1),limits(1));
    newXLim(2) = min(newXLim(2),limits(2));
    if newXLim(1) >= newXLim(2)
        newXLim(2) = newXLim(1) + 1e-9;
    end
    
    hAx.XLim = newXLim;
end

function X = floor(X,n)
if nargin < 2 || isempty(n)
    n = 0;
end
X = X / 10^n;
X = builtin('floor',X);
X = X * 10^n;
end

function X = ceil(X,n)
if nargin < 2 || isempty(n)
    n = 0;
end

X = X / 10^n;
X = builtin('ceil',X);
X = X * 10^n;
end


%--------------------------------------------------------------------------%
% DataScope.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
