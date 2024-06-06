classdef NI5771Sampler < handle    
    properties (Hidden)
        hFpga;
        hScan;
    end
    
    properties (SetObservable)
        gain;
        offset;
        showPhotonHistogram = false;
        
        hSIChannel1;
        hSIChannel2;
        hSIChannel3;
        hSIChannel4;
        
        hPhotonDiscriminatorChannel0;
        hPhotonDiscriminatorChannel1;
        
        twoGroups = true;
        
        hListeners;
    end
    
    properties (Access = private)        
        hTimerDma;
        hTimerHist;
        buffer;
        bufferIdx;
        requestedSamples;
        acquisitionCompleted;
        callback;
        
        samplingNow = false;
        hFigHist;
        hAxHistChannel0;
        hAxHistChannel1;
        hBarHistChannel0;
        hBarHistChannel1;
        
        silentAcquisition;
    end
    
    events
        configurationChanged
    end
    
    %% LifeCycle
    methods
        function obj = NI5771Sampler(hFpga,hScan2D)
            assert(isprop(hFpga,'fifo_NI5771SampleToHost'),'Invalid configuration for NI5771 photon counting');
            obj.hFpga = hFpga;
            obj.hScan = hScan2D;
            
            obj.hFpga.channelsInvert = obj.hScan.mdfData.channelsInvert;
            
            obj.initNI5771();
            
            obj.hSIChannel1 = scanimage.guis.photondiscriminator.NI5771Sampler.SIChannel(obj,1);
            obj.hSIChannel2 = scanimage.guis.photondiscriminator.NI5771Sampler.SIChannel(obj,2);
            obj.hSIChannel3 = scanimage.guis.photondiscriminator.NI5771Sampler.SIChannel(obj,3);
            obj.hSIChannel4 = scanimage.guis.photondiscriminator.NI5771Sampler.SIChannel(obj,4);
            
            obj.hPhotonDiscriminatorChannel0 = scanimage.guis.photondiscriminator.NI5771Sampler.PhotonDiscriminator(obj,0);
            obj.hPhotonDiscriminatorChannel1 = scanimage.guis.photondiscriminator.NI5771Sampler.PhotonDiscriminator(obj,1);
            
            obj.hListeners = [obj.hListeners addlistener(obj.hSIChannel1,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            obj.hListeners = [obj.hListeners addlistener(obj.hSIChannel2,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            obj.hListeners = [obj.hListeners addlistener(obj.hSIChannel3,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            obj.hListeners = [obj.hListeners addlistener(obj.hSIChannel4,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            
            obj.hListeners = [obj.hListeners addlistener(obj.hPhotonDiscriminatorChannel0,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            obj.hListeners = [obj.hListeners addlistener(obj.hPhotonDiscriminatorChannel1,'configurationChanged',@(varargin)notify(obj,'configurationChanged'))];
            
            prepareHistogram();
            
            obj.twoGroups = obj.twoGroups; % configure FPGA for 16samples per laser pulse
            
            function disablePhotonHistogram(varargin)
                obj.showPhotonHistogram = false;
            end
            
            function prepareHistogram()
                obj.hTimerDma = timer('Name','NI5771 Sampler Photon Counting DMA transfer','ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@obj.readSamples);
                obj.hTimerHist = timer('Name','NI5771 Sampler Photon Counting Histogram','ExecutionMode','fixedSpacing','Period',1,'TimerFcn',@obj.refreshPhotonHistogram);
                obj.hFigHist = figure('MenuBar','none','NumberTitle','off','Name','Photon Timing Histogram','Visible','off','CloseRequestFcn',@disablePhotonHistogram);
                obj.hAxHistChannel0 = subplot(2,1,1);
                obj.hAxHistChannel1 = subplot(2,1,2);
                obj.hBarHistChannel0 = bar(obj.hAxHistChannel0,0:15,zeros(1,16),'BarWidth',1,'LineStyle','none','FaceColor',most.idioms.vidrioBlue());
                obj.hBarHistChannel1 = bar(obj.hAxHistChannel1,0:15,zeros(1,16),'BarWidth',1,'LineStyle','none','FaceColor',most.idioms.vidrioBlue());
                obj.hAxHistChannel0.XLim = [-0.5 15.5];
                obj.hAxHistChannel0.XLim = [-0.5 15.5];
                obj.hAxHistChannel0.XTick = 0:15;
                obj.hAxHistChannel1.XTick = 0:15;
                obj.hAxHistChannel1.XLim = [-0.5 15.5];
                obj.hAxHistChannel1.XLim = [-0.5 15.5];
                title(obj.hAxHistChannel0,sprintf('Photon Arrival Time Histogram\nChannel0'));
                title(obj.hAxHistChannel1,'Channel1');
                box(obj.hAxHistChannel0,'on');
                box(obj.hAxHistChannel1,'on');
                %xlabel(obj.hAxHistChannel0,'Sample Number');
                ylabel(obj.hAxHistChannel0,'Number of Photons');
                xlabel(obj.hAxHistChannel1,'Sample Number');
                ylabel(obj.hAxHistChannel1,'Number of Photons');
            end
        end
        
        function delete(obj)
            % we don't own the hFpga handle, so don't delete it here
            most.idioms.safeDeleteObj(obj.hListeners);
            most.idioms.safeDeleteObj(obj.hTimerDma);
            most.idioms.safeDeleteObj(obj.hTimerHist);
            most.idioms.safeDeleteObj(obj.hFigHist);
            most.idioms.safeDeleteObj(obj.hSIChannel1);
            most.idioms.safeDeleteObj(obj.hSIChannel2);
            most.idioms.safeDeleteObj(obj.hSIChannel3);
            most.idioms.safeDeleteObj(obj.hSIChannel4);
            most.idioms.safeDeleteObj(obj.hPhotonDiscriminatorChannel0);
            most.idioms.safeDeleteObj(obj.hPhotonDiscriminatorChannel1);
        end
        
        function s = saveStruct(obj)
            s = struct();
            s.gain = obj.gain;
            s.offset = obj.offset;
            s.showPhotonHistogram = obj.showPhotonHistogram;
            s.twoGroups = obj.twoGroups;
            
            s.hPhotonDiscriminatorChannel0 = obj.hPhotonDiscriminatorChannel0.saveStruct();
            s.hPhotonDiscriminatorChannel1 = obj.hPhotonDiscriminatorChannel1.saveStruct();
        end
        
        function loadStruct(obj,s)
            assert(isa(s,'struct'));
            
            props = fieldnames(s);
            
            for idx = 1:length(props)
                prop = props{idx};
                try
                    if isobject(obj.(prop))
                        obj.(prop).loadStruct(s.(prop));
                    else
                        obj.(prop) = s.(prop);
                    end
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
    end
    
    %% User methods
    methods
        function nSamples = acquireSampleDataSet(obj,callback,nSamples,trigger,markPeriodClock,silent)
            if nargin<3 || isempty(nSamples)
                nSamples = 1e6;
            end
            
            if nargin<4 || isempty(trigger)
                trigger = 'none';
            end
            
            if nargin<5 || isempty(markPeriodClock)
                markPeriodClock = false;
            end
            
            if nargin<6 || isempty(silent)
                silent = false;
            end
            
            assert(~obj.samplingNow,'Sampling already in progress');
            
            validateattributes(callback,{'function_handle'},{'scalar'})
            validateattributes(trigger,{'char'},{'vector'});
            validateattributes(nSamples,{'numeric'},{'scalar','positive','integer'});
            validateattributes(markPeriodClock,{'numeric','logical'},{'scalar','binary'});
            validateattributes(silent,{'numeric','logical'},{'scalar','binary'});
            triggerList = {'None','Frame Clock','Period Clock','Beam Clock','Acquisition Trigger','Volume Trigger'};
            triggerIdx = find(strcmpi(trigger,triggerList));
            assert(~isempty(triggerIdx),'Invalid trigger name: %s',trigger);
            trigger = triggerList{triggerIdx}; %correct capitalization
            
            nSamples2Ch = nSamples*2;
            nSamples2Ch = ceil(nSamples2Ch/(8*8))*8*8; %memory blocks of 512bits = 64bytes
            nSamples2Ch = min(nSamples2Ch,2^31); % amount of memory available on FPGA
            assert(nSamples2Ch > 0);
            
            nSamples = nSamples2Ch / 2;
            
            obj.callback = callback;
            obj.silentAcquisition = silent;
            
            obj.buffer = {};%zeros(nSamples,1,'int8'); %preallocate buffer
            obj.bufferIdx = 0;
            obj.acquisitionCompleted = false;
            
            % reset sampler
            obj.hFpga.NI5771PhotonCountingSamplerReset = true;
            obj.hFpga.NI5771PhotonCountingSamplerReset = false;
            
            obj.hFpga.NI5771PhotonCountingSamplerMarkPeriodClock = markPeriodClock;
            obj.hFpga.NI5771PhotonCountingSamplerAcquireNSamples = nSamples2Ch;
            obj.requestedSamples = nSamples;
            
            obj.flushFifo();
            
            %ensure that DMA buffer is empty            
            obj.hFpga.NI5771PhotonCountingSamplerTriggerSelect = trigger;
            obj.hFpga.NI5771PhotonCountingSamplerDMATransferSafetyMargin = 1000; % ensure the imaging buffer is not overflowing
            
            obj.hTimerDma.Period = 0.05;
            obj.hFpga.fifo_NI5771SampleToHost.configure(3e9/8 * obj.hTimerDma.Period * 5);
            obj.hFpga.fifo_NI5771SampleToHost.start();
            obj.flushFifo();
            
            obj.samplingNow = true;
            obj.hFpga.NI5771PhotonCountingSamplerDoStart = true;
            start(obj.hTimerDma);
        end
        
        function [data,nSamples_] = acquireSampleDataSetBlocking(obj,varargin)            
            data = [];
            nSamples_ = obj.acquireSampleDataSet(@callbackFcn,varargin{:});
            
            while obj.samplingNow
                pause(0.01);
            end
            
            assert(size(data,1)==nSamples_,'Expected to acquire %d samples, but received %d',nSamples_,size(data,1));
                
            function callbackFcn(data_)
                data = data_;
            end
        end
        
        function abort(obj)
            stop(obj.hTimerDma);
            
            obj.hFpga.NI5771PhotonCountingSamplerReset = true;
            obj.hFpga.NI5771PhotonCountingSamplerReset = false;
            
            obj.hFpga.fifo_NI5771SampleToHost.stop();
            obj.requestedSamples = [];
            obj.buffer = {};
            obj.bufferIdx = [];
            
            obj.samplingNow = false;
        end
        
        function calibrateInputs(obj,nSamples)
            if nargin<2 || isempty(nSamples)
                nSamples = 10e6;
            end
            
            hFig = figure;
            hAx = axes('Parent',hFig);
            hLine = line('Parent',hAx,'XData',NaN,'YData',NaN);
            
            trigger = 'None';
            silent = true;
            
            obj.offset = 0;
            
            offsets = [0;15]; % initial guesses
            ps = zeros(0,2);
            
            idx = 0;
            while true
                idx = idx + 1;
                %fiddle with gain of channel 0;
                
                if idx <= 2 
                    offset_ = offsets(idx);
                else
                    do = diff(offsets(end-1:end));
                    dp = diff(ps(end-1:end,2));
                    
                    offset_ = offsets(end) - ps(end,2) * do / dp;
                    offset_ = round(offset_);
                    
                    if ismember(offset_, offsets)
                        break
                    end
                end
                
                obj.setChannelOffset(0,offset_);
                p_ = interChannelLinearRegression();
                fprintf('SetValue: %d Slope = %f Offset = %f\n',offset_,p_(1),p_(2));
                
                offsets(idx) = offset_;
                ps(idx,:) = p_;
            end
            
            % fuzz around offset
            offsets = offset_ + (-2:2);
            ps = zeros(length(offsets),2);
            for idx = 1:length(offsets)
                obj.setChannelOffset(0,offsets(idx));
                ps(idx,:) = interChannelLinearRegression();
                fprintf('SetValue: %d Slope = %f Offset = %f\n',offsets(idx),ps(idx,1),ps(idx,2));
            end
            
            [p,idx] = min(abs(ps(:,2)));
            offset_ = offsets(idx);
            obj.setChannelOffset(0,offset_);
            
            fprintf('Offset found: %d, Residual error: %f\n',offset_,p);
            
            function p = interChannelLinearRegression()
               [data,nSamples] = obj.acquireSampleDataSetBlocking(nSamples,trigger,silent);
                data = reshape(data,2,[])';
                
                %throw out data that saturates digitizer
                datatype = class(data);
                overflowIdxs = any(data==intmax(datatype) | data==intmin(datatype),2);
                data(overflowIdxs,:) = [];
                
                odd = data(:,1);
                even = data(:,2);
                
                [odd,idxs] = sort(odd);
                even = even(idxs);
                
                [odd,ia] = unique(odd);
                even_mean = zeros(size(odd));
                
                idxs = zeros(numel(ia),2);
                idxs(:,1) = ia;
                idxs(:,2) = circshift(ia,-1)-1;
                idxs(end,2) = length(even);
                
                for jdx = 1:length(even_mean)
                    even_mean(jdx) = mean(even(idxs(jdx,1):idxs(jdx,2)));
                end
                
                hLine.XData = odd;
                hLine.YData = even_mean;
                
                p = polyfit(double(odd),even_mean,1); 
            end
        end
    end
    
    %% Hidden methods
    methods (Hidden)
        function readSamples(obj,src,evt)
            persistent hWb
            
            try
                requestedSamples2Ch = obj.requestedSamples*2;
                
                if ~obj.silentAcquisition && (isempty(hWb) || ~isvalid(hWb))
                    hWb = waitbar(0,'Fetching Samples...','CreateCancelBtn',@abortRead);
                end
                
                assert(~obj.hFpga.NI5771PhotonCountingSamplerDataLoss,'Data Loss occured during sampling.');
                
                if ~obj.hFpga.NI5771PhotonCountingSamplerIdle
                    return
                elseif ~obj.acquisitionCompleted
                    obj.hFpga.NI5771PhotonCountingDoStartSamplerTransfer = true;
                    obj.acquisitionCompleted = true;
                end
                
                [data_1, elementsremaining] = obj.hFpga.fifo_NI5771SampleToHost.read(1,0); % read 1 element with 0 timeout
                data_1 = uint64ToInt8Array(data_1);
                
                %obj.buffer(obj.bufferIdx+1:obj.bufferIdx+length(data_1)) = data_1; %append data
                obj.buffer{end+1,1} = data_1;
                obj.bufferIdx = obj.bufferIdx + length(data_1);
                
                if elementsremaining > 0
                    elementsToRead = min(elementsremaining,50e6 / 8); % don't reade more than 50MB at a time
                    data_2 = obj.hFpga.fifo_NI5771SampleToHost.read(elementsToRead,0); % read 1 element with 0 timeout
                    data_2 = uint64ToInt8Array(data_2);
                    
                    %obj.buffer(obj.bufferIdx+1:obj.bufferIdx+length(data_2)) = data_2; %append data
                    obj.buffer{end+1,1} = data_2;
                    obj.bufferIdx = obj.bufferIdx + length(data_2);
                end
                
                if ~obj.silentAcquisition
                    waitbar(obj.bufferIdx/requestedSamples2Ch,hWb);
                end
                
                if obj.bufferIdx >= requestedSamples2Ch
                    stop(obj.hTimerDma);
                    data = vertcat(obj.buffer{:});
                    obj.buffer = {};
                    abortRead();
                    data = reshape(data,2,[]);
                    data = data';
                    obj.executeCallback(data);
                end
            catch ME
                abortRead();
                most.idioms.reportError(ME);
                rethrow(ME);
            end
            
            function data = uint64ToInt8Array(data)
                data = typecast(reshape(data(:)',1,[]),'int8')';
            end
            
            function abortRead(varargin)
                obj.abort();
                most.idioms.safeDeleteObj(hWb);
            end
        end
        
        function refreshPhotonHistogram(obj,varargin)
            histDataChannel0 = obj.hFpga.NI5771PhotonCountingHistogramCh0; % fetch data from FPGA
            histDataChannel1 = obj.hFpga.NI5771PhotonCountingHistogramCh1; % fetch data from FPGA
            
            plotHist(obj.hAxHistChannel0,obj.hBarHistChannel0,histDataChannel0);
            plotHist(obj.hAxHistChannel1,obj.hBarHistChannel1,histDataChannel1);
            
            function plotHist(hAx,hHist,data_)
                if max(data_) == 0
                    hAx.YLim = [0 1];
                else
                    hAx.YLimMode = 'auto';
                end
                
                %% downsampling because digitizer has some weired noise on
                %% it
%                 data_ = reshape(data_(:),2,[]);
%                 data_ = sum(data_,1);
%                 data_ = repmat(data_,2,1);
%                 data_ = data_(:)';
                %% end downsampling
                
                hHist.XData = 0:(length(data_)-1);
                hHist.YData = data_;                
            end
        end
    end
    
    %% Private methods
    methods %(Access = private)        
        function executeCallback(obj,data)
            obj.callback(data);
        end
        
        function flushFifo(obj)
            obj.hFpga.NI5771PhotonCountingSamplerReset = true;
            pause(0.01);
            obj.hFpga.NI5771PhotonCountingSamplerReset = false; %need to reset
            
            data = NaN;
            timeout = 1; % in seconds
            start = tic();
            while toc(start)<timeout && ~isempty(data) % flush fifo
                data = obj.hFpga.fifo_NI5771SampleToHost.readAll();
                pause(10e-3);
            end
            assert(isempty(data),'NI5771Sampler: Failed to flush fifo');
        end
        
        function initNI5771(obj)
            obj.hFpga.sendAdapterModuleUserCommand(4,0,0); % deactivate TIS
            obj.hFpga.sendAdapterModuleUserCommand(1,0,0); % self calibrate
            obj.gain = 0;
            obj.offset = 0;
        end
        
        function setChannelGain(obj,ch,val)
            validateattributes(val,{'numeric'},{'integer','nonnegative','<',512})% 0x0000 .. 0x01FF
            assert(ismember(ch,[0,1]));
            
            val = uint16(val);
            obj.hFpga.sendAdapterModuleUserCommand(2,val,ch); % channel 0
        end
        
        function setChannelOffset(obj,ch,val)
            validateattributes(val,{'numeric'},{'integer','>=',-256,'<',256});
            assert(ismember(ch,[0,1]));
            
            if val < 0
                val = -val+255;
            end
            
            obj.hFpga.sendAdapterModuleUserCommand(3,val,ch); % channel 0
        end
    end
    
    %% Property Getter/Setter
    methods        
        function set.twoGroups(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.twoGroups = val;
            obj.hFpga.NI5771PhotonCountingTwoGroups = val;
        end
        
        function set.gain(obj,val)
            obj.setChannelGain(0,val);
            obj.setChannelGain(1,val);
            
            obj.gain = val;
        end
        
        function set.offset(obj,val)
            obj.setChannelOffset(0,val);
            obj.setChannelOffset(1,val);
            obj.offset = val;
        end
        
        function set.showPhotonHistogram(obj,val)
            oldVal = obj.showPhotonHistogram;
            
            val = logical(val);
            
            if val && val~=oldVal
                stop(obj.hTimerHist);
                obj.hTimerHist.Period = 0.5;
                obj.hFpga.NI5771PhotonCountingHistogramSampleCount = 35e6;
                obj.refreshPhotonHistogram();
                start(obj.hTimerHist);
                obj.hFigHist.Visible = 'on';
            elseif ~val
                stop(obj.hTimerHist);
                obj.hFigHist.Visible = 'off';                
            end
            
            obj.showPhotonHistogram = val;
        end
    end
end
      

%--------------------------------------------------------------------------%
% NI5771Sampler.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
