classdef LineScanDisplay < handle
    
    properties
        hSI;
        hDisplay;
        hFig;
        hSpacialViewPnl;
        hSpacViewMouseFindAxes;
        hSpacialViewAx;
        hScannerFovSurf;
        hDataViewAx;
        hTimePlotAx;
        hLinePhotostimMonitor = [];
        
        hDataSurf;
        hHoverTimePlot;
        hUpdateLines;
        
        scanPath;
        hScanPath;
        hNomScanPath;
        
        scanPts;
        scanPtsN;
        hScanPts;
        
        timePts = {};
        ptAcrossZero = [];
        hTimePtsContextMenu;
        timeClrs;
        hTimeDataLines;
        hTimeFovPts;
        hTimePlots;
        
        hoverPt;
        hoverPtAcrossZero;
        hPathHoverPt;
        hDataHoverLine;
        
        channel;
        is3d = false;
        zrng = [0 0];
        CLim = [0 100];
        dataMultiplier = 1;
        dataViewSz;
        scanPathN;
        plotColors = {[0 1 1] [0.6392 0.2863 0.6431] [.5 .5 1] [0 .5 .5] [.5 .25 0] [.25 0 .25]};
        historyLen;
        minimumSpacialAvg = 10;
        
        mouseDownTf = false;
        mouseClickMode = 'none';
        mouseClickPt;
        mouseClickMv;
        pthHit = [];
        
        hLiveHistogram = [];
    end
    
    properties (Dependent)
        cameraProps;
    end
    
    %% LIFEYCLE
    methods
        function obj = LineScanDisplay(hSI,hFig,chan)
            obj.hSI = hSI;
            obj.hDisplay = hSI.hDisplay;
            obj.hFig = hFig;
            
            obj.historyLen = hSI.hDisplay.lineScanHistoryLength;
            obj.channel = chan;
            zs = obj.hSI.hRoiManager.currentRoiGroup.zs;
            obj.is3d = (numel(zs) > 1) && obj.hSI.hFastZ.enable;
            if ~isempty(zs)
                obj.zrng = [min(zs) max(zs)];
                obj.zrng = obj.zrng + diff(obj.zrng) * [-.1 .1];
            end
            
            hMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',hMenu,'Label','Reset Display','Callback',@obj.resetDisplay);
                uimenu('Parent',hMenu,'Label','Autoscale Contrast','Callback',@obj.autoContrast);
                uimenu('Parent',hMenu,'Label','Histogram','Callback',@obj.showHistogram);
                uimenu('Parent',hMenu,'Label','Delete All Plot Points','Callback',@obj.deleteAllTimePlots);
            
            obj.hTimePlotAx = axes('parent',hFig,'color','w','box','on','ylim',obj.CLim,'xlim',[1 obj.historyLen],'YTick',[],'YTickLabel',[],'UIContextMenu',hMenu);
            grid(obj.hTimePlotAx, 'on');
            xlabel(obj.hTimePlotAx,'Frame Number');
            ylabel(obj.hTimePlotAx,'Pixel Value');
            
            obj.hDataViewAx = axes('parent',hFig,'color','k','box','on','YDir','reverse','XTick',[],'XTickLabel',[],'xlim',[1 obj.historyLen],'ylim',[0 1],'YTick',[],'YTickLabel',[],'clim',[0 1],'UIContextMenu',hMenu);
            obj.hDataSurf = surface([1 obj.historyLen], [0 1], zeros(2),'parent',obj.hDataViewAx,'FaceColor','texturemap','CDataMapping','scaled','cdata',zeros(0),'hittest','off');
            ylabel(obj.hDataViewAx,'Cycle Phase');
            
            obj.hUpdateLines = [line([1 1],[0 1],[5 5],'parent',obj.hDataViewAx,'color','r')...
                line([1 1],obj.CLim,[5 5],'parent',obj.hTimePlotAx,'color','r')];
            
            % get scan path
            RG = obj.hSI.hRoiManager.currentRoiGroup;
            SS = obj.hSI.hScan2D.scannerset;
            [obj.scanPath,~,~] = RG.scanStackFOV(SS,0,0,'',0,'',[],false);
            
            %resample to max number of points
            maxp = 100000;
            N = size(obj.scanPath.G,1);
            if N > maxp
                obj.scanPath.G = [interp1(linspace(0,1,N),obj.scanPath.G(:,1),linspace(0,1,maxp)')...
                                  interp1(linspace(0,1,N),obj.scanPath.G(:,2),linspace(0,1,maxp)')];
                scl = maxp / N;
                obj.scanPathN = maxp;
            else
                scl = 1;
                obj.scanPathN = N;
            end
            
            
            obj.hSpacialViewPnl = uipanel('parent',hFig,'BorderType','None','backgroundcolor','k');
            obj.hSpacViewMouseFindAxes = axes('parent',obj.hSpacialViewPnl,'color','none','XColor','none','YColor','none','position',[0 0 1 1],'hittest','off');
            if obj.is3d
                obj.hSpacialViewAx = axes('parent',obj.hSpacialViewPnl,'color','k','PlotBoxAspectRatio', ones(1,3),'XColor','w','YColor','w','ZColor','w','Projection','perspective','zlim',obj.zrng,...
                    'box','on','DataAspectRatio',[1 1 1],'XLim',[-.5 .5] * obj.hSI.hRoiManager.refAngularRange,'YLim',[-.5 .5] * obj.hSI.hRoiManager.refAngularRange,'UIContextMenu',hMenu);
                view(obj.hSpacialViewAx,160,-45);
                camup(obj.hSpacialViewAx,[0,0,-1]);
                
                obj.scanPath.Z = interp1(linspace(0,1,numel(obj.scanPath.Z)),obj.scanPath.Z,linspace(0,1,size(obj.scanPath.G,1))');
            else
                obj.hSpacialViewAx = axes('parent',obj.hSpacialViewPnl,'position',[0 0 1 1],'color','k','XTick',[],'XTickLabel',...
                    [],'YTick',[],'YTickLabel',[],'DataAspectRatio',[1 1 1],'XLim',[-.5 .5] * obj.hSI.hRoiManager.refAngularRange,'YLim',[-.5 .5] * obj.hSI.hRoiManager.refAngularRange,...
                    'XColor','none','YColor','none','UIContextMenu',hMenu);
                view(obj.hSpacialViewAx,0,-90);
                
                % resample Z to length of galvo waveform
                obj.scanPath.Z = ones(size(obj.scanPath.G(:,2)));
            end
            
            cps = SS.fovCornerPoints();
            obj.hScannerFovSurf = surface([cps([1 4],1) cps([2 3],1)], [cps([1 4],2) cps([2 3],2)], zeros(2),'FaceColor','none','edgecolor','y','linewidth',.5,'linestyle',':','parent',obj.hSpacialViewAx,'hittest','off');
            
            obj.hScanPath = patch('parent',obj.hSpacialViewAx,'xdata',obj.scanPath.G(:,1),'ydata',obj.scanPath.G(:,2),'zdata',obj.scanPath.Z,...
                'facecolor','none','linewidth',2,'EdgeColor','interp','FaceVertexCData',[zeros(obj.scanPathN,2) ones(obj.scanPathN,1)],'Hittest','off');
            
            if obj.hSI.hScan2D.recordScannerFeedback
                obj.hNomScanPath = patch('parent',obj.hSpacialViewAx,'xdata',obj.scanPath.G(:,1),'ydata',obj.scanPath.G(:,2),'zdata',obj.scanPath.Z+.0001,...
                    'facecolor','none','linewidth',.5,'linestyle',':','EdgeColor','interp','FaceVertexCData',ones(obj.scanPathN,3),'Hittest','off');
            end
            
            obj.hTimePtsContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hTimePtsContextMenu,'Label','Delete Selection','Callback',@obj.contextMenuDeleteSelectionCb);
            
            % find point functions in path
            j = 1;
            obj.scanPts = [];
            pltPts = [];
            for i = 1:numel(RG.rois)
                if ~isempty(RG.rois(i).scanfields)
                    jdur = SS.nsamples(SS.scanners{1},RG.rois(i).scanfields(1).duration);
                    if RG.rois(i).scanfields(1).isPoint
                        phs = j+floor(jdur/2);
                        phsi = max(1,floor(scl * phs));
                        obj.scanPts(end+1,:) = [RG.rois(i).scanfields(1).centerXY obj.scanPath.Z(phsi)+.000001 phsi];
                        pltPts = [pltPts; obj.scanPts(end,1:3); nan(1,3)];
                    end
                    j = j+jdur;
                end
            end
            obj.scanPtsN = size(obj.scanPts,1);
            
            if ~isempty(pltPts)
                N = size(pltPts,1);
                obj.hScanPts = patch('parent',obj.hSpacialViewAx,'xdata',pltPts(:,1),'ydata',pltPts(:,2),'zdata',pltPts(:,3),'facecolor','none',...
                    'EdgeColor','interp','Marker','.','MarkerFaceColor','flat','MarkerSize',25,'FaceVertexCData',[zeros(N,2) ones(N,1)],...
                    'ButtonDownFcn',@obj.ptHit);
            end
            
            obj.hFig.SizeChangedFcn = @obj.onResize;
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;
            obj.hFig.WindowButtonDownFcn = @obj.buttonDownFcn;
            obj.hFig.WindowButtonMotionFcn = @obj.buttonMotionFcn;
            obj.hFig.WindowButtonUpFcn = @obj.buttonUpFcn;
            obj.onResize();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hSpacialViewPnl);
            most.idioms.safeDeleteObj(obj.hSpacViewMouseFindAxes);
            most.idioms.safeDeleteObj(obj.hSpacialViewAx);
            most.idioms.safeDeleteObj(obj.hScannerFovSurf);
            most.idioms.safeDeleteObj(obj.hDataViewAx);
            most.idioms.safeDeleteObj(obj.hTimePlotAx);
            most.idioms.safeDeleteObj(obj.hDataSurf);
            most.idioms.safeDeleteObj(obj.hHoverTimePlot);
            most.idioms.safeDeleteObj(obj.hUpdateLines);
            most.idioms.safeDeleteObj(obj.hScanPath);
            most.idioms.safeDeleteObj(obj.hNomScanPath);
            most.idioms.safeDeleteObj(obj.hTimeDataLines);
            most.idioms.safeDeleteObj(obj.hTimeFovPts);
            most.idioms.safeDeleteObj(obj.hTimePlots);
            most.idioms.safeDeleteObj(obj.hTimePtsContextMenu);
            most.idioms.safeDeleteObj(obj.hLiveHistogram);
        end
    end
    
    %% PROP ACCESS
    methods
        function set.CLim(obj,val)
            obj.CLim = double(val);
            cval = double(val) .* obj.dataMultiplier;
            
            obj.hDataViewAx.CLim = cval;
            obj.hTimePlotAx.YLim = obj.CLim;
            obj.hUpdateLines(2).YData = obj.CLim;
            
            obj.updateDisplay([]);
            
            if most.idioms.isValidObj(obj.hLiveHistogram)
                obj.hLiveHistogram.lut = obj.CLim;
            end
        end
        
        function set.dataMultiplier(obj,val)
            obj.dataMultiplier = double(val);
            obj.CLim = obj.CLim;
        end
        
        function set.hoverPt(obj,v)
            if numel(v) ~= numel(obj.hoverPt)
                most.idioms.safeDeleteObj(obj.hPathHoverPt)
                most.idioms.safeDeleteObj(obj.hDataHoverLine)
                most.idioms.safeDeleteObj(obj.hHoverTimePlot)
            end
            
            obj.hoverPt = v;
            obj.hoverPtAcrossZero = false;
            v = sort(v);
            
            if ~isempty(v)
                %create points in fov view
                if numel(v) == 1
                    [x,y,z] = getPtLoc(v(1));
                    if most.idioms.isValidObj(obj.hPathHoverPt)
                        obj.hPathHoverPt(1).XData = x;
                        obj.hPathHoverPt(1).YData = y;
                        obj.hPathHoverPt(1).ZData = z;
                    else
                        obj.hPathHoverPt = line(x,y,z,'parent',obj.hSpacialViewAx,'Marker','o','MarkerSize',8,'MarkerEdgeColor','r','LineWidth',2,'HitTest','off','PickableParts','none');
                    end
                else
                    [x,y,z,acrossZero] = obj.calcSpacAvgTimePlotFovPoints(v);
                    obj.hoverPtAcrossZero = acrossZero;
                    
                    if most.idioms.isValidObj(obj.hPathHoverPt)
                        obj.hPathHoverPt.XData = x;
                        obj.hPathHoverPt.YData = y;
                        obj.hPathHoverPt.ZData = z;
                    else
                        obj.hPathHoverPt = line(x,y,z,'parent',obj.hSpacialViewAx,'Color','r','LineWidth',2,'HitTest','off','PickableParts','none');
                    end
                end
                
                %create line in data view
                xd = obj.hDataViewAx.XLim;
                yd = [v(1) v(1)];
                zd = [2 2];
                if numel(v) > 1
                    if acrossZero
                        xd = [xd fliplr(xd) xd(1) nan xd fliplr(xd) xd(1)];
                        yd = [yd 0 0 yd(1) nan 1 1 v(2) v(2) 1];
                        zd = [zd zd zd(1) nan zd zd zd(1)];
                    else
                        xd = [xd fliplr(xd) xd(1)];
                        yd = [yd v(2) v(2) yd(1)];
                        zd = [zd zd zd(1)];
                    end
                end
                if most.idioms.isValidObj(obj.hDataHoverLine)
                    obj.hDataHoverLine.XData = xd;
                    obj.hDataHoverLine.YData = yd;
                    obj.hDataHoverLine.ZData = zd;
                else
                    obj.hDataHoverLine = line(xd,yd,zd,'parent',obj.hDataViewAx,'LineWidth',1,'color','r','HitTest','off','PickableParts','none');
                end
                
                % create plot
                if ~most.idioms.isValidObj(obj.hHoverTimePlot)
                    sz = size(obj.hDisplay.lineScanAvgDataBuffer,2);
                    tt = linspace(obj.hTimePlotAx.XLim(1),obj.hTimePlotAx.XLim(2),sz);
                    obj.hHoverTimePlot = line(tt,zeros(size(tt)),2*ones(size(tt)),'parent',obj.hTimePlotAx,'LineWidth',2,'color','r');
                end
                
                obj.updateHoverPlot();
            end
            
            function [x,y,z] = getPtLoc(phs)
                x = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,1),phs);
                y = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,2),phs);
                if obj.is3d
                    z = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.Z,phs);
                else
                    z = -2*ones(size(x));
                end
            end
        end
        
        function v = get.cameraProps(obj)
            v = struct(...
                'CameraTarget',    obj.hSpacialViewAx.CameraTarget,...
                'CameraPosition',  obj.hSpacialViewAx.CameraPosition,...
                'CameraViewAngle', obj.hSpacialViewAx.CameraViewAngle,...
                'CameraUpVector',  obj.hSpacialViewAx.CameraUpVector);
            v.timePts = obj.timePts;
            v.timeClrs = obj.timeClrs;
        end
        
        function set.cameraProps(obj,v)
            obj.hSpacialViewAx.CameraTarget = v.CameraTarget;
            obj.hSpacialViewAx.CameraPosition = v.CameraPosition;
            obj.hSpacialViewAx.CameraViewAngle = v.CameraViewAngle;
            obj.hSpacialViewAx.CameraUpVector = v.CameraUpVector;
            
            obj.deleteAllTimePlots();
            for i = 1:numel(v.timePts)
                obj.addTimePlot(v.timePts{i}, v.timeClrs(i));
            end
        end
    end
    
    %% METHODS
    methods
        function onResize(obj, varargin)
            obj.hFig.Units = 'pixels';
            obj.hDataViewAx.Units = 'pixels';
            obj.hTimePlotAx.Units = 'pixels';
            obj.hSpacialViewPnl.Units = 'pixels';
            
            p = obj.hFig.Position;
            
            smMarg = 10;
            bigMargX = 30;
            bigMargY = 50;
            
            if p(3) > p(4)
                spacSz = min(floor(p(3) / 2), p(4));
                xsz = p(3)-bigMargX-smMarg-spacSz;
                ysz = floor((p(4) - bigMargY - smMarg)/2);
                
                obj.hDataViewAx.Position = [bigMargX bigMargY+ysz xsz ysz];
                obj.hTimePlotAx.Position = [bigMargX bigMargY xsz ysz];
                obj.hSpacialViewPnl.Position = [p(3)-spacSz+1 1 spacSz p(4)];
                
                obj.dataViewSz = [xsz ysz];
            else
                spacSz = min(p(3), p(4)/ 2);
                xsz = p(3)-smMarg-bigMargX;
                ysz = (p(4)-spacSz-bigMargY-smMarg)/2;
                
                obj.hDataViewAx.Position = [bigMargX bigMargY+ysz+spacSz xsz ysz];
                obj.hTimePlotAx.Position = [bigMargX bigMargY+spacSz xsz ysz];
                obj.hSpacialViewPnl.Position = [1 1 p(3) spacSz];
                
                obj.dataViewSz = [xsz ysz];
            end
            
            obj.updateDisplay([],true);
        end
        
        function scrollWheelFcn(obj,~,evt)
            if mouseIsInAxes(obj.hSpacViewMouseFindAxes)
                zoomSpeedFactor = 1.1;
                cAngle = obj.hSpacialViewAx.CameraViewAngle;
                scroll = zoomSpeedFactor ^ double(evt.VerticalScrollCount);
                cAngle = cAngle * scroll;
                obj.hSpacialViewAx.CameraViewAngle = cAngle;
                obj.refreshTimePlotFovDisps();
            end
        end
        
        function buttonDownFcn(obj,src,evt)
            obj.mouseDownTf = true;
            obj.mouseClickMv = false;
            obj.mouseClickMode = 'none';
            obj.pthHit = [];
            
            switch obj.hFig.SelectionType
                case {'normal' 'extend'}
                    if mouseIsInAxes(obj.hDataViewAx)
                        obj.mouseClickMode = 'dataClick';
                        obj.mouseClickPt = axPt(obj.hDataViewAx);
                    elseif mouseIsInAxes(obj.hSpacViewMouseFindAxes)
                        obj.mouseClickMode = 'pathClick';
                        obj.mouseClickPt = obj.pixPt();
                        
                        pt = obj.findMousePathPt();
                        if ~isempty(pt)
                            obj.pthHit = pt;
                        end
                    end
            end
        end
        
        function buttonMotionFcn(obj,~,~)
            if obj.mouseDownTf
                % mouse drag
                obj.mouseClickMv = true;
                
                switch obj.mouseClickMode
                    case 'pathClick'
                        if isempty(obj.pthHit)
                            % click and drag on empty space. pan view
                            obj.hSpacialViewAx.CameraViewAngleMode = 'manual';
                            pt = obj.pixPt();
                            deltaPix = pt - obj.mouseClickPt;
                            obj.mouseClickPt = obj.pixPt();
                            
                            if obj.is3d && strcmp(obj.hFig.SelectionType,'extend')
                                camorbit(obj.hSpacialViewAx,deltaPix(1),-deltaPix(2),'data',[0 0 1])
                            else
                                camdolly(obj.hSpacialViewAx,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
                            end
                        else
                            % click and drag on path. adding a spacial average plot
                            pt = obj.findMousePathPt();
                            if ~isempty(pt)
                                obj.hoverPt(2) = pt;
                            end
                        end
                end
            else
                % mouse over
                if mouseIsInAxes(obj.hDataViewAx)
                    if obj.scanPathN
                        pt = axPt(obj.hDataViewAx);
                        obj.hoverPt = pt(2);
                    end
                else
                    if mouseIsInAxes(obj.hSpacViewMouseFindAxes)
                        obj.hoverPt = obj.findMousePathPt();
                    else
                        obj.hoverPt = [];
                    end
                end
            end
        end
        
        function pt = findMousePathPt(obj)
            if obj.is3d
                cp = obj.hSpacialViewAx.CurrentPoint;
                dists = scanimage.mroi.util.distanceLinePts3D(cp(1,:),cp(2,:)-cp(1,:),[obj.scanPath.G obj.scanPath.Z]);
            else
                xys = obj.scanPath.G - repmat(axPt(obj.hSpacialViewAx),obj.scanPathN,1);
                dists = sqrt(sum(xys.^2,2));
            end
            
            [r, i] = min(dists); % minimum distance from xyz path
            if r < 2*tand(obj.hSpacialViewAx.CameraViewAngle)
                pt = i/obj.scanPathN;
            else
                pt = [];
            end
        end
        
        function pt = pixPt(obj)
            pt = hgconvertunits(obj.hFig,[0 0 obj.hFig.CurrentPoint],obj.hFig.Units,'pixels',0);
            pt = pt(3:4);
        end
        
        function buttonUpFcn(obj,src,evt)
            switch obj.mouseClickMode
                case 'dataClick'
                    if ~obj.mouseClickMv
                        obj.addTimePlot(obj.mouseClickPt(2));
                    end
                    
                case 'pathClick'
                    if ~obj.mouseClickMv
                        if ~isempty(obj.pthHit)
                            obj.addTimePlot(obj.pthHit);
                        end
                    elseif ~isempty(obj.hoverPt)
                        obj.addTimePlot(sort(obj.hoverPt));
                    end
            end
            
            obj.mouseDownTf = false;
            obj.mouseClickMode = 'none';
            obj.pthHit = [];
        end
        
        function ptHit(obj,~,evt)
            diffs = abs(obj.scanPts(:,1:3) - repmat(evt.IntersectionPoint, size(obj.scanPts,1),1));
            [~, i] = min(sqrt(sum(diffs.^2,2)));
            obj.pthHit = obj.scanPts(i,4)/obj.scanPathN;
        end
        
        function updateDisplay(obj, stripeData, fullDataOnly)
            fullDataOnly = (nargin > 2) && fullDataOnly;
            
            if ~isempty(obj.hDisplay.lineScanAvgDataBuffer)
                %% update full data view
                % figure out appropriate downsample
                chIdx = ismembc2(obj.channel,obj.hDisplay.lineScanDataBufferChannels);
                if ~chIdx
                    return
                end
                
                fsz = obj.hDisplay.lineScanFrameLength;
                iter = floor(2*fsz / obj.dataViewSz(2));
                
                obj.hDataSurf.CData = obj.hDisplay.lineScanAvgDataBuffer(1:iter:end,:,chIdx);
                
                if ~fullDataOnly
                    set(obj.hUpdateLines, 'XData', [1 1] * obj.hDisplay.lineScanLastFramePtr);
                    
                    %% update time series plots
                    obj.updateHoverPlot(chIdx);
                    
                    for i = 1:numel(obj.timePts)
                        dat = obj.getPtData(obj.timePts{i},chIdx);
                        dat(dat > obj.CLim(2)) = obj.CLim(2);
                        dat(dat < obj.CLim(1)) = obj.CLim(1);
                        
                        obj.hTimePlots{i}.YData = dat;
                    end
                    
                    %% update fov view
                    clim = obj.CLim .* obj.dataMultiplier;
                    
                    if isempty(stripeData) || (stripeData.startOfFrame && stripeData.endOfFrame)
                        %update the whole path
                        %resample data to the number of display points. simple indexing is ok, no need to interpolate
                        datInds = ceil((1:obj.scanPathN) * fsz/obj.scanPathN);
                        dat = obj.hDisplay.lineScanAvgDataBuffer(datInds,obj.hDisplay.lineScanLastFramePtr,chIdx);
                        
                        % scale by clim
                        dat = (dat-clim(1)) / diff(clim);
                        dat(dat<0) = 0;
                        dat(dat>1) = 1;
                    
                        obj.hScanPath.FaceVertexCData = [dat dat ones(obj.scanPathN,1)];
                    else
                        %partial update
                        strpN = size(stripeData.rawData,1);
                        strt = stripeData.rawDataStripePosition;
                        nd = stripeData.rawDataStripePosition + strpN - 1;
                        
                        scl = obj.scanPathN/fsz;
                        is = max(1,floor(strt * scl));
                        ie = min(obj.scanPathN,ceil(nd * scl));
                        
                        datInds = ceil((is:ie) / scl);
                        dat = obj.hDisplay.lineScanAvgDataBuffer(datInds,obj.hDisplay.lineScanLastFramePtr,chIdx);
                        
                        dat = (dat-clim(1)) / diff(clim);
                        dat(dat<0) = 0;
                        dat(dat>1) = 1;
                        
                        obj.hScanPath.FaceVertexCData(is:ie,1:2) = [dat dat];
                    end
                    
                    if ~isempty(obj.scanPts)
                        ptDat(1:2:obj.scanPtsN*2-1,:) = obj.hScanPath.FaceVertexCData(obj.scanPts(:,4),:);
                        ptDat(2:2:obj.scanPtsN*2,:) = nan;
                        obj.hScanPts.FaceVertexCData = ptDat;
                    end
                    
                    if most.idioms.isValidObj(obj.hLiveHistogram) && strcmp(obj.hLiveHistogram.hFig.Visible, 'on')
                        % use second-to-latest frame because latest frame could be
                        % partial when striping is enabled with lower cycle rates
                        rp = obj.hDisplay.lineScanLastFramePtr - 1;
                        rp(rp < 1) = 1;
                        data = single(obj.hDisplay.lineScanAvgDataBuffer(:,rp,chIdx));
                        obj.hLiveHistogram.updateData(data);
                    end
                end
            end
        end
        
        function updatePosFdbk(obj)
            if any(~isnan(obj.hSI.hScan2D.lastFramePositionData))
                datInds = ceil((1:obj.scanPathN) * size(obj.hSI.hScan2D.lastFramePositionData,1)/obj.scanPathN);
                obj.scanPath.G = obj.hSI.hScan2D.lastFramePositionData(datInds,1:2);
                obj.hScanPath.XData = obj.scanPath.G(:,1);
                obj.hScanPath.YData = obj.scanPath.G(:,2);
                
                if obj.is3d && (size(obj.hSI.hScan2D.lastFramePositionData,2) > 2)
                    obj.scanPath.Z = obj.hSI.hScan2D.lastFramePositionData(datInds,3);
                    obj.hScanPath.ZData = obj.scanPath.Z;
                end
                
                if ~isempty(obj.scanPts)
                    ptDat(1:2:obj.scanPtsN*2-1,1) = obj.hScanPath.XData(obj.scanPts(:,4));
                    ptDat(1:2:obj.scanPtsN*2-1,2) = obj.hScanPath.YData(obj.scanPts(:,4));
                    ptDat(1:2:obj.scanPtsN*2-1,3) = obj.hScanPath.ZData(obj.scanPts(:,4))+.000001;
                    ptDat(2:2:obj.scanPtsN*2,:) = nan;
                    
                    obj.hScanPts.XData = ptDat(:,1);
                    obj.hScanPts.YData = ptDat(:,2);
                    
                    if obj.is3d
                        obj.hScanPts.ZData = ptDat(:,3);
                    end
                end
                
                for i = 1:numel(obj.timePts)
                    pt = obj.timePts{i};
                    
                    if numel(pt) == 1
                        datInd = ceil(pt*obj.scanPathN);
                        x = obj.scanPath.G(datInd,1);
                        y = obj.scanPath.G(datInd,2);
                        if obj.is3d
                            z = obj.scanPath.Z(datInd);
                        else
                            z = .5;
                        end
                        
                        if any(isnan([x y z]))
                            continue;
                        end
                    else
                        [x,y,z,~] = obj.calcSpacAvgTimePlotFovPoints(pt);
                        if isempty([x y z])
                            return;
                        end
                    end
                    
                    obj.hTimeFovPts{i}.XData = x;
                    obj.hTimeFovPts{i}.YData = y;
                    obj.hTimeFovPts{i}.ZData = z;
                end
            end
        end
        
        function updateHoverPlot(obj,chIdx)
            if most.idioms.isValidObj(obj.hHoverTimePlot)
                if nargin < 2
                    chIdx = ismembc2(obj.channel,obj.hDisplay.lineScanDataBufferChannels);
                    if ~chIdx
                        return
                    end
                end
                
                dat = obj.getPtData(sort(obj.hoverPt),chIdx);
                dat(dat > obj.CLim(2)) = obj.CLim(2);
                dat(dat < obj.CLim(1)) = obj.CLim(1);
                
                obj.hHoverTimePlot.YData = dat;
            end
        end
        
        function dat = getPtData(obj,pt,chIdx)
            fsz = obj.hDisplay.lineScanFrameLength;
            pt = floor(pt * fsz);
            if numel(pt) > 1
                if obj.hoverPtAcrossZero
                    pt = [1:pt(1) pt(2):fsz];
                else
                    pt = pt(1):pt(2);
                end
            else
                pt = floor(pt-[.5 -.5]*obj.minimumSpacialAvg);
                pt = pt(1):pt(2);
                pt(pt<1) = pt(pt<1)+fsz;
                pt(pt>fsz) = pt(pt>fsz)-fsz;
            end
            dat = mean(obj.hDisplay.lineScanAvgDataBuffer(pt,:,chIdx),1) / obj.dataMultiplier;
        end
        
        function addTimePlot(obj,pt,clr)
            if nargin < 3 || isempty(clr)
                clr = obj.pickMostUniquePltColor();
            end
            
            if size(obj.scanPath.G,1)==0
                return
            end
            
            if numel(pt) == 1
                [x,y,z] = getPtLoc(pt);
                if any(isnan([x y z]))
                    return;
                end
                acrossZero = false;
                args = {'Marker','o','MarkerSize',8,'MarkerEdgeColor'};
            else
                [x,y,z,acrossZero] = obj.calcSpacAvgTimePlotFovPoints(pt);
                if isempty([x y z])
                    return;
                end
                args = {'Color'};
            end
            
            % data view line
            xd = obj.hDataViewAx.XLim;
            yd = [pt(1) pt(1)];
            zd = [1.5 1.5];
            if numel(pt) > 1
                if acrossZero
                    xd = [xd fliplr(xd) xd(1) nan xd fliplr(xd) xd(1)];
                    yd = [yd 0 0 yd(1) nan 1 1 pt(2) pt(2) 1];
                    zd = [zd zd zd(1) nan zd zd zd(1)];
                else
                    xd = [xd fliplr(xd) xd(1)];
                    yd = [yd pt(2) pt(2) yd(1)];
                    zd = [zd zd zd(1)];
                end
            end
            
            obj.timeClrs(end+1) = clr;
            
            %create point in fov view
            obj.hTimeFovPts{end+1} = line(x,y,z,'parent',obj.hSpacialViewAx,args{:},obj.plotColors{obj.timeClrs(end)},'LineWidth',2,'UIContextMenu',obj.hTimePtsContextMenu,'UserData',pt);
            
            %create line in data view
            obj.hTimeDataLines{end+1} = line(xd,yd,zd,'parent',obj.hDataViewAx,'LineWidth',1,'color',obj.plotColors{obj.timeClrs(end)},'UIContextMenu',obj.hTimePtsContextMenu,'UserData',pt);
            
            %create plot
            sz = size(obj.hDisplay.lineScanAvgDataBuffer,2);
            tt = linspace(obj.hTimePlotAx.XLim(1),obj.hTimePlotAx.XLim(2),sz);
            obj.hTimePlots{end+1} = line(tt,zeros(size(tt)),'parent',obj.hTimePlotAx,'LineWidth',1,'color',obj.plotColors{obj.timeClrs(end)},'UIContextMenu',obj.hTimePtsContextMenu,'UserData',pt);
            obj.timePts{end+1} = sort(pt);
            obj.ptAcrossZero(end+1) = acrossZero;
            
            function [x,y,z] = getPtLoc(phs)
                x = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,1),phs);
                y = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,2),phs);
                if obj.is3d
                    z = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.Z,phs);
                else
                    z = .5*ones(size(x));
                end
            end
        end
        
        function refreshTimePlotFovDisps(obj)
            for i=1:numel(obj.timePts)
                if numel(obj.timePts{i}) > 1
                    [x,y,z,~] = obj.calcSpacAvgTimePlotFovPoints(obj.timePts{i});
                    obj.hTimeFovPts{i}.XData = x;
                    obj.hTimeFovPts{i}.YData = y;
                    obj.hTimeFovPts{i}.ZData = z;
                end
            end
        end
        
        function [x,y,z,acrossZero] = calcSpacAvgTimePlotFovPoints(obj,pt)
            if abs(pt(2) - pt(1)) < (1 - pt(2) + pt(1))
                [x,y,z] = getPtLoc(linspace(pt(1),pt(2),100));
                acrossZero = false;
            else
                N = floor(((pt(1) - 0) / (1 - pt(2) + pt(1)))*100);
                [x1,y1,z1] = getPtLoc(linspace(pt(1),0,N));
                [x2,y2,z2] = getPtLoc(linspace(1,pt(2),100-N));
                x = [x1 x2];
                y = [y1 y2];
                z = [z1 z2];
                acrossZero = true;
            end
            
            if any(isnan([x y z]))
                x = [];
                y = [];
                z = [];
                return;
            end
            
            % remove duplicate points
            sm = (x(2:end) == x(1:end-1)) & (y(2:end) == y(1:end-1)) & (z(2:end) == z(1:end-1));
            x(sm) = [];
            y(sm) = [];
            z(sm) = [];
            if numel(x) < 2
                x = [x x];
                y = [y y];
                z = [z z];
            end
            
            xn = [y(end) y(1:end-1)] - y;
            yn = x - [x(end) x(1:end-1)];
            dists = sqrt(sum([xn' yn'].^2,2))';
            
            scl = tand(obj.hSpacialViewAx.CameraViewAngle);
            
            xn = xn*scl./dists;
            yn = yn*scl./dists;
            
            % first point is bogus because of wrap around
            xn(1) = xn(2);
            yn(1) = yn(2);
            
            xd1 = [x(1) x+xn x(end)];
            xd2 = [x(1) x-xn x(end)];
            
            yd1 = [y(1) y+yn y(end)];
            yd2 = [y(1) y-yn y(end)];
            z = [z(1) z z(end)];
            
            x = [xd1 nan xd2];
            y = [yd1 nan yd2];
            z = [z nan z];
            
            function [x,y,z] = getPtLoc(phs)
                x = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,1),phs);
                y = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.G(:,2),phs);
                if obj.is3d
                    z = interp1(linspace(0,1,obj.scanPathN),obj.scanPath.Z,phs);
                else
                    z = -2*ones(size(x));
                end
            end
        end
        
        function contextMenuDeleteSelectionCb(obj,src,evt)
            pt = get(gco,'UserData');
            obj.deleteTimePlot(pt);
        end
        
        function deleteTimePlot(obj,pt)            
            idx = find(cellfun(@(ptel)all(ptel == pt),obj.timePts));
            if ~isempty(idx)
                obj.timePts(idx) = [];
                most.idioms.safeDeleteObj(obj.hTimeFovPts{idx});
                obj.hTimeFovPts(idx) = [];
                most.idioms.safeDeleteObj(obj.hTimeDataLines{idx});
                obj.hTimeDataLines(idx) = [];
                most.idioms.safeDeleteObj(obj.hTimePlots{idx});
                obj.hTimePlots(idx) = [];
                obj.timeClrs(idx) = [];
                obj.ptAcrossZero(idx) = [];
            end
        end
        
        function resetDisplay(obj,varargin)
            obj.hSI.hDisplay.resetActiveDisplayFigs(false);
        end
        
        function autoContrast(obj,varargin)
            chIdx = ismembc2(obj.channel,obj.hDisplay.lineScanDataBufferChannels);
            if ~chIdx
                return
            end
            
            pixels = single(obj.hDisplay.lineScanAvgDataBuffer(:,:,chIdx));
            
            if ~isempty(pixels)
                obj.hSI.hDisplay.channelAutoScale(obj.channel,pixels(:)./obj.dataMultiplier);
            end
        end
        
        function showHistogram(obj,varargin)
            chIdx = ismembc2(obj.channel,obj.hDisplay.lineScanDataBufferChannels);
            if ~chIdx
                return
            end
            
            % use second-to-latest frame because latest frame could be
            % partial when striping is enabled with lower cycle rates
            rp = obj.hDisplay.lineScanLastFramePtr - 1;
            rp(rp < 1) = 1;
            data = single(obj.hDisplay.lineScanAvgDataBuffer(:,rp,chIdx));
            
            if ~isempty(data)
                most.idioms.safeDeleteObj(obj.hLiveHistogram);
                obj.hLiveHistogram = scanimage.mroi.LiveHistogram(obj.hSI);
                
                obj.hLiveHistogram.channel = obj.channel;
                obj.hLiveHistogram.title = sprintf('Channel %d Histogram', obj.channel);
                res = obj.hSI.hScan2D.channelsAdcResolution;
                obj.hLiveHistogram.dataRange = [-(2^(res-1)),2^(res-1)-1];
                obj.hLiveHistogram.lut = obj.CLim;
                obj.hLiveHistogram.viewRange = mean(obj.CLim) + [-1.5 1.5].*double(diff(obj.CLim))./2;
                obj.hLiveHistogram.updateData(data);
            end
        end
        
        function deleteAllTimePlots(obj,varargin)
            for i=1:numel(obj.timePts)
                most.idioms.safeDeleteObj(obj.hTimeFovPts{i});
                most.idioms.safeDeleteObj(obj.hTimeDataLines{i});
                most.idioms.safeDeleteObj(obj.hTimePlots{i});
            end
            obj.timePts = {};
            obj.hTimeFovPts = {};
            obj.hTimeDataLines = {};
            obj.hTimePlots = {};
            obj.timeClrs = [];
            obj.ptAcrossZero = [];
        end
        
        function c = pickMostUniquePltColor(obj)
            usedColorCnt = [];
            for i = numel(obj.plotColors):-1:1
                usedColorCnt(i) = sum(obj.timeClrs == i);
            end
            [~, c] = min(usedColorCnt);
            
            if isempty(c)
                c = 1;
            end
        end
    end
end


function tf = mouseIsInAxes(hAx)
    coords = axPt(hAx);
    xlim = hAx.XLim;
    ylim = hAx.YLim;
    tf = (coords(1) > xlim(1)) && (coords(1) < xlim(2)) && (coords(2) > ylim(1)) && (coords(2) < ylim(2));
end

function pt = axPt(hAx)
    cp = hAx.CurrentPoint;
    pt = cp(1,1:2);
end



%--------------------------------------------------------------------------%
% LineScanDisplay.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
