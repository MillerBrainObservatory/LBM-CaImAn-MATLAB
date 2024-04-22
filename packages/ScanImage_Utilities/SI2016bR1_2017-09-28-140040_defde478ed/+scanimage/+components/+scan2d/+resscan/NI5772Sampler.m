classdef NI5772Sampler < most.Gui
    properties (SetObservable)
        updateRate = 15;
        bufferSizePackets = 10;        
        active = false;
        channelSettings = repmat(struct('show',false,'bounds',[0 0]),1,16);
    end
    
    properties (Constant)
        PACKET_SIZE_UINT64 = 25;
        MAGIC_NUMBER = 10580346;
    end
    
    properties (Dependent, SetObservable)
        triggerMode;
        triggerAnalogLevel;
        triggerWalk;
        triggerAutoRollover;
    end
    
    properties (Hidden, SetAccess = private, SetObservable)
        hContainers;
        hAx1;
        hAx2;
        hLineCh1;
        hLineCh2;
        hChannelSurfs = matlab.graphics.primitive.Surface.empty;
        hChannelLines = matlab.graphics.primitive.Line.empty;
        hChannelTexts = matlab.graphics.primitive.Text.empty;
        hChannelTable;
        hFpga;
        hAcq;
        hDLis;
        inputBufferUint64;
        hTimer;
        triggerRate = [];
    end
    
    properties (Hidden, Constant)
        FPGA_SYS_CLOCK_RATE = 200e6;
    end
    
    %% LifeCycle
    methods
        function obj = NI5772Sampler(hFpga)
            if nargin < 1
                try
                    obj.hFpga = evalin('base','hSI.hScan2D.hAcq.hFpga');
                catch
                    error('ScanImage must be running.');
                end
            else
                obj.hFpga = hFpga;
            end
            
            assert(most.idioms.isValidObj(obj.hFpga),'Could not find valid handle to running ScanImage FPGA.');
            
            obj.hTimer = timer('Name','NI5772 Sampler','ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@obj.readSamples);
            obj.makeFigure();
            obj.init();
        end
        
        function makeFigure(obj)
            obj.hFig.Name = 'NI5772 Sample configuration';
            obj.hFig.CloseRequestFcn = @obj.hFigCloseRequestFcn;
            obj.hContainers.main = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                obj.hContainers.left = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');                
                obj.hContainers.right = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');
                    obj.hContainers.right.WidthLimits = [220 220];
                    obj.hContainers.pnTrigger = uipanel('Parent',obj.hContainers.right,'Title','Trigger Configuration');
                    obj.hContainers.pnTrigger.HeightLimits = [150 150];
                        obj.hContainers.pnTriggerFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTrigger,'FlowDirection','TopDown');
                            obj.hContainers.pnTriggerLine1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine3 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine4 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine5 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                    obj.hContainers.pnMask = uipanel('Parent',obj.hContainers.right,'Title','Channel Configuration');
                    obj.hContainers.pnMask.HeightLimits = [160 400];
                        obj.hContainers.pnMaskFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMask,'FlowDirection','TopDown','margin',0.00001);
                            obj.hContainers.pnMaskFlR1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                                obj.hChannelTable = uitable('Parent',obj.hContainers.pnMaskFlR1,'ColumnName',{  'AI'; 'CH'; 'Show'; 'Start'; 'End' },'ColumnWidth',{  24 30 40 40 40 },...
                                    'ColumnEditable',[false false true true true],'ColumnFormat',{  'numeric' 'numeric' 'logical' 'numeric' 'numeric' },'rowname',{},'CellEditCallback',@obj.tableCb);
                                obj.updateTable();
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
            
                        
            obj.addUiControl(...
                'Parent',obj.hContainers.right,...
                'Tag','pbStart',...
                'Style','togglebutton',...
                'String','Start Monitoring',...
                'Bindings',{obj 'active' 'Value'});
            set(obj.pbStart,'HeightLimits',[50,50]);
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine1,'Style','text','String','Trigger Walk','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine1,...
                'Tag','etNI5771TriggerWalk',...
                'Style','edit','KeyPressFcn',@obj.keyFunc,...
                'Bindings',{obj 'triggerWalk' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine2,'Style','text','String','Trigger Mode','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine2,...
                'Tag','pmTriggerMode',...
                'Style','popupmenu',...
                'String',{'Auto','Digital','Analog'},...
                'Bindings',{obj 'triggerMode' 'Choice'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine3,'Style','text','String','Analog Level','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine3,...
                'Tag','etNI5771TriggerAnalogLevel',...
                'Style','edit',...
                'Bindings',{obj 'triggerAnalogLevel' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine4,'Style','text','String','Auto Rollover','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine4,...
                'Tag','etNI5771TriggerAutoRollover',...
                'Style','edit',...
                'Bindings',{obj 'triggerAutoRollover' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine5,'Style','text','String','Trigger Rate (MHz)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine5,...
                'Tag','etTriggerRate',...
                'Style','edit',...
                'BackgroundColor',0.95*ones(1,3),...
                'Enable','inactive',...
                'Bindings',{obj 'triggerRate' 'Value' '%1.3f', 'Scaling', 1e-6});
            
            obj.hAx1 = axes('Parent',obj.hContainers.left,'Box','on','XLim',[1 51],'YLim',2060*[-1 1],'XGrid','on','XTick',1:8:52,'XMinorGrid','on','YGrid','on');
            obj.hAx1.XRuler.MinorTick = 1:51;
            title(obj.hAx1,'PMT 1','FontWeight','normal');
            ylabel(obj.hAx1,'ADC Counts');
            
            obj.hAx2 = axes('Parent',obj.hContainers.left,'Box','on','XLim',[1 51],'YLim',2060*[-1 1],'XGrid','on','XTick',1:8:52,'XMinorGrid','on','YGrid','on');
            obj.hAx2.XRuler.MinorTick = 1:51;
            title(obj.hAx2,'PMT 2','FontWeight','normal');
            xlabel(obj.hAx2,'Samples');
            ylabel(obj.hAx2,'ADC Counts');
            
            obj.hLineCh1 = line('Parent',obj.hAx1,'XData',1:51,'YData',nan(1,51),'Color',[0.3 0.3 1],'Marker','.','MarkerSize',10);
            obj.hLineCh2 = line('Parent',obj.hAx2,'XData',1:51,'YData',nan(1,51),'Color',[0.3 0.3 1],'Marker','.','MarkerSize',10);
            
            alpha = 0.2;
            sArgs = {'YData',2060*[-1 1],'ZData',zeros(2),'FaceColor','g','FaceAlpha',alpha,'EdgeColor','none','ButtonDownFcn',@obj.surfHit,'visible','off'};
            lArgs = {'YData',2060*[-1 1],'Color','k','linewidth',1.5,'ButtonDownFcn',@obj.lineHit,'visible','off'};
            tArgs = {'Rotation',270,'HorizontalAlignment','right','visible','off'};
            for i = 1:8
                obj.hChannelSurfs(i) = surface('Parent',obj.hAx1,'XData',(i-1)*4+[1.5 3.5],sArgs{:},'UserData',i);
                obj.hChannelLines(i*2-1) = line('Parent',obj.hAx1,'XData',(i-1)*4+[1.5 1.5],lArgs{:},'UserData',struct('ch',i,'ind',1));
                obj.hChannelLines(i*2) = line('Parent',obj.hAx1,'XData',(i-1)*4+[3.5 3.5],lArgs{:},'UserData',struct('ch',i,'ind',2));
                obj.hChannelTexts(i) = text((i-1)*4+2.5,-1900,sprintf('CH%d',i),'Parent',obj.hAx1,tArgs{:});
            end
            for i = 9:16
                obj.hChannelSurfs(i) = surface('Parent',obj.hAx2,'XData',(i-9)*4+[1.5 3.5],sArgs{:},'UserData',i);
                obj.hChannelLines(i*2-1) = line('Parent',obj.hAx2,'XData',(i-9)*4+[1.5 1.5],lArgs{:},'UserData',struct('ch',i,'ind',1));
                obj.hChannelLines(i*2) = line('Parent',obj.hAx2,'XData',(i-9)*4+[3.5 3.5],lArgs{:},'UserData',struct('ch',i,'ind',2));
                obj.hChannelTexts(i) = text((i-9)*4+2.5,-1900,sprintf('CH%d',i),'Parent',obj.hAx2,tArgs{:});
            end           
            obj.drawSelection();
            
            obj.hDLis = addlistener(obj.hFpga,'ObjectBeingDestroyed',@(varargin)obj.delete);
            
            obj.Visible = true;
        end
        
        function delete(obj)
            obj.stop();
            most.idioms.safeDeleteObj(obj.hTimer);
            most.idioms.safeDeleteObj(obj.hDLis);
        end
        
        function init(obj)
            obj.triggerMode = obj.triggerMode;
            obj.triggerAnalogLevel = obj.triggerAnalogLevel;
            obj.triggerWalk = obj.triggerWalk;
            obj.triggerAutoRollover = 8*2;
        end
    end
    
    methods
        function start(obj)
            obj.stop(); % reset sampler system on FPGA
            obj.hFpga.fifo_NI5772SampleToHost.configure(obj.PACKET_SIZE_UINT64 * obj.bufferSizePackets);
            obj.hFpga.fifo_NI5772SampleToHost.start();
            obj.flushFifo();
            obj.hFpga.NI577xEnableSampling = true;
            obj.hTimer.Period = round((1/obj.updateRate)*1000)/1000; % timer resolution is limited to 1ms
            start(obj.hTimer);
        end
        
        function abort(obj)
            obj.stop();
        end
        
        function stop(obj)
            stop(obj.hTimer);
            obj.triggerRate = [];
            obj.hFpga.NI577xEnableSampling = false;
            obj.flushFifo();
            obj.hFpga.fifo_NI5772SampleToHost.stop();
            obj.inputBufferUint64 = uint64.empty(0,1);
        end
        
        function writeChannelConfig(obj,varargin)
            for i = 1:16
                p = floor((i-1)/8);
                v = i - p * 8 - 1;
                obj.hFpga.NI5772ChannelParamsPhysCH = p;
                obj.hFpga.NI5772ChannelParamsVirtCH = v;
                obj.hFpga.NI5772ChannelParamsStartSample = obj.hChannelTable.Data{i,4};
                obj.hFpga.NI5772ChannelParamsEndSample = obj.hChannelTable.Data{i,5};
                obj.hFpga.NI5772ChannelParamsWrite = true;
            end
        end
        
        function showAll(obj,varargin)
            obj.channelSettings = arrayfun(@(x)struct('show',true,'bounds',max(min(x.bounds,47),4)),obj.channelSettings);
        end
        
        function hideAll(obj,varargin)
            obj.channelSettings = arrayfun(@(x)setfield(x,'show',false),obj.channelSettings);
        end
        
        function saveConfig(obj,varargin)
            if nargin ~= 2
                [filename,pathname] = uiputfile('.mat','Choose filename to save channel settings to','channelSettings.mat');
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            else
                filename = varargin{1};
            end
            
            channelSettings = obj.channelSettings;
            triggerMode = obj.triggerMode;
            triggerAnalogLevel = obj.triggerAnalogLevel;
            triggerWalk = obj.triggerWalk;
            triggerAutoRollover = obj.triggerAutoRollover;
            save(filename,'channelSettings','triggerMode','triggerAnalogLevel','triggerWalk','triggerAutoRollover');
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
            nms = fieldnames(cs);
            for i = 1:numel(nms)
                obj.(nms{i}) = cs.(nms{i});
            end
        end
    end
    
    methods (Hidden)
        function keyFunc(obj,src,evt)
            switch evt.Key
                case 'uparrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        obj.triggerWalk = min(30,n+1);
                    end
                case 'downarrow'
                    n = str2num(src.String);
                    if ~isempty(n) && ~isnan(n)
                        obj.triggerWalk = max(0,n-1);
                    end
            end
        end
        
        function readSamples(obj,varargin)
            obj.triggerRate = double(obj.hFpga.NI5771TriggerIterationsCount)/double(obj.hFpga.NI5771TriggerMeasurePeriod) * obj.FPGA_SYS_CLOCK_RATE;
            
            data = obj.hFpga.fifo_NI5772SampleToHost.readAll();
            obj.inputBufferUint64 = vertcat(obj.inputBufferUint64,data);
            
            if ~isempty(obj.inputBufferUint64)
                % look for magic number to make sure we are in sync
                nD = 0;
                v = typecast(obj.inputBufferUint64(1), 'uint32');
                while ~isempty(obj.inputBufferUint64) && v(1) ~= obj.MAGIC_NUMBER
                    obj.inputBufferUint64(1) = [];
                    nD = nD + 1;
                    v = typecast(obj.inputBufferUint64(1), 'uint32');
                end
                if nD
                    fprintf('Data was out of sync! %d elements were discarded.\n', nD);
                end
            end
            
            numFullPacketElements = floor(length(obj.inputBufferUint64)/obj.PACKET_SIZE_UINT64)*obj.PACKET_SIZE_UINT64;
            
            if numFullPacketElements == 0
                obj.hLineCh1.YData = nan(1,51);
                obj.hLineCh2.YData = nan(1,51);
                return
            end
            
            data = obj.inputBufferUint64(numFullPacketElements-(obj.PACKET_SIZE_UINT64-1):numFullPacketElements);
            obj.inputBufferUint64(1:numFullPacketElements) = [];
            
            v = typecast(data(1), 'uint32');
            assert(v(1) == obj.MAGIC_NUMBER,'Still not in sync!');
            triggerPosition = v(2);
            data = single(typecast(data(2:end),'int16'));
            obj.hLineCh1.YData = [nan(1,3-triggerPosition) data(1:48)' nan(1,triggerPosition)];
            obj.hLineCh2.YData = [nan(1,3-triggerPosition) data(49:end)' nan(1,triggerPosition)];
        end
        
        function hFigCloseRequestFcn(obj,src,evt)
            src.Visible = 'off';
            obj.stop();
        end
    end
    
    %% Private methods
    methods (Access = private)        
        function flushFifo(obj)
            obj.hFpga.NI577xEnableSampling = false;
            
            data = NaN;
            timeout = 1; % in seconds
            start = tic();
            while toc(start)<timeout && ~isempty(data) % flush fifo
                data = obj.hFpga.fifo_NI5772SampleToHost.readAll();
                pause(10e-3);
            end
            assert(isempty(data),'NI5771Sampler: Failed to flush fifo');
        end
        
        function surfHit(obj,src,evt)
            persistent ch
            persistent ax
            
            if strcmp(evt.EventName, 'Hit')
                ch = src.UserData;
                ax = src.Parent;
                set(obj.hFig,'WindowButtonMotionFcn',@obj.surfHit,'WindowButtonUpFcn',@obj.surfHit);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                w = diff(obj.channelSettings(ch).bounds);
                s = round(ax.CurrentPoint(1) - w/2);
                
                obj.channelSettings(ch).bounds = max(min([s s+w],47),4);
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
                bds = obj.channelSettings(ch).bounds;
                bds(ind) = round(ax.CurrentPoint(1));
                if bds(1) > bds(2)
                    bds(3-ind) = bds(ind);
                end
                obj.channelSettings(ch).bounds = max(min(bds,47),4);
            else
                set(obj.hFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
        end
        
        function updateTable(obj)
            s = arrayfun(@(x,y,s){x y s.show s.bounds(1) s.bounds(2)},[zeros(1,8) ones(1,8)],1:16,obj.channelSettings,'UniformOutput',false);
            obj.hChannelTable.Data = vertcat(s{:});
        end
        
        function tableCb(obj,~,evt)
            switch evt.Indices(2)
                case 3
                    if ~obj.channelSettings(evt.Indices(1)).show && evt.NewData
                        bds = obj.channelSettings(evt.Indices(1)).bounds;
                        obj.channelSettings(evt.Indices(1)).bounds = max(min(bds,47),4);
                    end
                    obj.channelSettings(evt.Indices(1)).show = evt.NewData;
                case {4 5}
                    ind = evt.Indices(2) - 3;
                    bds = obj.channelSettings(evt.Indices(1)).bounds;
                    bds(ind) = evt.NewData;
                    if bds(1) > bds(2)
                        bds(3-ind) = bds(ind);
                    end
                    obj.channelSettings(evt.Indices(1)).bounds = bds;
            end
        end
        
        function drawSelection(obj)
            for i = 1:16
                vis = obj.tfMap(obj.channelSettings(i).show && obj.channelSettings(i).bounds(1) > 3 && obj.channelSettings(i).bounds(2) < 48);
                xd = [obj.channelSettings(i).bounds(1)-.5 obj.channelSettings(i).bounds(2)+.5];
                
                obj.hChannelSurfs(i).XData = xd;
                obj.hChannelSurfs(i).Visible = vis;
                
                obj.hChannelLines(i*2-1).XData = [xd(1) xd(1)];
                obj.hChannelLines(i*2-1).Visible = vis;
                
                obj.hChannelLines(i*2).XData = [xd(2) xd(2)];
                obj.hChannelLines(i*2).Visible = vis;
                
                obj.hChannelTexts(i).Position(1) = mean(xd);
                obj.hChannelTexts(i).Visible = vis;
            end
        end        
    end
    
    %% Property Getter/Setter
    methods
        function set.channelSettings(obj,v)
            obj.channelSettings = v;
            obj.updateTable();
            obj.drawSelection();
        end
        
        function set.active(obj,val)
            obj.active = val;
            
            if obj.active
                str = 'Stop Monitoring';
                obj.start();
            else
                str = 'Start Monitoring';
                obj.stop();
            end
            obj.pbStart.String = str;
        end
        
        function set.triggerMode(obj,val)
            assert(ismember(val,{'Auto','Digital','Analog'}));
            obj.hFpga.NI5772TriggerMode = val;
            
            obj.etNI5771TriggerAnalogLevel.Enable = 'off';
            obj.etNI5771TriggerAutoRollover.Enable = 'off';
            switch val
                case 'Auto'
                    obj.etNI5771TriggerAutoRollover.Enable = 'on';
                case 'Digital'
                    % No-Op
                case 'Analog'
                    obj.etNI5771TriggerAnalogLevel.Enable = 'on';
                otherwise
                    assert(false);
            end
        end
        
        function val = get.triggerMode(obj)
            val = obj.hFpga.NI5772TriggerMode;
        end
        
        function set.triggerAnalogLevel(obj,val)
            obj.hFpga.NI5772TriggerAnalogLevel = val;
        end
        
        function val = get.triggerAnalogLevel(obj)
            val = obj.hFpga.NI5772TriggerAnalogLevel;
        end
        
        function set.triggerWalk(obj,val)
%             lim = [-2 13] * 8;
%             assert(lim(1)<=val && val<=lim(2),'Trigger Walk has to be an integer in range [%d..%d]. Invalid value received: %d',lim(1),lim(2));
%             assert(floor(val/8)==val/8,'Trigger Walk has to be an integer multiple of 8');
            obj.hFpga.NI5772TriggerWalk = val;
        end
        
        function val = get.triggerWalk(obj)
            val = obj.hFpga.NI5772TriggerWalk;
        end
        
        function set.triggerAutoRollover(obj,val)
%             assert(val >= 16,'Trigger Auto Rollover needs to be greater than 8');
%             assert(floor(val/8) == val/8,'Trigger Auto Rollver needs to be a multiple of 8');
%             val = floor(val/8) - 1;
            obj.hFpga.NI5772TriggerAutoRollover = val;
        end
        
        function val = get.triggerAutoRollover(obj)
            val = obj.hFpga.NI5772TriggerAutoRollover;
%             val = (val+1)*8;
        end
    end
end


%--------------------------------------------------------------------------%
% NI5772Sampler.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
