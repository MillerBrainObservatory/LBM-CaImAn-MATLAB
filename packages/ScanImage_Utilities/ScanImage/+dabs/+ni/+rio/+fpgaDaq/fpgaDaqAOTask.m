classdef fpgaDaqAOTask < dabs.ni.rio.fpgaDaq.fpgaDaqTask
    
    properties
        channels;
        startTrigType;
        digEdgeStartTrigSrc;
        startTrigRetriggerable = false;
    end
    
    methods
        function obj = fpgaDaqAOTask(hDaq)
            obj = obj@dabs.ni.rio.fpgaDaq.fpgaDaqTask(hDaq);
        end
    end
    
    methods (Static)
        function task = createTaskObj(name,hFpga)
            if isa(hFpga,'dabs.ni.rio.fpgaDaq.fpgaDaq')
                task = dabs.ni.rio.fpgaDaq.fpgaDaqAOTask(hFpga);
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
        function createAOVoltageChan(obj,~,chan,varargin)
            obj.chans = [obj.chans chan];
        end
        
        function start(obj)
            obj.hFpgaDaq.aoStart();
            
            if obj.hFpgaDaq.hFpga.AOTriggerSel == 5
                obj.hFpgaDaq.aoTrigger();
            end
        end
        
        function writeAnalogData(obj,data)
            if obj.buffered
                assert(size(data,2) == numel(obj.chans), 'Incorrect number of channels');
                dat = zeros(size(data,1),8);
                for i = 1:numel(obj.chans)
                    c = obj.chans(i);
                    dat(:,c+1) = data(:,i);
                end
                obj.hFpgaDaq.aoWriteBuffer(dat);
            else
                assert(numel(data) == numel(obj.chans), 'Incorrect number of channels');
                obj.hFpgaDaq.aoSetValues(obj.chans,data);
            end
        end
        
        function writeAnalogDataAsync(obj,data,~,~,~,cb)
            % todo: actual async update
            try
                obj.writeAnalogData(data);
                evt.status = 0;
            catch ME
                evt.status = 1;
                evt.errorString = ME.message;
                evt.extendedErrorInfo = [ME.stack(1).name ' line ' num2str(ME.stack(1).line) '\n' ME.stack(1).file];
            end
            cb([],evt);
        end
        
        function cfgSampClkTiming(obj, sampleRate, mode, Nsamps, varargin)
            if nargin > 3
                obj.sampQuantSampPerChan = Nsamps;
            end
            obj.sampQuantSampMode = mode;
            obj.sampClkRate = sampleRate;
            
            obj.cfgOutputBuffer();
        end
        
        function cfgOutputBuffer(obj,~)
            finiteTf = strcmp(obj.sampQuantSampMode,'DAQmx_Val_FiniteSamps');
            if finiteTf
                N = obj.sampQuantSampPerChan;
            else
                N = 0;
            end
            obj.hFpgaDaq.aoConfigureSampleMode(finiteTf,N,obj.chans);
            obj.buffered = true;
        end
        
        function abort(obj)
            obj.hFpgaDaq.aoAbort();
        end
        
        function disableStartTrig(obj)
            obj.hFpgaDaq.aoConfigureTrigger(true,5,obj.startTrigRetriggerable);
        end
        
        function cfgDigEdgeStartTrig(obj,~,~)
            obj.hFpgaDaq.aoConfigureTrigger(true,0,obj.startTrigRetriggerable);
        end
        
        function issueSoftwareStartTrigger(obj)
            obj.hFpgaDaq.aoTrigger();
        end
        
        function v = isTaskDoneQuiet(obj)
            v = strcmp(obj.hFpgaDaq.aoTaskState, 'Idle');
        end
        
        function v = isTaskDone(obj)
            v = obj.isTaskDoneQuiet();
        end
        
        function registerEveryNSamplesEvent(varargin)
        end
        
        function waitUntilTaskDone(obj,timeout)
            t = tic;
            while ~obj.isTaskDone
                assert(toc(t) < timeout, 'Timed out waiting for AO task to complete.');
                pause(0.01);
            end
        end
    end
    
    methods
        function set.startTrigRetriggerable(obj,v)
            obj.startTrigRetriggerable = logical(v);
            obj.hFpgaDaq.hFpga.AOAllowRetrigger = logical(v);
        end
        
        function v = get.startTrigType(obj)
            if obj.hFpgaDaq.hFpga.AOTriggerSel == 5
                v = 'DAQmx_Val_None';
            else
                v = 'DAQmx_Val_DigEdge';
            end
        end
        
        function v = get.digEdgeStartTrigSrc(obj)
            v = ['DIO' num2str(obj.hFpgaDaq.hFpga.AOTriggerSel)];
        end
        
        function v = get.channels(obj)
            v = dabs.ni.rio.fpgaDaq.fpgaDaqChannel.empty;
            for c = obj.chans
                v(end+1) = dabs.ni.rio.fpgaDaq.fpgaDaqChannel;
                v(end).min = -10;
                v(end).max = 10;
            end
        end
    end
    
end



%--------------------------------------------------------------------------%
% fpgaDaqAOTask.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
