classdef roiIntegratorDisplayClass < handle
    properties
        hSI;
        hSICtl;
        
        cLim;
        
        hFig;
        hAx;
        hStatusText;
        hAuxAx;
        hAuxLine;
        hImSurf;
        hCursor;
        hDynamicSelectionRect;
        hSelectedRoiPlots;
        hCorrAx;
        hCorrBar;
        
        timestamps;
        
        auxAxHeightLimits = [200 200];
        auxAxHeightLimitsEnable = true;
        
        maxUpdateRate = Inf; % limits maximum update rate
        enableMainAx = true;
        enableCorrAx = false;
        enableAuxAx = true;
    end
    
    properties
        displayedRois = scanimage.mroi.Roi.empty(1,0);
        controls = struct();
        cursorPosition;
        dynamicSelectedRoi = scanimage.mroi.Roi.empty(1,0);
        selectedRois;
        
        containers = struct();
    end
    
    properties (Hidden, SetAccess = private)
        xTick;                  % Buffer to increase performance
        dynamicSelectedRoiRow;  % Buffer to increase performance
        selectedRoiRows;        % Buffer to increase performance
        
        displayedRoisUuiduint64Resorted = uint64([]);     % Buffer to increase performance
        displayedRoisUuiduint64ResortedIdxs;              % Buffer to increase performance
        
        data = [];
    end
    
    properties (Dependent)
        historyLength;
        statusText;
    end
    
    properties (Constant, Hidden)
        graphics2014b = most.idioms.graphics2014b();
        numXTicks = 10;
    end
    
    %% Lifecycle
    methods
        function obj = roiIntegratorDisplayClass()           
            obj.hFig = handle(figure('Name','ROI Integrator Traces','Tag','roiIntegratorDisplay','NumberTitle','off','MenuBar','none','Toolbar','none'));
            obj.containers.td1 = handle(most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown'));
                obj.containers.lr2_1 = handle(most.idioms.uiflowcontainer('Parent',obj.containers.td1,'FlowDirection','LeftToRight'));
                obj.containers.lr2_2 = handle(most.idioms.uiflowcontainer('Parent',obj.containers.td1,'FlowDirection','LeftToRight'));
                    obj.containers.lr3_1 = handle(most.idioms.uiflowcontainer('Parent',obj.containers.lr2_2,'FlowDirection','TopDown'));
                        obj.containers.lr4_1 = handle(uicontainer('Parent',obj.containers.lr3_1));
                        obj.containers.lr4_2 = handle(uicontainer('Parent',obj.containers.lr3_1));
            
            obj.hFig.Position(3) = 820;
                        
            makeTopMenuBar(obj.containers.lr2_1);
            makeAxis(obj.containers.lr4_1);
            makeAuxiliaryAxis(obj.containers.lr4_2);
            makeCorrAx(obj.containers.lr4_1);
            
            if obj.graphics2014b
                obj.hFig.WindowButtonMotionFcn = @obj.windowButtonMotion;
                obj.hFig.SizeChangedFcn = @obj.windowSizeChangedFcn;
            else
                obj.hFig.WindowButtonMotionFcn = @obj.windowButtonMotion;
                obj.hFig.ResizeFcn = @obj.windowSizeChangedFcn;
            end
            
            obj.cursorPosition = 0;
            obj.displayedRois = obj.displayedRois;
            obj.historyLength = 1000;
            obj.cLim = [];
            
            obj.maxUpdateRate = obj.maxUpdateRate;
            obj.enableMainAx = obj.enableMainAx;
            obj.enableCorrAx = obj.enableCorrAx;
            obj.enableAuxAx = obj.enableAuxAx;
            obj.auxAxHeightLimits = obj.auxAxHeightLimits;
            
            obj.alignAxes();
            
            function makeTopMenuBar(ctr)
                ctr.HeightLimits = [25 25];
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [80 80];
                obj.controls.pbResetData = handle(uicontrol('Parent',flctr,'Tag','pbResetData','style','pushbutton','String','Reset Data','Callback',@(varargin)obj.reset()));
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [80 80];
                obj.controls.historyLengthLabel = handle(uicontrol('Parent',flctr,'Tag','historyLengthLabel','style','text','String','History Length','HorizontalAlignment','right'));
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [50 50];
                obj.controls.etHistoryLength = handle(uicontrol('Parent',flctr,'Tag','etHistoryLength','Style','edit','String','100','Callback',@obj.changeHistoryLength));
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [60 60];
                obj.controls.cLimLabel = handle(uicontrol('Parent',flctr,'Tag','cLimLabel','style','text','String','CLim/YLim','HorizontalAlignment','right'));
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [70 70];
                obj.controls.etClim = handle(uicontrol('Parent',flctr,'Tag','etClim','Style','edit','String','Auto','Callback',@obj.changeCLim,'Tooltip',sprintf('Enter lower and upper bound for Clim as a 1x2 array e.g. [0 1000]\nEnter ''Auto'' for automatic scaling.')));
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [115 115];
                obj.controls.maxUpdateRateLabel = handle(uicontrol('Parent',flctr,'Tag','maxUpdateRateLabel','style','text','String','Max Display Rate (Hz)','HorizontalAlignment','right'));
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [60 60];
                obj.controls.etMaxUpdateRate = handle(uicontrol('Parent',flctr,'Tag','etMaxUpdateRate','Style','edit','String','Auto','Callback',@obj.changeMaxUpdateRate));
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [90 90];
                obj.controls.enableMainAxLabel = handle(uicontrol('Parent',flctr,'Tag','enableMainAxLabel','style','text','String','Show Heatmap','HorizontalAlignment','right'));
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [20 20];
                obj.controls.cbEnableMainAx = handle(uicontrol('Parent',flctr,'Tag','cbEnableMainAx','Style','checkbox','Value',true,'Callback',@obj.changeEnableMainAx));
                
%                 flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
%                 flctr.WidthLimits = [90 90];
%                 obj.controls.enableCorrAxLabel = handle(uicontrol('Parent',flctr,'Tag','enableCorrAxLabel','style','text','String','Show Correlation','HorizontalAlignment','right'));
%                 flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
%                 flctr.WidthLimits = [20 20];
%                 obj.controls.cbEnableCorrAx = handle(uicontrol('Parent',flctr,'Tag','cbEnableCorrAx','Style','checkbox','Value',true,'Callback',@obj.changeEnableCorrAx));
                
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [80 80];
                obj.controls.enableAuxAxLabel = handle(uicontrol('Parent',flctr,'Tag','enableAuxAxLabel','style','text','String','Show Traces','HorizontalAlignment','right'));
                flctr = handle(most.idioms.uiflowcontainer('Parent',ctr,'FlowDirection','TopDown'));
                flctr.WidthLimits = [20 20];
                obj.controls.cbEnableAuxAx = handle(uicontrol('Parent',flctr,'Tag','cbEnableAuxAx','Style','checkbox','Value',true,'Callback',@obj.changeEnableAuxAx));
            end
            
            function makeAxis(ctr)                    
                obj.hAx = axes('Parent',ctr,'Tag','hAx',...
                        'NextPlot','add','LooseInset',[0 0 0 0],...
                        'XLimMode','auto','YLimMode','auto','ZLimMode','auto',...
                        'YDir','reverse','Color','black','Box','on');
                    colorbar('peer',obj.hAx,'Location','EastOutside');
                obj.hAx = handle(obj.hAx); %workaround for Matlab 2013b: colorbar(...) does not accept axes handle as 'peer' input
                if obj.graphics2014b
                    obj.hAx.XLimSpec = 'tight';
                    obj.hAx.YLimSpec = 'tight';
                    obj.hAx.ZLimSpec = 'tight';
                end
                
                obj.hImSurf = handle(surface('Parent',obj.hAx,'ButtonDownFcn',@obj.imButtonDownFcn,...
                    'XData',[],'YData',[],'ZData',[],'CData',[],...
                    'FaceColor','texturemap','CDataMapping','scaled','FaceLighting','none','LineStyle','none'));
                obj.hCursor = handle(line('Parent',obj.hAx,'XData',[0,0],'YData',[0,1],'ZData',[10,10],...
                    'LineStyle','-','LineWidth',2,'Color',[1 0 0]));
                
                obj.hDynamicSelectionRect = handle(surface('Parent',obj.hAx,'Visible','off',...
                    'FaceColor','none','CData',[],'EdgeColor','r','LineWidth',2,...
                    'HitTest','off'));
                obj.hStatusText = handle(text(0,0,'','Parent',obj.hAx,'Visible','off','Hittest','off','LineStyle','none','Color',[1 1 1]));
                if obj.graphics2014b
                    obj.hDynamicSelectionRect.PickableParts = 'none';
                    obj.hStatusText.PickableParts = 'none';
                end
            end
            
            function makeAuxiliaryAxis(ctr)
                obj.hAuxAx = handle(axes('Parent',ctr,'Tag','hAuxAx',...
                    'LooseInset',[0 0 0 0],'Box','on','XTickLabel',[]));
                obj.hAuxLine = handle(line('Parent',obj.hAuxAx,'LineWidth',2,'Color','r','DisplayName',''));
                most.idioms.setLegendEntryVisible(obj.hAuxLine,false);
            end
            
            function makeCorrAx(ctr)
                obj.hCorrAx = axes('Parent',ctr,'Tag','hCorrAx',...
                    'XTick',[],'XTickMode','manual',...
                    'YDir','reverse','YTick',[],'YTickMode','manual',...
                    'Color','none','Box','off',...
                    'LooseInset',[0 0 0 0],'Hittest','off');
                axis(obj.hCorrAx,'off');
                obj.hCorrBar = handle(barh(obj.hCorrAx,[0],[0],...
                    'Visible','off','BarWidth',1,'FaceColor',[0.5 0.5 1],'EdgeColor',[1 1 1],...
                    'Hittest','off'));
                obj.hCorrAx = handle(obj.hCorrAx); % workaround for Matlab 2013b: barh does not accept axes handle as input
                if obj.graphics2014b
                    obj.hCorrAx.PickableParts = 'none';
                    obj.hCorrBar.PickableParts = 'none';
                end
                
                try
                    % this is only supported in Matlab 2015b and later
                    obj.hCorrBar.FaceAlpha = 0.7;
                catch
                    % no-op                    
                end

                obj.hCorrAx.YTick = [];
                obj.hCorrAx.YTickMode = 'manual';
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
        end
    end
    
    methods        
        function reset(obj)
            obj.data = nan(size(obj.data));
            obj.timestamps = nan(size(obj.data));
            obj.cursorPosition = 0;
            
            obj.updateMainAx();
            obj.updateAuxAx();
            obj.updateCorrAx();
        end
        
        function updateDisplay(obj,hIntegrationRois,integrationValues,integrationTimestamps)
            persistent lastUpdate
            
            if isempty(hIntegrationRois)
                obj.setDisplayedRoisMaintainOrder([]);
                return
            end
            
            roisDisplay = [hIntegrationRois.display];
            
            hIntegrationRois = hIntegrationRois(roisDisplay);
            integrationValues = integrationValues(roisDisplay);
            integrationTimestamps = integrationTimestamps(roisDisplay);
            
            [tfdisplayed,resortedIdxs] = obj.setDisplayedRoisMaintainOrder(hIntegrationRois);
            
            % sort to get in right order
%             [tfdisplayed,resortedIdxs] = ismember([obj.displayedRois.uuiduint64],[hIntegrationRois.uuiduint64]);
%             integrationValues = integrationValues(resortedIdxs(tfdisplayed));
%             timestamps_ = timestamps_(resortedIdxs(tfdisplayed));
            
            %integrationValues = idxs;
            %timestamps_ = idxs;
            [~,idxs] = sort(resortedIdxs(tfdisplayed));
            
            integrationValues = integrationValues(idxs);
            integrationTimestamps = integrationTimestamps(idxs);
            obj.appendData(integrationValues,integrationTimestamps);
            
            if isempty(lastUpdate)
                lastUpdate = tic();
            end
            
            if toc(lastUpdate) > 1/obj.maxUpdateRate
                obj.updateMainAx();
                obj.updateAuxAx();
                lastUpdate = tic();
            end
        end
        
        function appendData(obj,newData,newTimestamps)
            newCursPos = obj.cursorPosition + 1;
            if newCursPos > obj.historyLength
                newCursPos = 1;
            end
            
            obj.data(newCursPos,:) = newData(:)';
            obj.timestamps(newCursPos,:) = newTimestamps(:)';
            obj.cursorPosition = newCursPos;
        end
        
        function changeHistoryLength(obj,src,evt)
            val = str2double(src.String);
            
            if isempty(val) || isnan(val) || isinf(val) || (val < 10) || (round(val) ~= val)
                most.idioms.warn('History Length must be an integer greater than or equal to 10. Resetting to previous value.');
                set(obj.controls.etHistoryLength, 'String', num2str(obj.historyLength));
            else
                obj.historyLength = val;
            end
        end
        
        function changedHistoryLength(obj,varargin)
            obj.controls.etHistoryLength.String = num2str(obj.historyLength);
        end
        
        function changeCLim(obj,src,evt)
            try
                cLim_ = eval(obj.controls.etClim.String);
            catch
                cLim_ = [];
            end
            obj.cLim = cLim_;
        end
        
        function changedCLim(obj)
            if isempty(obj.cLim)
                obj.controls.etClim.String = 'Auto';
            else
                obj.controls.etClim.String = mat2str(obj.cLim);
            end            
        end
        
        function changeMaxUpdateRate(obj,src,evt)
            try
                val = eval(obj.controls.etMaxUpdateRate.String);
            catch
                val = [];
            end
            obj.maxUpdateRate = val;
        end
        
        function changedMaxUpdateRate(obj)
            obj.controls.etMaxUpdateRate.String = mat2str(obj.maxUpdateRate);
        end
        
        function changeEnableMainAx(obj,src,evt)
            obj.enableMainAx = obj.controls.cbEnableMainAx.Value;
        end
        
        function changedEnableMainAx(obj)
            obj.controls.cbEnableMainAx.Value = obj.enableMainAx;
        end
        
        function changeEnableCorrAx(obj,src,evt)
            obj.enableCorrAx = obj.controls.cbEnableCorrAx.Value;            
        end
        
        function changedEnableCorrAx(obj)
            obj.controls.cbEnableCorrAx.Value = obj.enableCorrAx;
        end
        
        function changeEnableAuxAx(obj,src,evt)
            obj.enableAuxAx = obj.controls.cbEnableAuxAx.Value;
        end
        
        function changedEnableAuxAx(obj)
            obj.controls.cbEnableAuxAx.Value = obj.enableAuxAx;
        end
        
        function windowButtonMotion(obj,src,evt)
            persistent previousRow
            [currentColumn,currentRow] = obj.getCurrentPt();
            
            if ~isempty(currentColumn) && ~isempty(currentRow)
                obj.statusText = sprintf('Time: %.3f Value: %.3f  ',obj.timestamps(currentColumn,currentRow),obj.data(currentColumn,currentRow));
            else
                obj.statusText = '';
            end
            
            if isempty(currentRow)
                obj.dynamicSelectedRoi = [];
            elseif isempty(previousRow) || previousRow ~= currentRow
                obj.dynamicSelectedRoi = currentRow;
            end
            previousRow = currentRow;
        end
        
        function rows = roiToRow(obj,rois)
            %[tf,rows] = ismember([rois.uuiduint64],[obj.displayedRois.uuiduint64]);
            [tf,rows] = obj.ismemberDisplayedRois([rois.uuiduint64]);
            rows(~tf) = NaN;
        end
        
        function [tf,idxs] = ismemberDisplayedRois(obj,uuiduint64s)
            idxs = ismembc2(uint64(uuiduint64s),obj.displayedRoisUuiduint64Resorted); % obj.displayedRoisUuiduint64Resorted is guaranteed to be sorted
            tf = idxs~=0;
            
            % resort idxs
            idxs(tf) = obj.displayedRoisUuiduint64ResortedIdxs(idxs(tf));            
        end
        
        function imButtonDownFcn(obj,src,evt)
            switch obj.hFig.SelectionType
                case 'normal'
                    obj.imDrag('start');
                case 'open'
                    [~,currentRow] = obj.getCurrentPt();
                    roi = obj.displayedRois(currentRow);
                    if isempty(roi)
                        return
                    end
                    isSelected = false;
                    if ~isempty(obj.selectedRois)
                        [isSelected,idx] = ismember(roi.uuiduint64,[obj.selectedRois.uuiduint64]);
                    end
                    
                    if isSelected
                        obj.selectedRois(idx) = [];
                    else
                        obj.selectedRois = [obj.selectedRois roi];
                    end
            end
        end
        
        function windowSizeChangedFcn(obj,src,evt)
            % this function is reentrant and called multiple times when the
            % window size is changed. However, we only want to call
            % alignAxes after the window size has not changed for
            % settlingTime
            settlingTime = 0.5; % [seconds]
            pollingTime = 0.1; % [seconds]
            persistent updateInProgress
            persistent lastUpdate
            
            lastUpdate = tic();
            
            if isempty(updateInProgress) || ~updateInProgress
                updateInProgress = true; %#ok<NASGU>
                while toc(lastUpdate) < settlingTime
                    pause(pollingTime);
                end
                updateInProgress = false;
                obj.alignAxes();                
            end
        end
        
        function alignAxes(obj)
            obj.hAx.ActivePositionProperty = 'outerposition';
            obj.hAuxAx.ActivePositionProperty = 'outerposition';
            obj.hCorrAx.ActivePositionProperty = 'outerposition';
            posAx = obj.hAx.Position;
            posAuxAx = obj.hAuxAx.Position;
            posAuxAx([1,3]) = posAx([1,3]);
            
            posCorrAx = obj.hCorrAx.Position;
            posCorrAx([2,4]) = posAx([2,4]);
            
            obj.hAuxAx.Position = posAuxAx;
            obj.hCorrAx.Position = posCorrAx;
        end
        
        function imDrag(obj,status)
            persistent origSettings
            persistent previousRow
            
            try
                switch status
                    case 'start'
                        [~,currentRow] = obj.getCurrentPt();
                        if isempty(currentRow)
                           return
                        end
                        previousRow = currentRow;
                        
                        origSettings.WindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                        origSettings.WindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                        origSettings.Interruptible = obj.hFig.Interruptible;
                        origSettings.Pointer = obj.hFig.Pointer;
                        
                        obj.hFig.WindowButtonMotionFcn = @(varargin)obj.imDrag('drag');
                        obj.hFig.WindowButtonUpFcn = @(varargin)obj.imDrag('stop');
                        obj.hFig.Interruptible = 'off';
                        obj.hFig.Pointer = 'top';
                    case 'drag'
                        [~,currentRow] = obj.getCurrentPt();
                        if ~isempty(currentRow) && (currentRow ~= previousRow)
                            % resort rois
                            rois = obj.displayedRois;
                            roiToMove = obj.displayedRois(previousRow);
                            if currentRow > previousRow
                                rois(previousRow:currentRow-1) = obj.displayedRois(previousRow+1:currentRow);
                                rois(currentRow) = roiToMove;
                            elseif currentRow < previousRow
                                rois(currentRow+1:previousRow) = obj.displayedRois(currentRow:previousRow-1);
                                rois(currentRow) = roiToMove;
                            end
                            previousRow = currentRow;
                            obj.displayedRois = rois;
                        end
                    case 'stop'
                        stopDrag();
                    otherwise
                        assert(false);
                end
                
            catch ME
                stopDrag();
                rethrow(ME);
            end
            
            function stopDrag()
                obj.hFig.WindowButtonMotionFcn = origSettings.WindowButtonMotionFcn;
                obj.hFig.WindowButtonUpFcn = origSettings.WindowButtonUpFcn;
                obj.hFig.Interruptible = origSettings.Interruptible;
                obj.hFig.Pointer = origSettings.Pointer;
            end
        end
        
        % Helper methods
        function [ptx,pty] = getCurrentPt(obj)
            if ~obj.enableMainAx
                ptx = [];
                pty = [];
                return
            end
            
            pt = obj.hAx.CurrentPoint;
            ptx = pt(1);
            pty = pt(3);
            
            ptx = round(ptx) + 1;
            pty = round(pty) + 1;
            
            if ptx < 1 || ptx > obj.historyLength
                ptx = [];
            end
            
            if pty < 1 || pty > length(obj.displayedRois)
                pty = [];
            end
        end
        
        function updateMainAx(obj)
            persistent xTickLabels
            
            if ~obj.enableMainAx
                return
            end
            
            obj.hImSurf.CData = obj.data;
            obj.hCursor.XData = [obj.cursorPosition obj.cursorPosition]-0.5;

            if ~isempty(obj.displayedRois) % not the case if length(obj.displayedRois) == 0
                xTickLabels_ = max(obj.timestamps(obj.xTick,:),[],2);
                
                if ~isequaln(xTickLabels,xTickLabels_)
                    obj.hAx.XTickLabel = arrayfun(@(l)sprintf('%.2f',l),xTickLabels_,'UniformOutput',false);
                    xTickLabels = xTickLabels_;
                end
            end
            if obj.cursorPosition == 1
                obj.alignAxes();
            end
        end
        
        function updateAuxAx(obj)
            % update dynamic roi selection
            if ~obj.enableAuxAx
                return
            end
            
            if isempty(obj.dynamicSelectedRoiRow) || isnan(obj.dynamicSelectedRoiRow) 
                % no-op
            else                
                newDataDyn = obj.data(:,obj.dynamicSelectedRoiRow);
                if obj.cursorPosition > 0 && obj.cursorPosition < obj.historyLength
                    newDataDyn(obj.cursorPosition+1) = NaN;
                end
                obj.hAuxLine.YData = newDataDyn';
            end
            
            % update roi plots
            if isempty(obj.selectedRois)
                % No-op
            else
                newDataSel = obj.data(:,obj.selectedRoiRows);
                if  obj.cursorPosition > 0 && obj.cursorPosition < obj.historyLength
                    newDataSel(obj.cursorPosition+1,:) = NaN;
                end

                for idx = 1:length(obj.hSelectedRoiPlots)
                    obj.hSelectedRoiPlots(idx).YData = newDataSel(:,idx);
                end
            end
        end
        
        function updateCorrAx(obj)
            if ~obj.enableCorrAx
                return
            end
            
            if isempty(obj.data) || isempty(obj.dynamicSelectedRoi)
                obj.hCorrAx.Visible = 'off';
                obj.hCorrBar.Visible = 'off';
            else
                numRois = length(obj.displayedRois);
                
                datatemp = obj.data;
                for idx = 1:numRois
                    dat = datatemp(:,idx);
                    dat = dat(~isnan(dat)); % filter nans
                    datatemp(:,idx) = (datatemp(:,idx) - mean(dat)) ./ std(dat); % normalize data
                end
                
                selectedrow = obj.roiToRow(obj.dynamicSelectedRoi);
                selectedrowdata = datatemp(:,selectedrow);
                
                xData = 0:numRois-1;
                yData = zeros(numRois,1);
                for idx = 1:numRois
                    rowdata = datatemp(:,idx);
                    tf1 = isnan(selectedrowdata);
                    tf2 = isnan(rowdata);
                    tf = ~(tf1 | tf2); % filter all nans
                    data1 = selectedrowdata(tf);
                    data2 = rowdata(tf);
                    numPts = length(data1);
                    if numPts < 2
                        yData(idx) = 0;
                    else
                        yData(idx) = max(most.mimics.xcorr(data1,data2))./(numPts-1);
                    end
                end
                pos = obj.hAx.Position;
                pos(3) = pos(3) * 0.2;
                
                xLim = [0,max(yData)];
                if ~(xLim(1)<xLim(2))
                   xLim = [0,1] ;
                end
                
                obj.hCorrBar.XData = xData;
                obj.hCorrBar.YData = yData';
                obj.hCorrBar.Visible = 'on';
                
                obj.hCorrAx.Visible = 'on';
                obj.hCorrAx.Position = pos;
                obj.hCorrAx.XLim = xLim;
                obj.hCorrAx.YLim = [0,numRois]-0.5;
                obj.hCorrAx.YTick = [];
                obj.hCorrAx.YTickMode = 'manual';
                obj.hCorrAx.YDir = 'reverse';
                axis(obj.hCorrAx,'off');
            end
        end
        
        function updateChannelsDisplay(obj)
            if isempty(obj.hSI)
                return
            end
            
            dispAxes = horzcat(obj.hSI.hDisplay.hAxes{:});
            dispAxes = horzcat(dispAxes{:});
            dispAxes(~isvalid(dispAxes)) = []; % remove invalid handles
            
            set([dispAxes.hHighlightGroup],'Visible','off');
            
            if ~isempty(obj.dynamicSelectedRoi)
                allZs = obj.hSI.hStackManager.zs;
                sfs = arrayfun(@(z)obj.dynamicSelectedRoi.get(z),allZs,'UniformOutput',false);
                tf = cellfun(@(sf)~isempty(sf),sfs);
                roiZs = allZs(tf);
                roiSfs = horzcat(sfs{tf});
                
                for idx = 1:length(dispAxes)
                    hDispAx = dispAxes(idx);
                    delete(hDispAx.hHighlightGroup.Children);
                    
                    dispZs = hDispAx.zs;
                    dispChan = hDispAx.chan;
                    
                    tf = ismember(roiZs,dispZs);
                    zs = roiZs(tf);
                    sfs = roiSfs(tf);
                    
                    surfsXData = {};
                    surfsYData = {};
                    surfsZData = {};
                    surfsMask = {};
                    
                    for zidx = 1:length(zs)
                        z = zs(zidx);
                        sf = sfs(zidx);
                        mask = sf.mask;
                        
                        if any(ismember(sf.channel,dispChan))
                            [xx,yy] = sf.cornersurf;
                            surfsXData{end+1} = xx;
                            surfsYData{end+1} = yy;
                            surfsZData{end+1} = repmat(z,size(xx));
                            surfsMask{end+1} = mask;
                        end
                    end
                    
                    
                    for surfidx = 1:length(surfsXData)
                        zOffset = -1e-6;        % the highlighting surface needs to be a small distance above the image to be visible
                        surfColor = uint8([255 0 255]);
                        alpha = 0.3;
                        
                        mask = surfsMask{surfidx};
                        hSurf = handle(surface('Parent',hDispAx.hHighlightGroup,...
                                'XData',surfsXData{surfidx},'YData',surfsYData{surfidx},'ZData',surfsZData{surfidx}+zOffset,...
                                'CData',repmat(reshape(surfColor,1,1,[]),size(mask)),'FaceColor','texturemap','CDataMapping','direct',...
                                'AlphaData',mask.*(alpha/max(mask(:))),'AlphaDataMapping','none','FaceAlpha','texturemap',...
                                'FaceLighting','none','EdgeColor',surfColor,'Hittest','off'));
                        if obj.graphics2014b
                            hSurf.PickableParts = 'none';
                        end                            
                    end
                    
                    if ~isempty(surfsXData)
                        hDispAx.hHighlightGroup.Visible = 'on';
                    end
                end
            end
        end
    end
    
    methods
        function set.selectedRois(obj,val)
            if isempty(val)
                rois = scanimage.mroi.Roi.empty(1,0);
            else
                % ensure all vals are actually displayed
                %tf = ismember([val.uuiduint64],[obj.displayedRois.uuiduint64]);
                tf = obj.ismemberDisplayedRois([val.uuiduint64]);
                
                rois = val(tf);
                [~,idxs] = unique([rois.uuiduint64]);
                rois = rois(sort(idxs)); % ensure unique
                
%                 %ensure order of selected Rois is order of displayedRois
%                 [~,resortedIdxs] = ismember([obj.displayedRois.uuiduint64],[rois.uuiduint64]);
%                 rois = rois(resortedIdxs);
            end
            
            % delete all old selection rects
            handles = findall(obj.hAx,'Tag','SelectionRect');
            delete(handles);            
            
            rows = zeros(1,length(rois));
            for idx = 1:length(rois)
                roi = rois(idx);
                row = obj.roiToRow(roi);
                
                xAlphaFrac = obj.historyLength*0.05;
                yAlphaFrac = 0.25;
                
                xx = [0, obj.historyLength, obj.historyLength, 0, 0;...
                      xAlphaFrac, obj.historyLength-xAlphaFrac, obj.historyLength-xAlphaFrac, xAlphaFrac, xAlphaFrac] - 0.5;
                yy = [0, 0, 1, 1, 0;...
                      yAlphaFrac, yAlphaFrac, 1-yAlphaFrac, 1-yAlphaFrac, yAlphaFrac] - 1.5;
                zz = ones(size(xx));
                
                yy = yy + row;
                color = [1 1 1];
                surfs = handle(surface('Parent',obj.hAx,'Tag','SelectionRect',...
                    'XData',xx,'YData',yy,'ZData',zz,...
                    'FaceColor','interp','CData',repmat(reshape(color,1,1,[]),size(xx)),...
                    'FaceAlpha','interp','AlphaData',repmat([1;0],1,size(xx,2)),...
                    'EdgeColor','none','HitTest','off'));
                if obj.graphics2014b
                    set(surfs,'PickableParts','none');
                end
                
                %rectangle('Parent',obj.hAx,'Tag','SelectionRect',...
                %    'Position',[-.5,row-1.5,obj.historyLength,1],...
                %    'EdgeColor','w','LineWidth',2);
                rows(idx) = row;
            end
            
            obj.selectedRois = rois;
            obj.selectedRoiRows = obj.roiToRow(obj.selectedRois);
            
            delete(obj.hSelectedRoiPlots);
            hold(obj.hAuxAx,'on'); % otherwise all other lines will be deleted by plot()
            obj.hSelectedRoiPlots = handle(plot(obj.hAuxAx,repmat([0:obj.historyLength-1]',1,length(rows)),obj.data(:,rows)));
            
            if isempty(rois)
                legend(obj.hAuxAx,'off');
            else
                legend(obj.hAuxAx,{rois.name});
            end
            obj.updateAuxAx();
            obj.alignAxes();
        end
        
        function set.dynamicSelectedRoi(obj,val)
            row = NaN;
            if isempty(val)
                %No-op
            elseif isnumeric(val)
                if val > 0 && val <= numel(obj.displayedRois)
                    row = val;
                end
            elseif isa(val,'scanimage.mroi.Roi')
                row = obj.roiToRow(val);
            else
                assert(false,'Wrong datatype');
            end
            
            if isempty(row) || isnan(row)
                roi = scanimage.mroi.Roi.empty(1,0);
                obj.hDynamicSelectionRect.Visible = 'off';
            else
                roi = obj.displayedRois(row);
                [xx,yy,zz]=meshgrid([-0.5,obj.historyLength-0.5],[row-1.5,row-0.5],2);
                obj.hDynamicSelectionRect.Visible = 'on';
                obj.hDynamicSelectionRect.XData = xx;
                obj.hDynamicSelectionRect.YData = yy;
                obj.hDynamicSelectionRect.ZData = zz;
            end
            
            obj.dynamicSelectedRoi = roi;
            obj.dynamicSelectedRoiRow = obj.roiToRow(obj.dynamicSelectedRoi);
            
            if isempty(obj.dynamicSelectedRoiRow) || isnan(obj.dynamicSelectedRoiRow)
                obj.hAuxLine.Visible = 'off';
            else
                obj.hAuxLine.Visible = 'on';
                obj.hAuxLine.YData = nan(1,obj.historyLength);
            end
            
            obj.updateAuxAx();
            obj.updateCorrAx();
            obj.updateChannelsDisplay();
        end
        
        function set.displayedRois(obj,newRois)
            if isempty(newRois)
                newRois = scanimage.mroi.Roi.empty(1,0);
            end
            
            newRois = newRois(:)'; % ensure row vector
            [~,idxs] = unique([newRois.uuiduint64]);
            newRois = newRois(sort(idxs)); % ensure unique
                        
            [~,idxsToKeep,idxsToPush] = intersect([obj.displayedRois.uuiduint64],[newRois.uuiduint64]);
            
            newData = nan(obj.historyLength,length(newRois));
            newData(:,idxsToPush) = obj.data(:,idxsToKeep);
            
            newTimestamps = nan(obj.historyLength,length(newRois));
            newTimestamps(:,idxsToPush) = obj.timestamps(:,idxsToKeep);
            
            obj.displayedRois = newRois;
            uuiduint64s = [newRois.uuiduint64];
            [uuiduint64sResorted,sortIdxs] = sort(uuiduint64s);
            obj.displayedRoisUuiduint64Resorted = uint64(uuiduint64sResorted); % ensure the right class
            obj.displayedRoisUuiduint64ResortedIdxs = sortIdxs;
            
            obj.data = newData;
            obj.timestamps = newTimestamps;
            
            obj.hCursor.YData = [-0.5 length(obj.displayedRois)-0.5];
            obj.updateImagePosition();
            
            obj.selectedRois = obj.selectedRois; % calls obj.updateAuxAx();
            obj.dynamicSelectedRoi = obj.dynamicSelectedRoi; % calls obj.updateCorrAx();
            
            obj.updateMainAx();
            obj.alignAxes();
        end
        
        function updateImagePosition(obj)
            obj.hAx.YTick = 0:length(obj.displayedRois)-1;
            obj.hAx.YTickMode = 'manual';
            obj.hAx.YTickLabel = {obj.displayedRois.name};
            obj.hAx.YTickLabelMode = 'manual';
            
            [xx,yy,zz] = meshgrid([-0.5 obj.historyLength-0.5],[-0.5 length(obj.displayedRois)-.5],0);
            obj.hImSurf.XData = xx';
            obj.hImSurf.YData = yy';
            obj.hImSurf.ZData = zz';
            axis(obj.hAx,'tight');
        end
        
        function [ismembertf,ismemberidxs] = setDisplayedRoisMaintainOrder(obj,newRois)
            if isempty(newRois)
                newRois = scanimage.mroi.Roi.empty(1,0);
            end

            [ismembertf,ismemberidxs] = obj.ismemberDisplayedRois([newRois.uuiduint64]);
            maskidxs = ismemberidxs(ismembertf);
            mask_toAdd = ~ismembertf;
            
            mask_toRemove = true(1,length(obj.displayedRois));
            mask_toRemove(maskidxs) = false;
            
            if any(mask_toAdd) || any(mask_toRemove)
                rois_ = obj.displayedRois;
                rois_(mask_toRemove) = [];
                
                rois_(end+1:end+sum(mask_toAdd)) = newRois(mask_toAdd);
                
                obj.displayedRois = rois_;
                
                [ismembertf,ismemberidxs] = obj.setDisplayedRoisMaintainOrder(newRois); % update ismembertf and ismemberidx return values
            end
        end
        
        function set.historyLength(obj,val)
            assert(val >= 10,'History length value of %d is too small',val);
            oldData = circshift(obj.data,[-obj.cursorPosition,0]);
            oldTimestamps = circshift(obj.timestamps,[-obj.cursorPosition,0]);
            newCursPos = min(val,obj.cursorPosition);
            
            newData = nan(val,length(obj.displayedRois));
            newData(1:newCursPos,:) = oldData(end-newCursPos+1:end,:);
            newTimestamps = nan(val,length(obj.displayedRois));
            newTimestamps(1:newCursPos,:) = oldTimestamps(end-newCursPos+1:end,:);
            obj.data = newData;
            obj.timestamps = newTimestamps;
            obj.updateImagePosition();
            
            
            obj.xTick = round(linspace(1,obj.historyLength,obj.numXTicks));
            obj.hAx.XTick = obj.xTick-1;
            obj.hAuxAx.XTick = obj.xTick-1;
            
            obj.hAuxLine.XData = 0:obj.historyLength-1;
            obj.hAuxLine.YData = nan(1,obj.historyLength);
            
            obj.cursorPosition = newCursPos;
            
            obj.selectedRois = obj.selectedRois;
            obj.dynamicSelectedRoi = obj.dynamicSelectedRoi;
            obj.hAuxAx.XLim = [0,obj.historyLength-1];
            obj.updateImagePosition();
            obj.alignAxes();
            obj.changedHistoryLength();
        end
        
        function val = get.historyLength(obj)
            val = size(obj.data,1);
        end
        
        function set.cursorPosition(obj,val)
            obj.cursorPosition = val;
        end
        
        function set.statusText(obj,val)
            if isempty(val)
                obj.hStatusText.Visible = 'off';
                obj.hStatusText.String = '';
            else
                obj.hStatusText.Position = [obj.historyLength-0.5,-0.5,20];
                obj.hStatusText.HorizontalAlignment = 'right';
                obj.hStatusText.VerticalAlignment = 'top';
                obj.hStatusText.String = val;
                obj.hStatusText.Visible = 'on';
            end
        end
        
        function val = get.statusText(obj)
            val = obj.hStatusText.String;
        end
        
        function set.cLim(obj,val)            
            if isempty(val) || ~isnumeric(val) || ~isequal(size(val),[1,2]) || any(isnan(val)) || any(isinf(val)) || val(1)>=val(2)
                obj.hAx.CLimMode = 'auto';
                obj.hAuxAx.YLimMode = 'auto';
                val = [];
            else
                obj.cLim = val;
                obj.hAx.CLim = val;
                obj.hAuxAx.YLim = val;
            end
            
            obj.cLim = val;
            obj.changedCLim();
        end
        
        function set.maxUpdateRate(obj,val)
            obj.maxUpdateRate = val;
            obj.changedMaxUpdateRate();
        end
        
        function set.auxAxHeightLimitsEnable(obj,val)
            obj.auxAxHeightLimitsEnable = val;
            
            if obj.auxAxHeightLimitsEnable
                obj.hAuxAx.Parent.HeightLimits = obj.auxAxHeightLimits;
            else
                obj.hAuxAx.Parent.HeightLimits = [0 Inf];
            end
        end
        
        function set.auxAxHeightLimits(obj,val)
            obj.auxAxHeightLimits = val;
            obj.auxAxHeightLimitsEnable = obj.auxAxHeightLimitsEnable;
        end
        
        function set.enableMainAx(obj,val)
            obj.enableMainAx = val;
            obj.enableCorrAx = obj.enableCorrAx;
            
            if val
                obj.hAx.Visible = 'on';
                obj.hAx.Parent.Visible = 'on';
                colorbar(obj.hAx);
                obj.updateMainAx();
                obj.auxAxHeightLimitsEnable = true;
                obj.alignAxes();
            else
                obj.hAx.Visible = 'off';
                obj.hAx.Parent.Visible = 'off';
                colorbar(obj.hAx,'off');
                obj.auxAxHeightLimitsEnable = false;
                obj.alignAxes();
            end
        end
        
        function set.enableCorrAx(obj,val)
            obj.enableCorrAx = val;
            
            if val && obj.enableMainAx;
                obj.updateCorrAx();
            else
                obj.hCorrAx.Visible = 'off';
                obj.hCorrBar.Visible = 'off';
            end
            
            obj.changedEnableCorrAx();
        end
        
        function val = get.enableCorrAx(obj)
            val = obj.enableCorrAx && obj.enableMainAx;
        end
        
        function set.enableAuxAx(obj,val)
            obj.enableAuxAx = val;
            
            if val
                obj.hAuxAx.Visible = 'on';
                obj.hAuxAx.Parent.Visible = 'on';
                obj.updateAuxAx();
                obj.alignAxes();
            else
                obj.hAuxAx.Visible = 'off';
                obj.hAuxAx.Parent.Visible = 'off';
            end
            
            obj.changedEnableAuxAx();
        end
    end 
end


%--------------------------------------------------------------------------%
% roiIntegratorDisplayClass.m                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
