classdef FrameScanDataView < scanimage.guis.ScanImageDataView
    
    properties (Hidden)
        hFig;
        
        hCfgFig;
        
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
        hPlotFovPts = matlab.graphics.primitive.Line.empty;
        
        hFovFlow;
        hFovPanel;
        zFlow;
        hFovAxes;
        hZSelAxes;
        hFovMouseFindAxes;
        hContrastSlider;
        hViewModeSel;
        hChannelSel;
        hRenderButton;
        
        hZSliderLine;
        hZSliderHashes;
        hZSliderCar;
        hZSliderTexts = matlab.graphics.primitive.Text.empty;
        
        hTimeAxes;
        hTimeSliderLine;
        hTimeSliderCar;
        hTimePlotCar;
        hTimePlotCarL;
        hTimePlotCarH;
        
        hPathHoverPt;
        hHoverTimePlot;
        hPlotTimeHoverLine;
        
        hFovContextMenu;
        hPltContextMenu;
        hDelTimePtContextMenu;
        hLgndMnu;
        hLegend;
        
        hLdPanel;
        hRenderTool;
        
        % rendering params
        sliderCarR = 12;
        sliderEdgeMarg = 4;
        timeViewParams;
        plotColors = {[1 0 0] [0 1 0] [0 1 1] [0.6392 0.2863 0.6431] [.5 .5 1] [0 .5 .5] [.5 .25 0] [.25 0 .25]};
        
        % current values
        timePos = 0;
        plotTPos = .5;
        plotTsz = 1;
        timeClrs;
        hoverPt;
        timeHoverPt;
        plotValueHoverPt;
        
        % data info
        is3d = false;
        frameTs;
        frameZs;
        zs;
        zsTs;
        zRois;
        zSurfs;
        dataXLims;
        dataYLims;
        
        sfSkipLines = 0;
        
        experimentT0 = 0;
        experimentTE = 0;
        experimentT = 0;
        zticks;
        
        
        contrasts;
        
        mouseDownTf = false;
        mouseClickMode = 'none';
        mouseClickPt;
        mouseClickMv;
        
        timeExponent;
        tfMap = containers.Map({true false}, {'on' 'off'});
        autoScaleSaturationFraction = [.1 .01];
        
        is3dView = false;
    end
    
    properties (Hidden,SetObservable)
        viewModeCh = 1;
    end
    
    properties (SetObservable)
        pmtChannel = 1;
        showPlotLegend = true;
        
        clim = [0 100];
        timePts;
        
        viewMode = '2D';
        lockLastZ = true;
        viewZ = 0;
        
        showSfBorders = true;
        enableTransparency = false;
        sliceSpacing = 1;
    end
    
    methods
        function obj = FrameScanDataView(filename)
            obj.hFig = figure('numbertitle','off','name','ScanImage Data View','menubar','none','units','pixels',...
                'position',most.gui.centeredScreenPos([1600 800]),'CloseRequestFcn',@(varargin)delete(obj),'visible','on','WindowScrollWheelFcn',@obj.scrollWheelFcn);
            bc = 0.1 * ones(1,3);
            obj.hFig.Color = bc;
            
            %% Menus
            obj.hFovContextMenu = uicontextmenu('Parent',obj.hFig);
                uimenu('Parent',obj.hFovContextMenu,'Label','Reset View','Callback',@obj.resetView);
                uimenu('Parent',obj.hFovContextMenu,'Label','Delete All Time Plots','Callback',@obj.delAllTimePts);
                
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
            hFovTFlow = most.gui.uiflowcontainer('parent',obj.hFovFlow,'flowdirection','lefttoright','margin',0.0001);
            obj.hFovPanel = uipanel('parent',hFovTFlow,'BackgroundColor',bc,'bordertype','none','UIContextMenu',obj.hFovContextMenu);
            obj.hFovMouseFindAxes = axes('parent',obj.hFovPanel,'color','none','XColor','none','YColor','none','position',[0 0 1 1],'hittest','off');
            obj.hFovAxes = axes('parent',obj.hFovPanel,'Color','None','xcolor','none','ycolor','none','Zcolor','none','DataAspectRatio',[1 1 1],'UIContextMenu',obj.hFovContextMenu);
            colormap(obj.hFovAxes,repmat((0:.01:1)',1,3));
            
            obj.zFlow = most.gui.uiflowcontainer('parent',hFovTFlow,'flowdirection','topdown','margin',0.0001,'Visible','off','WidthLimits',90);
            most.gui.staticText('parent',obj.zFlow,'string','Z Pos (um)','BackgroundColor',bc,'FontColor','w','HeightLimits',24,'FontSize',12,'FontWeight','bold');
            most.gui.uicontrol('parent',obj.zFlow,'style','edit','FontSize',12,'FontWeight','bold',...
                'Bindings',{obj 'viewZ' 'value'},'HeightLimits',24,'BackgroundColor',bc,'ForegroundColor','w');
            most.gui.checkbox('parent',obj.zFlow,'String','Current','FontSize',12,'FontWeight','bold',...
                'Bindings',{obj 'lockLastZ' 'value'},'HeightLimits',24,'BackgroundColor',bc,'ForegroundColor','w');
            hZpnl = most.gui.uipanel('parent',obj.zFlow,'BackgroundColor',bc,'bordertype','none');
            obj.hZSelAxes = axes('parent',hZpnl,'Color','None','xcolor','none','ycolor','none','position',[0 0 1 1],'xlim',[0 90],'ylim',[0 1],'ydir','reverse','ButtonDownFcn',@obj.hitZSlider);
            
            obj.hZSliderLine = line('parent',obj.hZSelAxes,'xdata',40*ones(1,2),'ydata',[0 1],'color','w','linewidth',2,'hittest','off');
            obj.hZSliderHashes = line('parent',obj.hZSelAxes,'xdata',nan,'ydata',nan,'color','w','linewidth',2,'hittest','off');
            obj.hZSliderCar = line('parent',obj.hZSelAxes,'xdata',22,'ydata',.5,'color','w','linewidth',2,'marker','>','markersize',12,'hittest','off');
            
            hFovBottomFlow = most.gui.uiflowcontainer('parent',obj.hFovFlow,'flowdirection','lefttoright','HeightLimits',32);
            hFovBottomFlow.BackgroundColor = bc;
            obj.hViewModeSel = most.gui.wire.popupMenu('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','WidthLimits',105,'FontColor','w','FontSize',12,'FontWeight','bold','Bindings',{obj 'viewModeCh'},'visible','off');
            most.gui.wire.button('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','FontColor','w','FontSize',12,'FontWeight','bold','String','...','Callback',@obj.viewSettings,'WidthLimits',34);
            most.gui.staticText('parent',hFovBottomFlow,'string','','BackgroundColor',bc,'WidthLimits',6);
            obj.hChannelSel = most.gui.wire.popupMenu('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','WidthLimits',160,'FontColor','w','FontSize',12,'FontWeight','bold','Bindings',{obj 'pmtChannel'},'visible','off');
            most.gui.staticText('parent',hFovBottomFlow,'string','Contrast:','BackgroundColor',bc,'FontColor','w','FontSize',12,'FontWeight','bold','HorizontalAlignment','right','WidthLimits',85);
            obj.hContrastSlider = most.gui.constrastSlider('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','BarColor',bc,'DarkColor',[0 0 0],'BrightColor',[1 1 1],'Bindings',{obj 'clim'},'Min',0,'Max',100);
            most.gui.wire.button('parent',hFovBottomFlow,'BackgroundColor',bc, 'BorderColor','w','WidthLimits',30,'FontColor','w','FontSize',12,'FontWeight','bold','String','A','Callback',@obj.autoContrast);
            obj.hViewModeSel.choices = {'2D View' '3D View'};
            obj.hRenderButton = most.gui.wire.button('parent',obj.hFig,'BackgroundColor',bc, 'BorderColor','w','FontColor','w','FontSize',12,'FontWeight','bold','String','Render Frame Sequence','Callback',@obj.renderFrameSequence);
            
            obj.hPathHoverPt = patch(nan,nan,nan,'parent',obj.hFovAxes,'Marker','+','MarkerSize',12,'EdgeColor','r','MarkerEdgeColor','r','LineWidth',1,'HitTest','off','PickableParts','none','visible','off','FaceColor','r','FaceAlpha',.4);
            obj.hHoverTimePlot = line(nan,nan,'parent',obj.hPlotAxes,'LineWidth',1,'LineStyle','--','color','r','visible','off');
            
            %% Time axes
            obj.hTimeAxes = axes('parent',obj.hFig,'Color','None','xcolor','none','ycolor','none','xlim',[0 1],'ylim',[0 1],'Hittest','off');
            colormap(obj.hTimeAxes,repmat((0:.01:1)',1,3));
            obj.hTimeSliderLine = line('parent',obj.hTimeAxes,'color','w','linewidth',2,'xdata',[0 1],'ydata',[.1 .1],'zdata',[0 0],'ButtonDownFcn',@obj.dragTimeCar);
            obj.hTimeSliderCar = patch('parent',obj.hTimeAxes,'xdata',ones(1,37),'ydata',ones(1,37),'zdata',ones(1,37),'EdgeColor','w','FaceColor',.5*ones(1,3),'LineWidth',2,'ButtonDownFcn',@obj.dragTimeCar);
            obj.hTimePlotCar = surface('parent',obj.hTimeAxes,'xdata',[0 1;0 1],'ydata',[1 1;0 0],'zdata',.6*ones(2),'EdgeColor','y','FaceColor','none','LineWidth',1,'ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'both'),'Visible','off');
            obj.hTimePlotCarL = line('parent',obj.hTimeAxes,'xdata',0,'ydata',.5,'zdata',.7,'Color','y','Markersize',30,'marker','.','ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'low'),'Visible','off');
            obj.hTimePlotCarH = line('parent',obj.hTimeAxes,'xdata',0,'ydata',.5,'zdata',.7,'Color','y','Markersize',30,'marker','.','ButtonDownFcn',@(~,evt)obj.dragPlotTimeCar(evt,'high'),'Visible','off');
            
            obj.hLdPanel = scanimage.guis.scanimagedataview.LoadingPanel(obj);
            obj.hRenderTool = scanimage.guis.scanimagedataview.RenderTool(obj);
            
            %% display cfg
            g = 4;
            obj.hCfgFig = figure('numbertitle','off','name','View Properties','menubar','none','units','pixels',...
                'position',[0 0 300 150],'CloseRequestFcn',@obj.hideCfgFig,'visible','off');
                of = most.gui.uiflowcontainer('parent',obj.hCfgFig,'flowdirection','topdown','margin',0.0001);
                    tf = most.gui.uiflowcontainer('parent',of,'flowdirection','topdown','margin',0.0001);
                        f = most.gui.uiflowcontainer('parent',tf,'flowdirection','lefttoright','HeightLimits',34);
                            most.gui.staticText('parent',f,'string','','WidthLimits',g);
                            most.gui.uicontrol('Parent',f,'String','Show Scanfield Borders','style','checkbox','Bindings',{obj 'showSfBorders' 'value'},'WidthLimits',200,'FontSize',12);
                        f = most.gui.uiflowcontainer('parent',tf,'flowdirection','lefttoright','HeightLimits',34);
                            most.gui.staticText('parent',f,'string','','WidthLimits',g);
                            most.gui.uicontrol('Parent',f,'String','Enable Transparency','style','checkbox','Bindings',{obj 'enableTransparency' 'value'},'WidthLimits',200,'FontSize',12);
                        f = most.gui.uiflowcontainer('parent',tf,'flowdirection','lefttoright','HeightLimits',34);
                            most.gui.staticText('parent',f,'string','','WidthLimits',g);
                            most.gui.staticText('parent',f,'string','Slice Spacing:','FontSize',12,'WidthLimits',100);
                            most.gui.uicontrol('Parent',f,'style','edit','WidthLimits',60,'FontSize',12,'Bindings',{obj 'sliceSpacing' 'value'});
                            f2 = most.gui.uiflowcontainer('parent',f,'flowdirection','topdown','margin',3);
                            most.gui.slider('Parent',f2,'Bindings',{obj 'sliceSpacing' 100},'HeightLimits',24);
                    bf = most.gui.uiflowcontainer('parent',of,'flowdirection','bottomup','HeightLimits',34);
                        most.gui.uicontrol('Parent',bf,'String','OK','callback',@obj.hideCfgFig,'WidthLimits',100,'FontSize',12);
            
            %% Resize gui
            obj.resize();
            obj.hFig.SizeChangedFcn = @obj.resize;
            obj.hFig.WindowButtonDownFcn = @obj.buttonDownFcn;
            obj.hFig.WindowButtonMotionFcn = @obj.buttonMotionFcn;
            obj.hFig.WindowButtonUpFcn = @obj.buttonUpFcn;
            
            try
                obj.loadData(filename);
            catch ME
                delete(obj);
                error('Failed to load data file. %s', ME.message);
            end
        end
        
        function delete(obj)
            if ~isempty(obj.data)
                most.idioms.safeDeleteObj(obj.data.roiGroup);
            end
            most.idioms.safeDeleteObj(obj.hContrastSlider);
            most.idioms.safeDeleteObj(obj.hChannelSel);
            most.idioms.safeDeleteObj(obj.hFig);
            most.idioms.safeDeleteObj(obj.hLdPanel);
            most.idioms.safeDeleteObj(obj.hRenderTool);
            most.idioms.safeDeleteObj(obj.hCfgFig);
        end
    end
    
    %% USER FUNCTIONS
    methods
        function autoContrast(obj)
            if iscell(obj.zSurfs)
                px = arrayfun(@(sf){sf.CData(~isnan(sf.CData))},[obj.zSurfs{:}]);
                pixels = vertcat(px{:});
                
                if ~isempty(pixels)
                    pixels = sort(pixels);
                    N = numel(pixels);
                    iblk = ceil(N*obj.autoScaleSaturationFraction(1));
                    iwht = ceil(N*(1-obj.autoScaleSaturationFraction(2)));

                    obj.clim = round([pixels(iblk) pixels(iwht)]);
                end
            end
        end
        
        function loadData(obj,filename)
            if nargin > 1
                obj.fileName = filename;
            end
            [~,nm,~] = fileparts(obj.fileName);
            obj.hFig.Name = ['ScanImage Data View: ' nm];
            
            obj.hLdPanel.show();
            
            % read the files
            [header, imageData, imgInfo] = scanimage.util.opentif(filename,'raw','transpose',false);
            if isfield(header, 'scanimage')
                header.SI = header.scanimage.SI;
            end
            roiGroup = scanimage.util.readTiffRoiData(filename,header);
            
            % support for old free tifs
            if isempty(roiGroup)
                roiGroup = scanimage.mroi.RoiGroup;
                sf = scanimage.mroi.scanfield.fields.RotatedRectangle;
                sf.centerXY = mean(header.SI.hRoiManager.imagingFovDeg,1);
                sf.sizeXY = max(header.SI.hRoiManager.imagingFovDeg,[],1) - min(header.SI.hRoiManager.imagingFovDeg,[],1);
                roi = scanimage.mroi.Roi;
                roi.add(0,sf);
                roiGroup.add(roi);
            end
            
            % parse rois and cache axes limits
            xlims = [inf -inf];
            ylims = [inf -inf];
            
            dataZs = header.SI.hStackManager.zs;
            obj.zRois = {};
            
            for idx = numel(dataZs) : -1 : 1
                [df, ind] = min(abs(dataZs(idx)-roiGroup.zs));
                if df < 1e-4
                    dataZs(idx) = roiGroup.zs(ind);
                end
                
                [scanfields,rois] = roiGroup.scanFieldsAtZ(dataZs(idx));
                
                if ~isempty(scanfields)
                    obj.zRois{idx} = cellfun(@(sf,roi)struct('scanfield',sf,'roi',roi,'cornerPts',sf.cornerpoints(),'ref2PixT',inv(sf.pixelToRefTransform)),scanfields,rois);
                    
                    cp = vertcat(obj.zRois{idx}.cornerPts);
                    
                    xlims(1) = min([cp(:,1); xlims(1)]);
                    xlims(2) = max([cp(:,1); xlims(2)]);
                    ylims(1) = min([cp(:,2); ylims(1)]);
                    ylims(2) = max([cp(:,2); ylims(2)]);
                else
                    obj.zRois{idx} = struct('scanfield',{},'roi',{},'cornerPts',{},'ref2PixT',{});
                end
            end
            obj.zs = dataZs;
            
            framesPerSlice = header.SI.hStackManager.framesPerSlice / header.SI.hScan2D.logAverageFactor;
            obj.sfSkipLines = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod) * strcmp(header.SI.hScan2D.scannerType,'Resonant');
            
            obj.data = struct('header',header,'imageData',reshape(imageData,size(imageData,1),size(imageData,2),imgInfo.numChans,[]),'roiGroup',roiGroup,'imgInfo',imgInfo,'channels',header.SI.hChannels.channelSave);
            obj.delAllTimePts();
            obj.is3d = imgInfo.numSlices > 1;
            obj.hViewModeSel.Visible = obj.is3d;
            
%             obj.hChannelSel.choices = [arrayfun(@(i)sprintf('PMT Channel %d',i),obj.data.channels,'uniformoutput',false); {'Merge'}];
            obj.hChannelSel.choices = arrayfun(@(i)sprintf('PMT Channel %d',i),obj.data.channels,'uniformoutput',false);
            obj.hChannelSel.Visible = obj.tfMap(imgInfo.numChans > 1);
            
            % cache timestamp info
            if isfield(header,'FrameTimestamp_s')
                % support for legacy files
                obj.frameTs = header.FrameTimestamp_s(1:imgInfo.numChans:end);
            else
                obj.frameTs = header.frameTimestamps_sec(1:imgInfo.numChans:end);
            end
            obj.experimentT0 = min(obj.frameTs);
            obj.experimentTE = max(obj.frameTs);
            obj.experimentT = obj.experimentTE - obj.experimentT0;
            
            %% build a map of every z and when it gets updated
            tframeZs = repmat(obj.zs(:)',framesPerSlice,1);
            tframeZs = tframeZs(:)';
            tframeZs = tframeZs(mod((1:numel(obj.frameTs))-1,numel(tframeZs))+1);
            obj.zsTs = arrayfun(@(z){obj.frameTs(tframeZs==z)},obj.zs);
            obj.frameZs = tframeZs;
            
            %% apply axes limits
            obj.dataXLims = xlims;
            obj.dataYLims = ylims;
            obj.hFovAxes.XLim = mean(xlims) + .51*diff(xlims)*[-1 1];
            obj.hFovAxes.YLim = mean(ylims) + .51*diff(ylims)*[-1 1];
            obj.hFovAxes.ZLim = [min(obj.zs)-1 max(obj.zs)+1];
            
            obj.hZSliderLine.YData = [min(obj.zs) max(obj.zs)];
            obj.hZSliderHashes.XData = repmat([36 44 nan],1,numel(obj.zs));
            obj.hZSliderHashes.YData = reshape([repmat(obj.zs,2,1); nan(size(obj.zs))],1,[]);
            obj.resizeZSlider();
            
            %% delete old and create surfs
            if iscell(obj.zSurfs)
                delete([obj.zSurfs{:}]);
            end
            clls = arrayfun(@(zind){arrayfun(@(sf){createSurf(sf,zind)},[obj.zRois{zind}.scanfield])},1:numel(obj.zs));
            obj.zSurfs = cellfun(@(sfs){[sfs{:}]},clls);
            
            %% misc
            obj.hContrastSlider.max = double(max(obj.data.imageData(:)));
            obj.hContrastSlider.min = double(min(obj.data.imageData(:)));
            nc = header.SI.hChannels.channelLUT(header.SI.hChannels.channelSave);
            obj.pmtChannel = 1;
            obj.contrasts = nc;
            obj.clim = nc{1};
            
            obj.plotTsz = obj.experimentT;
            obj.plotTPos = obj.experimentT0 + .5 * obj.experimentT;
            obj.updatePlotAxes();
            obj.timePos = obj.frameTs(1);
            
            %% find the most interesting time point and plot it
            obj.delAllTimePts();
%             sqdat = squeeze(obj.data.pmtData(:,obj.pmtChannel,:));
%             mns = min(sqdat,[],2);
%             mxs = max(sqdat,[],2);
%             dffs = abs(mxs-mns);
%             [~, i] = max(dffs);
%             obj.addPlotPt(i/obj.scanPathN);
            
            obj.viewZ = obj.zs(1);
            obj.viewMode = '3D';
            obj.sliceSpacing = 1;
            obj.resetView();
            obj.hLdPanel.close();
            
            function surf = createSurf(sf,zind)
                cps = sf.cornerpoints();
                xx = [cps(1:2,1) cps([4 3],1)];
                yy = [cps(1:2,2) cps([4 3],2)];
                surf = surface(xx,yy,obj.zs(zind)*ones(2),'Parent',obj.hFovAxes,'linewidth',1,'FaceColor','texturemap','CData',nan(3),'EdgeColor','b','userdata',[]);
            end
        end
        
        function renderFrameSequence(obj,varargin)
            obj.pmtChannel = obj.pmtChannel;
            obj.hRenderTool.doDialog();
        end
        
        function viewSettings(obj,varargin)
            obj.hFig.Units = 'pixels';
            p = obj.hFig.Position;
            
            obj.hCfgFig.Units = 'pixels';
            mp = obj.hCfgFig.Position;
            mp = [(p([1 2]) + 0.5*(p([3 4]) - mp([3 4]))) mp([3 4])];
            obj.hCfgFig.Position = mp;
            figure(obj.hCfgFig);
        end
        
        function hideCfgFig(obj,varargin)
            obj.hCfgFig.Visible = 'off';
        end
        
        function addPlotPt(obj,pt)
            %% pick color
            clr = obj.pickMostUniquePltColor();
            obj.timeClrs(end+1) = clr;
            clr = obj.plotColors{clr};
            if isempty(obj.timePts)
                obj.timePts = pt;
            else
                obj.timePts(end+1) = pt;
            end
            
            %% fov pt
            fp = pt.point;
            
            if size(fp,1) < 2
                mrkr = '+';
                lw = 2;
                fovx = fp(1,1);
                fovy = fp(1,2);
                fovz = fp(1,3);
            else
                mrkr = 'none';
                lw = 1;
                fovx = repmat([fp(1,1) fp(1,1) fp(2,1) fp(2,1) fp(1,1)],1,2);
                fovy = repmat([fp(1,2) fp(2,2) fp(2,2) fp(1,2) fp(1,2)],1,2);
                fovz = [(fp(1,3)-.01)*ones(1,5) (fp(1,3)+.01)*ones(1,5)];
            end
            
            obj.hPlotFovPts(end+1) = patch('xdata',fovx,'ydata',fovy,'zdata',fovz,'Marker',mrkr,'MarkerSize',12,'EdgeColor',clr,'MarkerEdgeColor',clr,'LineWidth',lw,...
                'FaceColor',clr,'FaceAlpha',.4,'parent',obj.hFovAxes,'UIContextMenu',obj.hDelTimePtContextMenu,'UserData',pt);
            
            %% create plot
            [ts,vs] = obj.getPmtData(pt);
            obj.hPlotLines(end+1) = line('parent',obj.hPlotAxes,'color',clr,'linewidth',2,'xdata',ts,'ydata',vs,'zdata',ones(size(vs)),'UIContextMenu',obj.hDelTimePtContextMenu,'UserData',pt);
            
            obj.updateLegend();
        end
        
        function updatePlotLines(obj)
            if ~isempty(obj.hoverPt)
                [t,v] = obj.getPmtData(obj.hoverPt);
                obj.hHoverTimePlot.XData = t;
                obj.hHoverTimePlot.YData = v;
            end
            
            for i=1:numel(obj.timePts)
                [t,v] = obj.getPmtData(obj.timePts(i));
                obj.hPlotLines(i).XData = t;
                obj.hPlotLines(i).YData = v;
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
        
        function delAllTimePts(obj,varargin)
            most.idioms.safeDeleteObj(obj.hPlotLines);
            most.idioms.safeDeleteObj(obj.hPlotFovPts);
            obj.hPlotLines = matlab.graphics.primitive.Line.empty;
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
                most.idioms.safeDeleteObj(obj.hPlotFovPts(id));
                obj.hPlotLines(id) = [];
                obj.hPlotFovPts(id) = [];
                
                obj.timePts(id) = [];
                obj.timeClrs(id) = [];
            end
            
            obj.updateLegend();
        end
        
        function timestamps = getRoiTimeStamps(obj,frames)
            
            if nargin > 1 && all(frames == inf)
                frames = 1:numel(obj.frameTs);
            elseif nargin < 2
                mTs = obj.frameTs;
                [~,frames] = max(mTs(mTs <= obj.timePos));
            end
            
            N = numel(frames);
            if N > 1
                timestamps = arrayfun(@getRoiTimeStampsForFrame,frames,'uniformoutput',false);
            elseif N
                timestamps = getRoiTimeStampsForFrame(frames);
            else
                timestamps = [];
            end
            
            function ts = getRoiTimeStampsForFrame(frameInd)
                ts = 0;
            end
        end
    end
    
    %% INTERNAL
    methods (Hidden)
        function scrollWheelFcn(obj,~,evt)
            mod = get(obj.hFig, 'currentModifier');
            
            if ismember('shift',mod) || mouseIsInAxes(obj.hTimeAxes)
                cTs = obj.frameTs;
                obj.timePos = cTs(min(max(find(max(cTs(cTs <= obj.timePos)) == cTs) + sign(evt.VerticalScrollCount),1),numel(cTs)));
            elseif strcmp(obj.zFlow.Visible,'on') && mouseIsInAxes(obj.hZSelAxes) || (ismember('control',mod) && mouseIsInAxes(obj.hFovMouseFindAxes));
                obj.viewZ = obj.zs(min(max(find(obj.viewZ == obj.zs) + sign(evt.VerticalScrollCount),1),numel(obj.zs)));
            elseif mouseIsInAxes(obj.hFovMouseFindAxes)
                ppt = axPt(obj.hFovAxes);
                oAngle = obj.hFovAxes.CameraViewAngle;
                obj.hFovAxes.CameraViewAngle = oAngle * 1.1^double(-evt.VerticalScrollCount);
                
                if ~obj.is3dView
                    % maintain point under mouse
                    dp = axPt(obj.hFovAxes) - ppt;
                    camdolly(obj.hFovAxes,-dp(1),-dp(2),0,'movetarget','data');
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
        
        function buttonDownFcn(obj,~,~)
            if obj.hFig.CurrentObject == obj.hRenderButton.hPnl
                return
            end
            
            obj.mouseClickMv = false;
            obj.mouseClickMode = 'none';
            
            if ismember(obj.hFig.SelectionType, {'normal' 'extend'})
                if mouseIsInAxes(obj.hFovMouseFindAxes)
                    obj.mouseClickMode = 'pathClick';
                    obj.mouseClickPt = obj.pixPt();
                    if ~strcmp(obj.hFig.SelectionType,'extend')
                        obj.hoverPt = obj.findMousePathPt();
                    else
                        obj.hoverPt = [];
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
                        if isempty(obj.hoverPt)
                            % click and drag on empty space. pan view
                            obj.hFovAxes.CameraViewAngleMode = 'manual';
                            pt = obj.pixPt();
                            deltaPix = pt - obj.mouseClickPt;
                            obj.mouseClickPt = obj.pixPt();
                            
                            if obj.is3dView && strcmp(obj.hFig.SelectionType,'extend')
                                camorbit(obj.hFovAxes,deltaPix(1),-deltaPix(2),'data',[0 0 1])
                            else
                                camdolly(obj.hFovAxes,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
                            end
                        else
                            % click and drag on roi
                            obj.hoverPt = obj.findMousePathPt(obj.hoverPt);
                        end
                        
                        
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
                    
                    p = (ap(1) - tvp.horzNormPos(1)) * tvp.rgscl;
                    if (p >= 0) && (p <= 1)
                        obj.timeHoverPt = p*obj.experimentTE;
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
                    obj.timeHoverPt = ap(1);
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
                case 'pathClick'
                    if ~isempty(obj.hoverPt)
                        obj.addPlotPt(obj.hoverPt);
                        obj.hoverPt = [];
                    end
            end
            
            obj.resetMouseState();
        end
        
        function resetMouseState(obj)
            obj.mouseDownTf = false;
            obj.mouseClickMode = 'none';
        end
        
        function pt = findMousePathPt(obj,pt)
            cp = obj.hFovAxes.CurrentPoint;
            
            if nargin > 1
                pt.point(2,3) = pt.point(1,3);
                pt.point(2,1:2) = getPlnPt(cp,pt.point(1,3));
                pt.point(2,1:2) = [max(min(pt.point(2,1), max(pt.sfcp(:,1))), min(pt.sfcp(:,1))) max(min(pt.point(2,2), max(pt.sfcp(:,2))), min(pt.sfcp(:,2)))];
                
                pt.px(2,:) = max(floor(scanimage.mroi.util.xformPoints(pt.point(2,1:2),obj.zRois{pt.zind}(pt.roiZIdx).ref2PixT)),1);
                pt.px(2,:) = [min(pt.px(2,1), pt.sfres(1)) min(pt.px(2,2), pt.sfres(2))];
            else
                if obj.is3dView
                    zinds = 1:numel(obj.zs);
                    if cp(1,3) > cp(2,3)
                        zinds = fliplr(zinds);
                    end
                else
                    zinds = find(obj.zs == obj.viewZ);
                end
                
                for zi = zinds
                    z = obj.zs(zi);
                    pp = getPlnPt(cp,z);
                    
                    for roiIdx = 1:numel(obj.zRois{zi})
                        r = obj.zRois{zi}(roiIdx);
                        res = r.scanfield.pixelResolutionXY;
                        
                        px = scanimage.mroi.util.xformPoints(pp,r.ref2PixT);
                        if all(px>.5) && all(px < (res + .5))
                            pt = struct('zind',zi,'point',[pp z],'roiZIdx',roiIdx,'roiId',find(r.roi == obj.data.roiGroup.rois),'px',round(px),'sfres',res,'sfcp',r.cornerPts);
                            return;
                        end
                    end
                end
                
                pt = [];
            end
            
            function p = getPlnPt(cp,z)
                p = [interp1(cp(:,3),cp(:,1),z,'linear','extrap') interp1(cp(:,3),cp(:,2),z,'linear','extrap')];
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
                obj.timePos = (obj.hTimeAxes.CurrentPoint(1)*scl - offs)*obj.experimentT+obj.experimentT0;
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.dragTimeCar,'WindowButtonUpFcn',@obj.dragTimeCar);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                obj.timePos = (obj.hTimeAxes.CurrentPoint(1)*scl - offs)*obj.experimentT+obj.experimentT0;
            else
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
            end
            
            obj.resetMouseState();
        end
        
        function hitZSlider(obj,~,evt)
            persistent prevWindowButtonMotionFcn
            persistent prevWindowButtonUpFcn
            
            obj.viewZ = obj.hZSelAxes.CurrentPoint(1,2);
            
            if strcmp(evt.EventName, 'Hit') && (evt.Button == 1)
                prevWindowButtonMotionFcn = obj.hFig.WindowButtonMotionFcn;
                prevWindowButtonUpFcn = obj.hFig.WindowButtonUpFcn;
                set(obj.hFig,'WindowButtonMotionFcn',@obj.hitZSlider,'WindowButtonUpFcn',@obj.hitZSlider);
            elseif strcmp(evt.EventName, 'WindowMouseRelease')
                set(obj.hFig,'WindowButtonMotionFcn',prevWindowButtonMotionFcn,'WindowButtonUpFcn',prevWindowButtonUpFcn);
            end
        end
        
        function resize(obj,~,~)
            obj.hFig.Units = 'pixels';
            ps = obj.hFig.Position;
            sz = ps([3 4]);
            
            marg = 8;
            
            plotSize = .4;
            
            timeAPos = [marg marg (sz(1) - marg*2) obj.sliderCarR*2];
            plotAPos = [marg (marg*2+timeAPos(4)) (sz(1)*plotSize) (sz(2)-marg*3-timeAPos(4))];
            fovAPos = [(marg*2+plotAPos(3)) (marg*2+timeAPos(4)) (sz(1)-marg*3-plotAPos(3)) plotAPos(4)];
            
            obj.hFovFlow.Units = 'pixels';
            obj.hFovFlow.Position = fovAPos;
            obj.hTimeAxes.Units = 'pixels';
            obj.hTimeAxes.Position = timeAPos;
            
            obj.hRenderButton.Units = 'pixels';
            obj.hRenderButton.Position = [fovAPos(1) fovAPos(2)+fovAPos(4)-29 240 30];
            
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
            
            obj.resizeZSlider();
            
            %% time section
            % adjust vertical position of line to keep it correct number of pixels from bottom
            vertPixPos = obj.sliderCarR;
            vertNormPos = vertPixPos/timeAPos(4);
            obj.hTimeSliderLine.YData = vertNormPos*ones(1,2);
            
            % cache some numbers
            extra = (obj.sliderCarR + obj.sliderEdgeMarg)/timeAPos(3);
            tvp.horzNormPos = [extra (1-extra)];
            tvp.scl = 1./timeAPos([3 4]);
            tvp.rg = diff(tvp.horzNormPos);
            tvp.rgscl = 1./tvp.rg;
            obj.timeViewParams = tvp;
            
            obj.drawTimeCar();
        end
        
        function resizeZSlider(obj)
            drawnow
            obj.hZSelAxes.Units = 'normalized';
            obj.hZSelAxes.Position = [0 0 1 1];
            obj.hZSelAxes.Units = 'pixels';
            ap = obj.hZSelAxes.Position;
            obj.hZSelAxes.Units = 'normalized';
            
            z = obj.zs;
            if numel(z) > 1
                lims = [min(z) max(z)];
                dl = diff(lims);
                obj.hZSelAxes.YLim = lims + (dl*ap/(ap-32) - dl) * [-.5 .5];
            elseif numel(z) == 1
                obj.hZSelAxes.YLim = z + [-1 1];
            end
            
            ozt = obj.zticks;
            zt = obj.hZSelAxes.YTick;
            if (numel(zt) ~= numel(ozt)) || any(ozt ~= zt)
                Nt = numel(zt);
                for i = 1:Nt
                    if i > numel(obj.hZSliderTexts)
                        obj.hZSliderTexts(i) = text(50,nan,'','parent',obj.hZSelAxes,'FontSize',12,'FontWeight','bold','Color','w');
                    end
                    obj.hZSliderTexts(i).String = num2str(zt(i));
                    obj.hZSliderTexts(i).Position(2) = zt(i);
                end
                set(obj.hZSliderTexts(1:Nt),'Visible','on');
                set(obj.hZSliderTexts(Nt+1:end),'Visible','off');
                obj.zticks = zt;
            end
        end
        
        function drawTimeCar(obj)
            xs = obj.sliderCarR*cosd(0:10:360);
            ys = obj.sliderCarR*sind(0:10:360) + obj.sliderCarR;
            
            tvp = obj.timeViewParams;
            x = tvp.horzNormPos(1) + (obj.timePos - obj.experimentT0)*tvp.rg/obj.experimentT;
            
            obj.hTimeSliderCar.XData = xs*tvp.scl(1) + x;
            obj.hTimeSliderCar.YData = ys*tvp.scl(2);
            obj.hPlotTimeLine.XData = obj.timePos*ones(1,2);
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
            obj.delTimePltById(find(cellfun(@(p)(numel(p)==numel(pt.point))&&all(all(p==pt.point)),{obj.timePts.point})));
        end
        
        function [ts,vs] = getPmtData(obj,pt)
            % determine frame inds
            ts = obj.zsTs{pt.zind};
            [~,frameInds] = ismember(ts, obj.frameTs);
            
            % determine roi offset y coords
            rb = 1;
            yOffs = 0;
            while rb < pt.roiZIdx
                res = obj.zRois{pt.zind}(rb).scanfield.pixelResolutionXY;
                yOffs = yOffs + obj.sfSkipLines + res(2);
                rb = rb + 1;
            end
            
            mnx = min(pt.px(:,1));
            mxx = max(pt.px(:,1));
            mny = yOffs+min(pt.px(:,2));
            mxy = yOffs+max(pt.px(:,2));
            
            vs = obj.data.imageData(mnx:mxx,mny:mxy,obj.pmtChannel,frameInds);
            vs = squeeze(mean(mean(vs,1),2));
            
            vs(vs > obj.clim(2)) = obj.clim(2);
            vs(vs < obj.clim(1)) = obj.clim(1);
        end
        
        function updatePlotAxes(obj)
            obj.hPlotAxes.Units = 'pixels';
            plotAPos = obj.hPlotAxes.Position;
            xl = obj.plotTPos + obj.plotTsz*[-.5 .5];
            scl = diff(xl)/plotAPos(3);
            
            if obj.plotTsz > 0
                obj.hPlotAxes.XLim = xl;
            end
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
                obj.hTimePlotCarL.XData = obj.hTimePlotCar.XData(1,1);
                obj.hTimePlotCarH.XData = obj.hTimePlotCar.XData(1,2);
            else
                obj.hTimePlotCar.Visible = 'off';
                obj.hTimePlotCarL.Visible = 'off';
                obj.hTimePlotCarH.Visible = 'off';
            end
        end
        
        function toggleLegend(obj,varargin)
            obj.showPlotLegend = ~obj.showPlotLegend;
        end
        
        function labels = getPlotNames(obj,includehover)
            N = numel(obj.hPlotLines);
            labels = cell(1,N);
            for i = 1:N
                labels{i} = pltnm(obj.timePts(i));
            end
            if includehover && ~isempty(obj.hoverPt)
                labels = [labels {pltnm(obj.hoverPt)}];
            end
            
            function str = pltnm(pt)
                if numel(pt.px) > 2
                    px = sort(pt.px(:,1));
                    py = sort(pt.px(:,2));
                    str = sprintf('%d:%d,%d:%d',px(1),px(2),py(1),py(2));
                else
                    str = sprintf('%d,%d',pt.px(1),pt.px(2));
                end
                str = sprintf('Roi: %d, Z=%s, Px:(%s)',pt.roiId,num2str(pt.point(1,3)),str);
            end
        end
        
        function updateLegend(obj,varargin)
            N = numel(obj.hPlotLines);
            if obj.showPlotLegend && (N || strcmp(obj.hHoverTimePlot.Visible,'on'))
                if isempty(obj.hoverPt)
                    hs = obj.hPlotLines;
                else
                    hs = [obj.hPlotLines obj.hHoverTimePlot];
                end
                
                obj.hLegend = legend(hs, obj.getPlotNames(true), 'TextColor', 'w', 'FontSize', 12, 'EdgeColor', 'w', 'LineWidth', .5);
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
                
                legend(lines,obj.getPlotNames(false));
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
        
        function resetView(obj,varargin)
            obj.hFovAxes.CameraViewAngleMode = 'auto';
            if obj.is3dView
                view(obj.hFovAxes,-135,-45);
                camup(obj.hFovAxes,[0,0,-1]);
            else
                view(obj.hFovAxes,0,-90);
            end
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
        
        function frame = getFrame(obj,zind,t,ch)
            frameIdx = t == obj.frameTs;
            rois = obj.zRois{zind};
            
            rline = 1;
            for r = 1:numel(rois)
                res = rois(r).scanfield.pixelResolutionXY;
                frame.roiData(r).imageData = obj.data.imageData(1:res(1),rline:rline+res(2)-1,ch,frameIdx);
                rline = rline + res(2) + obj.sfSkipLines;
            end
        end
        
        function updateAxesToT(obj,lzSurfs,it,ch)
            if nargin < 4
                ch = obj.pmtChannel;
            end
            
            for zind = 1:numel(obj.zs)
                zTs = obj.zsTs{zind};
                t = max(zTs(zTs <= it));
                
                if isempty(t) && ~isempty(lzSurfs{zind}(1).UserData)
                    set(obj.zSurfs{zind},'CData',nan,'UserData',[],'AlphaData',nan);
                elseif ~isempty(t) && (isempty(lzSurfs{zind}(1).UserData) || (lzSurfs{zind}(1).UserData(1) ~= t) || (lzSurfs{zind}(1).UserData(2) ~= ch))
                    frame = obj.getFrame(zind,t,ch);
                    for ir = 1:numel(frame.roiData)
                        d = frame.roiData(ir).imageData(:,:);
                        lzSurfs{zind}(ir).CData = d;
                        lzSurfs{zind}(ir).AlphaData = d;
                    end
                    set(lzSurfs{zind},'UserData',[t obj.pmtChannel]);
                end
            end
        end
    end
    
    %% PROP ACCESS
    methods
        function set.timePos(obj,v)
            obj.timePos = max(min(v,obj.experimentTE),obj.experimentT0);
            obj.drawTimeCar();
            
            obj.updateAxesToT(obj.zSurfs,obj.timePos,obj.pmtChannel)
            
            if obj.lockLastZ
                [~,i] = max(obj.frameTs(obj.frameTs <= obj.timePos));
                if ~isempty(i)
                    obj.viewZ = obj.frameZs(i);
                end
            end
        end
        
        function set.lockLastZ(obj,v)
            obj.lockLastZ = v;
            
            if v
                [~,i] = max(obj.frameTs(obj.frameTs <= obj.timePos));
                obj.viewZ = obj.frameZs(i);
            end
        end
        
        function set.viewZ(obj,v)
            [~,i] = min(abs(obj.zs-v));
            
            obj.viewZ = obj.zs(i);
            
            obj.hZSliderCar.YData = obj.viewZ;
            
            set([obj.zSurfs{:}],'Visible',obj.tfMap(obj.is3dView));
            set(obj.hPlotFovPts,'Visible',obj.tfMap(obj.is3dView));
            if ~obj.is3dView
                set([obj.zSurfs{obj.zs == obj.viewZ}],'Visible','on');
                if ~isempty(obj.timePts)
                    set(obj.hPlotFovPts([obj.timePts.zind] == i),'Visible','on');
                end
            end
        end
        
        function set.viewMode(obj,v)
            if obj.is3d
                obj.viewMode = v;
            else
                obj.viewMode = '2D';
            end
            
            obj.is3dView = strcmp(obj.viewMode, '3D');
            obj.zFlow.Visible = obj.tfMap((~obj.is3dView) && obj.is3d);
            obj.enableTransparency = obj.enableTransparency;
            obj.resetView();
            
            obj.viewZ = obj.viewZ;
            
            i = 1 + obj.is3dView;
            if obj.viewModeCh ~= i
                obj.viewModeCh = i;
            end
        end
        
        function set.clim(obj,v)
            v(1) = min(v(1),v(2)-1);
            obj.clim = v;
            
            obj.hPlotAxes.YLim = v;
            obj.hPlotTimeLine.YData = v;
            obj.hTimeAxes.CLim = v;
            obj.hFovAxes.CLim = v;
            obj.hFovAxes.ALim = [v(1) mean(v)];
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
            obj.plotTPos = max(min(val,obj.experimentTE - marg),obj.experimentT0 + marg);
        end
        
        function set.pmtChannel(obj,v)
            obj.contrasts{obj.pmtChannel} = obj.clim;
            
            obj.pmtChannel = v;
            
            obj.clim = obj.contrasts{obj.pmtChannel};
            obj.timePos = obj.timePos;
        end
        
        function set.timeHoverPt(obj,v)
            if isempty(v)
                obj.hPlotTimeHoverLine.Visible = 'off';
                obj.hPlotHValHovText.Visible = 'off';
            else
                tvp = obj.timeViewParams;
                obj.hPlotTimeHoverLine.XData = v*ones(1,2);
                obj.hPlotHValHovText.String = sprintf('%.3f', v*obj.timeExponent);
                obj.hPlotHValHovText.Position(1) = v;
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
            obj.hoverPt = v;
            
            set([obj.hPathHoverPt obj.hHoverTimePlot], 'Visible', obj.tfMap(~isempty(v)));
            if ~isempty(v)
                cp = obj.hFovAxes.CurrentPoint;
                if cp(1,3) > cp(2,3)
                    ad = .01;
                else
                    ad = -.01;
                end
                
                fp = v.point;
                
                if size(fp,1) < 2
                    obj.hPathHoverPt.Marker = '+';
                    obj.hPathHoverPt.XData = fp(1,1);
                    obj.hPathHoverPt.YData = fp(1,2);
                    obj.hPathHoverPt.ZData = fp(1,3)+ad;
                else
                    obj.hPathHoverPt.Marker = 'none';
                    obj.hPathHoverPt.XData = [fp(1,1) fp(1,1) fp(2,1) fp(2,1) fp(1,1)];
                    obj.hPathHoverPt.YData = [fp(1,2) fp(2,2) fp(2,2) fp(1,2) fp(1,2)];
                    obj.hPathHoverPt.ZData = fp(1,3)+ad*ones(1,5);
                end
                
                % create plot
                [ts,vs] = obj.getPmtData(v);
                
                obj.hHoverTimePlot.XData = ts;
                obj.hHoverTimePlot.YData = vs;
            end
            
            obj.updateLegend();
        end
        
        function set.showPlotLegend(obj,v)
            obj.showPlotLegend = v;
            obj.hLgndMnu.Checked = obj.tfMap(v);
            obj.updateLegend();
        end
        
        function set.viewModeCh(obj,v)
            switch v
                case 1
                    md = '2D';
                
                case 2
                    md = '3D';
            end
            
            obj.viewModeCh = v;
            obj.viewMode = md;
        end
        
        function set.showSfBorders(obj,v)
            obj.showSfBorders = v;
            if v
                c = 'b';
            else
                c = 'none';
            end
            set([obj.zSurfs{:}],'EdgeColor',c);
        end
        
        function set.enableTransparency(obj,v)
            obj.enableTransparency = v;
            if v && obj.is3dView
                a = 'texturemap';
            else
                a = 1;
            end
            
            set([obj.zSurfs{:}],'FaceAlpha',a);
        end
        
        function set.sliceSpacing(obj,v)
            v = max(0.001,v);
            obj.sliceSpacing = v;
            obj.hFovAxes.DataAspectRatio = [1 1 15/v];
            if obj.is3dView
                obj.resetView();
            end
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
% FrameScanDataView.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
