classdef SignalDemuxControls < most.Gui
    properties (SetObservable)
        updateRate = 10;
        scopeCaptureSize = 20000;
        
        active = false;
        virtualChannelSettings;
        
        triggerMode = 'Auto';
        triggerAnalogLevel = 100;
        triggerAutoRollover = 16;
        triggerInvert = false;
        
        physicalChInvert;
        physicalChThresholdEnable;
        physicalChThresholdLevel;
        physicalChEdgeDetection;
    end
    
    properties (Hidden, SetAccess = private, SetObservable)
        hContainers;
        hChAx;
        hDataLine;
        hTrigLine;
        hChannelSurfs = matlab.graphics.primitive.Surface.empty;
        hChannelLines = matlab.graphics.primitive.Line.empty;
        hChannelTexts = matlab.graphics.primitive.Text.empty;
        hPhysChannelTable;
        hVirtChannelTable;
        hFpga;
        hAcq;
        hDLis;
        hTimer;
        
        triggerRate = [];
        triggerPeriodTicks = 18;
        
        numPhysChans = 2;
        physChanBitDepth = 8;
        numVirtChans = 16;
        
        pauseTblUpdate = false;
    end
    
    properties (Hidden, Constant)
        MIN_SAMPLE_ACCUM_IDX = 0;
        MAX_SAMPLE_ACCUM_IDX = 4000;
    end
    
    %% LifeCycle
    methods
        function obj = SignalDemuxControls(hSI,hCtl)
            if nargin < 1
                try
                    hSI = evalin('base','hSI');
                catch
                    error('ScanImage must be running.');
                end
            end
            
            obj = obj@most.Gui(hSI, [], [800 600]);
            
            if isprop(hSI.hScan2D.hAcq, 'hFpga') && ~isempty(hSI.hScan2D.hAcq.hFpga) && isprop(hSI.hScan2D.hAcq.hFpga, 'fifo_NI577XSampsToHost')
                obj.hAcq = hSI.hScan2D.hAcq;
                obj.hFpga = obj.hAcq.hFpga;
                assert(most.idioms.isValidObj(obj.hFpga),'Could not find valid handle to running ScanImage FPGA.');
                
                obj.numPhysChans = 2 - obj.hAcq.FPGA_SET_TIS(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
                obj.numVirtChans = obj.hAcq.adapterModuleChannelCount;
                obj.physChanBitDepth = obj.hAcq.hFpga.ADAPTER_MODULE_ADC_RAW_BIT_DEPTH(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
                
                % for simulated testing
                obj.numPhysChans = 1;
                obj.numVirtChans = 32;
                obj.physChanBitDepth = 12;
                
                obj.hTimer = timer('Name','Signal Demux Controls','ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@obj.readSamples);
                obj.makeFigure();
                obj.init();
                
                obj.virtualChannelSettings = repmat(struct('physicalChannel',0,'show',false,'bounds',nan(1,2)),1,obj.numVirtChans);
                
                if nargin > 1
                    hObjs = hCtl.hGUIs.mainControlsV4.Children;
                    hVwMnu = hObjs(arrayfun(@(o)isa(o,'matlab.ui.container.Menu')&&strcmp(o.Label,'View'), hObjs));
                    hTrigScopeMenu = hVwMnu.Children(strcmp({hVwMnu.Children.Label},'Laser Trigger Scope'));
                    hTrigScopeMenu.Callback = @(varargin)figure(obj.hFig);
                end
            end
        end
        
        function makeFigure(obj)
            obj.hFig.Name = 'Signal Demux Controls';
            obj.hFig.CloseRequestFcn = @obj.hFigCloseRequestFcn;
            
            tblNames = {'' 'AI' 'Show' 'Start' 'End'};
            tblWdths = {34 38 40 38 38};
            tblEdits = [false true true true true];
            tblFrmts = {'numeric' {'AI0' 'AI1'} 'logical' 'numeric' 'numeric'};
            if obj.numPhysChans == 1
                tblNames(2) = [];
                tblWdths(2) = [];
                tblEdits(2) = [];
                tblFrmts(2) = [];
            end
            
            obj.hContainers.main = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                obj.hContainers.left = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');                
                obj.hContainers.right = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');
                    obj.hContainers.right.WidthLimits = [220 220];
                    obj.hContainers.pnTrigger = most.gui.uipanel('Parent',obj.hContainers.right,'Title','Trigger Configuration','HeightLimits',98);
                        obj.hContainers.pnTriggerFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTrigger,'FlowDirection','TopDown');
                            obj.hContainers.trigMode = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.anLvl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight','visible','off');
                            obj.hContainers.autoRate = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.measRate = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                    obj.hContainers.pnPhys = most.gui.uipanel('Parent',obj.hContainers.right,'Title','Physical Channel Configuration','HeightLimits',79);
                        obj.hContainers.pnPhysF1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnPhys,'FlowDirection','TopDown');
                            obj.hPhysChannelTable = uitable('Parent',obj.hContainers.pnPhysF1,'ColumnName',{'' 'Invert' 'Threshold' 'Level' 'Edge'},'ColumnWidth',{24 40 60 40 40},...
                                'ColumnEditable',[false true true true true],'ColumnFormat',{'numeric' 'logical' 'logical' 'numeric' 'logical'},'rowname',{},'CellEditCallback',@obj.phyTableCb);
                                obj.updatePhysTable();
                    obj.hContainers.pnMask = most.gui.uipanel('Parent',obj.hContainers.right,'Title','Virtual Channel Configuration','HeightLimits',[160 inf]);
                        obj.hContainers.pnMaskFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMask,'FlowDirection','TopDown','margin',0.00001);
                            obj.hContainers.pnMaskFlR1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                                obj.hVirtChannelTable = uitable('Parent',obj.hContainers.pnMaskFlR1,'ColumnName',tblNames,'ColumnWidth',tblWdths,...
                                    'ColumnEditable',tblEdits,'ColumnFormat',tblFrmts,'rowname',{},'CellEditCallback',@obj.virtTableCb);
                            obj.hContainers.pnMaskFlR2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                                set(obj.hContainers.pnMaskFlR2, 'HeightLimits', 32*ones(1,2));
                                obj.addUiControl('Parent',obj.hContainers.pnMaskFlR2,'Tag','pbShow','String','Show All','Callback',@obj.showAll);
                                obj.addUiControl('Parent',obj.hContainers.pnMaskFlR2,'Tag','pbHide','String','Hide All','Callback',@obj.hideAll);
                                obj.addUiControl('Parent',obj.hContainers.pnMaskFlR2,'Tag','pbSave','String','Save','Callback',@obj.saveConfig);
                                obj.pbSave.WidthLimits = 40*ones(1,2);
                                obj.addUiControl('Parent',obj.hContainers.pnMaskFlR2,'Tag','pbLoad','String','Load','Callback',@obj.loadConfig);
                                obj.pbLoad.WidthLimits = 40*ones(1,2);
                            obj.hContainers.pnMaskFlR3 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                                set(obj.hContainers.pnMaskFlR3, 'HeightLimits', 32*ones(1,2));
                                obj.addUiControl('Parent',obj.hContainers.pnMaskFlR3,'Tag','pbWrite','String','Apply Channel Configuration','Callback',@obj.writeChannelConfig);
            
            most.gui.uipanel('Parent',obj.hContainers.right,'borderType','none','HeightLimits',4);
            obj.addUiControl(...
                'Parent',obj.hContainers.right,...
                'Tag','pbStart',...
                'Style','togglebutton',...
                'String','Start Scope',...
                'Bindings',{obj 'active' 'Value'},'HeightLimits',40);
            
            most.gui.staticText('Parent',obj.hContainers.trigMode,'String','Trigger Mode','HorizontalAlignment','right','VerticalAlignment','middle','WidthLimits',80);
            obj.addUiControl(...
                'Parent',obj.hContainers.trigMode,...
                'Tag','pmTriggerMode',...
                'Style','popupmenu',...
                'String',{'Auto','Digital','Analog'},...
                'Bindings',{obj 'triggerMode' 'Choice'},'WidthLimits',60);
            most.gui.uipanel('Parent',obj.hContainers.trigMode,'borderType','none','WidthLimits',4);
            obj.addUiControl('string','Invert',...
                'Parent',obj.hContainers.trigMode,...
                'Tag','cbInvertTrigger',...
                'Style','checkbox',...
                'Bindings',{obj 'triggerInvert' 'value'},'WidthLimits',48);
            
            most.gui.staticText('Parent',obj.hContainers.anLvl,'String','Analog Level','HorizontalAlignment','right','VerticalAlignment','middle','WidthLimits',80);
            obj.addUiControl(...
                'Parent',obj.hContainers.anLvl,...
                'Tag','etNI5771TriggerAnalogLevel',...
                'Style','edit',...
                'Bindings',{obj 'triggerAnalogLevel' 'Value'});
            
            most.gui.staticText('Parent',obj.hContainers.autoRate,'String','Auto Rollover','HorizontalAlignment','right','VerticalAlignment','middle','WidthLimits',80);
            obj.addUiControl(...
                'Parent',obj.hContainers.autoRate,...
                'Tag','etNI5771TriggerAutoRollover',...
                'Style','edit',...
                'Bindings',{obj 'triggerAutoRollover' 'Value'});
            
            most.gui.staticText('Parent',obj.hContainers.measRate,'String','Trigger Rate','HorizontalAlignment','right','VerticalAlignment','middle','WidthLimits',80);
            obj.addUiControl(...
                'Parent',obj.hContainers.measRate,...
                'Tag','etTriggerRate',...
                'Style','edit',...
                'BackgroundColor',0.95*ones(1,3),...
                'Enable','inactive',...
                'Bindings',{obj 'triggerRate' 'Value' '%1.3f MHz', 'Scaling', 1e-6});
            
            lim = round(1.02 * 2^(obj.physChanBitDepth-1));
            obj.hChAx = axes('Parent',obj.hContainers.left,'Box','on','XLim',[-1 51],'YLim',lim*[-1 1],'XGrid','on','XMinorGrid','on','YGrid','on','ButtonDownFcn',@obj.axHit);
            title(obj.hChAx,'PMT 1','FontWeight','normal');
            ylabel(obj.hChAx,'ADC Counts');
            obj.hDataLine = line('Parent',obj.hChAx(1),'XData',1:51,'YData',nan(1,51),'Color',[0.3 0.3 1],'Marker','.','MarkerSize',10);
            obj.hTrigLine = line('Parent',obj.hChAx(1),'XData',[0 0 nan 50 50],'YData',lim*[-1 1 nan -1 1],'Color','r');
            
            if obj.numPhysChans > 1
                obj.hChAx(2) = axes('Parent',obj.hContainers.left,'Box','on','XLim',[-1 51],'YLim',lim*[-1 1],'XGrid','on','XMinorGrid','on','YGrid','on','ButtonDownFcn',@obj.axHit);
                title(obj.hChAx(2),'PMT 2','FontWeight','normal');
                xlabel(obj.hChAx(2),'Samples');
                ylabel(obj.hChAx(2),'ADC Counts');
                obj.hDataLine(2) = line('Parent',obj.hChAx(2),'XData',1:51,'YData',nan(1,51),'Color',[0.3 0.3 1],'Marker','.','MarkerSize',10);
                obj.hTrigLine(2) = line('Parent',obj.hChAx(2),'XData',[0 0 nan 50 50],'YData',lim*[-1 1 nan -1 1],'Color','r');
            end
            
            alpha = 0.2;
            sArgs = {'YData',lim*[-1 1],'ZData',zeros(2),'FaceColor','g','FaceAlpha',alpha,'EdgeColor','none','ButtonDownFcn',@obj.surfHit,'visible','off'};
            lArgs = {'YData',lim*[-1 1],'Color','k','linewidth',1.5,'ButtonDownFcn',@obj.lineHit,'visible','off'};
            tArgs = {'Rotation',270,'HorizontalAlignment','right','visible','off'};
            for i = 1:obj.numVirtChans
                obj.hChannelSurfs(i) = surface('Parent',obj.hChAx(1),'XData',(i-1)*4+[1.5 3.5],sArgs{:},'UserData',i);
                obj.hChannelLines(i*2-1) = line('Parent',obj.hChAx(1),'XData',(i-1)*4+[1.5 1.5],lArgs{:},'UserData',struct('ch',i,'ind',1));
                obj.hChannelLines(i*2) = line('Parent',obj.hChAx(1),'XData',(i-1)*4+[3.5 3.5],lArgs{:},'UserData',struct('ch',i,'ind',2));
                obj.hChannelTexts(i) = text((i-1)*4+2.5,-240,sprintf('CH%d',i),'Parent',obj.hChAx(1),tArgs{:});
            end
            
            obj.hDLis = addlistener(obj.hFpga,'ObjectBeingDestroyed',@(varargin)obj.delete);
            obj.hFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;
        end
        
        function delete(obj)
            obj.stop();
            most.idioms.safeDeleteObj(obj.hTimer);
            most.idioms.safeDeleteObj(obj.hDLis);
        end
        
        function init(obj)
            obj.triggerMode = obj.triggerMode;
            obj.triggerInvert = obj.triggerInvert;
            obj.triggerAnalogLevel = obj.triggerAnalogLevel;
            obj.triggerAutoRollover = 8*2;
        end
    end
    
    methods
        function start(obj)
            obj.stop(); % reset sampler system on FPGA
            
            if ~obj.hAcq.acqRunning
                obj.hAcq.measureExternalRawSampleClockRate();
            end
            
            obj.hFpga.fifo_NI577XSampsToHost.configure(obj.scopeCaptureSize);
            obj.hFpga.fifo_NI577XSampsToHost.start();
            if isprop(obj.hFpga, 'fifo_NI577XSampsToHostHi')
                obj.hFpga.fifo_NI577XSampsToHostHi.configure(obj.scopeCaptureSize);
                obj.hFpga.fifo_NI577XSampsToHostHi.start();
            end
            obj.hFpga.fifo_NI577XTriggerToHost.configure(obj.scopeCaptureSize/2);
            obj.hFpga.fifo_NI577XTriggerToHost.start();
            obj.flushFifo();
            obj.hTimer.Period = round((1/obj.updateRate)*1000)/1000; % timer resolution is limited to 1ms
            obj.hFig.CloseRequestFcn = @obj.hFigCloseRequestFcn;
            start(obj.hTimer);
        end
        
        function abort(obj)
            obj.stop();
        end
        
        function stop(obj)
            if ~isempty(obj.hTimer)
                stop(obj.hTimer);
            end
            if ~isempty(obj.hFpga) && ~obj.hFpga.simulated
                obj.flushFifo();
                obj.hFpga.fifo_NI577XSampsToHost.stop();
                if isprop(obj.hFpga, 'fifo_NI577XSampsToHostHi')
                    obj.hFpga.fifo_NI577XSampsToHostHi.stop();
                end
                obj.hFpga.fifo_NI577XTriggerToHost.stop();
            end
        end
        
        function writeChannelConfig(obj,varargin)
            for i = 0:(obj.numVirtChans-1)
                s = obj.virtualChannelSettings(i+1);
                obj.hFpga.NI5771VirtualChanWriteIdx = i;
                if any(isnan(s.bounds))
                    bounds = [-8 -8];
                else
                    bounds = s.bounds;
                end
                obj.hFpga.NI5771VirtualChanStartSample = bounds(1)+8; % sample 8 is the sample where the trigger arrived
                obj.hFpga.NI5771VirtualChanEndSample = bounds(2)+8;
                obj.hFpga.NI5771VirtualChanChannelSel = s.physicalChannel;
                obj.hFpga.NI5771VirtualChanWriteEnable = true;
            end
            
            obj.hFpga.NI5771SendIdx = max([obj.virtualChannelSettings.bounds 8]);
        end
        
        function showAll(obj,varargin)
            obj.virtualChannelSettings = arrayfun(@(x)setfield(x,'show',true),obj.virtualChannelSettings);
        end
        
        function hideAll(obj,varargin)
            obj.virtualChannelSettings = arrayfun(@(x)setfield(x,'show',false),obj.virtualChannelSettings);
        end
        
        function saveConfig(obj,varargin)
            if nargin ~= 2
                [filename,pathname] = uiputfile('.mat','Choose filename to save channel settings to','signalDemuxSettings.mat');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            else
                filename = varargin{1};
            end
            
            s = obj.saveConfigStruct();
            nms = fieldnames(s);
            cellfun(@eval,strcat(nms,' = s.',nms,';'))
            save(filename,nms{:});
        end
        
        function s = saveConfigStruct(obj)
            settingProps = {'virtualChannelSettings' 'triggerMode' 'triggerInvert' 'triggerAnalogLevel' 'triggerAutoRollover'...
                'physicalChInvert' 'physicalChThresholdEnable' 'physicalChThresholdLevel' 'physicalChEdgeDetection'};
            
            cellfun(@eval, strcat('s.', settingProps,' = obj.',settingProps,';'))
        end
        
        function loadStruct(obj,cs)
            nms = fieldnames(cs);
            for i = 1:numel(nms)
                obj.(nms{i}) = cs.(nms{i});
            end
        end
        
        function loadConfig(obj,varargin)
            if nargin ~= 2
                [filename,pathname] = uigetfile('.mat','Choose filename to save channel settings to','signalDemuxSettings.mat');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            else
                filename = varargin{1};
            end
            
            cs = load(filename);
            obj.loadStruct(cs);
        end
    end
    
    methods (Hidden)
        function readSamples(obj,varargin)
            try
                trigPeriod = nan(1,obj.numPhysChans);
                
                for chan = 1:obj.numPhysChans
                    trigPeriod(chan) = doScope(chan-1);
                end
                m = mean(trigPeriod);
                
                if isnan(m)
                    obj.triggerRate = [];
                else
                    obj.triggerPeriodTicks = round(m);
                    obj.triggerRate = obj.hFpga.rawSampleRateAcq/(8*m);
                end
            catch ME
                fprintf(2,'Error while processing scope data: %s\n', ME.message);
                obj.active = false;
            end
            
            function trigPeriod = doScope(ch)
                %% capture some data
                obj.hFpga.NI5771CaptureSizeN = obj.scopeCaptureSize;
                obj.hFpga.NI5771CaptureChannelSel = ch;
                obj.hFpga.NI5771StartCapture = true;
                most.idioms.pauseTight(0.001);
                
                sampleData = obj.hFpga.fifo_NI577XSampsToHost.readAll();
                nRetry = 3;
                while nRetry && (numel(sampleData) < obj.scopeCaptureSize)
                    nRetry = nRetry - 1;
                    newData = obj.hFpga.fifo_NI577XSampsToHost.readAll();
                    sampleData = [sampleData; newData];
                end
                assert(numel(sampleData) == obj.scopeCaptureSize, 'Incorrect ammount of data received');
                
                
                if isprop(obj.hFpga, 'fifo_NI577XSampsToHostHi')
                    sampleDataHi = obj.hFpga.fifo_NI577XSampsToHostHi.readAll();
                    nRetry = 3;
                    while nRetry && (numel(sampleDataHi) < obj.scopeCaptureSize)
                        nRetry = nRetry - 1;
                        newData = obj.hFpga.fifo_NI577XSampsToHostHi.readAll();
                        sampleDataHi = [sampleDataHi; newData];
                    end
                    assert(numel(sampleDataHi) == obj.scopeCaptureSize, 'Incorrect ammount of data received');
                    
                    sampleData = reshape([sampleData sampleDataHi]',1,[])';
                end
                
                sampleData = single(typecast(sampleData,'int16'));
                triggerData = obj.hFpga.fifo_NI577XTriggerToHost.readAll();
                
                %% process the triggers
                triggerData = single(reshape(typecast(triggerData, 'uint16'),2,[])');
                nSig = size(triggerData,1) - 2;
                
                if nSig < 1
                    trigPeriod = nan;
                    return;
                end
                
                % determine longest signal duration
                diffs = triggerData(2:end,1) - triggerData(1:end-1,1);
                trigPeriod = mean(diffs);
                maxLen = (max(diffs)+3)*8;
                
                signals = nan(maxLen,nSig,'single');
                
                for i = 1:nSig
                    triggerTS = triggerData(i,1);
                    nextTriggerTS = triggerData(i+1,1);
                    sigOffset = triggerData(i,2);
                    
                    offsetSig = [nan(7-sigOffset,1); sampleData(triggerTS*8+1:(nextTriggerTS+1)*8)];
                    signals(1:size(offsetSig,1),i) = offsetSig;
                end
                
                plotDataY = reshape(signals,1,[]);
                plotDataT = reshape(repmat((1:maxLen)'-8,1,nSig),1,[]);
                
                obj.hDataLine(ch+1).XData = plotDataT;
                obj.hDataLine(ch+1).YData = plotDataY;
            end
        end
        
        function hFigCloseRequestFcn(obj,src,~)
            src.Visible = 'off';
            obj.stop();
        end
        
        function scrollWheelFcn(obj,~,evt)
            if mouseIsInAxes(obj.hChAx(1))
                hAx = obj.hChAx(1);
            elseif obj.numPhysChans > 1 && mouseIsInAxes(obj.hChAx(2))
                hAx = obj.hChAx(2);
            else
                return
            end
            
            maxRg = [-5 obj.triggerPeriodTicks*8+4];
            p = axPt(hAx);
            lims = hAx.XLim;
            zoomSpeedFactor = 1.6;
            
            lims = p(1) + (lims - p(1)) .* (zoomSpeedFactor ^ double(evt.VerticalScrollCount));
            if diff(lims) > 20
                set(obj.hChAx,'XLim',max(min(lims,maxRg(2)),maxRg(1)));
            end
        end
    end
    
    %% Private methods
    methods (Access = private)        
        function flushFifo(obj)
            obj.hFpga.EnableSampleScope = false;
            
            data = NaN;
            datat = NaN;
            timeout = 1; % in seconds
            start = tic();
            while toc(start)<timeout && (~isempty(data) || ~isempty(datat))
                data = obj.hFpga.fifo_NI577XSampsToHost.readAll();
                if isprop(obj.hFpga, 'fifo_NI577XSampsToHostHi')
                    obj.hFpga.fifo_NI577XSampsToHostHi.readAll();
                end
                datat = obj.hFpga.fifo_NI577XTriggerToHost.readAll();
                pause(10e-3);
            end
            assert(isempty(data),'NI5771Sampler: Failed to flush fifo');
        end
        
        function axHit(obj,src,evt)
            persistent org
            persistent ppt
            persistent maxRg
            persistent hAx
            
            if strcmp(evt.EventName, 'Hit')
                set(obj.hFig,'WindowButtonMotionFcn',@obj.axHit,'WindowButtonUpFcn',@obj.axHit);
                ppt = axPt(src);
                org = diff(src.XLim);
                maxRg = [-1 obj.triggerPeriodTicks*8+1];
                hAx = src;
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                npt = axPt(hAx);
                
                nlims = hAx.XLim + ppt(1) - npt(1);
                if any(nlims > maxRg(2))
                    nlims = [maxRg(2)-org maxRg(2)];
                elseif any(nlims < -1)
                    nlims = [-1 org-1];
                end
                set(obj.hChAx, 'XLim', nlims);
                
                ppt = axPt(hAx);
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function surfHit(obj,src,evt)
            persistent ch
            persistent ax
            persistent opc
            
            if strcmp(evt.EventName, 'Hit')
                ch = src.UserData;
                ax = src.Parent;
                
                if obj.numPhysChans > 1
                    opc = ax == obj.hChAx(2);
                end
                
                set(obj.hFig,'WindowButtonMotionFcn',@obj.surfHit,'WindowButtonUpFcn',@obj.surfHit);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                w = diff(obj.virtualChannelSettings(ch).bounds);
                s = round(ax.CurrentPoint(1) - w/2);
                obj.pauseTblUpdate = true;
                
                obj.virtualChannelSettings(ch).bounds = max(min([s s+w],obj.MAX_SAMPLE_ACCUM_IDX),obj.MIN_SAMPLE_ACCUM_IDX);
                
                if obj.numPhysChans > 1
                    obj.virtualChannelSettings(ch).physicalChannel = double((opc && (ax.CurrentPoint(3) < 400)) || (~opc && (ax.CurrentPoint(3) < -400)));
                end
                
                obj.pauseTblUpdate = false;
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function lineHit(obj,src,evt)
            persistent ch
            persistent ind
            persistent ax
            
            if strcmp(evt.EventName, 'Hit')
                ch = src.UserData.ch;
                ind = src.UserData.ind;
                ax = src.Parent;
                set(obj.hFig,'WindowButtonMotionFcn',@obj.lineHit,'WindowButtonUpFcn',@obj.lineHit);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                bds = obj.virtualChannelSettings(ch).bounds;
                bds(ind) = round(ax.CurrentPoint(1));
                if bds(1) > bds(2)
                    bds(3-ind) = bds(ind);
                end
                obj.virtualChannelSettings(ch).bounds = max(min(bds,obj.MAX_SAMPLE_ACCUM_IDX),obj.MIN_SAMPLE_ACCUM_IDX);
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function updatePhysTable(obj)
            dat = [{' AI0' ' AI1'}; num2cell(obj.physicalChInvert); num2cell(obj.physicalChThresholdEnable); num2cell(obj.physicalChThresholdLevel); num2cell(obj.physicalChEdgeDetection)]';
            obj.hPhysChannelTable.Data = dat(1:obj.numPhysChans,:);
        end
        
        function updateVirtTable(obj)
            if obj.numPhysChans == 1
                s = arrayfun(@(ch,s){sprintf(' CH%d', ch) s.show s.bounds(1) s.bounds(2)},1:obj.numVirtChans,obj.virtualChannelSettings,'UniformOutput',false);
            else
                s = arrayfun(@(ch,s){sprintf(' CH%d', ch) sprintf('AI%d', s.physicalChannel) s.show s.bounds(1) s.bounds(2)},1:obj.numVirtChans,obj.virtualChannelSettings,'UniformOutput',false);
            end
            obj.hVirtChannelTable.Data = vertcat(s{:});
        end
        
        function virtTableCb(obj,~,evt)
            clmn = evt.Indices(2);
            if (obj.numPhysChans == 1) && (clmn > 1)
                clmn = clmn + 1;
            end
            switch clmn
                case 2
                    obj.virtualChannelSettings(evt.Indices(1)).physicalChannel = str2double(evt.NewData(end));
                case 3
                    if ~obj.virtualChannelSettings(evt.Indices(1)).show && evt.NewData
                        bds = obj.virtualChannelSettings(evt.Indices(1)).bounds;
                        if any(isnan(bds))
                            obj.virtualChannelSettings(evt.Indices(1)).bounds = [10 30];
                        end
                    end
                    obj.virtualChannelSettings(evt.Indices(1)).show = evt.NewData;
                case {4 5}
                    ind = clmn - 3;
                    bds = obj.virtualChannelSettings(evt.Indices(1)).bounds;
                    bds(ind) = evt.NewData;
                    if bds(1) > bds(2)
                        bds(3-ind) = bds(ind);
                    end
                    obj.virtualChannelSettings(evt.Indices(1)).bounds = bds;
            end
        end
        
        function phyTableCb(obj,~,evt)
            switch evt.Indices(2)
                case 2
                    obj.physicalChInvert(evt.Indices(1)) = evt.NewData;
                case 3
                    obj.physicalChThresholdEnable(evt.Indices(1)) = evt.NewData;
                case 4
                    obj.physicalChThresholdLevel(evt.Indices(1)) = evt.NewData;
                case 5
                    obj.physicalChEdgeDetection(evt.Indices(1)) = evt.NewData;
            end
            
            obj.updatePhysTable();
        end
        
        function drawSelection(obj)
            for i = 1:obj.numVirtChans
                s = obj.virtualChannelSettings(i);
                
                vis = obj.tfMap(s.show);
                xd = [s.bounds(1)-.5 s.bounds(2)+.5];
                
                obj.hChannelSurfs(i).Parent = obj.hChAx(s.physicalChannel+1);
                obj.hChannelSurfs(i).XData = xd;
                obj.hChannelSurfs(i).Visible = vis;
                
                obj.hChannelLines(i*2-1).Parent = obj.hChAx(s.physicalChannel+1);
                obj.hChannelLines(i*2-1).XData = [xd(1) xd(1)];
                obj.hChannelLines(i*2-1).Visible = vis;
                
                obj.hChannelLines(i*2).Parent = obj.hChAx(s.physicalChannel+1);
                obj.hChannelLines(i*2).XData = [xd(2) xd(2)];
                obj.hChannelLines(i*2).Visible = vis;
                
                obj.hChannelTexts(i).Parent = obj.hChAx(s.physicalChannel+1);
                obj.hChannelTexts(i).Position(1) = mean(xd);
                obj.hChannelTexts(i).Visible = vis;
            end
        end        
    end
    
    %% Property Getter/Setter
    methods
        function set.virtualChannelSettings(obj,v)
            obj.virtualChannelSettings = v;
            if ~obj.pauseTblUpdate
                obj.updateVirtTable();
            end
            obj.drawSelection();
        end
        
        function set.active(obj,val)
            obj.active = val;
            
            if obj.active
                str = 'Stop Scope';
                obj.start();
            else
                str = 'Start Scope';
                obj.stop();
            end
            obj.pbStart.String = str;
        end
        
        function set.triggerMode(obj,val)
            assert(ismember(val,{'Auto','Digital','Analog'}));
            obj.hFpga.NI5771TriggerMode = val;
            
            switch val
                case 'Auto'
                    obj.hContainers.anLvl.Visible = 'off';
                    obj.hContainers.autoRate.Visible = 'on';
                    obj.hContainers.pnTrigger.HeightLimits = 98*ones(1,2);
                    obj.cbInvertTrigger.Visible = 'off';
                case 'Digital'
                    obj.hContainers.anLvl.Visible = 'off';
                    obj.hContainers.autoRate.Visible = 'off';
                    obj.hContainers.pnTrigger.HeightLimits = 72*ones(1,2);
                    obj.cbInvertTrigger.Visible = 'on';
                case 'Analog'
                    obj.hContainers.anLvl.Visible = 'on';
                    obj.hContainers.autoRate.Visible = 'off';
                    obj.hContainers.pnTrigger.HeightLimits = 98*ones(1,2);
                    obj.cbInvertTrigger.Visible = 'on';
                otherwise
                    assert(false);
            end
            
            obj.triggerMode = val;
        end
        
        function val = get.triggerMode(obj)
            if obj.hFpga.simulated
                val = obj.triggerMode;
            else
                val = obj.hFpga.NI5771TriggerMode;
            end
        end
        
        function set.triggerInvert(obj,val)
            obj.hFpga.NI5771InvertTrigger = val;
            obj.triggerInvert = val;
        end
        
        function val = get.triggerInvert(obj)
            if obj.hFpga.simulated
                val = obj.triggerInvert;
            else
                val = obj.hFpga.NI5771InvertTrigger;
            end
        end
        
        function set.triggerAnalogLevel(obj,val)
            obj.hFpga.NI5771TriggerAnalogLevel = val;
            obj.triggerAnalogLevel = val;
        end
        
        function val = get.triggerAnalogLevel(obj)
            if obj.hFpga.simulated
                val = obj.triggerAnalogLevel;
            else
                val = obj.hFpga.NI5771TriggerAnalogLevel;
            end
        end
        
        function set.triggerAutoRollover(obj,val)
%             assert(val >= 16,'Trigger Auto Rollover needs to be greater than 8');
%             assert(floor(val/8) == val/8,'Trigger Auto Rollver needs to be a multiple of 8');
%             val = floor(val/8) - 1;
            obj.hFpga.NI5771TriggerAutoRollover = val;
            obj.triggerAutoRollover = val;
        end
        
        function val = get.triggerAutoRollover(obj)
            if obj.hFpga.simulated
                val = obj.triggerAutoRollover;
            else
                val = obj.hFpga.NI5771TriggerAutoRollover;
            end
        end
        
        function set.triggerPeriodTicks(obj,v)
            obj.triggerPeriodTicks = v;
            
            set(obj.hTrigLine, 'XData', [0 0 nan 8*v 8*v]);
        end
        
        function set.physicalChInvert(obj,v)
            obj.hFpga.AcqParamLiveInvertChannels(1:2) = v;
            obj.physicalChInvert = v;
        end
        
        function v = get.physicalChInvert(obj)
            if obj.hFpga.simulated
                v = logical(obj.physicalChInvert);
            else
                v = logical(obj.hFpga.AcqParamLiveInvertChannels(1:2));
            end
        end
        
        function set.physicalChThresholdEnable(obj,v)
            v = max(min(v,127),-128);
            
            obj.hFpga.NI5771SigCondThreshholdEnableCh0 = v(1);
            obj.hFpga.NI5771SigCondThreshholdEnableCh1 = v(2);
            obj.physicalChThresholdEnable = v;
            
            setYLims(obj.hChAx(1),v(1));
            if obj.numPhysChans > 1
                setYLims(obj.hChAx(2),v(2));
            end
            
            function setYLims(hAx,t)
                if t
                    l = [-.25 1.25];
                    hAx.YTick = [0 1];
                    hAx.YTickLabel = {'L' 'H'};
                else
                    l = round(1.02*2^(obj.physChanBitDepth-1))*[-1 1];
                    hAx.YTickMode = 'auto';
                    hAx.YTickLabelMode = 'auto';
                end
                hAx.YLim = l;
            end
        end
        
        function v = get.physicalChThresholdEnable(obj)
            if obj.hFpga.simulated
                v = logical(obj.physicalChThresholdEnable);
            else
                v = logical([obj.hFpga.NI5771SigCondThreshholdEnableCh0 obj.hFpga.NI5771SigCondThreshholdEnableCh1]);
            end
        end
        
        function set.physicalChThresholdLevel(obj,v)
            obj.hFpga.NI5771SigCondThreshholdLevelCh0 = v(1);
            obj.hFpga.NI5771SigCondThreshholdLevelCh1 = v(2);
            obj.physicalChThresholdLevel = v;
        end
        
        function v = get.physicalChThresholdLevel(obj)
            if obj.hFpga.simulated
                v = obj.physicalChThresholdLevel;
            else
                v = [obj.hFpga.NI5771SigCondThreshholdLevelCh0 obj.hFpga.NI5771SigCondThreshholdLevelCh1];
            end
        end
        
        function set.physicalChEdgeDetection(obj,v)
            obj.hFpga.NI5771SigCondEdgeDetectionCh0 = v(1);
            obj.hFpga.NI5771SigCondEdgeDetectionCh1 = v(2);
            obj.physicalChEdgeDetection = v;
        end
        
        function v = get.physicalChEdgeDetection(obj)
            if obj.hFpga.simulated
                v = logical(obj.physicalChEdgeDetection);
            else
                v = logical([obj.hFpga.NI5771SigCondEdgeDetectionCh0 obj.hFpga.NI5771SigCondEdgeDetectionCh1]);
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
