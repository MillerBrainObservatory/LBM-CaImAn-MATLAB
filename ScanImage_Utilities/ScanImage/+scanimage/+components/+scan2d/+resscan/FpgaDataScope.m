classdef FpgaDataScope < scanimage.components.scan2d.interfaces.DataScope
    properties (SetObservable)
        trigger = 'None';
        triggerLineNumber = 1;
        triggerSliceNumber = 1;
        channel = 1;
        acquisitionTime = 0.1;
        triggerHoldOffTime = 0;
        callbackFcn = @(src,evt)plot(evt.data);
    end
    
    properties (SetObservable, SetAccess = protected)
        active = false;
        triggerAvailable = {'none','frame','slice','line'};
    end
    
    properties (Constant, Hidden)
        DATA_SIZE_BYTES = 4;
        FIFO_POLLING_PERIOD = 0.1;
    end
    
    properties (Hidden)
        maxAllowedDataRate = 30e6;
        displayPeriod = 60e-3;
        maxDataLength = 100e3;
    end
    
    properties (SetObservable,Dependent,SetAccess = protected)
        channelsAvailable;
        digitizerSampleRate;
        currentDataRate;
    end
    
    properties (Hidden, SetAccess = private)
        hFpga
        hScan2D
        hFifo
        acquisitionActive = false;
        fifoStarted = false;
        continuousAcqActive = false;
        lastDataReceivedTime = 0;
        hDataStream;
    end
    
    properties (SetAccess = private)
        hFifoPollingTimer;
        hContAcqTimer;
    end
    
    
    %% LifeCycle
    methods
        function obj = FpgaDataScope(hScan2D)
            if isa(hScan2D,'scanimage.components.scan2d.ResScan')
                obj.hFpga = hScan2D.hAcq.hFpga;
            elseif isa(hScan2D,'scanimage.components.scan2d.LinScan')
                obj.hDataStream = hScan2D.hAcq.hAI;
                if strcmpi(obj.hDataStream.streamMode,'fpga')
                    obj.hFpga = obj.hDataStream.hFpga;
                else
                    obj.delete();
                    return;
                end
            end
            
            obj.hScan2D = hScan2D;
            obj.hFifo = obj.hFpga.fifo_DataScopeTargetToHostU32;
            obj.hFifoPollingTimer = timer('Name','DataScope Polling Timer');
            obj.hFifoPollingTimer.ExecutionMode = 'fixedSpacing';
            
            obj.hContAcqTimer = timer('Name','DataScope Continuous Acquisition Timer');
            obj.hContAcqTimer.ExecutionMode = 'fixedSpacing';
            obj.hContAcqTimer.TimerFcn = @obj.nextContAcq;
            obj.hContAcqTimer.Period = 0.03;
        end
        
        function delete(obj)
            obj.abort();
            most.idioms.safeDeleteObj(obj.hFifoPollingTimer);
            most.idioms.safeDeleteObj(obj.hContAcqTimer);
        end
    end
    
    %% Public Methods
    methods
        function startContinuousAcquisition(obj)
            assert(~obj.active,'DataScope is already started');
            obj.start();
            obj.continuousAcqActive = true;
            obj.lastDataReceivedTime = uint64(0);
            start(obj.hContAcqTimer);
        end
        
        function start(obj)
            assert(~obj.active,'DataScope is already started');
            obj.abort();
            obj.active = true;
            obj.acquisitionActive = false;
            
            obj.startFifo();
        end
        
        function acquire(obj,callback)
            if nargin < 2 || isempty(callback)
                callback = obj.callbackFcn;
            end
            
            assert(obj.active,'DataScope is not started');
            assert(~obj.acquisitionActive,'Acquisition is already active');
            
            adcRes = obj.hScan2D.channelsAdcResolution;
            inputRange = obj.hScan2D.channelsInputRanges{obj.channel};
            adc2VoltFcn = @(a)inputRange(2)*single(a)./2^(adcRes-1);

            [nSamples,sampleRate,downSampleFactor] = obj.getSampleRate();
            triggerHoldOff = round(obj.triggerHoldOffTime*sampleRate); % coerce triggerHoldOffTime
            triggerHoldOffTime_ = triggerHoldOff/sampleRate;
            
            settings = struct();
            settings.channel = obj.channel;
            settings.sampleRate = sampleRate;
            settings.digitzerSampleRate = obj.digitizerSampleRate;
            settings.downSampleFactor = downSampleFactor;
            settings.inputRange = inputRange;
            settings.adcRes = adcRes;
            settings.nSamples = nSamples;
            settings.trigger = obj.trigger;
            settings.triggerHoldOff = triggerHoldOff;
            settings.triggerHoldOffTime = triggerHoldOffTime_;
            settings.triggerLineNumber = obj.triggerLineNumber;
            settings.triggerSliceNumber = obj.triggerSliceNumber;
            settings.adc2VoltFcn = adc2VoltFcn;
            
            obj.configureFpga(settings);
            
            obj.hFifoPollingTimer.Period = obj.FIFO_POLLING_PERIOD;
            obj.hFifoPollingTimer.TimerFcn = @(varargin)obj.checkFifo(nSamples,settings,callback);
            
            obj.lastDataReceivedTime = tic();
            obj.acquisitionActive = true;
            obj.hFpga.DataScopeDoStart = true;
            
            start(obj.hFifoPollingTimer);
        end
        
        function abort(obj)
            if ~most.idioms.isValidObj(obj.hScan2D)
                return
            end
            
            try
                stop(obj.hContAcqTimer);
                stop(obj.hFifoPollingTimer);
                obj.hFpga.DataScopeDoReset = true;
                obj.stopFifo();
                obj.active = false;
                obj.acquisitionActive = false;
                obj.continuousAcqActive = false;
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function info = mouseHoverInfo2Pix(obj,mouseHoverInfo)
            info = [];
            
            if ~isa(obj.hScan2D,'scanimage.components.scan2d.ResScan')
                info = [];
                return
            end
            
            if nargin < 2 || isempty(mouseHoverInfo)
                mouseHoverInfo = obj.hScan2D.hSI.hDisplay.mouseHoverInfo;
            end
            
            acqParamBuffer = obj.hScan2D.hAcq.acqParamBuffer;
            if isempty(acqParamBuffer) || isempty(fieldnames(acqParamBuffer) )|| isempty(mouseHoverInfo)
                return
            end
            
            xPix = mouseHoverInfo.pixel(1);
            yPix = mouseHoverInfo.pixel(2);
            
            [tf,zIdx] = ismember(mouseHoverInfo.z,acqParamBuffer.zs);
            if ~tf
                return
            end
            
            rois = acqParamBuffer.rois{zIdx};
            
            mask = cellfun(@(r)isequal(mouseHoverInfo.hRoi,r),rois);
            if ~any(mask)
                return
            end
            
            roiIdx = find(mask,1);
            roiStartLine = acqParamBuffer.startLines{zIdx}(roiIdx);
            roiEndLine   = acqParamBuffer.endLines{zIdx}(roiIdx);
            
            pixelLine = roiStartLine + yPix - 1;
            
            mask = obj.hScan2D.hAcq.mask;
            if numel(mask) < xPix
                return
            end
            
            cumMask = cumsum(mask);
            
            if xPix==1
                pixelStartSample = 1;
            else
                pixelStartSample = cumMask(xPix-1)+1;
            end
            pixelEndSample = cumMask(xPix);
            
            reverseLine = obj.hScan2D.bidirectional && xor(obj.hScan2D.mdfData.reverseLineRead,~mod(pixelLine,2));
            
            if reverseLine
                pixelStartSample = cumMask(end) - pixelStartSample +1;
                pixelEndSample = cumMask(end) - pixelEndSample + 1;
            end
            
            info = struct();
            info.pixelStartSample = pixelStartSample;
            info.pixelEndSample = pixelEndSample;
            info.pixelStartTime = (pixelStartSample - 1) / obj.digitizerSampleRate;
            info.pixelEndTime = pixelEndSample / obj.digitizerSampleRate;
            info.roiStartLine = roiStartLine;
            info.roiEndLine = roiEndLine;
            info.pixelLine = pixelLine;
            info.lineDuration = (cumMask(end)-1) / obj.digitizerSampleRate;
            info.channel = mouseHoverInfo.channel;
            info.z = mouseHoverInfo.z;
            info.zIdx = zIdx;
        end
    end
    
    %% Internal Functions    
    methods (Hidden)
        function nextContAcq(obj,varargin)
            if ~obj.continuousAcqActive || obj.acquisitionActive 
                return
            end
            
            elapsedTime = toc(obj.lastDataReceivedTime);
            
            if  elapsedTime >= obj.displayPeriod
                obj.acquire();
            end
        end
        
        function restart(obj)
            if obj.continuousAcqActive
                obj.abort();
                obj.startContinuousAcquisition();
            elseif obj.active
                obj.abort();
                obj.start();
            end
        end
        
        function configureFpga(obj,settings)            
            obj.hFpga.DataScopeChannelSelection = settings.channel - 1;
            obj.hFpga.DataScopeDownSampleByPowerOf2 = log2(settings.downSampleFactor);
            obj.hFpga.DataScopeNSamples = settings.nSamples;
            obj.hFpga.DataScopeTriggerSliceNumber = settings.triggerSliceNumber-1;
            obj.hFpga.DataScopeTriggerLineNumber  = settings.triggerLineNumber-1;
            obj.hFpga.DataScopeTriggerHoldoff = settings.triggerHoldOff;
                        
            switch lower(settings.trigger)
                case 'none'
                    obj.hFpga.DataScopeTriggerType = 'None';
                case 'frame'
                    obj.hFpga.DataScopeTriggerType = 'Frame';
                case 'slice'
                    obj.hFpga.DataScopeTriggerType = 'Slice';
                case 'line'
                    obj.hFpga.DataScopeTriggerType = 'Line';
                otherwise
                    error('Unsupported trigger type: %s',settings.trigger);
            end
        end        
        
        function startFifo(obj)
            obj.hFifo.stop();
            obj.hFifo.configure(obj.maxDataLength*10);
            obj.hFifo.start();
            scanimage.components.scan2d.resscan.util.flushFpgaFifo(obj.hFifo);
            obj.fifoStarted = true;
        end
        
        function stopFifo(obj)
            if obj.fifoStarted
                scanimage.components.scan2d.resscan.util.flushFpgaFifo(obj.hFifo);
                obj.hFifo.stop();
                obj.fifoStarted = false;
            end
        end
        
        function checkFifo(obj,nSamples,settings,callback)
            if ~obj.acquisitionActive
                return
            end
            
            if obj.hFpga.DataScopeFIFOOverflow
                obj.abort();
                error('DataScope: overflow');
            end
            
            try
                [data,elremaining] = obj.hFifo.read(nSamples,0); % Poll FIFO with 0 timeout
            catch ME
                if isempty(strfind(ME.message,'-50400')) % filter timeout error
                    rethrow(ME) % if FIFO times out
                else
                    return
                end
            end

            stop(obj.hFifoPollingTimer);
            
            if elremaining
                obj.abort();
                error('DataScope: No elements are supposed to remain in FIFO');
            end
            
            data = typecast(data,'int16');
            data = reshape(data(:),2,[]);
            data = data';
            channeldata = data(:,1);
            triggers = data(:,2);
            triggers = triggerDecode(triggers);
            
            if ~isempty(callback)
                src = obj;
                evt = struct();
                evt.data = channeldata;
                evt.triggers = triggers;
                evt.settings = settings;
                callback(src,evt);
            end
            
            obj.acquisitionActive = false;
            
            function s = triggerDecode(trigger)
                s = struct();
                s.PeriodClockRaw        = bitget(trigger,1);
                s.PeriodClockDebounced  = bitget(trigger,2);
                s.PeriodClock           = bitget(trigger,3);
                s.MidPeriodClock        = bitget(trigger,4);
                s.AcquisitionTrigger    = bitget(trigger,5);
                s.AdvanceTrigger        = bitget(trigger,6);
                s.StopTrigger           = bitget(trigger,7);
                s.LaserTriggerRaw       = bitget(trigger,8);
                s.LaserTrigger          = bitget(trigger,9);
                s.ResonantTimeBase      = bitget(trigger,10);
                s.FrameClock            = bitget(trigger,11);
                s.BeamClock             = bitget(trigger,12);
                s.AcquisitionActive     = bitget(trigger,13);
                s.VolumeTrigger         = bitget(trigger,14);
                s.LineActive            = bitget(trigger,15);
            end
        end
        
        function [nSamples,sampleRate,downSampleFactor] = getSampleRate(obj)
            nSamples = ceil(obj.acquisitionTime * obj.digitizerSampleRate);
            if nSamples <= obj.hFifo.fifoNumberOfElementsFpga
                % entire acquisition fits into FPGA FIFO
                sampleRate = obj.digitizerSampleRate;
                downSampleFactor = 1;
            else
                % need to coerce to maxAllowedDataRate, not exceeding
                % maxDataLength
                maxAllowedSampleRate = obj.maxAllowedDataRate / obj.DATA_SIZE_BYTES;
                maxAllowedSampleRate = min(obj.digitizerSampleRate,maxAllowedSampleRate);
                % coerce maxAllowedSampleRate
                downSampleFactor = 2^ceil(log2(obj.digitizerSampleRate/maxAllowedSampleRate));
                sampleRate = obj.digitizerSampleRate / downSampleFactor;
                nSamples = ceil(sampleRate * obj.acquisitionTime);
                
                if nSamples > obj.maxDataLength
                    factor = nSamples / obj.maxDataLength;
                    downSampleFactor = downSampleFactor * factor;
                    downSampleFactor = 2^ceil(log2(downSampleFactor));
                    sampleRate = obj.digitizerSampleRate / downSampleFactor;
                    nSamples = ceil(sampleRate * obj.acquisitionTime);
                end
            end
        end
    end
    
    %% Property Setter/Getter
    methods
        function val = get.digitizerSampleRate(obj)
            val = obj.hScan2D.sampleRate;
        end
        
        function val = get.channelsAvailable(obj)
            val = obj.hScan2D.channelsAvailable;
        end
        
        function set.channel(obj,val)
            validateattributes(val,{'numeric'},{'integer','positive','<=',obj.channelsAvailable});
            obj.channel = val;
        end
        
        function set.maxDataLength(obj,val)
            assert(~obj.active,'Cannot change maxDataLength while DataScope is active');
            obj.maxDataLength = val;
        end
                
        function set.trigger(obj,val)
            val = lower(val);
            mask = strcmpi(val,obj.triggerAvailable);
            assert(sum(mask) == 1,'%s is not a supported Trigger Type',val);
            obj.trigger = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function set.triggerLineNumber(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','integer','<',2^16});
            obj.triggerLineNumber = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function set.triggerSliceNumber(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative','integer','<',2^16});
            obj.triggerSliceNumber = val;
            
            obj.restart(); % abort old acquisition that might be stuck on a trigger that's not firing
        end
        
        function val = get.currentDataRate(obj)
            [nSamples,sampleRate,downSampleFactor] = obj.getSampleRate();
            val = sampleRate * obj.DATA_SIZE_BYTES;
        end
    end
end



%--------------------------------------------------------------------------%
% FpgaDataScope.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
