classdef NI5771Sampler < most.Gui
    properties
        updateRate = 15;
        bufferSizePackets = 100;        
        started = false;
    end
    
    properties (Constant)
        PACKET_SIZE_UINT64 = 9;
    end
    
    properties (Dependent, SetObservable)
        NI5771TriggerMode;
        NI5771TriggerAnalogLevel;
        NI5771TriggerWalk;
        NI5771TriggerAutoRollover;
        NI5771SampleMaskChannel1;
        NI5771SampleMaskChannel2;
        NI5771SampleMaskChannel3;
        NI5771SampleMaskChannel4;
        NI5771ChannelScaleByPowerOf2;
    end
    
    properties (Hidden, SetAccess = private, SetObservable)
        hContainers;
        hAx1;
        hAx2;
        hLineCh1;
        hLineCh2;
        hPatchMaskCh1;
        hPatchMaskCh2;
        hPatchMaskCh3;
        hPatchMaskCh4;
        hFpga;
        hAcq;
        inputBufferUint64;
        hTimer;
        triggerRate = 0;
    end
    
    properties (Hidden, Constant)
        FPGA_SYS_CLOCK_RATE = 200e6;
    end
    
    %% LifeCycle
    methods
        function obj = NI5771Sampler(hFpga)
            %obj.hAcq = hAcq;
            obj.hFpga = hFpga;
            
            obj.hTimer = timer('Name','NI5771 Sampler','ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@obj.readSamples);
            obj.makeFigure();
            obj.init();
        end
        
        function makeFigure(obj)
            obj.hFig.Name = 'NI5771 Sample configuration';
            obj.hFig.CloseRequestFcn = @obj.hFigCloseRequestFcn;
            obj.hContainers.main = most.idioms.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                obj.hContainers.left = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');                
                obj.hContainers.right = most.idioms.uiflowcontainer('Parent',obj.hContainers.main,'FlowDirection','TopDown');
                    obj.hContainers.right.WidthLimits = [220 220];
                    obj.hContainers.pnTrigger = uipanel('Parent',obj.hContainers.right,'Title','Trigger Configuration');
                    obj.hContainers.pnTrigger.HeightLimits = [135 135];
                        obj.hContainers.pnTriggerFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTrigger,'FlowDirection','TopDown');
                            obj.hContainers.pnTriggerLine1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine3 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine4 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnTriggerLine5 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnTriggerFl,'FlowDirection','LeftToRight');
                    obj.hContainers.pnMask = uipanel('Parent',obj.hContainers.right,'Title','Channel Configuration');
                    obj.hContainers.pnMask.HeightLimits = [135 135];
                        obj.hContainers.pnMaskFl = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMask,'FlowDirection','TopDown');
                            obj.hContainers.pnMaskLine1 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnMaskLine2 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnMaskLine3 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnMaskLine4 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
                            obj.hContainers.pnMaskLine5 = most.idioms.uiflowcontainer('Parent',obj.hContainers.pnMaskFl,'FlowDirection','LeftToRight');
            
                            
            obj.addUiControl(...
                'Parent',obj.hContainers.right,...
                'Tag','pbStart',...
                'Style','pushbutton',...
                'String','Start Monitoring',...
                'Callback',@(src,evt)obj.toggleStart);
            set(obj.pbStart,'HeightLimits',[50,50]);
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine1,'Style','text','String','Trigger Walk','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine1,...
                'Tag','etNI5771TriggerWalk',...
                'Style','edit',...
                'Bindings',{obj 'NI5771TriggerWalk' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine2,'Style','text','String','Trigger Mode','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine2,...
                'Tag','pmTriggerMode',...
                'Style','popupmenu',...
                'String',{'Auto','Digital','Analog'},...
                'Bindings',{obj 'NI5771TriggerMode' 'Choice'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine3,'Style','text','String','Analog Level','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine3,...
                'Tag','etNI5771TriggerAnalogLevel',...
                'Style','edit',...
                'Bindings',{obj 'NI5771TriggerAnalogLevel' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine4,'Style','text','String','Auto Rollover','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine4,...
                'Tag','etNI5771TriggerAutoRollover',...
                'Style','edit',...
                'Bindings',{obj 'NI5771TriggerAutoRollover' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnTriggerLine5,'Style','text','String','Trigger Rate (MHz)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnTriggerLine5,...
                'Tag','etTriggerRate',...
                'Style','edit',...
                'Enable','off',...
                'Bindings',{obj 'triggerRate' 'Value' '%1.3f', 'Scaling', 1e-6});
            
            uicontrol('Parent',obj.hContainers.pnMaskLine1,'Style','text','String','Channel*2^x','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnMaskLine1,...
                'Tag','etNI5771ChannelScaleByPowerOf2',...
                'Style','edit',...
                'Bindings',{obj 'NI5771ChannelScaleByPowerOf2' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnMaskLine2,'Style','text','String','Mask Ch1 (PMT1)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnMaskLine2,...
                'Tag','etNI5771SampleMaskChannel1',...
                'Style','edit',...
                'Bindings',{obj 'NI5771SampleMaskChannel1' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnMaskLine3,'Style','text','String','Mask Ch2 (PMT2)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnMaskLine3,...
                'Tag','etNI5771SampleMaskChannel2',...
                'Style','edit',...
                'Bindings',{obj 'NI5771SampleMaskChannel2' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnMaskLine4,'Style','text','String','Mask Ch3 (PMT1)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnMaskLine4,...
                'Tag','etNI5771SampleMaskChannel3',...
                'Style','edit',...
                'Bindings',{obj 'NI5771SampleMaskChannel3' 'Value'});
            
            uicontrol('Parent',obj.hContainers.pnMaskLine5,'Style','text','String','Mask Ch4 (PMT2)','HorizontalAlignment','right');
            obj.addUiControl(...
                'Parent',obj.hContainers.pnMaskLine5,...
                'Tag','etNI5771SampleMaskChannel4',...
                'Style','edit',...
                'Bindings',{obj 'NI5771SampleMaskChannel4' 'Value'});
            
            obj.hAx1 = axes('Parent',obj.hContainers.left,'Box','on','XLim',[1 24],'YLim',[-128 127],'XGrid','on','XTick',1:8:24,'XMinorGrid','on','YGrid','on');
            obj.hAx1.XRuler.MinorTick = 1:24;
            title(obj.hAx1,'PMT 1','FontWeight','normal');
            ylabel(obj.hAx1,'Counts');
            
            obj.hAx2 = axes('Parent',obj.hContainers.left,'Box','on','XLim',[1 24],'YLim',[-128 127],'XGrid','on','XTick',1:8:24,'XMinorGrid','on','YGrid','on');
            obj.hAx2.XRuler.MinorTick = 1:24;
            title(obj.hAx2,'PMT 2','FontWeight','normal');
            xlabel(obj.hAx2,'Samples');
            ylabel(obj.hAx2,'Counts');
            
            alpha = 0.2;
            channelColors = [0 0 0;1 0 0;0 1 0;0 0 1];
            obj.hLineCh1 = line('Parent',obj.hAx1,'XData',NaN,'YData',NaN,'Color',[0.3 0.3 1]);
            obj.hLineCh2 = line('Parent',obj.hAx2,'XData',NaN,'YData',NaN,'Color',[0.3 0.3 1]);
            obj.hPatchMaskCh1 = patch('Parent',obj.hAx1,'FaceColor',channelColors(1,:),'FaceAlpha',alpha,'EdgeColor','none');
            obj.hPatchMaskCh2 = patch('Parent',obj.hAx2,'FaceColor',channelColors(2,:),'FaceAlpha',alpha,'EdgeColor','none');
            obj.hPatchMaskCh3 = patch('Parent',obj.hAx1,'FaceColor',channelColors(3,:),'FaceAlpha',alpha,'EdgeColor','none');
            obj.hPatchMaskCh4 = patch('Parent',obj.hAx2,'FaceColor',channelColors(4,:),'FaceAlpha',alpha,'EdgeColor','none');            
            obj.drawSelection();
            
            channelColors = [0 0 0;1 0 0;0 1 0;0 0 1];
            channelColors = min(channelColors + (1-alpha),1);
            obj.etNI5771SampleMaskChannel1.hCtl.BackgroundColor = channelColors(1,:);
            obj.etNI5771SampleMaskChannel2.hCtl.BackgroundColor = channelColors(2,:);
            obj.etNI5771SampleMaskChannel3.hCtl.BackgroundColor = channelColors(3,:);
            obj.etNI5771SampleMaskChannel4.hCtl.BackgroundColor = channelColors(4,:);           
            
            obj.Visible = true;
        end
        
        function delete(obj)
            obj.stop();
            most.idioms.safeDeleteObj(obj.hTimer);
        end
        
        function init(obj)
            obj.NI5771TriggerMode = obj.NI5771TriggerMode;
            obj.NI5771TriggerAnalogLevel = obj.NI5771TriggerAnalogLevel;
            obj.NI5771TriggerWalk = obj.NI5771TriggerWalk;
            obj.NI5771TriggerAutoRollover = 8*2;
            obj.NI5771SampleMaskChannel1 = obj.NI5771SampleMaskChannel1;
            obj.NI5771SampleMaskChannel2 = obj.NI5771SampleMaskChannel2;
            obj.NI5771SampleMaskChannel3 = obj.NI5771SampleMaskChannel3;
            obj.NI5771SampleMaskChannel4 = obj.NI5771SampleMaskChannel4;
            obj.NI5771ChannelScaleByPowerOf2 = obj.NI5771ChannelScaleByPowerOf2;
        end
    end
    
    methods
        function toggleStart(obj)
            if obj.started
                obj.stop();
            else
                obj.start();
            end
        end
        
        function start(obj)
            obj.stop(); % reset sampler system on FPGA
            obj.hFpga.fifo_NI5771SampleToHost.configure(obj.PACKET_SIZE_UINT64 * obj.bufferSizePackets);
            obj.hFpga.fifo_NI5771SampleToHost.start();
            obj.flushFifo();
            obj.hFpga.NI5771EnableSampling = true;
            obj.hTimer.Period = round((1/obj.updateRate)*1000)/1000; % timer resolution is limited to 1ms
            obj.started = true;
            start(obj.hTimer);
        end
        
        function abort(obj)
            obj.stop();
        end
        
        function stop(obj)
            stop(obj.hTimer);
            obj.triggerRate = 0;
            obj.started = false;
            obj.hFpga.NI5771EnableSampling = false;
            obj.flushFifo();
            obj.hFpga.fifo_NI5771SampleToHost.stop();
            obj.inputBufferUint64 = uint64.empty(0,1);
        end
    end
    
    methods (Hidden)
        function readSamples(obj,varargin)
            obj.triggerRate = double(obj.hFpga.NI5771TriggerIterationsCount)/double(obj.hFpga.NI5771TriggerMeasurePeriod) * obj.FPGA_SYS_CLOCK_RATE;
            
            data = obj.hFpga.fifo_NI5771SampleToHost.readAll();
            obj.inputBufferUint64 = vertcat(obj.inputBufferUint64,data);
            
            numPackets = floor(length(obj.inputBufferUint64)/obj.PACKET_SIZE_UINT64)*obj.PACKET_SIZE_UINT64;
            
            if numPackets == 0
                obj.hLineCh1.XData = NaN;
                obj.hLineCh1.YData = NaN;
                
                obj.hLineCh2.XData = NaN;
                obj.hLineCh2.YData = NaN;
                return
            end
            
            data = obj.inputBufferUint64(1:numPackets);
            obj.inputBufferUint64(1:numPackets) = [];
            
            data = typecast(data,'int8');
            data = reshape(data,obj.PACKET_SIZE_UINT64*8,[]); % uint64 consists of 8 bytes
            shifts = data(1,:);
            
            if any(shifts>7)
                obj.stop();
                error('NI5771: Something bad happened during the data transfer. Stpped monitoring.');
            end
            
            for jdx = 1:length(shifts)
                % this loop is slow! Is there a better way to do this?
                data(:,jdx) = circshift(data(:,jdx),-shifts(jdx),1);
            end
            
            ch1 = data(2:33-8+1,:);
            ch2 = data(34:65-8+1,:);
            
%             ch1 = ch1(:,1);
%             ch2 = ch2(:,1);
            
            % Prepare for plotting
            t = single((1:size(ch1,1)))';
            t = repmat(t,1,size(ch1,2));
            t(end+1,:) = NaN;
            ch1 = single(ch1);
            ch2 = single(ch2);
            ch1(end+1,:) = NaN;
            ch2(end+1,:) = NaN;
            
            obj.hLineCh1.XData = t(:);
            obj.hLineCh1.YData = ch1(:);
            
            obj.hLineCh2.XData = t(:);
            obj.hLineCh2.YData = ch2(:);
        end
        
        function hFigCloseRequestFcn(obj,src,evt)
            src.Visible = 'off';
            obj.stop();
        end
    end
    
    %% Private methods
    methods (Access = private)        
        function flushFifo(obj)
            obj.hFpga.NI5771EnableSampling = false;
            
            data = NaN;
            timeout = 1; % in seconds
            start = tic();
            while toc(start)<timeout && ~isempty(data) % flush fifo
                data = obj.hFpga.fifo_NI5771SampleToHost.readAll();
                pause(10e-3);
            end
            assert(isempty(data),'NI5771Sampler: Failed to flush fifo');
        end
        
        function drawSelection(obj)
            setVertices(obj.NI5771SampleMaskChannel1,obj.hPatchMaskCh1,1);
            setVertices(obj.NI5771SampleMaskChannel2,obj.hPatchMaskCh2,2);
            setVertices(obj.NI5771SampleMaskChannel3,obj.hPatchMaskCh3,3);
            setVertices(obj.NI5771SampleMaskChannel4,obj.hPatchMaskCh4,4);
            
            function [faces,vertices] = setVertices(mask,hPatch,z)
                hAx = ancestor(hPatch,'axes');
                YLim = hAx.YLim;
                mask = mask(:);
                N = length(mask);
                
                vertices = nan(4*N,3);
                vertices(1:N,:)       = [mask-0.5,repmat(YLim(1),N,1),repmat(z,N,1)];
                vertices(N+1:2*N,:)   = [mask+0.5,repmat(YLim(1),N,1),repmat(z,N,1)];
                vertices(2*N+1:3*N,:) = [mask+0.5,repmat(YLim(2),N,1),repmat(z,N,1)];
                vertices(3*N+1:4*N,:) = [mask-0.5,repmat(YLim(2),N,1),repmat(z,N,1)];
                
                faces = [(1:N)', (N+1:2*N)', (2*N+1:3*N)', (3*N+1:4*N)'];
                
                hPatch.Faces = faces;
                hPatch.Vertices = vertices;
                hPatch.FaceAlpha = .2;
            end
        end        
    end
    
    %% Property Getter/Setter
    methods        
        function set.started(obj,val)
            obj.started = val;
            
            if obj.started
                str = 'Stop Monitoring';
            else
                str = 'Start Monitoring';
            end
            obj.pbStart.String = str;
        end
        
        function set.NI5771TriggerMode(obj,val)
            assert(ismember(val,{'Auto','Digital','Analog'}));
            obj.hFpga.NI5771TriggerMode = val;
            
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
        
        function val = get.NI5771TriggerMode(obj)
            val = obj.hFpga.NI5771TriggerMode;
        end
        
        function set.NI5771TriggerAnalogLevel(obj,val)
            obj.hFpga.NI5771TriggerAnalogLevel = val;
        end
        
        function val = get.NI5771TriggerAnalogLevel(obj)
            val = obj.hFpga.NI5771TriggerAnalogLevel;
        end
        
        function set.NI5771TriggerWalk(obj,val)
            lim = [-2 13] * 8;
            assert(lim(1)<=val && val<=lim(2),'Trigger Walk has to be an integer in range [%d..%d]. Invalid value received: %d',lim(1),lim(2));
            assert(floor(val/8)==val/8,'Trigger Walk has to be an integer multiple of 8');
            obj.hFpga.NI5771TriggerWalk = val/8 + 2;
        end
        
        function val = get.NI5771TriggerWalk(obj)            
            val = (double(obj.hFpga.NI5771TriggerWalk) - 2)*8;
        end
        
        function set.NI5771TriggerAutoRollover(obj,val)
            assert(val >= 16,'Trigger Auto Rollover needs to be greater than 8');
            assert(floor(val/8) == val/8,'Trigger Auto Rollver needs to be a multiple of 8');
            val = floor(val/8) - 1;
            obj.hFpga.NI5771TriggerAutoRollover = val;
        end
        
        function val = get.NI5771TriggerAutoRollover(obj)
            val = obj.hFpga.NI5771TriggerAutoRollover;
            val = (val+1)*8;
        end
        
        function set.NI5771SampleMaskChannel1(obj,val)
            val(val<1)=[];
            val(val>24)=[];
            val(val~=floor(val)) = [];
            val = bitset(uint32(0),val);
            mask = uint32(0);
            for idx = 1:length(val)
                mask = bitor(mask,val(idx));
            end
            obj.hFpga.NI5771SampleMaskChannel0 = mask;
            
            obj.drawSelection();
        end
        
        function val = get.NI5771SampleMaskChannel1(obj)
            val = obj.hFpga.NI5771SampleMaskChannel0;
            val = bitget(val,1:32);
            val = find(val);
            if isempty(val)
                val = []; % we don't want to see 'zeros(0,1)' in the gui
            end
        end
        
        function set.NI5771SampleMaskChannel2(obj,val)
            val(val<1)=[];
            val(val>24)=[];
            val(val~=floor(val)) = [];
            val = bitset(uint32(0),val);
            val(end+1) = uint32(0);
            for idx = 2:length(val) 
                val(1) = bitor(val(1),val(idx));
            end
            val = val(1);
            obj.hFpga.NI5771SampleMaskChannel1 = val;
            
            obj.drawSelection();
        end
        
        function val = get.NI5771SampleMaskChannel2(obj)
            val = obj.hFpga.NI5771SampleMaskChannel1;
            val = bitget(val,1:32);
            val = find(val);
            if isempty(val)
                val = []; % we don't want to see 'zeros(0,1)' in the gui
            end
        end
        
        function set.NI5771SampleMaskChannel3(obj,val)
            val(val<1)=[];
            val(val>24)=[];
            val(val~=floor(val)) = [];
            val = bitset(uint32(0),val);
            mask = uint32(0);
            for idx = 1:length(val)
                mask = bitor(mask,val(idx));
            end
            obj.hFpga.NI5771SampleMaskChannel2 = mask;
            
            obj.drawSelection();
        end
        
        function val = get.NI5771SampleMaskChannel3(obj)
            val = obj.hFpga.NI5771SampleMaskChannel2;
            val = bitget(val,1:32);
            val = find(val);
            if isempty(val)
                val = []; % we don't want to see 'zeros(0,1)' in the gui
            end
        end
        
        function set.NI5771SampleMaskChannel4(obj,val)
            val(val<1)=[];
            val(val>24)=[];
            val(val~=floor(val)) = [];
            val = bitset(uint32(0),val);
            val(end+1) = uint32(0);
            for idx = 2:length(val) 
                val(1) = bitor(val(1),val(idx));
            end
            val = val(1);
            obj.hFpga.NI5771SampleMaskChannel3 = val;
            
            obj.drawSelection();
        end
        
        function val = get.NI5771SampleMaskChannel4(obj)
            val = obj.hFpga.NI5771SampleMaskChannel3;
            val = bitget(val,1:32);
            val = find(val);
            if isempty(val)
                val = []; % we don't want to see 'zeros(0,1)' in the gui
            end
        end
        
        function set.NI5771ChannelScaleByPowerOf2(obj,val)
            obj.hFpga.NI5771ChannelScaleByPowerOf2 = val;            
        end
        
        function val = get.NI5771ChannelScaleByPowerOf2(obj)
            val = obj.hFpga.NI5771ChannelScaleByPowerOf2;    
        end
    end
end


%--------------------------------------------------------------------------%
% NI5771Sampler.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
