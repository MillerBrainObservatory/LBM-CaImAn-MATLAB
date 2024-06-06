classdef DataPlot < most.gui.GuiElement
    properties
        hAxRaw
        hLineRaw
        hTextGridSize
        
        hAxProcessed
        hAxProcessedLegend
        hLineProcessed
        hLineThreshold
        hLinePhotons
        hText
        
        hAxBrush
        hLineBrush
        hPatchBrush
        
        brushWindow = [0 1];
        threshold = 0;
        
        data;
        dataProcessed;
        
        hPhotonDiscriminator;
        
        photonSelection = [];
        hPatchPhotonWindow;
        hLineDebounce;
        hLineDebounceMarker;
        hLineDebounceLimit;
        
        photonIdxs = [];
        
        cr;
        cp;
    end
    
    methods
        function obj = DataPlot(hParent,hPhotonDiscriminator)
            obj = obj@most.gui.GuiElement(hParent);
            obj.hPhotonDiscriminator = hPhotonDiscriminator;
            obj.init();
        end
        
        function delete(obj)
        end
        
        function init(obj)
            most.idioms.safeDeleteObj(obj.hUIPanel.Children);
            
            colors = get(gca,'colororder');
            
            obj.hAxRaw = axes('Parent',obj.hUIPanel,'ButtonDownFcn',@obj.axisButtonDownFcn,'Box','on','XTickLabel','');
            grid(obj.hAxRaw,'on');
            obj.hLineRaw = line('Parent',obj.hAxRaw,'XData',[],'YData',[],'Color',[0 0.4470 0.7410]);%,'Hittest','off','PickableParts','none'
            obj.hTextGridSize = text('Parent',obj.hAxRaw,'Visible','off','String','','FontWeight','bold','Units','normalized','Position',[0.01 0.95 0],'HorizontalAlignment','left','VerticalAlignment','top','FontSize',10,'BackgroundColor','white','Hittest','off');
            legend(obj.hAxRaw,'Raw Data');
            
            obj.hAxProcessed = axes('Parent',obj.hUIPanel,'ButtonDownFcn',@obj.axisButtonDownFcn,'Box','on','XTickLabel','');
            grid(obj.hAxProcessed,'on');
            obj.hLineProcessed = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Color',colors(1,:));%,'Hittest','off','PickableParts','none');
            obj.hLineThreshold = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Color',colors(3,:),'LineWidth',2,'ButtonDownFcn',@obj.lineThresholdBtnDwnFcn);
            obj.hLinePhotons = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Hittest','on','PickableParts','visible','LineStyle','none','LineStyle','none','Marker','o','Color',colors(2,:),'MarkerFaceColor',min(colors(2,:)+0.3,1),'ButtonDownFcn',@obj.selectPhotonButtonDown);
            obj.hText = text('Parent',obj.hAxProcessed,'Visible','off','String','Zoom in to see photons','FontWeight','bold','Units','normalized','Position',[0.5 0.9 0],'HorizontalAlignment','center','VerticalAlignment','top','FontSize',10,'BackgroundColor','white','Hittest','off');
            obj.hPatchPhotonWindow = patch('Parent',obj.hAxProcessed,'Vertices',[],'Faces',[],'FaceColor',[0 0 0],'FaceAlpha',0.2,'Hittest','on','PickableParts','visible','EdgeColor','none','ButtonDownFcn',@obj.moveWindow);
            obj.hLineDebounce = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Color',[1 0 1],'Hittest','off','PickableParts','none','Marker','none','LineWidth',2);
            obj.hLineDebounceMarker = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Color',[1 0 1],'MarkerFaceColor',[1 0 1],'Hittest','on','PickableParts','visible','Marker','<','ButtonDownFcn',@obj.moveDebounce);
            obj.hLineDebounceLimit = line('Parent',obj.hAxProcessed,'XData',[],'YData',[],'Color',[1 0 1],'Hittest','on','PickableParts','visible','Marker','none','LineStyle','--','LineWidth',1,'ButtonDownFcn',@obj.moveDebounce);
            obj.hAxProcessedLegend = legend([obj.hLineProcessed, obj.hLinePhotons, obj.hLineThreshold],{'Processed Data','Photons','Threshold'});
            
            obj.hAxBrush = axes('Parent',obj.hUIPanel,'ButtonDownFcn',@obj.axisButtonDownFcn,'Box','on','XTickLabel','','YTickLabel','');
            obj.hLineBrush = line('Parent',obj.hAxBrush,'XData',[],'YData',[],'Color',colors(1,:),'Hittest','off','PickableParts','none');
            obj.hPatchBrush = patch('Parent',obj.hAxBrush,'Vertices',[],'Faces',[],'FaceColor',[0 0 0],'FaceAlpha',0.2,'Hittest','off','PickableParts','none','EdgeColor',colors(2,:),'LineWidth',2);
            
            obj.cr = uicontextmenu;
            uimenu(obj.cr,'Label','Assign raw data in base','Callback',@obj.assignRawDataInBase);
            obj.hLineRaw.UIContextMenu = obj.cr;
            
            obj.cp = uicontextmenu;
            uimenu(obj.cp,'Label','Assign processed data in base','Callback',@obj.assignProcessedDataInBase);
            uimenu(obj.cp,'Label','Assign photons in base','Callback',@obj.assignPhotonsInBase);
            obj.hLineProcessed.UIContextMenu = obj.cp;
            
            obj.panelResized();
        end
        
        function panelResized(obj)
            panelPos = obj.getPositionInUnits('pixel');
            w = panelPos(3);
            h = panelPos(4);
            
            padding = [50 30 20 40]; %lrtb
            axwidth = w-padding(1)-padding(2);
            
            axpadding = 30;
            pos = [padding(1),padding(4),axwidth,50];
            obj.hAxBrush.Units = 'pixel';
            obj.hAxBrush.Position = pos;
            
            axheight = (h-pos(1)-pos(4)-padding(3)-axpadding*2)/2;
            
            pos(2) = pos(2)+pos(4)+axpadding;
            pos(4) = axheight;
            obj.hAxProcessed.Units = 'pixel';
            obj.hAxProcessed.Position = pos;
            
            pos(2) = pos(2)+pos(4)+axpadding;
            pos(4) = axheight;
            obj.hAxRaw.Units = 'pixel';
            obj.hAxRaw.Position = pos;
        end
        
        function configurationChanged(obj)
            thresh = obj.hPhotonDiscriminator.peakThreshold;
            obj.hLineThreshold.XData = [-1000 length(obj.data)+1000];
            obj.hLineThreshold.YData = [thresh thresh];
            obj.reprocessData();
            obj.updateBrush(obj.brushWindow);
            obj.processPhotons();
        end
        
        function updateData(obj,data)
            oldDataLength = length(obj.data);
            obj.data = data;
            
            if isempty(data)
                obj.hLineRaw.Visible = 'off';
                obj.hLineProcessed.Visible = 'off';
                obj.hLineThreshold.Visible = 'off';
                obj.hLinePhotons.Visible = 'off';
                obj.hLineBrush.Visible = 'off';
                obj.hPatchBrush.Visible = 'off';
                return
            end
            
            obj.hLineRaw.Visible = 'on';
            obj.hLineProcessed.Visible = 'on';
            obj.hLineThreshold.Visible = 'on';
            obj.hLinePhotons.Visible = 'on';
            obj.hLineBrush.Visible = 'on';
            obj.hPatchBrush.Visible = 'on';
            
            if length(data) ~= oldDataLength
                obj.brushWindow = [1 length(data)];
            end
            
            obj.hLineBrush.XData = 0:length(data)-1;
            obj.hLineBrush.YData = data;
            obj.hAxBrush.XLim = [0,length(data)-1];
            obj.hAxBrush.YLim = [min(data),max(data)];
            
            obj.hLineRaw.XData = 0:length(data)-1;
            obj.hLineRaw.YData = data;
            
            obj.selectPhoton([]);
            obj.configurationChanged();
        end
        
        function reprocessData(obj)
            [~,dataProcessed_] = obj.hPhotonDiscriminator.processData(obj.data);
            obj.dataProcessed = dataProcessed_;
            obj.hLineProcessed.XData = 0:length(obj.dataProcessed)-1;
            obj.hLineProcessed.YData = obj.dataProcessed;
        end
        
        function updateBrush(obj,brushWindow)
            % coerce brush Window
            if isempty(obj.data)
                return
            end
            
            brushWindow(1) = min(max(brushWindow(1),0),length(obj.data)-1);
            brushWindow(2) = min(max(brushWindow(2),0),length(obj.data)-1);
            
            brushWindow = sort(brushWindow);
            if diff(brushWindow) == 0
                if brushWindow(1) == 0
                    brushWindow(2) = brushWindow(2) + 1;
                else
                    brushWindow(1) = brushWindow(1) - 1;
                end
            end
            
            obj.brushWindow = brushWindow;
            
            brushYLim = double(obj.hAxBrush.YLim);
            obj.hPatchBrush.Vertices = [brushWindow(1)-1,brushYLim(1);
                                        brushWindow(1)-1,brushYLim(2);
                                        brushWindow(2)-1,brushYLim(2);
                                        brushWindow(2)-1,brushYLim(1)];
            obj.hPatchBrush.Faces = [1 2 3 4];
            
            w = obj.hAxBrush.Position(3);
            if w*diff(brushWindow)/length(obj.data) < w
                obj.hPatchBrush.LineStyle = '-';
            else
                obj.hPatchBrush.LineStyle = 'none';
            end
            
            dataWindow = round(obj.brushWindow);
            obj.hLineRaw.XData = dataWindow(1):dataWindow(2);
            obj.hLineRaw.YData = obj.data(dataWindow(1)+1:dataWindow(2)+1);
            
            obj.hLineProcessed.XData = dataWindow(1):dataWindow(2);
            obj.hLineProcessed.YData = obj.dataProcessed(dataWindow(1)+1:dataWindow(2)+1);            
            
            obj.hAxRaw.XLim = obj.brushWindow;
            obj.hAxProcessed.XLim = obj.brushWindow;
            
            
            
            if diff(obj.brushWindow) < 1e5
                % coerce tick spacing to 16
                samples16 = [floor(obj.brushWindow(1)/16) ceil(obj.brushWindow(2)/16)]*16;
                samples16 = samples16(1):16:samples16(end);
                numsamples16 = length(samples16)-1;
                if numsamples16 < 50
                    obj.hAxRaw.XTick = samples16;
                    obj.hAxRaw.XTickMode = 'manual';
                    obj.hAxProcessed.XTick = samples16;
                    obj.hAxProcessed.XTickMode = 'manual';
                    xTicks = samples16;
                else
                    obj.hAxRaw.XTickMode = 'auto';
                    obj.hAxProcessed.XTickMode = 'auto';
                    xTicks = get(obj.hAxRaw,'XTick');
                end
            else
                xTicks = get(obj.hAxRaw,'XTick');
            end
            
                        
            
            if length(xTicks) > 1
                tickSpacing = diff(xTicks(1:2));
                tickSpacingTime = tickSpacing / obj.hPhotonDiscriminator.hSampler.hFpga.rawSampleRateAcq;
                
                obj.hTextGridSize.String = sprintf('X Grid Spacing: %d Samples, %s',tickSpacing,most.idioms.engineersStyle(tickSpacingTime,'s','%.3f'));
                obj.hTextGridSize.Visible = 'on';
            else
                obj.hTextGridSize.Visible = 'off';
            end
        end
        
        function processPhotons(obj)
            if isempty(obj.data) || diff(obj.brushWindow) > 1e5 ...
                || sum(obj.dataProcessed(round(obj.brushWindow(1)+1):round(obj.brushWindow(2)+1))>=obj.hPhotonDiscriminator.peakThreshold)>1e4
            
                obj.hLinePhotons.XData = [];
                obj.hLinePhotons.YData = [];
                obj.hText.Visible = 'on';
                obj.selectPhoton([]);
            else
                window = round(obj.brushWindow)+1;
                window(1) = max(1,window(1)-100); % avoid edge effects in display
                
                data_ = obj.dataProcessed(window(1):window(2));
                obj.photonIdxs = obj.hPhotonDiscriminator.findPhotons(data_);
                obj.photonIdxs = obj.photonIdxs + window(1) -1;
                obj.hLinePhotons.XData = obj.photonIdxs - 1;
                obj.hLinePhotons.YData = obj.dataProcessed(obj.photonIdxs);
                obj.hText.Visible = 'off';
                obj.selectPhoton(obj.photonSelection);
            end
        end
        
        function selectPhoton(obj,phtIdx)
            if isempty(phtIdx)
                obj.photonSelection = [];
                obj.hPatchPhotonWindow.Visible = 'off';
                obj.hLineDebounce.Visible = 'off';
                obj.hLineDebounceMarker.Visible = 'off';
                obj.hLineDebounceLimit.Visible = 'off';
            else
                 selectionIdx = find(obj.photonIdxs==phtIdx, 1);
                 
                 if isempty(selectionIdx)
                    obj.photonSelection = [];
                    obj.hPatchPhotonWindow.Visible = 'off';
                    obj.hLineDebounce.Visible = 'off';
                    obj.hLineDebounceMarker.Visible = 'off';
                    obj.hLineDebounceLimit.Visible = 'off';
                 else
                    obj.photonSelection = phtIdx;
                    obj.hPatchPhotonWindow.Visible = 'off';
                    obj.hLineDebounceLimit.Visible = 'off';
                    
                    windowSize = obj.hPhotonDiscriminator.peakDetectionWindowSize;
                    debounce = obj.hPhotonDiscriminator.peakDebounceSamples;
                    
                    window = [obj.photonSelection-1-(windowSize-1)/2,obj.photonSelection-1+(windowSize-1)/2];
                    yLim = obj.hAxProcessed.YLim;
                    obj.hPatchPhotonWindow.Vertices = ...
                        [window(1),yLim(1);
                         window(1),yLim(2);
                         window(2),yLim(2);
                         window(2),yLim(1)];
                    obj.hPatchPhotonWindow.Faces = [1 2 3 4];
                    
                    obj.hLineDebounce.Marker = 'none';
                    obj.hLineDebounce.XData = [obj.photonSelection-1-debounce obj.photonSelection-1];
                    obj.hLineDebounce.YData = [obj.dataProcessed(obj.photonSelection) obj.dataProcessed(obj.photonSelection)];
                    obj.hLineDebounceMarker.XData = obj.photonSelection-1-debounce;
                    obj.hLineDebounceMarker.YData = obj.dataProcessed(obj.photonSelection);
                    obj.hLineDebounceLimit.XData = [obj.photonSelection-1-debounce obj.photonSelection-1-debounce];
                    obj.hLineDebounceLimit.YData = yLim;

                    obj.hPatchPhotonWindow.Visible = 'on';
                    obj.hLineDebounce.Visible = 'on';
                    obj.hLineDebounceMarker.Visible = 'on';
                    obj.hLineDebounceLimit.Visible = 'on';
                 end
            end
        end
        
        function scrollWheelFcn(obj,src,evt)
            if most.util.mouseOnObj(obj.hAxRaw);       obj.scrollBrush(src,evt,obj.hAxRaw.CurrentPoint);       end
            if most.util.mouseOnObj(obj.hAxProcessed); obj.scrollBrush(src,evt,obj.hAxProcessed.CurrentPoint); end
            if most.util.mouseOnObj(obj.hAxBrush);     obj.scrollBrush(src,evt,obj.hAxBrush.CurrentPoint);     end
        end
        
        function scrollBrush(obj,src,evt,currentPoint)
            d = diff(obj.brushWindow);
            ratio = (currentPoint(1,1)-obj.brushWindow(1))/d;
            if ratio<0 || ratio>1
                ratio = 0.5;
            end
            zoom = 1.3 ^ evt.VerticalScrollCount;
            d = (d-d*zoom);
            newBrushWindow = [obj.brushWindow(1)+d*ratio obj.brushWindow(2)-d*(1-ratio)];
            obj.updateBrush(newBrushWindow);
            obj.processPhotons();
        end
        
        function lineThresholdBtnDwnFcn(obj,src,evt)
            obj.hAxProcessed.YLimMode = 'manual';
            obj.hFig.WindowButtonMotionFcn = @(varargin)dragLine;
            obj.hFig.WindowButtonUpFcn = @(varargin)dragStop;
            
            function dragLine
                try
                    y = obj.hAxProcessed.CurrentPoint(1,2);
                    obj.hLineThreshold.XData = [-1000 length(obj.data)+1000];
                    obj.hLineThreshold.YData = [y y];
                catch ME
                    obj.hAxProcessed.YLimMode = 'auto';
                    obj.stopMotionFcn();
                    rethrow(ME);
                end
            end
            
            function dragStop
                try
                    obj.hAxProcessed.YLimMode = 'auto';
                    thresh = round(obj.hLineThreshold.YData(1));
                    obj.hPhotonDiscriminator.peakThreshold = thresh;
                catch ME
                    obj.stopMotionFcn();
                    rethrow(ME)
                end
                obj.stopMotionFcn();
            end
        end
        
        function selectPhotonButtonDown(obj,src,evt)
            hAx = ancestor(src,'axes');
            pt = hAx.CurrentPoint(1,1);
            
            [~,idx] = min(abs(pt-(obj.photonIdxs-1)));
            obj.selectPhoton(obj.photonIdxs(idx))
        end
        
        function moveWindow(obj,src,evt)
            if ~isempty(obj.photonSelection)
                obj.hFig.WindowButtonMotionFcn = @obj.moveWindowMotionFcn;
                obj.hFig.WindowButtonUpFcn = @obj.stopWindowMotion;
            end
        end
        
        function stopWindowMotion(obj,src,evt)
            obj.stopMotionFcn();
            pht = obj.photonSelection-1;
            pt = obj.hAxProcessed.CurrentPoint(1,1);
            d = round(abs(pht-pt));
            window = d*2+1;
            %enforce limit
            window = min(window,17);
            try
                obj.hPhotonDiscriminator.peakDetectionWindowSize = window;
            catch ME
                obj.configurationChanged();
                rethrow(ME);
            end
        end
        
        function moveWindowMotionFcn(obj,src,evt)
            pht = obj.photonSelection-1;
            pt = obj.hAxProcessed.CurrentPoint(1,1);
            d = abs(pht-pt);  
            obj.hPatchPhotonWindow.Vertices([1 2 3 4]) = [pht-d pht-d pht+d pht+d];
        end
        
        function moveDebounce(obj,src,evt)
            if ~isempty(obj.photonSelection)
                obj.hFig.WindowButtonMotionFcn = @obj.moveDebounceMotionFcn;
                obj.hFig.WindowButtonUpFcn = @obj.stopDebounceMotion;
            end
        end
        
        function stopDebounceMotion(obj,src,evt)
            obj.stopMotionFcn();
            pht = obj.photonSelection-1;
            pt = obj.hAxProcessed.CurrentPoint(1,1);
            debounce = round(pht-pt);
            %enforce limits
            debounce = min(debounce,16);
            debounce = max(debounce,0);
            try
                obj.hPhotonDiscriminator.peakDebounceSamples = debounce;
            catch ME
                obj.configurationChanged();
                rethrow(ME);
            end
        end
        
        function moveDebounceMotionFcn(obj,src,evt)
            pt = obj.hAxProcessed.CurrentPoint(1,1);
            obj.hLineDebounce.XData(1) = pt;
            obj.hLineDebounceMarker.XData = pt;
            obj.hLineDebounceLimit.XData = [pt pt];
        end
        
        function axisButtonDownFcn(obj,src,evt)
            startPt = src.CurrentPoint;
            startBrushWindow = obj.brushWindow;
            obj.hFig.WindowButtonMotionFcn = @(a,b)obj.motionFcn(src,evt,startPt,startBrushWindow);
            obj.hFig.WindowButtonUpFcn = @obj.stopMotionFcn;
        end
        
        function stopMotionFcn(obj,varargin)
            obj.hFig.WindowButtonMotionFcn = [];
            obj.hFig.WindowButtonUpFcn = [];
        end
        
        function motionFcn(obj,src,evt,startPt,startBrushWindow)
            try
                if src ==  obj.hAxBrush
                    d = src.CurrentPoint(1,1)-startPt(1,1);
                    newBrushWindow = startBrushWindow + d;
                else
                    d = startPt(1,1) - src.CurrentPoint(1,1);
                    newBrushWindow = obj.brushWindow+d;
                end
                
                if newBrushWindow(1)<0
                    newBrushWindow = newBrushWindow - newBrushWindow(1);
                elseif newBrushWindow(2)>length(obj.data)-1
                    newBrushWindow = newBrushWindow - (newBrushWindow(2)-(length(obj.data)-1));
                end                
                obj.updateBrush(newBrushWindow);
                obj.processPhotons();
            catch ME
                obj.stopMotionFcn();
                rethrow(ME);
            end
        end
        
        function assignRawDataInBase(obj,varargin)
            varname = sprintf('dataRawAI%d',obj.hPhotonDiscriminator.physicalChannelNumber);
            assignin('base',varname,obj.data);
            fprintf('Assigned ''%s'' in base workspace\n',varname);
        end
        
        function assignProcessedDataInBase(obj,varargin)
            varname = sprintf('dataProcessedAI%d',obj.hPhotonDiscriminator.physicalChannelNumber);
            assignin('base',varname,obj.dataProcessed);
            fprintf('Assigned ''%s'' in base workspace\n',varname);
        end
        
        function assignPhotonsInBase(obj,varargin)            
            hWaitbar = waitbar(0,'ProcessingPhotons','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            
            try
                [photonIdxs_,~,canceled] = obj.hPhotonDiscriminator.findPhotons(obj.dataProcessed,false,@cancel_progressFcn);
            catch ME
                most.idioms.safeDeleteObj(hWaitbar);
                rethrow(ME);
            end
            
            if ~canceled
                varname = sprintf('photonIdxsAI%d',obj.hPhotonDiscriminator.physicalChannelNumber);
                assignin('base',varname,photonIdxs_);
                fprintf('Assigned ''%s'' in base workspace\n',varname);
            end
            
            most.idioms.safeDeleteObj(hWaitbar);
            
            function cancel = cancel_progressFcn(progress)
                if ~isvalid(hWaitbar)
                    cancel = true;
                else
                    cancel = false;
                    if nargin > 0 && ~isempty(progress)
                        waitbar(progress,hWaitbar);
                    end
                end
            end
        end
    end
end

%--------------------------------------------------------------------------%
% DataPlot.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
