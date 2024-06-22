classdef LineScanDataView < scanimage.guis.ScanImageDataView
    
    properties (Hidden)
        hFig;
        
        hPlotAxes;
        hPlotTimeLine;
        hPlotVLblAxes;
        hPlotVLblHighText;
        hPlotVLblLowText;
        hPlotVValHovText;
        hPlotValHovLine;
        hPlotHLblAxes;
        hPlotHLblHighText;
        hPlotHLblLowText;
        hPlotHValHovText;
        
        hPlotLines = matlab.graphics.primitive.Line.empty;
        hPlotTimeLines = matlab.graphics.primitive.Line.empty;
        hPlotFovPts = matlab.graphics.primitive.Line.empty;
        
        hFovFlow;
        hFovPanel;
        hFovAxes;
        hFovMouseFindAxes;
        hFovLine;
        hFovIdealLine;
        hFovScanPts;
        hContrastSlider;
        hChannelSel;
        
        hTimeAxes;
        hTimeSliderLine;
        hTimeSliderCar;
        hTimeDispSurf;
        hTimeDispLine;
        hTimePlotCar;
        hTimePlotCarL;
        hTimePlotCarH;
        
        hPathHoverPt;
        hDataHoverLine;
        hHoverTimePlot;
        hDataTimeHoverLine;
        hPlotTimeHoverLine;
        
        hFovContextMenu;
        hDelAllTimePtsContextMenu;
        hPltContextMenu;
        hDelTimePtContextMenu;
        hContextImMenu;
        hLgndMnu;
        hLegend;
        
        hContexImCfgPanel;
        
        scannerSet;
        
        % rendering params
        sliderCarR = 12;
        sliderEdgeMarg = 4;
        plotColors = {[1 0 0] [0 1 0] [0 1 1] [0.6392 0.2863 0.6431] [.5 .5 1] [0 .5 .5] [.5 .25 0] [.25 0 .25]};
        minimumSpacialAvg = 10;
        
        % current values
        timeNormPos = 0;
        plotTPos = .5;
        plotTsz = 1;
        timeClrs;
        hoverPt;
        timeHoverPt;
        plotValueHoverPt;
        
        % data info
        timeViewParams;
        is3d = false;
        experimentT = 1;
        experimentdT = 1;
        experimentN = 1;
        experimentNfr = 1;
        
        contrasts;
        
        mouseDownTf = false;
        mouseClickMode = 'none';
        mouseClickPt;
        mouseClickMv;
        pthHit = [];
        
        contextImgs = struct('chans',{},'chan',{},'luts',{},'roiCps',{},'roiImgs',{},'surfs',{});
        
        timeExponent;
        tfMap = containers.Map({true false}, {'on' 'off'});
    end
    
    properties (SetObservable)
        scanPath;
        scanPathDt;
        scanPathN;
        scanPts;
        scanPtsN;
        pmtChannel = 1;
        showPlotLegend = true;
        
        clim = [0 100];
        timePts;
    end
    
    methods
        function obj = LineScanDataView(filename,debug)
            obj.hFig = figure('numbertitle','off','name','ScanImage Data View','menubar','none','units','pixels',...
                'position',most.gui.centeredScreenPos([1600 800]),'CloseRequestFcn',@(varargin)delete(obj),'visible','on','WindowScrollWheelFcn',@obj.scrollWheelFcn);
            bc = 0.1 * ones(1,3);
            obj.hFig.Color = bc;
            
            %% Menus
            obj.hDelAllTimePtsContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hDelAllTimePtsContextMenu,'Label','Delete All Time Plots','Callback',@obj.delAllTimePts);
                
            obj.hFovContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hFovContextMenu,'Label','Delete All Time Plots','Callback',@obj.delAllTimePts);
                uimenu('Parent',obj.hFovContextMenu,'Label','Add Context Image','Callback',@obj.addCtxImFile);
                
            obj.hContextImMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hContextImMenu,'Label','Configure Context Image','Callback',@obj.configureCtxIm);
                uimenu('Parent',obj.hContextImMenu,'Label','Remove Context Image','Callback',@obj.removeCtxIm);
                
            obj.hPltContextMenu = uicontextmenu('Parent',obj.hFig);
                obj.hLgndMnu = uimenu('Parent',obj.hPltContextMenu,'Label','Show Legend','Callback',@obj.toggleLegend, 'Checked', 'on');
                uimenu('Parent',obj.hPltContextMenu,'Label','Delete All Time Plots','Callback',@obj.delAllTimePts);
                uimenu('Parent',obj.hPltContextMenu,'Label','Export Plot','Callback',@obj.exportPlot);
            
            obj.hDelTimePtContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hDelTimePtContextMenu,'Label','Delete Selection','Callback',@obj.delTimePtMnuCb);
            
            %% Plot axes
            obj.hPlotAxes = axes('parent',obj.hFig,'Color','None','box','on','xgrid','on','ygrid','on','xcolor','w','ycolor','w',...
                'YTickLabel',[],'XTickLabel',[],'LineWidth',2,'UIContextMenu',obj.hPltContextMenu,'xlim',[0 1],'FontSize',12,'FontWeight','bold');
            xlabel(obj.hPlotAxes,'Experiment Time (s)');
            ylabel(obj.hPlotAxes,'PMT Signal');
            obj.hPlotTimeLine = line('parent',obj.hPlotAxes,'color','r','linewidth',.5,'xdata',[0 0],'ydata',[0 1],'zdata',.5*ones(1,2));
            obj.hPlotTimeHoverLine = line('parent',obj.hPlotAxes,'color','r','linewidth',.5,'linestyle','--','xdata',[0 0],'ydata',[0 1],'zdata',.5*ones(1,2),'visible','off','Hittest','off');
            
            obj.hPlotVLblAxes = axes('parent',obj.hFig,'Color','none','xcolor','none','ycolor','none','xlim',[0 1],'ylim',[0 1],'Hittest','off');
            obj.hPlotVLblHighText = text(0.5,1,'100','parent',obj.hPlotVLblAxes,'Color','w','HorizontalAlignment','right','FontSize',12,'FontWeight','bold','Rotation',90);
            obj.hPlotVLblLowText = text(0.5,0,'0','parent',obj.hPlotVLblAxes,'Color','w','HorizontalAlignment','left','FontSize',12,'FontWeight','bold','Rotation',90);
            obj.hPlotVValHovText = text(0,0,1,'0','parent',obj.hPlotAxes,'Color','w','HorizontalAlignment','left','FontSize',12,'FontWeight','bold','visible','off');
            obj.hPlotValHovLine = line('parent',obj.hPlotAxes,'color','w','linewidth',.5,'linestyle','--','xdata',[0 0],'ydata',[0 1],'zdata',.5*ones(1,2),'visible','off','Hittest','off');
        
            obj.hPlotHLblAxes = axes('parent',obj.hFig,'Color','none','xcolor','none','ycolor','none','xlim',[0 1],'ylim',[0 1],'Hittest','off');
            obj.hPlotHLblHighText = text(1,.5,'100','parent',obj.hPlotHLblAxes,'Color','w','HorizontalAlignment','right','FontSize',12,'FontWeight','bold');
            obj.hPlotHLblLowText = text(0,.5,'0','parent',obj.hPlotHLblAxes,'Color','w','HorizontalAlignment','left','FontSize',12,'FontWeight','bold');
            obj.hPlotHValHovText = text(0,0,1,'0','parent',obj.hPlotAxes,'Color','w','HorizontalAlignment','center','FontSize',12,'FontWeight','bold','visible','off','VerticalAlignment','bottom');
            
        
            %% FOV area
            obj.hFovFlow = most.gui.uiflowcontainer('parent',obj.hFig,'flowdirection','topdown','margin',0.0001);
            obj.hFovPanel = uipanel('parent',obj.hFovFlow,'BackgroundColor',bc,'bordertype','none','UIContextMenu',obj.hFovContextMenu);
            obj.hFovMouseFindAxes = axes('parent',obj.hFovPanel,'color','none','XColor','none','YColor','none','position',[0 0 1 1],'hittest','off');
            obj.hFovAxes = axes('parent',obj.hFovPanel,'Color','None','xcolor','none','ycolor','none','DataAspectRatio',[1 1 1],'YDir','reverse','ZDir','reverse','UIContextMenu',obj.hFovContextMenu);
            colormap(obj.hFovAxes,[repmat((0:.01:1)',1,2) ones(101,1)]);
            obj.hFovLine = patch('parent',obj.hFovAxes,'xdata',[],'ydata',[],'zdata',[],'facecolor','none','linewidth',2,'EdgeColor','interp','FaceVertexCData',[],'Hittest','off');
            obj.hFovIdealLine = line('parent',obj.hFovAxes,'xdata',[],'ydata',[],'zdata',[],'linestyle',':','linewidth',1,'Color','w','Hittest','off','Visible','off');
            obj.hFovScanPts = patch('parent',obj.hFovAxes,'xdata',[],'ydata',[],'zdata',[],'facecolor','none','EdgeColor','interp','Marker','.','MarkerFaceColor','flat','MarkerSize',30,'FaceVertexCData',[],'ButtonDownFcn',@obj.ptHit);
            
            hFovBottomFlow = most.gui.uiflowcontainer('parent',obj.hFovFlow,'flowdirection','lefttoright','HeightLimits',32);
            hFovBottomFlow.BackgroundColor = bc;
            obj.hChannelSel = most.gui.wire.popupMenu('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','WidthLimits',160,'FontColor','w','FontSize',12,'FontWeight','bold','Bindings',{obj 'pmtChannel'});
            most.gui.staticText('parent',hFovBottomFlow,'string','Contrast:','BackgroundColor',bc,'FontColor','w','FontSize',12,'FontWeight','bold','HorizontalAlignment','right','WidthLimits',100);
            obj.hContrastSlider = most.gui.constrastSlider('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','BarColor',bc,'DarkColor',[0 0 1],'BrightColor',[1 1 1],'Bindings',{obj 'clim'});
            most.gui.wire.button('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','WidthLimits',30,'FontColor','w','FontSize',12,'FontWeight','bold','String','A','Callback',@obj.autoContrast);
            
            %% Time axes
            obj.hTimeAxes = axes('parent',obj.hFig,'Color','None','xcolor','none','ycolor','none','xlim',[0 1],'ylim',[0 1],'Hittest','off','UIContextMenu',obj.hDelAllTimePtsContextMenu);
            colormap(obj.hTimeAxes,repmat((0:.01:1)',1,3));
            obj.hTimeSliderLine = line('parent',obj.hTimeAxes,'color','w','linewidth',2,'xdata',[0 1],'ydata',[.1 .1],'zdata',[0 0],'ButtonDownFcn',@obj.dragTimeCar);
            obj.hTimeSliderCar = patch('parent',obj.hTimeAxes,'xdata',ones(1,37),'ydata',ones(1,37),'zdata',ones(1,37),'EdgeColor','w','FaceColor',.5*ones(1,3),'LineWidth',2,'ButtonDownFcn',@obj.dragTimeCar);
            obj.hTimeDispSurf = surface('parent',obj.hTimeAxes,'xdata',[0 1;0 1],'ydata',[1 1;0 0],'zdata',zeros(2,2),'EdgeColor','w','FaceColor','texturemap','CDataMapping','scaled','LineWidth',.5,'cdata',nan(0),'Hittest','off');
            obj.hTimeDispLine = line('parent',obj.hTimeAxes,'color','r','linewidth',.5,'xdata',[0 0],'ydata',[0 1],'zdata',.5*ones(1,2),'ButtonDownFcn',@obj.dragTimeCar);
            obj.hTimePlotCar = surface('parent',obj.hTimeAxes,'xdata',[0 1;0 1],'ydata',[1 1;0 0],'zdata',.6*ones(2),'EdgeColor','y','FaceColor','none','LineWidth',1,'ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'both'),'Visible','off');
            obj.hTimePlotCarL = line('parent',obj.hTimeAxes,'xdata',0,'ydata',1,'zdata',.7,'Color','y','Markersize',30,'marker','.','ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'low'),'Visible','off');
            obj.hTimePlotCarH = line('parent',obj.hTimeAxes,'xdata',0,'ydata',1,'zdata',.7,'Color','y','Markersize',30,'marker','.','ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'high'),'Visible','off');
            obj.hDataTimeHoverLine = line('parent',obj.hTimeAxes,'color','r','linewidth',.5,'linestyle','--','xdata',[0 0],'ydata',[0 1],'zdata',.5*ones(1,2),'visible','off','hittest','off');
            
            obj.hContexImCfgPanel = scanimage.guis.scanimagedataview.ContexImCfgPanel(obj);
            
            %% Resize gui
            obj.resize();
            obj.hFig.SizeChangedFcn = @obj.resize;
            obj.hFig.WindowButtonDownFcn = @obj.buttonDownFcn;
            obj.hFig.WindowButtonMotionFcn = @obj.buttonMotionFcn;
            obj.hFig.WindowButtonUpFcn = @obj.buttonUpFcn;
            obj.hFig.UIContextMenu = obj.hDelAllTimePtsContextMenu;
            
            try
                obj.loadData(filename);
            catch ME
                delete(obj);
                if (nargin > 1) && debug
                    ME.rethrow();
                else
                    error('Failed to load data file. %s', ME.message);
                end
            end
        end
        
        function delete(obj)
            if ~isempty(obj.data)
                most.idioms.safeDeleteObj(obj.data.roiGroup);
            end
            most.idioms.safeDeleteObj(obj.scannerSet);
            most.idioms.safeDeleteObj(obj.hContrastSlider);
            most.idioms.safeDeleteObj(obj.hChannelSel);
            most.idioms.safeDeleteObj(obj.hContexImCfgPanel);
            most.idioms.safeDeleteObj(obj.hFig);
            
            obj.delete@scanimage.guis.ScanImageDataView;
        end
    end
    
    %% USER FUNCTIONS
    methods
        function lims = autoContrast(obj,ch)
            if nargin < 2
                ch = obj.pmtChannel;
            end
            
            dat = squeeze(obj.data.pmtData(:,ch,:));
            
            %avg data down first
            if obj.minimumSpacialAvg > 0
                 % too many samps per frame. avg down to smaller
                af = obj.minimumSpacialAvg;
                m = floor(obj.scanPathN / af);
                N = af * m;
                
                leftover = dat(N+1:end,:);
                lastLine = mean(leftover,1);
                
                mainDat = reshape(dat(1:N,:)',size(dat,2),af,[]);
                if obj.data.header.numFrames > 1
                    sqDat = squeeze(mean(mainDat,2))';
                else
                    sqDat = squeeze(mean(mainDat,2));
                end
                dat = [sqDat; lastLine];
            end
            
            lims = [min(dat(:)) max(dat(:))];
            
            if ~nargout
                obj.clim = lims;
            end
        end
        
        function loadData(obj,filename)
            if nargin > 1
                obj.fileName = filename;
            end
            [fileDir,nm,~] = fileparts(obj.fileName);
            fileNameStem = strrep(nm,'.meta','');
            obj.hFig.Name = ['ScanImage Data View: ' fileNameStem];
            
            [header, pmtData, scannerPosData, roiGroup] = scanimage.util.readLineScanDataFiles(obj.fileName);
            obj.data = struct('header',header,'pmtData',pmtData,'scannerPosData',scannerPosData,'roiGroup',roiGroup);
            obj.scannerSet = scanimage.mroi.scannerset.GalvoGalvo.default;
            
            if isfield(header.SI.hScan2D, 'sampleRateCtl')
                Fsc = header.SI.hScan2D.sampleRateCtl;
            else
                Fsc = 500e3;
            end
            obj.scannerSet.scanners{1}.sampleRateHz = Fsc;
            obj.scannerSet.scanners{2}.sampleRateHz = Fsc;
            obj.scannerSet.beams.sampleRateHz = Fsc;
            obj.scannerSet.fastz.sampleRateHz = Fsc;
            [obj.scanPath,~,~] = obj.data.roiGroup.scanStackFOV(obj.scannerSet,0,0,'',0,'',[],false);
            
            % resample scan path to acq sample rate
            N = numel(obj.scanPath.G(:,1));
            Nt = header.samplesPerFrame;
            obj.scanPath.G = [interp1(linspace(0,1,N),obj.scanPath.G(:,1),linspace(0,1,Nt)')...
                                  interp1(linspace(0,1,N),obj.scanPath.G(:,2),linspace(0,1,Nt)')];
            obj.scanPath.Z = interp1(linspace(0,1,N),obj.scanPath.Z,linspace(0,1,Nt)');
            obj.scanPathN = Nt;
            
            % find point functions in path
            j = 1;
            scanPtsTmp = [];
            pltPts = [];
            for i = 1:numel(roiGroup.rois)
                if ~isempty(roiGroup.rois(i).scanfields)
                    jdur = obj.scannerSet.nsamples(obj.scannerSet.scanners{1},roiGroup.rois(i).scanfields(1).duration);
                    if roiGroup.rois(i).scanfields(1).isPoint
                        phs = j+floor(jdur/2);
                        scanPtsTmp(end+1,:) = [roiGroup.rois(i).scanfields(1).centerXY roiGroup.rois(i).zs(1) phs];
                        pltPts = [pltPts; scanPtsTmp(end,1:3); nan(1,3)];
                    end
                    j = j+jdur;
                end
            end
            if ~isempty(scanPtsTmp)
                obj.scanPts = [scanPtsTmp(:,1:3) ceil(scanPtsTmp(:,4)*obj.scanPathN/j)];
                obj.scanPtsN = size(obj.scanPts,1);
            end
            
            if ~isempty(pltPts)
                obj.hFovScanPts.XData = pltPts(:,1);
                obj.hFovScanPts.YData = pltPts(:,2);
                obj.hFovScanPts.ZData = pltPts(:,3);
                obj.hFovScanPts.FaceVertexCData = zeros(size(pltPts(:,3)));
                obj.hFovScanPts.Visible = 'on';
            else
                obj.hFovScanPts.Visible = 'off';
            end
            
            
            lims = [min(obj.scanPath.G(:,1)) max(obj.scanPath.G(:,1))];
            obj.hFovAxes.XLim = mean(lims) + .6*diff(lims)*[-1 1];
            
            lims = [min(obj.scanPath.G(:,2)) max(obj.scanPath.G(:,2))];
            obj.hFovAxes.YLim = mean(lims) + .6*diff(lims)*[-1 1];
            
            obj.hFovAxes.ZLim = [min(obj.scanPath.Z)-1 max(obj.scanPath.Z)+1];
            
            if numel(header.acqChannels) > 1
                obj.hChannelSel.choices = arrayfun(@(i)sprintf('PMT Channel %d',i),header.acqChannels,'uniformoutput',false);
                obj.hChannelSel.Visible = 'on';
            else
                obj.hChannelSel.choices = arrayfun(@(i)sprintf('PMT Channel %d',i),header.acqChannels,'uniformoutput',false);
                obj.hChannelSel.Visible = 'off';
            end
            
            obj.hFovLine.XData = obj.scanPath.G(:,1);
            obj.hFovLine.YData = obj.scanPath.G(:,2);
            obj.hFovLine.ZData = zeros(obj.scanPathN,1);
            obj.hFovLine.FaceVertexCData = [zeros(obj.scanPathN,2) ones(obj.scanPathN,1)];
            
            if ~isempty(obj.data.scannerPosData)
                obj.hFovIdealLine.XData = obj.scanPath.G(:,1);
                obj.hFovIdealLine.YData = obj.scanPath.G(:,2);
                obj.hFovIdealLine.ZData = zeros(obj.scanPathN,1)-.1;
                obj.hFovIdealLine.Visible = 'on';
            else
                obj.hFovIdealLine.Visible = 'off';
            end
            
            obj.experimentNfr = header.numFrames;
            obj.experimentdT = 1 / header.sampleRate;
            obj.experimentN = header.numSamples;
            obj.experimentT = obj.experimentN * obj.experimentdT;
            obj.plotTPos = .5 * obj.experimentT;
            obj.plotTsz = obj.experimentT;
            obj.updatePlotAxes();
            
            % set contrast
            obj.hContrastSlider.max = max(obj.data.pmtData(:));
            obj.hContrastSlider.min = min(obj.data.pmtData(:));
            nc = arrayfun(@(ch){obj.autoContrast(ch)},1:numel(header.acqChannels));
            obj.pmtChannel = 1;
            obj.contrasts = nc;
            obj.clim = nc{1};
            
            % set time view
            obj.updateTimeSurf();
            
            % find the most interesting time point and plot it
            sqdat = squeeze(obj.data.pmtData(:,obj.pmtChannel,:));
            mns = min(sqdat,[],2);
            mxs = max(sqdat,[],2);
            dffs = abs(mxs-mns);
            [~, i] = max(dffs);
            obj.delAllTimePts();
            obj.addPlotPt(i/obj.scanPathN);
            
            obj.timeNormPos = 0;
            
            %% load ref images if present
            refFileName = fullfile(fileDir,[fileNameStem '.ref.dat']);
            obj.addCtxImFile(refFileName);
        end
        
        function addPlotPt(obj,normPt)
            normPt = sort(normPt);
            pt = ceil(normPt * obj.scanPathN);
            %% get point to plot
            if numel(pt) == 1
                [fovx,fovy,fovz] = obj.getPtLoc(pt);
                if any(isnan([fovx fovy fovz]))
                    return;
                end
                args = {'Marker','o','MarkerSize',8,'MarkerEdgeColor'};
                pta = [normPt normPt];
            else
                [fovx,fovy,fovz] = obj.calcSpacAvgTimePlotFovPoints(normPt);
                if isempty([fovx fovy fovz])
                    return;
                end
                args = {'Color'};
                pta = normPt;
            end
            
            %% pick color
            clr = obj.pickMostUniquePltColor();
            obj.timeClrs(end+1) = clr;
            clr = obj.plotColors{clr};
            obj.timePts(end+1,:) = pta;
            
            %% time plot
            [dat,t] = obj.getPmtData(normPt,obj.pmtChannel);
            dat(dat > obj.clim(2)) = obj.clim(2);
            dat(dat < obj.clim(1)) = obj.clim(1);
            obj.hPlotLines(end+1) = line('parent',obj.hPlotAxes,'color',clr,'linewidth',2,'xdata',t,'ydata',dat,'zdata',ones(size(dat)),'UIContextMenu',obj.hDelTimePtContextMenu,'UserData',pta);
            
            %% data surf line
            [xd, yd] = obj.calcTimeViewPts(normPt);
            obj.hPlotTimeLines(end+1) = line('parent',obj.hTimeAxes,'color',clr,'linewidth',1,'xdata',xd,'ydata',yd,'UIContextMenu',obj.hDelTimePtContextMenu,'UserData',pta);
            
            %% fov point
            obj.hPlotFovPts(end+1) = line(fovx,fovy,fovz,'parent',obj.hFovAxes,args{:},clr,'LineWidth',2,'UIContextMenu',obj.hDelTimePtContextMenu,'UserData',pta);
            
            obj.updateLegend();
        end
        
        function updatePlotLines(obj)
            if ~isempty(obj.hoverPt)
                [dat,t] = obj.getPmtData(obj.hoverPt,obj.pmtChannel);
                dat(dat > obj.clim(2)) = obj.clim(2);
                dat(dat < obj.clim(1)) = obj.clim(1);
                obj.hHoverTimePlot.XData = t;
                obj.hHoverTimePlot.YData = dat;
            end
            
            for i=1:size(obj.timePts,1)
                [dat,t] = obj.getPmtData(obj.timePts(i,:),obj.pmtChannel);
                dat(dat > obj.clim(2)) = obj.clim(2);
                dat(dat < obj.clim(1)) = obj.clim(1);
                obj.hPlotLines(i).XData = t;
                obj.hPlotLines(i).YData = dat;
                obj.hPlotLines(i).ZData = ones(size(dat));
            end
        end
        
        function [xd, yd, zd] = calcTimeViewPts(obj,normPt)
            tvp = obj.timeViewParams;
            timy = tvp.vertNormPos(1) + (1-normPt(1))*tvp.rg(2);
            xd = tvp.horzNormPos;
            yd = [timy timy];
            zd = [1.5 1.5];
            
            if numel(normPt) > 1
                timy = tvp.vertNormPos(1) + (1-normPt(2))*tvp.rg(2);
                if normPt(1) > normPt(2)
                    xd = [xd fliplr(xd) xd(1) nan xd fliplr(xd) xd(1)];
                    yd = [yd tvp.vertNormPos(1) tvp.vertNormPos(1) yd(1) nan 1 1 timy timy 1];
                    zd = [zd zd zd(1) nan zd zd zd(1)];
                else
                    xd = [xd fliplr(xd) xd(1)];
                    yd = [yd timy timy yd(1)];
                    zd = [zd zd zd(1)];
                end
            end
        end
        
        function [x,y,z] = getPtLoc(obj,i)
            x = obj.scanPath.G(i,1);
            y = obj.scanPath.G(i,2);
            z = obj.scanPath.Z(i);
        end
        
        function [x,y,z] = calcSpacAvgTimePlotFovPoints(obj,pt)
            if abs(pt(2) - pt(1)) < (1 - pt(2) + pt(1))
                [x,y,z] = getPtLoc(linspace(pt(1),pt(2),100));
            else
                N = floor(((pt(1) - 0) / (1 - pt(2) + pt(1)))*100);
                [x1,y1,z1] = getPtLoc(linspace(pt(1),0,N));
                [x2,y2,z2] = getPtLoc(linspace(1,pt(2),100-N));
                x = [x1 x2];
                y = [y1 y2];
                z = [z1 z2];
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
            
            scl = tand(obj.hFovAxes.CameraViewAngle)*.5;
            
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
                    z = obj.scanPath.Z(1)*ones(size(x));
                end
            end
        end
        
        function refreshTimePlotFovDisps(obj)
            for i=1:size(obj.timePts,1)
                if diff(obj.timePts(i,:))
                    [x,y,z] = obj.calcSpacAvgTimePlotFovPoints(obj.timePts(i,:));
                    obj.hPlotFovPts(i).XData = x;
                    obj.hPlotFovPts(i).YData = y;
                    obj.hPlotFovPts(i).ZData = z;
                end
            end
        end
        
        function delAllTimePts(obj,varargin)
            most.idioms.safeDeleteObj(obj.hPlotLines);
            most.idioms.safeDeleteObj(obj.hPlotTimeLines);
            most.idioms.safeDeleteObj(obj.hPlotFovPts);
            obj.hPlotLines = matlab.graphics.primitive.Line.empty;
            obj.hPlotTimeLines = matlab.graphics.primitive.Line.empty;
            obj.hPlotFovPts = matlab.graphics.primitive.Line.empty;
            
            obj.timePts = [];
            obj.timeClrs = [];
            
            obj.updateLegend();
        end
        
        function delTimePltById(obj,id)
            if (numel(obj.timePts) < 2) && (id == 1)
                obj.delAllTimePts();
            else
                most.idioms.safeDeleteObj(obj.hPlotLines(id));
                most.idioms.safeDeleteObj(obj.hPlotTimeLines(id));
                most.idioms.safeDeleteObj(obj.hPlotFovPts(id));
                obj.hPlotLines(id) = [];
                obj.hPlotTimeLines(id) = [];
                obj.hPlotFovPts(id) = [];
                
                obj.timePts(id,:) = [];
                obj.timeClrs(id) = [];
            end
            
            obj.updateLegend();
        end
    end
    
    %% INTERNAL
    methods (Hidden)
        function updateTimeSurf(obj)
            dat = squeeze(obj.data.pmtData(:,obj.pmtChannel,:));
            
            % get monitor positions
            p = get(0,'MonitorPositions');
            
            
            %% resample to reduce number of phase points
            m = 0.5*max(p(:,4));
            
            if size(dat,1) > m
                % too many samps per frame. avg down to smaller
                af = floor(obj.scanPathN / m);
                N = af * m;
                
                leftover = dat(N+1:end,:);
                lastLine = mean(leftover,1);
                
                mainDat = reshape(dat(1:N,:)',size(dat,2),af,[]);
                if obj.data.header.numFrames > 1
                    sqDat = squeeze(mean(mainDat,2))';
                else
                    sqDat = squeeze(mean(mainDat,2));
                end
                dat = [sqDat; lastLine];
            end
            
            obj.hTimeDispSurf.CData = dat;
        end
        
        function scrollWheelFcn(obj,~,evt)
            if mouseIsInAxes(obj.hFovMouseFindAxes)
                ppt = axPt(obj.hFovAxes);
                oAngle = obj.hFovAxes.CameraViewAngle;
                obj.hFovAxes.CameraViewAngle = oAngle * 1.1^double(evt.VerticalScrollCount);
                obj.refreshTimePlotFovDisps();
                
                if ~obj.is3d
                    % maintain point under mouse
                    dp = axPt(obj.hFovAxes) - ppt;
                    camdolly(obj.hFovAxes,dp(1),dp(2),0,'movetarget','data');
                end
            elseif mouseIsInAxes(obj.hPlotAxes)
                ppt = axPt(obj.hPlotAxes);
                obj.plotTsz = obj.plotTsz * 1.25^double(evt.VerticalScrollCount);
                obj.updatePlotAxes();
                npt = axPt(obj.hPlotAxes);
                obj.plotTPos = obj.plotTPos + ppt(1) - npt(1);
                obj.updatePlotAxes();
            end
        end
        
        function buttonDownFcn(obj,~,evt)
            obj.mouseClickMv = false;
            obj.mouseClickMode = 'none';
            obj.pthHit = [];
            
            switch obj.hFig.SelectionType
                case {'normal' 'extend'}
                    if mouseIsInAxes(obj.hTimeAxes)
                        obj.mouseClickMode = 'dataClick';
                        tvp = obj.timeViewParams;
                        p = 1- (axPt(obj.hTimeAxes) - tvp.vertNormPos(1)) * tvp.rgscl(2);
                        obj.mouseClickPt = p(2);
                        obj.mouseDownTf = true;
                    elseif mouseIsInAxes(obj.hFovMouseFindAxes)
                        obj.mouseClickMode = 'pathClick';
                        obj.mouseClickPt = obj.pixPt();
                        
                        pt = obj.findMousePathPt();
                        if ~isempty(pt)
                            obj.pthHit = pt;
                        end
                        obj.mouseDownTf = true;
                    elseif mouseIsInAxes(obj.hPlotAxes)
                        obj.mouseClickMode = 'plotClick';
                        obj.mouseClickPt = axPt(obj.hPlotAxes);
                        obj.mouseDownTf = true;
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
                            obj.hFovAxes.CameraViewAngleMode = 'manual';
                            pt = obj.pixPt();
                            deltaPix = pt - obj.mouseClickPt;
                            obj.mouseClickPt = obj.pixPt();
                            
                            if obj.is3d && strcmp(obj.hFig.SelectionType,'extend')
                                camorbit(obj.hFovAxes,deltaPix(1),-deltaPix(2),'data',[0 0 1])
                            else
                                camdolly(obj.hFovAxes,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
                            end
                        else
                            % click and drag on path. adding a spacial average plot
                            pt = obj.findMousePathPt();
                            if ~isempty(pt)
                                obj.hoverPt(2) = pt;
                            end
                        end
                        
                    case 'dataClick'
                        tvp = obj.timeViewParams;
                        p = 1- (axPt(obj.hTimeAxes) - tvp.vertNormPos(1)) * tvp.rgscl(2);
                        obj.mouseClickPt(2) = min(p(2),1);
                        obj.hoverPt = obj.mouseClickPt;
                        
                    case 'plotClick'
                        npt = axPt(obj.hPlotAxes);
                        obj.plotTPos = obj.plotTPos + obj.mouseClickPt(1) - npt(1);
                        obj.updatePlotAxes();
                end
            else
                % mouse over
                if mouseIsInAxes(obj.hTimeAxes)
                    tvp = obj.timeViewParams;
                    ap = axPt(obj.hTimeAxes);
                    
                    p = 1 - (ap(2) - tvp.vertNormPos(1)) * tvp.rgscl(2);
                    if (p >= 0) && (p <= 1)
                        obj.hoverPt = p;
                    else
                        obj.hoverPt = [];
                    end
                    
                    p = (ap(1) - tvp.horzNormPos(1)) * tvp.rgscl(1);
                    if (p >= 0) && (p <= 1)
                        obj.timeHoverPt = p;
                    else
                        obj.timeHoverPt = [];
                    end
                    
                    obj.plotValueHoverPt = [];
                elseif mouseIsInAxes(obj.hFovMouseFindAxes)
                    obj.hoverPt = obj.findMousePathPt();
                    obj.timeHoverPt = [];
                    obj.plotValueHoverPt = [];
                elseif mouseIsInAxes(obj.hPlotAxes)
                    ap = axPt(obj.hPlotAxes);
                    obj.hoverPt = [];
                    obj.timeHoverPt = ap(1) / obj.experimentT;
                    obj.plotValueHoverPt = ap(2);
                else
                    obj.hoverPt = [];
                    obj.timeHoverPt = [];
                    obj.plotValueHoverPt = [];
                end
            end
        end
        
        function buttonUpFcn(obj,~,~)
            switch obj.mouseClickMode
                case 'dataClick'
                    if obj.mouseClickPt <= 1
                        obj.addPlotPt(obj.mouseClickPt);
                    end
                    
                case 'pathClick'
                    if ~obj.mouseClickMv
                        if ~isempty(obj.pthHit)
                            obj.addPlotPt(obj.pthHit);
                        end
                    elseif ~isempty(obj.hoverPt)
                        obj.addPlotPt(obj.hoverPt);
                    end
            end
            
            obj.resetMouseState();
        end
        
        function resetMouseState(obj)
            obj.mouseDownTf = false;
            obj.mouseClickMode = 'none';
            obj.pthHit = [];
        end
        
        function ptHit(obj,~,evt)
            diffs = abs(obj.scanPts(:,1:3) - repmat(evt.IntersectionPoint, size(obj.scanPts,1),1));
            [~, i] = min(sqrt(sum(diffs.^2,2)));
            obj.pthHit = obj.scanPts(i,4)/obj.scanPathN;
        end
        
        function pt = findMousePathPt(obj)
            if obj.is3d
                cp = obj.hFovAxes.CurrentPoint;
                dists = scanimage.mroi.util.distanceLinePts3D(cp(1,:),cp(2,:)-cp(1,:),[obj.scanPath.G obj.scanPath.Z]);
            else
                xys = obj.scanPath.G - repmat(axPt(obj.hFovAxes),obj.scanPathN,1);
                dists = sqrt(sum(xys.^2,2));
            end
            
            [r, i] = min(dists); % minimum distance from xyz path
            if r < 2*tand(obj.hFovAxes.CameraViewAngle)
                pt = i/obj.scanPathN;
            else
                pt = [];
            end
        end
        
        function pt = pixPt(obj)
            pt = hgconvertunits(obj.hFig,[0 0 obj.hFig.CurrentPoint],obj.hFig.Units,'pixels',0);
            pt = pt(3:4);
        end
        
        function dragPlotTimeCar(obj,evt,inds)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent scl
            persistent ppt
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                tvp = obj.timeViewParams;
                scl = tvp.rgscl(1);
                ppt = obj.hTimeAxes.CurrentPoint(1)*scl;
                
                set(obj.hFig,'WindowButtonMotionFcn',@(~,evt)obj.dragPlotTimeCar(evt,inds),'WindowButtonUpFcn',@(~,evt)obj.dragPlotTimeCar(evt,inds));
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                npt = obj.hTimeAxes.CurrentPoint(1)*scl;
                delt = (npt - ppt) * obj.experimentT;
                if strcmp(inds,'both')
                    obj.plotTPos = obj.plotTPos + delt;
                else
                    obj.plotTPos = obj.plotTPos + delt / 2;
                    if strcmp(inds,'low')
                        obj.plotTsz = obj.plotTsz - delt;
                    else
                        obj.plotTsz = obj.plotTsz + delt;
                    end
                end
                obj.updatePlotAxes();
                ppt = npt;
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
            end
            
            obj.resetMouseState();
        end
        
        function dragTimeCar(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            persistent offs
            persistent scl
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                
                tvp = obj.timeViewParams;
                scl = tvp.rgscl(1);
                offs = tvp.horzNormPos(1);
                obj.timeNormPos = obj.hTimeAxes.CurrentPoint(1)*scl - offs;
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.dragTimeCar,'WindowButtonUpFcn',@obj.dragTimeCar);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                obj.timeNormPos = obj.hTimeAxes.CurrentPoint(1)*scl - offs;
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
            end
            
            obj.resetMouseState();
        end
        
        function resize(obj,~,~)
            obj.hFig.Units = 'pixels';
            ps = obj.hFig.Position;
            sz = ps([3 4]);
            
            marg = 8;
            
            timeSize = .28;
            plotSize = .6;
            
            timeAPos = [marg marg (sz(1) - marg*2) ((sz(2) - marg*3)*timeSize)];
            plotAPos = [marg (marg*2+timeAPos(4)) (sz(1)*plotSize) (sz(2)-marg*3-timeAPos(4))];
            fovAPos = [(marg*2+plotAPos(3)) (marg*2+timeAPos(4)) (sz(1)-marg*3-plotAPos(3)) plotAPos(4)];
            
            obj.hFovFlow.Units = 'pixels';
            obj.hFovFlow.Position = fovAPos;
            obj.hTimeAxes.Units = 'pixels';
            obj.hTimeAxes.Position = timeAPos;
            
            %% Plot section
            marg = 28;
            
            obj.hPlotAxes.Units = 'pixels';
            plotAPosM = plotAPos + marg*[1 1 -1 -1];
            obj.hPlotAxes.Position = plotAPosM;
            obj.hPlotVLblAxes.Units = 'pixels';
            obj.hPlotVLblAxes.Position = [0 plotAPosM(2) plotAPosM(1) plotAPosM(4)];
            obj.hPlotHLblAxes.Units = 'pixels';
            obj.hPlotHLblAxes.Position = [plotAPosM(1) plotAPos(2) plotAPosM(3) plotAPosM(2)-plotAPos(2)];
            
            xl = obj.hPlotAxes.XLim;
            scl = diff(xl)/plotAPosM(3);
            obj.hPlotVValHovText.Position(1) = xl(1)+8*scl;
            
            %% time section
            % adjust vertical position of line to keep it correct number of pixels from bottom
            vertPixPos = obj.sliderCarR;
            vertNormPos = vertPixPos/timeAPos(4);
            obj.hTimeSliderLine.YData = vertNormPos*ones(1,2);
            % adjust position of surface
            vertPixPos = 2*obj.sliderCarR + 8;
            vertNormPos = vertPixPos/timeAPos(4);
            extra = (obj.sliderCarR + obj.sliderEdgeMarg)/timeAPos(3);
            obj.hTimeDispSurf.XData = [extra*ones(2,1) (1-extra)*ones(2,1)];
            obj.hTimeDispSurf.YData = [1 1; vertNormPos*ones(1,2)];
            
            tvp.vertNormPos = [vertNormPos 1];
            tvp.horzNormPos = [extra (1-extra)];
            tvp.scl = 1./timeAPos([3 4]);
            tvp.rg = [diff(tvp.horzNormPos) diff(tvp.vertNormPos)];
            tvp.rgscl = 1./tvp.rg;
            obj.timeViewParams = tvp;
            
            obj.drawTimeCar();
            
            % resize time lines
            if ~isempty(obj.hoverPt)
                [xd, yd, zd] = obj.calcTimeViewPts(obj.hoverPt);
                obj.hDataHoverLine.XData = xd;
                obj.hDataHoverLine.YData = yd;
                obj.hDataHoverLine.ZData = zd;
            end
            for i=1:size(obj.timePts,1)
                [xd, yd, zd] = obj.calcTimeViewPts(obj.timePts(i,:));
                obj.hPlotTimeLines(i).XData = xd;
                obj.hPlotTimeLines(i).YData = yd;
                obj.hPlotTimeLines(i).ZData = zd;
            end
            obj.hDataTimeHoverLine.YData = tvp.vertNormPos;
        end
        
        function drawTimeCar(obj)
            xs = obj.sliderCarR*cosd(0:10:360);
            ys = obj.sliderCarR*sind(0:10:360) + obj.sliderCarR;
            
            tvp = obj.timeViewParams;
            x = tvp.horzNormPos(1) + obj.timeNormPos*tvp.rg(1);
            
            obj.hTimeSliderCar.XData = xs*tvp.scl(1) + x;
            obj.hTimeSliderCar.YData = ys*tvp.scl(2);
            obj.hTimeDispLine.XData = x*ones(1,2);
            obj.hPlotTimeLine.XData = obj.timeNormPos*obj.experimentT*ones(1,2);
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
        
        function delTimePtMnuCb(obj,varargin)
            pt = obj.hFig.CurrentObject.UserData;
            obj.delTimePltById(find(sum(repmat(pt,size(obj.timePts,1),1) == obj.timePts,2) == 2));
        end
        
        function [y,t] = getPmtData(obj,normi,chIdx)
            fsz = obj.scanPathN;
            ii = max(floor(normi * fsz),1);
            if numel(ii) == 1 || ~diff(ii)
                ii = floor(ii(1)-[.5 -.5]*obj.minimumSpacialAvg);
                ii = ii(1):ii(2);
                ii(ii<1) = ii(ii<1)+fsz;
                ii(ii>fsz) = ii(ii>fsz)-fsz;
            else
                if ii(1) > ii(2)
                    ii = [1:ii(2) ii(1):fsz];
                else
                    ii = ii(1):ii(2);
                end
            end
            y = squeeze(mean(obj.data.pmtData(ii,chIdx,:),1));
            t = linspace(obj.experimentdT,obj.experimentT,obj.experimentNfr);
        end
        
        function updatePlotAxes(obj)
            obj.hPlotAxes.Units = 'pixels';
            plotAPos = obj.hPlotAxes.Position;
            xl = obj.plotTPos + obj.plotTsz*[-.5 .5];
            scl = diff(xl)/plotAPos(3);
            
            obj.hPlotAxes.XLim = xl;
            obj.hPlotValHovLine.XData = xl + [60*scl 0];
            obj.hPlotVValHovText.Position(1) = xl(1)+8*scl;
            
            expInd = min(max(-floor(log10(xl(2))/3),0),3);
            obj.timeExponent = 10^(3*expInd);
            exps = {'' 'm' char(181) 'n'};
            xlabel(obj.hPlotAxes,['Experiment Time (' exps{expInd+1} 's)']);
            
            obj.hPlotHLblLowText.String = sprintf('%.3f',xl(1)*obj.timeExponent);
            obj.hPlotHLblHighText.String = sprintf('%.3f',xl(2)*obj.timeExponent);
            
            %% update time view box
            if obj.plotTsz < obj.experimentT
                obj.hTimePlotCar.Visible = 'on';
                obj.hTimePlotCarL.Visible = 'on';
                obj.hTimePlotCarH.Visible = 'on';
                
                tvp = obj.timeViewParams;
                obj.hTimePlotCar.XData = tvp.horzNormPos(1) + repmat((obj.plotTPos + obj.plotTsz*[-.5 .5])/obj.experimentT,2,1)/tvp.rgscl(1);
                obj.hTimePlotCar.YData = repmat(tvp.vertNormPos',1,2);
                
                obj.hTimePlotCarL.XData = obj.hTimePlotCar.XData(1,1);
                obj.hTimePlotCarL.YData = mean(obj.hTimePlotCar.YData(:,1));
                
                obj.hTimePlotCarH.XData = obj.hTimePlotCar.XData(1,2);
                obj.hTimePlotCarH.YData = obj.hTimePlotCarL.YData;
            else
                obj.hTimePlotCar.Visible = 'off';
                obj.hTimePlotCarL.Visible = 'off';
                obj.hTimePlotCarH.Visible = 'off';
            end
        end
        
        function toggleLegend(obj,varargin)
            obj.showPlotLegend = ~obj.showPlotLegend;
        end
        
        function labels = getPlotNames(obj)
            N = numel(obj.hPlotLines);
            labels = cell(1,N);
            for i = 1:N
                labels{i} = cyclePhaseStr(obj.timePts(i,:));
            end
            
            function str = cyclePhaseStr(phs)
                str = sprintf('Cycle phase %.2f', phs(1));
            end
        end
        
        function updateLegend(obj,varargin)
            N = numel(obj.hPlotLines);
            if obj.showPlotLegend && N
                obj.hLegend = legend(obj.hPlotLines, obj.getPlotNames(), 'TextColor', 'w', 'FontSize', 12, 'EdgeColor', 'w', 'LineWidth', .5);
            else
                legend(obj.hPlotAxes,'hide');
            end
        end
        
        function exportPlot(obj,varargin)
            N = numel(obj.hPlotLines);
            if N
                f = figure;
                a = axes('parent',f);
                
                for i = 1:N
                    lines(i) = plot(obj.hPlotLines(i).XData*obj.timeExponent, obj.hPlotLines(i).YData);
                    hold on;
                end
                
                legend(lines,obj.getPlotNames());
                xlabel(a,obj.hPlotAxes.XLabel.String);
                xlim(a,obj.hPlotAxes.XLim*obj.timeExponent);
                ylabel(a,'PMT Signal');
                ylim(a,obj.hPlotAxes.YLim);
                grid(a,'on');
            end
            
            function str = cyclePhaseStr(phs)
                str = sprintf('Cycle phase %.2f', phs(1));
            end
        end
        
        function addCtxImFile(obj,n,~)
            if ischar(n)
                if ~exist(n,'file')
                    return;
                end
                
                [~,~,ext]=fileparts(n);
                
                switch ext
                    case '.tif'
                        try
                            warning('off');
                            [roiData, ~, hdr, ~, ~] = scanimage.util.getMroiDataFromTiff(n);
                            warning('on');
                        catch
                            msgbox('The selected file is not a ScanImage tif file.','Invalid File','warn');
                            return;
                        end
                        s.chans = hdr.SI.hChannels.channelSave;
                        s.chan = 1;
                        s.luts = hdr.SI.hChannels.channelLUT(s.chans);
                        
                        for i = 1:numel(roiData)
                            rd = roiData{i};
                            sf = rd.hRoi.get(rd.zs(1));
                            s.roiCps{i} = sf.cornerpoints();
                            % ctx im
                            % settingssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
                            for c = 1:numel(s.chans)
                                s.roiImgs{i}{c} = rd.imageData{c}{1}{1}{end};
                            end
                        end
                        
                        obj.addCtxIm(s);
                        
                    case '.dat'
                        refIms = load(n,'-mat');
                        for i = 1:numel(refIms.contextImageChanSel)
                            s = struct('chans',refIms.contextImageChans(i),'chan',{refIms.contextImageChanSel(i)},'luts',refIms.contextImageLuts(i),...
                                'roiCps',refIms.contextImageRoiCPs{i}(1),'roiImgs',refIms.contextImageImgs{i}(1));
                            
                            for r = 1:numel(s.roiImgs)
                                for c = 1:numel(s.roiImgs{r})
                                    s.roiImgs{r}{c} = s.roiImgs{r}{c}';
                                end
                            end
                            
                            obj.addCtxIm(s);
                        end
                end
            else
                cn = 'scanimage.guis.ScanImageDataView';
                most.HasClassDataFile.ensureClassDataFileStatic(cn,struct('lastFile','linescanData.meta.txt'));
                filename = fileparts(most.HasClassDataFile.getClassDataVarStatic(cn,'lastFile',[],false));
                [filename,pathname] = uigetfile({'*.tif;*.ref.dat' 'ScanImage Frame Scan Data (*.tif, *.ref.dat)'},'Open ScanImage Data',filename);
                if filename==0;return;end
                obj.addCtxImFile(fullfile(pathname,filename));
            end
        end
        
        function addCtxIm(obj,s)
            s.surfs = matlab.graphics.primitive.Surface.empty;
            
            lut = single(s.luts{s.chan});
            for i = 1:numel(s.roiCps)
                cps = s.roiCps{i};
                xx = [cps(1:2,1) cps([4 3],1)];
                yy = [cps(1:2,2) cps([4 3],2)];
                
                s.surfs(i) = surface(xx,yy,(obj.hFovAxes.ZLim(2)-.01)*ones(2),'Parent',obj.hFovAxes,'linewidth',1,'FaceColor','texturemap','CData',nan(3),'EdgeColor','c','UIContextMenu',obj.hContextImMenu);
                
                xl = obj.hFovAxes.XLim;
                yl = obj.hFovAxes.YLim;
                obj.hFovAxes.XLim = [min([xx(:); xl(1)]) max([xx(:); xl(2)])];
                obj.hFovAxes.YLim = [min([yy(:); yl(1)]) max([yy(:); yl(2)])];
                
                s.surfs(i).CData = repmat(uint8(255 * max(min((single(s.roiImgs{i}{s.chan}) - lut(1)) / diff(lut),1),0))',1,1,3);
            end
            
            obj.contextImgs(end+1) = s;
        end
        
        function configureCtxIm(obj,varargin)
            sf = obj.hFig.CurrentObject;
            
            for i = 1:numel(obj.contextImgs)
                if any(sf == obj.contextImgs(i).surfs)
                    obj.hContexImCfgPanel.show(i);
                    break
                end
            end
        end
        
        function removeCtxIm(obj,varargin)
            sf = obj.hFig.CurrentObject;
            
            for i = 1:numel(obj.contextImgs)
                if any(sf == obj.contextImgs(i).surfs)
                    most.idioms.safeDeleteObj(obj.contextImgs(i).surfs);
                    obj.contextImgs(i) = [];
                    break
                end
            end
        end
    end
    
    %% PROP ACCESS
    methods
        function set.timeNormPos(obj,val)
            obj.timeNormPos = max(min(val,1),0);
            obj.drawTimeCar();
            
            i = max(1,round(size(obj.data.pmtData,3) * obj.timeNormPos));
            obj.hFovLine.FaceVertexCData = squeeze(obj.data.pmtData(:,obj.pmtChannel,i));
            
            if ~isempty(obj.scanPts)
                ptDat(1:2:obj.scanPtsN*2-1) = obj.hFovLine.FaceVertexCData(obj.scanPts(:,4));
                ptDat(2:2:obj.scanPtsN*2) = nan;
                obj.hFovScanPts.FaceVertexCData = ptDat';
            end
            
            if ~isempty(obj.data.scannerPosData)
                xdat = squeeze(obj.data.scannerPosData.G(:,1,i));
                ydat = squeeze(obj.data.scannerPosData.G(:,2,i));
                Nd = numel(xdat);
                
                N = numel(obj.hFovLine.XData);
                obj.hFovLine.XData = [interp1(linspace(0,1,Nd),xdat,linspace(0,1,N)'); nan];
                obj.hFovLine.YData = [interp1(linspace(0,1,Nd),ydat,linspace(0,1,N)'); nan];
                obj.hFovLine.ZData = [zeros(obj.scanPathN,1); nan];
                obj.hFovLine.FaceVertexCData(end:size(obj.hFovLine.Vertices,1)) = nan;
            end
        end
        
        function set.clim(obj,v)
            v(1) = min(v(1),v(2)-1);
            obj.clim = v;
            
            obj.hPlotAxes.YLim = v;
            obj.hPlotTimeLine.YData = v;
            obj.hTimeAxes.CLim = v;
            obj.hFovAxes.CLim = v;
            obj.hPlotTimeHoverLine.YData = v;
            
            obj.hPlotAxes.Units = 'pixels';
            scl = diff(v) / obj.hPlotAxes.Position(4);
            obj.hPlotHValHovText.Position(2) = v(1) + 20*scl;
            
            obj.hPlotVLblHighText.String = num2str(round(v(2)));
            obj.hPlotVLblLowText.String = num2str(round(v(1)));
            
            obj.updatePlotLines();
        end
        
        function set.plotTsz(obj,val)
            obj.plotTsz = max(min(val,obj.experimentT),obj.experimentT * .001);
        end
        
        function set.plotTPos(obj,val)
            marg = obj.plotTsz * .5;
            obj.plotTPos = max(min(val,obj.experimentT - marg),marg);
        end
        
        function set.pmtChannel(obj,v)
            obj.contrasts{obj.pmtChannel} = obj.clim;
            
            obj.pmtChannel = v;
            
            obj.clim = obj.contrasts{obj.pmtChannel};
            obj.updateTimeSurf();
            obj.timeNormPos = obj.timeNormPos;
        end
        
        function set.timeHoverPt(obj,v)
            if isempty(v)
                obj.hDataTimeHoverLine.Visible = 'off';
                obj.hPlotTimeHoverLine.Visible = 'off';
                obj.hPlotHValHovText.Visible = 'off';
            else
                tvp = obj.timeViewParams;
                obj.hDataTimeHoverLine.XData = v*ones(1,2)/tvp.rgscl(1) + tvp.horzNormPos(1);
                obj.hPlotTimeHoverLine.XData = obj.experimentT*v*ones(1,2);
                obj.hPlotHValHovText.String = sprintf('%.3f', obj.experimentT*v*obj.timeExponent);
                obj.hPlotHValHovText.Position(1) = obj.experimentT*v;
                obj.hDataTimeHoverLine.Visible = 'on';
                obj.hPlotTimeHoverLine.Visible = 'on';
                obj.hPlotHValHovText.Visible = 'on';
            end
        end
        
        function set.plotValueHoverPt(obj,v)
            if isempty(v)
                obj.hPlotVValHovText.Visible = 'off';
                obj.hPlotValHovLine.Visible = 'off';
            else
                obj.hPlotAxes.Units = 'pixels';
                xl = obj.hPlotAxes.XLim;
                scl = diff(xl) / obj.hPlotAxes.Position(3);
                obj.hPlotValHovLine.XData = xl + [obj.hPlotVValHovText.Extent(3)+16*scl 0];
                
                obj.hPlotValHovLine.YData = v*ones(1,2);
                obj.hPlotVValHovText.Position(2) = v;
                obj.hPlotVValHovText.String = num2str(round(v));
                obj.hPlotValHovLine.Visible = 'on';
                obj.hPlotVValHovText.Visible = 'on';
                
            end
        end
        
        function set.hoverPt(obj,v)
            v = sort(max(min(v,1),0));
            
            if numel(v) ~= numel(obj.hoverPt)
                most.idioms.safeDeleteObj(obj.hPathHoverPt)
                most.idioms.safeDeleteObj(obj.hDataHoverLine)
                most.idioms.safeDeleteObj(obj.hHoverTimePlot)
            end
            
            obj.hoverPt = v;
            
            if ~isempty(v)
                %create points in fov view
                if numel(v) == 1
                    [x,y,z] = obj.getPtLoc(ceil(v(1) * obj.scanPathN));
                    if most.idioms.isValidObj(obj.hPathHoverPt)
                        obj.hPathHoverPt(1).XData = x;
                        obj.hPathHoverPt(1).YData = y;
                        obj.hPathHoverPt(1).ZData = z;
                    else
                        obj.hPathHoverPt = line(x,y,z,'parent',obj.hFovAxes,'Marker','o','MarkerSize',8,'MarkerEdgeColor','r','LineWidth',.5,'HitTest','off','PickableParts','none');
                    end
                else
                    [x,y,z] = obj.calcSpacAvgTimePlotFovPoints(v);
                    
                    if most.idioms.isValidObj(obj.hPathHoverPt)
                        obj.hPathHoverPt.XData = x;
                        obj.hPathHoverPt.YData = y;
                        obj.hPathHoverPt.ZData = z;
                    else
                        obj.hPathHoverPt = line(x,y,z,'parent',obj.hFovAxes,'Color','r','LineWidth',.5,'HitTest','off','PickableParts','none');
                    end
                end
                
                %create line in data view
                [xd, yd, zd] = obj.calcTimeViewPts(obj.hoverPt);
                if most.idioms.isValidObj(obj.hDataHoverLine)
                    obj.hDataHoverLine.XData = xd;
                    obj.hDataHoverLine.YData = yd;
                    obj.hDataHoverLine.ZData = zd;
                else
                    obj.hDataHoverLine = line(xd,yd,zd,'parent',obj.hTimeAxes,'LineWidth',1,'LineStyle','--','color','r','HitTest','off','PickableParts','none');
                end
                
                % create plot
                if ~most.idioms.isValidObj(obj.hHoverTimePlot)
                    sz = size(obj.data.pmtData,3);
                    tt = linspace(0,1,sz);
                    obj.hHoverTimePlot = line(tt,zeros(size(tt)),2*ones(size(tt)),'parent',obj.hPlotAxes,'LineWidth',1,'LineStyle','--','color','r');
                end
                
                [dat, t] = obj.getPmtData(obj.hoverPt,obj.pmtChannel);
                dat(dat > obj.clim(2)) = obj.clim(2);
                dat(dat < obj.clim(1)) = obj.clim(1);
                obj.hHoverTimePlot.XData = t;
                obj.hHoverTimePlot.YData = dat;
            end
        end
        
        function set.showPlotLegend(obj,v)
            obj.showPlotLegend = v;
            obj.hLgndMnu.Checked = obj.tfMap(v);
            obj.updateLegend();
        end
    end
end

function tf = mouseIsInAxes(hAx)
    coords =  hAx.CurrentPoint(1,1:2);
    xlim = hAx.XLim;
    ylim = hAx.YLim;
    tf = (coords(1) > xlim(1)) && (coords(1) < xlim(2)) && (coords(2) > ylim(1)) && (coords(2) < ylim(2));
end

function pt = axPt(hAx)
    cp = hAx.CurrentPoint;
    pt = cp(1,1:2);
end


%--------------------------------------------------------------------------%
% LineScanDataView.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
