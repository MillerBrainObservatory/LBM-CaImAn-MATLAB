classdef CycleData < handle & matlab.mixin.Copyable
%% CYCLEDATA Data structure for the relevant "iteration" information for cycle-mode
% 
    properties (SetObservable)
        idx;            % Integer that allows CycleDataGroup to use CRUD operations on the current object
                        % IDs should always be numerically contiguous and integers. The CycleDataGroup
                        % should manage them to be 1-based
                        % This is for all intents and purposes an index in CycleDataGroup
                        % Perhaps we should make this read-only

        % Each property in CycleData can be empty, which "disables" it
        cfgName;
        iterDelay;
        motorAction;
        motorStep;
        repeatPeriod;
        numRepeats;
        numSlices;
        zStepPerSlice;
        numFrames;
        power;
        numAvgFrames;
        framesPerFile;
        lockFramesPerFile;
        active;
    end
    
    properties (Hidden)
        hTimer;
    end
    
    events
        propertyChanged;
    end
    
    methods
        function obj = CycleData()
            obj.reset();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTimer);
        end

        function reset(obj)
            obj.active = false;
            obj.idx = [];

            obj.cfgName = [];
            obj.iterDelay = [];
            obj.motorAction = [];
            obj.motorStep = [];
            obj.repeatPeriod = [];
            obj.numRepeats = [];
            obj.numSlices = [];
            obj.zStepPerSlice = [];
            obj.numFrames = [];
            obj.power = [];
            obj.numAvgFrames = [];
            obj.framesPerFile = [];
            obj.lockFramesPerFile = false;
        end

        function waitParams = go(obj, hSI)
        %   Runs the current iteration
        %   NOTE: This is a blocks function. This prevents issues when multiple cycles are being called
        %         from a different script and simplifies usage
        %
            initGoTime = tic;
            waitParams = [];

            obj.active = true;
            if ~isempty(obj.cfgName)
                hSI.hConfigurationSaver.cfgLoadConfig(obj.cfgName);
            end

            if ~isempty(obj.motorAction) && ~isempty(obj.motorStep)
                if strcmp(obj.motorAction,'Posn #')
                    %1x3 array specifying motor position (in microns)
                    if obj.motorStep(1) == '['
                        pos = eval(obj.motorStep);
                    else
                        pos = str2num(obj.motorStep);
                    end
                    
                    try
                        hSI.hMotors.motorPosition = pos;
                    catch ME
                        error('Failed to set motor position. Position may be invalid. Error:\n%s',ME.message);
                    end
                elseif strcmp(obj.motorAction, 'ID #');
                    hSI.hMotors.gotoUserDefinedPosition(str2double(obj.motorStep));
                end
            end

            if ~isempty(obj.repeatPeriod)
                hSI.loopAcqInterval = obj.repeatPeriod;
            end

            if ~isempty(obj.numRepeats)
                hSI.acqsPerLoop = obj.numRepeats;
            end

            if ~isempty(obj.numSlices)
                hSI.hStackManager.numSlices = obj.numSlices;
            end

            if ~isempty(obj.zStepPerSlice)
                hSI.hStackManager.stackZStepSize = obj.zStepPerSlice;
            end

            if ~isempty(obj.numFrames)
                hSI.hStackManager.framesPerSlice = obj.numFrames;
            end

            %+++ 
            if ~isempty(obj.power)
                if obj.power(1) == '['
                    pow = eval(obj.power);
                else
                    pow = str2num(obj.power);
                end
                
                if numel(pow) < numel(hSI.hBeams.powers)
                    pow(end+1:numel(hSI.hBeams.powers)) = nan;
                end
                
                hSI.hBeams.powers(~isnan(pow)) = pow(~isnan(pow));
            end

            if ~isempty(obj.numAvgFrames)
                hSI.hScan2D.logAverageFactor = obj.numAvgFrames;
            end

            if ~isempty(obj.framesPerFile)
                hSI.hScan2D.logFramesPerFile = obj.framesPerFile;
            end

            % NOTE: Since this is a checkbox we don't have the option to not override the default parameters on an empty value
            hSI.hScan2D.logFramesPerFileLock = obj.lockFramesPerFile;

            % wait for SI to be idle
            delay = 0.003;  
            %+++ We might want to abort on this case
            while ~strcmpi(hSI.acqState,'idle')
                pause(delay);
            end
            
            if ~isempty(obj.iterDelay)
                d = floor((obj.iterDelay - toc(initGoTime))*1000);
                if d > 2
                    if ~most.idioms.isValidObj(obj.hTimer)
                        obj.hTimer = timer('Name','CycleData','TimerFcn',@timerFcn);
                    end
                    obj.hTimer.StartDelay = d/1000;
                    start(obj.hTimer);
                    waitParams = struct('waitStartTime', tic, 'delay', d/1000);
                else
                    hSI.startLoop();
                end
            else
                hSI.startLoop();
            end
        
            function timerFcn(varargin)
                hSI.startLoop();
            end
        end
        
        function abort(obj)
            if most.idioms.isValidObj(obj.hTimer);
                stop(obj.hTimer);
            end
            obj.active = false;
        end

        function update(obj, cycleData)
            obj.cfgName           = cycleData.cfgName;
            obj.iterDelay         = cycleData.iterDelay;
            obj.motorAction       = cycleData.motorAction;
            obj.motorStep         = cycleData.motorStep;
            obj.repeatPeriod      = cycleData.repeatPeriod;
            obj.numRepeats        = cycleData.numRepeats;
            obj.numSlices         = cycleData.numSlices;
            obj.zStepPerSlice     = cycleData.zStepPerSlice;
            obj.numFrames         = cycleData.numFrames;
            obj.power             = cycleData.power;
            obj.numAvgFrames      = cycleData.numAvgFrames;
            obj.framesPerFile     = cycleData.framesPerFile;
            obj.lockFramesPerFile = cycleData.lockFramesPerFile;
        end
    end
    
    %% Property Getter/Setter
    methods
        function notifyChanged(obj)
            notify(obj, 'propertyChanged');
        end
        
        function set.cfgName(obj,val)
            obj.cfgName = val;
            obj.notifyChanged();
        end
        
        function set.idx(obj,val)
            obj.idx = val;
            obj.notifyChanged();
        end
        
        function set.iterDelay(obj,val)
            obj.iterDelay = val;
            obj.notifyChanged();
        end
        
        function set.motorAction(obj,val)
            obj.motorAction = val;
            obj.notifyChanged();
        end
        
        function set.motorStep(obj,val)
            obj.motorStep = val;
            obj.notifyChanged();
        end
        
        function set.repeatPeriod(obj,val)
            obj.repeatPeriod = val;
            obj.notifyChanged();
        end
        
        function set.numRepeats(obj,val)
            obj.numRepeats = val;
            obj.notifyChanged();
        end
        
        function set.numSlices(obj,val)
            obj.numSlices = val;
            obj.notifyChanged();
        end
        
        function set.zStepPerSlice(obj,val)
            obj.zStepPerSlice = val;
            obj.notifyChanged();
        end
        
        function set.numFrames(obj,val)
            obj.numFrames = val;
            obj.notifyChanged();
        end
        
        function set.power(obj,val)
            obj.power = val;
            obj.notifyChanged();
        end
        
        function set.numAvgFrames(obj,val)
            obj.numAvgFrames = val;
            obj.notifyChanged();
        end
        
        function set.framesPerFile(obj,val)
            obj.framesPerFile = val;
            obj.notifyChanged();
        end
        
        function set.lockFramesPerFile(obj,val)
            obj.lockFramesPerFile = val;
            obj.notifyChanged();
        end
        
        function set.active(obj,val)
            obj.active = val;
            obj.notifyChanged();
        end
    end
end


%--------------------------------------------------------------------------%
% CycleData.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
