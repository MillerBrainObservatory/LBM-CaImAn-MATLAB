classdef fpgaDaqAITask < dabs.ni.rio.fpgaDaq.fpgaDaqTask
    
    properties
        startTrigType;
        digEdgeStartTrigSrc;
        readReadAllAvailSamp;
        everyNSamplesReadDataEnable = false;
        everyNSamplesEventCallbacks = [];
        doneEventCallbacks = [];
        startTrigRetriggerable = false;
        everyNSamples = [];
        channels;
    end
    
    methods
        function obj = fpgaDaqAITask(hDaq)
            obj = obj@dabs.ni.rio.fpgaDaq.fpgaDaqTask(hDaq);
        end
    end
    
    methods (Static)
        function task = createTaskObj(name,hFpga)
            if isa(hFpga,'dabs.ni.rio.fpgaDaq.fpgaDaq')
                task = dabs.ni.rio.fpgaDaq.fpgaDaqAITask(hFpga);
                task.name = name;
            else
                task = most.util.safeCreateTask(name);

                % make available for dot notation access
                get(task, 'sampClkTimebaseSrc'); 
                get(task, 'sampClkTimebaseRate');
                get(task, 'writeRelativeTo');
                get(task, 'writeOffset');
            end
        end
    end
    
    methods
        function createAIVoltageChan(obj,~,chan,varargin)
            obj.chans = [obj.chans chan];
        end
        
        function start(obj)
            obj.hFpgaDaq.aiStart();
            
            if obj.hFpgaDaq.hFpga.AITriggerSel == 5
                obj.hFpgaDaq.aiTrigger();
            end
        end
        
        function abort(obj)
            obj.hFpgaDaq.aiAbort();
        end
        
        function cfgSampClkTiming(obj, sampleRate, mode, Nsamps, varargin)
            if nargin > 3
                obj.sampQuantSampPerChan = Nsamps;
            end
            obj.sampQuantSampMode = mode;
            obj.sampClkRate = sampleRate;
            obj.buffered = true;
            
            
            finiteTf = strcmp(obj.sampQuantSampMode,'DAQmx_Val_FiniteSamps');
            if finiteTf
                N = obj.sampQuantSampPerChan;
            else
                N = 0;
            end
            
            obj.hFpgaDaq.aiConfigureSampleMode(finiteTf,N,obj.chans,N);
        end
        
        function outputData = readAnalogData(obj, numSampsPerChan, outputFormat, timeout)
            if nargin < 3 || isempty(outputFormat)
                outputFormat = 'scaled';
            end
            
            if nargin < 4 || isempty(timeout)
                timeout = 10;
            end
            
            if obj.buffered
                dat = obj.hFpgaDaq.aiReadBuffer(numSampsPerChan, timeout, strcmp(outputFormat,'native'));
                outputData = dat(:,obj.chans+1);
            else
                outputData = zeros(numSampsPerChan,numel(obj.chans));
                for i = 1:numSampsPerChan
                    outputData(i,:) = obj.hFpgaDaq.aiValues(obj.chans+1);
                end
            end
        end
        
        function disableStartTrig(obj)
            obj.hFpgaDaq.aiConfigureTrigger(true,5,obj.startTrigRetriggerable);
        end
        
        function cfgDigEdgeStartTrig(obj,port,~)
            if strncmp(port,'PFI',3)
                port = str2double(port(4:end));
            end
            obj.hFpgaDaq.aiConfigureTrigger(true,port,obj.startTrigRetriggerable);
        end
        
        function issueSoftwareStartTrigger(obj)
            obj.hFpgaDaq.aiTrigger();
        end
        
        function v = isTaskDoneQuiet(obj)
            v = strcmp(obj.hFpgaDaq.aiTaskState, 'Idle');
        end
        
        function v = isTaskDone(obj)
            v = obj.isTaskDoneQuiet();
        end
        
        function waitUntilTaskDone(obj,timeout)
            t = tic;
            while ~obj.isTaskDone
                assert(toc(t) < timeout, 'Timed out waiting for AI task to complete.');
                pause(0.01);
            end
        end
        
        function registerEveryNSamplesEvent(varargin)
        end
        
        function configureCallbacks(obj)
            if isempty(obj.everyNSamples) || isempty(obj.everyNSamplesEventCallbacks)
                n = 0;
            else
                n = obj.everyNSamples;
            end
%             obj.hFpgaDaq.aiConfigureCallbacks(n, @obj.nSampCb, @obj.doneCb);
        end
        
        function nSampCb(obj)
            if isempty(obj.everyNSamplesEventCallbacks)
                evnt.errorMessage = '';
                if obj.everyNSamplesReadDataEnable
                    evnt.data = obj.readAnalogData(obj.everyNSamples,0);
                end
                
                obj.everyNSamplesEventCallbacks(obj,evnt);
            end
        end
        
        function doneCb(obj)
        end
    end
    
    methods
        function set.startTrigRetriggerable(obj,v)
            obj.startTrigRetriggerable = logical(v);
            obj.hFpgaDaq.hFpga.AIAllowRetrigger = logical(v);
        end
        
        function v = get.startTrigType(obj)
            if obj.hFpgaDaq.hFpga.AITriggerSel == 5
                v = 'DAQmx_Val_None';
            else
                v = 'DAQmx_Val_DigEdge';
            end
        end
        
        function v = get.digEdgeStartTrigSrc(obj)
            v = ['DIO' num2str(obj.hFpgaDaq.hFpga.AITriggerSel)];
        end
        
        function v = get.channels(obj)
            v = dabs.ni.rio.fpgaDaq.fpgaDaqChannel.empty;
            for c = obj.chans
                v(end+1) = dabs.ni.rio.fpgaDaq.fpgaDaqChannel;
                m = obj.hFpgaDaq.hFpga.(['AI' num2str(c) 'VoltageRange']);
                v(end).max = str2double(m(5:end-2));
                v(end).min = -v(end).max;
            end
        end
        
        function set.everyNSamplesEventCallbacks(obj,v)
            obj.everyNSamplesEventCallbacks = v;
            obj.configureCallbacks();
        end
    end
end



%--------------------------------------------------------------------------%
% fpgaDaqAITask.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
