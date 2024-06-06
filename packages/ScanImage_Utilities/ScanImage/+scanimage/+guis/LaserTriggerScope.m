classdef LaserTriggerScope < most.Gui
    properties (SetObservable)
        updateRate = 10;
        traceLength = 1000;        
        active = false;
        channel = 1;
        
        laserTriggerFilter = 1;
        enableSampleMask = false;
        samplingWindow = [0 1];
    end
    
    properties (Hidden)
        hSI;
        hAxes;
        hDigAxes;
        
        hISLis;
        hFpga;
        hDataScope;
        hFifo;
        
        pbStart;
        hChanPop;
        
        hPLLine;
        hSLLine;
        hAnLine;
        hRawLLine;
        hFiltLLine;
        hMaskSurf;
        hMaskDLine;
        hMaskLLine;
        hMaskArrL;
        hMaskArrH;
        hMaskSurf2;
        hMaskDLine2;
        hMaskLLine2;
        scaleHistory;
    end
    
    properties (Hidden, SetObservable)
        triggerRate = '';
        triggerNominalPeriodTicks = [];
        triggerNominalPeriodTicksStr = ''
        wndDelay = 0;
        wndWidth = 1;
        chanStr = '';
        ylim = [-100 1000];
    end
    
    %% LifeCycle
    methods
        function obj = LaserTriggerScope(hSI,~)
            if nargin < 1
                try
                    obj.hSI = evalin('base','hSI');
                catch
                    error('ScanImage must be running.');
                end
            else
                obj.hSI = hSI;
            end
            
            assert(most.idioms.isValidObj(obj.hSI),'Could not find valid handle to ScanImage.');
            
            obj.hFig.Name = 'Laser Trigger Scope';
            obj.hFig.CloseRequestFcn = @obj.figCloseRequestFcn;
            
            myl = mean(obj.ylim);
            
            f = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight','margin',0.00001);
                pf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','TopDown','margin',0.00001);
                    obj.hDigAxes = axes('Parent',pf,'Box','on','XGrid','on','XMinorGrid','on','ylim',[-.25 1.25],'ytick',[0 1],'YTickLabel',{'L' 'H'},'XTickLabel',[]);
                        set(obj.hDigAxes,'HeightLimits',80*ones(1,2));
                        obj.hRawLLine = line('parent',obj.hDigAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','b','Linewidth',.5,'visible','off');
                        obj.hFiltLLine = line('parent',obj.hDigAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',1,'visible','off');
                        title(obj.hDigAxes,'Laser Trigger');
                    obj.hAxes = axes('Parent',pf,'Box','on','XGrid','on','YGrid','on','XMinorGrid','on','ylim',obj.ylim);
                        obj.hPLLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','r','Linewidth',2);
                        obj.hSLLine = line('parent',obj.hAxes,'xdata',[0 0 nan 0 0],'ydata',[obj.ylim nan obj.ylim],'Color','r','Linewidth',2,'LineStyle','--');
                        obj.hAnLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',1,'marker','.','visible','off','markersize',10);
                        obj.hMaskSurf = surface('parent',obj.hAxes,'xdata',[0 1; 0 1],'ydata',[obj.ylim; obj.ylim]','zdata',zeros(2),'FaceColor','g','Facealpha',.3,'linestyle','none','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskDLine = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',1,'LineStyle','--','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskLLine = line('parent',obj.hAxes,'xdata',[1 1],'ydata',obj.ylim,'Color','k','Linewidth',1,'LineStyle','--','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskSurf2 = surface('parent',obj.hAxes,'xdata',[0 1; 0 1],'ydata',[obj.ylim; obj.ylim]','zdata',zeros(2),'FaceColor','g','Facealpha',.2,'linestyle','none','visible','off','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskDLine2 = line('parent',obj.hAxes,'xdata',[0 0],'ydata',obj.ylim,'Color','k','Linewidth',.5,'LineStyle','--','visible','off','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskLLine2 = line('parent',obj.hAxes,'xdata',[1 1],'ydata',obj.ylim,'Color','k','Linewidth',.5,'LineStyle','--','visible','off','ButtonDownFcn',@obj.wndHit);
                        obj.hMaskArrL = line('parent',obj.hAxes,'xdata',nan(1,5),'ydata',myl * [1 1 nan 1 1],'Color','k','Linewidth',1,'Marker','.','markersize',16);
                        obj.hMaskArrH = line('parent',obj.hAxes,'xdata',nan(1,3),'ydata',myl * [1 nan 1],'Color','k','Linewidth',1,'Marker','>','markersize',6,'MarkerFaceColor','w','ButtonDownFcn',@obj.wndHit);
                        title(obj.hAxes,'PMT Signal');
                        xlabel(obj.hAxes, 'Sample Number/Time (Ticks)');
                lf = most.gui.uiflowcontainer('Parent',f,'FlowDirection','TopDown','WidthLimits',120);
                    up = most.gui.uipanel('parent',lf,'title','Laser Trigger','HeightLimits',142);
                        ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown');
                            most.gui.staticText('parent',ifl,'HorizontalAlignment','left','VerticalAlignment','bottom','string','Trigger Filter (Tick):','HeightLimits',14);
                            most.gui.uicontrol('parent',ifl,'style','edit','Bindings',{obj 'laserTriggerFilter' 'value'}, 'HeightLimits',22,'KeyPressFcn',@obj.keyFunc);
                            most.gui.staticText('parent',ifl,'HorizontalAlignment','left','VerticalAlignment','bottom','string','Detected Freq:','HeightLimits',14);
                            most.gui.uicontrol('parent',ifl,'style','edit', 'HeightLimits',22,'Bindings',{obj 'triggerRate' 'string'},'BackgroundColor',.95*ones(1,3),'enable','inactive');
                            most.gui.staticText('parent',ifl,'HorizontalAlignment','left','VerticalAlignment','bottom','string','Detected Period','HeightLimits',14);
                            most.gui.uicontrol('parent',ifl,'style','edit','Bindings',{obj 'triggerNominalPeriodTicksStr' 'string'}, 'HeightLimits',22,'BackgroundColor',.95*ones(1,3),'enable','inactive');
                    up = most.gui.uipanel('parent',lf,'title','Sample Masking','HeightLimits',90);
                        ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown','margin',0.00001);
                            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
                                most.gui.uicontrol('parent',rf,'style','checkbox','Bindings',{obj 'enableSampleMask' 'value'},'String','Enable Mask');
                            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
                                most.gui.staticText('parent',rf,'HorizontalAlignment','left','string','Delay (Tick):','WidthLimits',64);
                                most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'wndDelay' 'value'},'KeyPressFcn',@obj.keyFunc);
                            rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
                                most.gui.staticText('parent',rf,'HorizontalAlignment','left','string','Width (Tick):','WidthLimits',64);
                                most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'wndWidth' 'value'},'KeyPressFcn',@obj.keyFunc);
                    most.gui.uicontrol('Parent',lf,'string','Save Settings','callback',@obj.saveSettings,'HeightLimits',24);
                    lfb = most.gui.uiflowcontainer('Parent',lf,'FlowDirection','BottomUp','margin',0.00001);
                        up = most.gui.uipanel('parent',lfb,'title','Scope Capture','HeightLimits',100);
                            ifl = most.gui.uiflowcontainer('Parent',up,'FlowDirection','TopDown','margin',0.00001);
                                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
                                    most.gui.staticText('parent',rf,'HorizontalAlignment','left','VerticalAlignment','middle','string','Channel:','WidthLimits',64);
                                    obj.hChanPop = most.gui.popupMenuEdit('parent',rf,'choices',{'1' '2' '3' '4'},'Bindings',{obj 'chanStr' 'string'},'showEdit',false);
                                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',24);
                                    most.gui.staticText('parent',rf,'HorizontalAlignment','left','string','Capture N:','WidthLimits',64);
                                    most.gui.uicontrol('parent',rf,'style','edit','Bindings',{obj 'traceLength' 'value'});
                                rf = most.gui.uiflowcontainer('Parent',ifl,'FlowDirection','LeftToRight','HeightLimits',28);
                                    obj.pbStart = most.gui.uicontrol('parent',rf,'style','togglebutton','string','Start Scope','Bindings',{obj 'active' 'callback' @obj.actvChanged},'callback',@obj.pbStartCb);
                
            obj.hISLis = obj.hSI.addlistener('imagingSystem','PostSet',@obj.setImgSys);
            obj.setImgSys();
            
            obj.triggerNominalPeriodTicks = 16;
            obj.triggerNominalPeriodTicks = [];
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hISLis);
        end
    end
    
    methods
        function start(obj)
            obj.stop(); % reset sampler system on FPGA
            if most.idioms.isValidObj(obj.hDataScope)
                obj.scaleHistory = [];
                obj.channel = obj.channel;
                obj.traceLength = obj.traceLength;
                obj.active = true;
                obj.hDataScope.callbackFcn = @obj.readSamples;
                obj.hDataScope.startContinuousAcquisition();
            end
        end
        
        function stop(obj)
            obj.active = false;
            if most.idioms.isValidObj(obj.hSI.hScan2D.hDataScope)
                obj.hSI.hScan2D.hDataScope.abort();
            end
        end
        
        function loadConfig(obj,varargin)
            if nargin ~= 2
                [filename,pathname] = uigetfile('.mat','Choose filename to save channel settings to','channelSettings.mat');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            else
                filename = varargin{1};
            end
            
            cs = load(filename);
            obj.loadStruct(cs);
        end
        
        function saveSettings(obj,varargin)
            mdf = most.MachineDataFile.getInstance();
            if mdf.isLoaded
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerSampleMaskEnable',obj.enableSampleMask);
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerSampleWindow',obj.samplingWindow);
				mdf.writeVarToHeading(obj.hSI.hScan2D.custMdfHeading,'LaserTriggerFilterTicks',obj.laserTriggerFilter);
            end
        end
    end
    
    methods (Hidden)
        function keyFunc(~,src,evt)
            switch evt.Key
                case 'uparrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = n + 1;
                        src.Callback(src);
                    end
                case 'downarrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        src.String = max(0,n-1);
                        src.Callback(src);
                    end
            end
        end
        
        function readSamples(obj,~,data)
            if ~most.idioms.isValidObj(obj.hDataScope)
                return;
            end
            
            %% parse data
            analogData = single(data.data);
            
            rawlaser = logical(data.triggers.LaserTriggerRaw);
            filteredlaser = logical(data.triggers.LaserTrigger);
            
            %% find laser rising edges
            reInds = find(filteredlaser(2:end) .* ~filteredlaser(1:end-1)) + 1;
            if numel(reInds) < 5
                obj.triggerRate = 'Not detected';
                obj.triggerNominalPeriodTicks = [];
                obj.hAnLine.Visible = 'off';
                obj.hRawLLine.Visible = 'off';
                obj.hFiltLLine.Visible = 'off';
            else
                periods = reInds(2:end) - reInds(1:end-1);
                f = mean(single(periods));
                obj.triggerRate = sprintf('%.3f MHz',obj.hDataScope.digitizerSampleRate*1e-6/f);
                p = round(f);
                obj.triggerNominalPeriodTicks = p;
                
                N = numel(reInds)-4;
                analogTraces = nan((p+2)*2+2,N);
                rawLaserTraces = nan((p+2)*2+2,N);
                filtLaserTraces = nan((p+2)*2+2,N);
                
                for ind = 1:N
                    reind = reInds(ind+2);
                    if reind > (p+3) && reind < (length(analogData) - p - 1)
                        ad = analogData(reind-p-2:reind+p+2);
                        analogTraces(1:end-1,ind) = ad;
                        rawLaserTraces(1:end-1,ind) = rawlaser(reind-p-2:reind+p+2);
                        filtLaserTraces(1:end-1,ind) = filteredlaser(reind-p-2:reind+p+2);
                    end
                end
                
                xdat = repmat([(-p-2):(p+2) nan]',N,1);
                
                rg = [min(analogTraces(:)) max(analogTraces(:))];
                dr = diff(rg);
                lims = mean(rg) + .55*dr*[-1 1];
                obj.scaleHistory = [lims; obj.scaleHistory];
                obj.scaleHistory(31:end,:) = [];
                nwlms = [min(obj.scaleHistory(:,1)) max(obj.scaleHistory(:,2))];
                olims = obj.ylim;
                dff = (nwlms - olims) .* [1 -1];
                d = min(dff,dff*.2) .* [1 -1];
                obj.ylim = olims + d;
                
                obj.hAnLine.Visible = 'on';
                obj.hAnLine.YData = analogTraces(:);
                obj.hAnLine.XData = xdat;
                
                obj.hRawLLine.Visible = 'on';
                obj.hRawLLine.YData = rawLaserTraces(:);
                obj.hRawLLine.XData = xdat;
                
                obj.hFiltLLine.Visible = 'on';
                obj.hFiltLLine.YData = filtLaserTraces(:);
                obj.hFiltLLine.XData = xdat;
            end
        end
        
        function figCloseRequestFcn(obj,src,~)
            src.Visible = 'off';
            obj.stop();
        end
        
        function wndHit(obj,src,evt)
            persistent inds
            persistent op
            persistent ov
            if strcmp(evt.EventName, 'Hit')
                if any(src == [obj.hMaskSurf obj.hMaskDLine obj.hMaskArrH obj.hMaskSurf2 obj.hMaskDLine2])
                    inds = 1;
                else
                    inds = 2;
                end
                op = obj.hAxes.CurrentPoint(1);
                ov = obj.samplingWindow(inds);
                set(obj.hFig,'WindowButtonMotionFcn',@obj.wndHit,'WindowButtonUpFcn',@obj.wndHit);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                obj.samplingWindow(inds) = ov + round(obj.hAxes.CurrentPoint(1) - op);
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function updateWindowDisp(obj)
            obj.hMaskSurf.XData = repmat(obj.wndDelay + [0 obj.wndWidth],2,1);
            obj.hMaskDLine.XData = repmat(obj.wndDelay,1,2);
            obj.hMaskLLine.XData = repmat(obj.wndDelay + obj.wndWidth,1,2);
            obj.hMaskArrL.XData(1:2) = [0 obj.wndDelay];
            obj.hMaskArrH.XData(1) = obj.wndDelay;
            set([obj.hMaskArrL obj.hMaskArrH], 'Visible', obj.tfMap(logical(obj.wndDelay)));
            if isempty(obj.triggerNominalPeriodTicks)
                set([obj.hMaskSurf2 obj.hMaskDLine2 obj.hMaskLLine2], 'Visible', 'off');
                obj.hMaskArrL.XData(4:5) = nan;
                obj.hMaskArrH.XData(3) = nan;
            else
                set([obj.hMaskSurf2 obj.hMaskDLine2 obj.hMaskLLine2], 'Visible', 'on');
                obj.hMaskSurf2.XData = repmat(obj.wndDelay + [0 obj.wndWidth] - obj.triggerNominalPeriodTicks,2,1);
                obj.hMaskDLine2.XData = repmat(obj.wndDelay - obj.triggerNominalPeriodTicks,1,2);
                obj.hMaskLLine2.XData = repmat(obj.wndDelay + obj.wndWidth - obj.triggerNominalPeriodTicks,1,2);
                obj.hMaskArrL.XData(4:5) = [0 obj.wndDelay]-obj.triggerNominalPeriodTicks;
                obj.hMaskArrH.XData(3) = obj.wndDelay-obj.triggerNominalPeriodTicks;
            end
        end
        
        function setImgSys(obj,varargin)
            obj.stop();
            
            if isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.ResScan')
                obj.hFpga = obj.hSI.hScan2D.hAcq.hFpga;
            elseif isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.LinScan')
                if strcmp(obj.hSI.hScan2D.hAcq.hAI.streamMode,'fpga')
                    obj.hFpga = obj.hSI.hScan2D.hAcq.hAI.hFpga;
                else
                    obj.hFpga = [];
                end
            else
                obj.hFpga = [];
            end
            
            if isempty(obj.hFpga) || ~most.idioms.isValidObj(obj.hSI.hScan2D.hDataScope)
                obj.hFpga = [];
                obj.hDataScope = [];
            else
                obj.hDataScope = obj.hSI.hScan2D.hDataScope;
                
                numchans = obj.hSI.hScan2D.channelsAvailable;
                obj.channel = min(obj.channel,numchans);
                obj.hChanPop.choices = cellstr(strrep(num2str(1:numchans),' ','')')';
                
                obj.enableSampleMask = obj.hSI.hScan2D.mdfData.LaserTriggerSampleMaskEnable;
                obj.samplingWindow = obj.hSI.hScan2D.mdfData.LaserTriggerSampleWindow;
                obj.laserTriggerFilter = obj.hSI.hScan2D.mdfData.LaserTriggerFilterTicks;
            end
        end
        
        function pbStartCb(obj, varargin)
            if obj.active
                obj.stop();
            else
                obj.start();
            end
        end
        
        function actvChanged(obj,varargin)
            if obj.active
                str = 'Stop Scope';
            else
                str = 'Start Scope';
            end
            obj.pbStart.Value = obj.active;
            obj.pbStart.String = str;
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.chanStr(obj,v)
            obj.chanStr = v;
            n = str2num(v);
            if obj.channel ~= n
                obj.channel = n;
            end
        end
        
        function set.triggerNominalPeriodTicks(obj,v)
            obj.triggerNominalPeriodTicks = v;
            if ~isempty(v)
                vs = (v+2) * [-1 1];
                obj.hAxes.XLim = vs;
                obj.hDigAxes.XLim = vs;
                setMinorXTick(obj.hAxes, vs(1):vs(2));
                setMinorXTick(obj.hDigAxes, vs(1):vs(2));
                obj.hSLLine.XData = [-v -v nan v v];
                
                if v == 1
                    s = ' Tick';
                else
                    s = ' Ticks';
                end
                
                obj.triggerNominalPeriodTicksStr = [num2str(v) s];
                
                obj.updateWindowDisp();
            else
                obj.triggerNominalPeriodTicksStr = '';
            end
            obj.updateWindowDisp();
        end
        
        function set.ylim(obj,v)
            v(2) = max(v(1)+1,v(2));
            obj.ylim = v;
            
            obj.hAxes.YLim = obj.ylim;
            obj.hPLLine.YData = obj.ylim;
            obj.hSLLine.YData = [obj.ylim nan obj.ylim];
            
            obj.hMaskSurf.YData = [obj.ylim; obj.ylim]';
            obj.hMaskDLine.YData = obj.ylim;
            obj.hMaskLLine.YData = obj.ylim;
            obj.hMaskArrL.YData = mean(obj.ylim) * [1 1 nan 1 1];
            obj.hMaskArrH.YData = mean(obj.ylim) * [1 nan 1];
            
            obj.hMaskSurf2.YData = [obj.ylim; obj.ylim]';
            obj.hMaskDLine2.YData = obj.ylim;
            obj.hMaskLLine2.YData = obj.ylim;
        end
        
        function v = get.samplingWindow(obj)
            v = [obj.wndDelay obj.wndWidth];
        end
        
        function set.samplingWindow(obj,v)
            obj.wndDelay = v(1);
            obj.wndWidth = v(2);
        end
        
        function set.wndDelay(obj,v)
            v = max(round(v),0);
            obj.wndDelay = v;
            obj.updateWindowDisp();
            obj.hFpga.LaserTriggerDelay = v;
            obj.hSI.hScan2D.mdfData.LaserTriggerSampleWindow = obj.samplingWindow;
        end
        
        function set.wndWidth(obj,v)
            v = max(round(v),1);
            obj.wndWidth = v;
            obj.updateWindowDisp();
            obj.hFpga.LaserSampleWindowSize = v;
            obj.hSI.hScan2D.mdfData.LaserTriggerSampleWindow = obj.samplingWindow;
        end
        
        function set.laserTriggerFilter(obj,v)
            obj.laserTriggerFilter = v;
            obj.hFpga.LaserTriggerFilterTicks = v;
            obj.hSI.hScan2D.mdfData.LaserTriggerFilterTicks = v;
        end
        
        function set.enableSampleMask(obj,v)
            obj.enableSampleMask = v;
            obj.hFpga.ResScanFilterSamples = v;
            obj.hSI.hScan2D.mdfData.LaserTriggerSampleMaskEnable = v;
        end
        
        function set.traceLength(obj,v)
            if most.idioms.isValidObj(obj.hDataScope)
                v = double(min(v,obj.hDataScope.hFifo.fifoNumberOfElementsFpga));
            end
            obj.traceLength = v;
            obj.hDataScope.acquisitionTime = obj.traceLength / obj.hDataScope.digitizerSampleRate;
        end
        
        function set.channel(obj,v)
            obj.channel = v;
            
            s = num2str(v);
            if ~strcmp(s,obj.chanStr)
                obj.chanStr = s;
            end
            
            obj.hDataScope.channel = obj.channel;
        end
    end
end

function setMinorXTick(hA, vs)
    if isprop(hA, 'XAxis')
        hA.XAxis.MinorTickValues = vs;
    else
        hA.XRuler.MinorTick = vs;
    end
end


%--------------------------------------------------------------------------%
% LaserTriggerScope.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
