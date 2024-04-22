classdef GenericPmtController < scanimage.interfaces.PmtController & most.HasMachineDataFile
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'GenericPmtController';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (scanimage.interfaces.PmtController)
    
    %% USER PROPS
    properties (SetAccess = protected)
        hSI;
        numPmts = 0;                % [numerical] number of PMTs managed by the PMT controller
        pmtNames = {};              % Cell array of strings with a short name for each PMT
        pmtInitSuccessful = false;  % Indicates PMT control is ready
        pmtsStatusLastUpdated;      % time of last pmt status update
    end
    
    %% FRIEND PROPS
    properties (Dependent)
        pmtsPowerOn;             % [logical]   array containing power status for each PMT
        pmtsGain;                % [numerical] array containing gain setting for each PMT
        pmtsOffsets;            % [numeric] array containing offset for each PMT
        pmtsBandwidths          % [numeric] array containing amplifier bandwidth for each PMT
    end
    
    properties (Dependent, SetAccess=private)
        pmtsTripped;             % [logical]   array containing trip status for each PMT
    end
    
    properties (Hidden, SetAccess = private)
        hTaskAO;
        hTaskDI;
        hTaskDO;
        hTaskDOTripReset;
        
        power_ = nan;
        gain_ = nan;
        tripped_ = nan;
    end
    
    methods 
        function obj = GenericPmtController(hSI)
            obj.hSI = hSI;
            try
                obj.pmtNames = obj.mdfData.pmtNames;
                obj.numPmts = length(obj.pmtNames);
                
                if ischar(obj.mdfData.pmtDaqDeviceName)
                    obj.mdfData.pmtDaqDeviceName = {obj.mdfData.pmtDaqDeviceName};
                end
                
                if length(obj.mdfData.pmtDaqDeviceName) == 1
                    obj.mdfData.pmtDaqDeviceName = repmat(obj.mdfData.pmtDaqDeviceName,1,obj.numPmts);
                end
                
                assert(length(obj.mdfData.pmtDaqDeviceName) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqDeviceName does not match length of pmtNames');
                
                if ~isempty(obj.mdfData.pmtDaqGainAOChannels) && ~any(isnan(obj.mdfData.pmtDaqGainAOChannels))
                    assert(length(obj.mdfData.pmtDaqGainAOChannels) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqGainAOChannels does not match length of pmtNames');
                    obj.hTaskAO = most.util.safeCreateTask('GenericPmtController AO Gain');
                    for idx = 1:obj.numPmts
                        obj.hTaskAO.createAOVoltageChan(obj.mdfData.pmtDaqDeviceName{idx},obj.mdfData.pmtDaqGainAOChannels(idx),obj.pmtNames{idx});
                    end
                end
                
                if ~isempty(obj.mdfData.pmtDaqTrippedDIChannels) && ~isempty(obj.mdfData.pmtDaqTrippedDIChannels{1})
                    assert(length(obj.mdfData.pmtDaqTrippedDIChannels) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqTrippedDIChannels does not match length of pmtNames');
                    obj.hTaskDI = most.util.safeCreateTask('GenericPmtController DI Trip Detect');
                    for idx = 1:obj.numPmts
                        obj.mdfData.pmtDaqTrippedDIChannels{idx} = formatDigitalPortString(obj.mdfData.pmtDaqTrippedDIChannels{idx});
                        obj.hTaskDI.createDIChan(obj.mdfData.pmtDaqDeviceName{idx},obj.mdfData.pmtDaqTrippedDIChannels{idx},obj.pmtNames{idx});
                    end
                end
                
                if ~isempty(obj.mdfData.pmtDaqPowerDOChannels) && ~isempty(obj.mdfData.pmtDaqPowerDOChannels{1})
                    assert(length(obj.mdfData.pmtDaqPowerDOChannels) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqPowerDOChannels does not match length of pmtNames');
                    obj.hTaskDO = most.util.safeCreateTask('GenericPmtController DO Power');
                    for idx = 1:obj.numPmts
                        obj.mdfData.pmtDaqPowerDOChannels{idx} = formatDigitalPortString(obj.mdfData.pmtDaqPowerDOChannels{idx});
                        obj.hTaskDO.createDOChan(obj.mdfData.pmtDaqDeviceName{idx},obj.mdfData.pmtDaqPowerDOChannels{idx},obj.pmtNames{idx});
                    end
                end
                
                if ~isempty(obj.mdfData.pmtDaqTripResetDOChannels) && ~isempty(obj.mdfData.pmtDaqTripResetDOChannels{1})
                    assert(length(obj.mdfData.pmtDaqTripResetDOChannels) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqTripResetDOChannels does not match length of pmtNames');
                    obj.hTaskDOTripReset = most.util.safeCreateTask('GenericPmtController DO Trip Reset');
                    for idx = 1:obj.numPmts
                        obj.mdfData.pmtDaqTripResetDOChannels{idx} = formatDigitalPortString(obj.mdfData.pmtDaqTripResetDOChannels{idx});
                        obj.hTaskDOTripReset.createDOChan(obj.mdfData.pmtDaqDeviceName{idx},obj.mdfData.pmtDaqTripResetDOChannels{idx},obj.pmtNames{idx});
                    end
                end
                
                if length(obj.mdfData.pmtDaqAOVoltageRange) == 1;
                    obj.mdfData.pmtDaqAOVoltageRange = repmat(obj.mdfData.pmtDaqAOVoltageRange,1,obj.numPmts);
                end
                assert(length(obj.mdfData.pmtDaqAOVoltageRange) == obj.numPmts,'PMT controller: length of mdf variable pmtDaqAOVoltageRange does not match length of pmtNames');
                
                if length(obj.mdfData.pmtMaxGainValue) == 1;
                    obj.mdfData.pmtMaxGainValue = repmat(obj.mdfData.pmtMaxGainValue,1,obj.numPmts);
                end
                assert(length(obj.mdfData.pmtMaxGainValue) == obj.numPmts,'PMT controller: length of mdf variable pmtMaxGainValue does not match length of pmtNames');
                
                obj.power_ = false(1,obj.numPmts);
                obj.gain_ = nan(1,obj.numPmts);
                obj.tripped_ = false(1,obj.numPmts);
                
                obj.pmtInitSuccessful = true;
                obj.updateOutputs();
                obj.notify('pmtStatusChanged');
            catch ME
                fprintf(2,'Error initializing GenericPmtController PMTs\n');
                most.idioms.reportError(ME);
                delete(obj);                
            end
            
            function str = formatDigitalPortString(str)
                if ~regexpi(str,'PFI')
                    str = scanimage.util.translateTriggerToPort(str);
                end
            end
        end
        
        function delete(obj)
            try
                if obj.pmtInitSuccessful
                    obj.pmtsPowerOn = false(1,obj.numPmts);
                    obj.pmtsGain    = zeros(1,obj.numPmts);
                end
            catch ME
                most.idioms.reportError(ME);
            end
            most.idioms.safeDeleteObj(obj.hTaskAO);
            most.idioms.safeDeleteObj(obj.hTaskDI);
            most.idioms.safeDeleteObj(obj.hTaskDO);
            most.idioms.safeDeleteObj(obj.hTaskDOTripReset);            
        end
    end
    
    % setter/getter methods
    methods
        function set.pmtsPowerOn(obj,val)
            validateattributes(val,{'logical','numeric'},{'vector','numel',obj.numPmts});
            
            chg = any(val ~= obj.power_);
            obj.power_ = logical(val(:)');
            
            if obj.pmtInitSuccessful
                obj.updateOutputs();
                
                if chg
                    obj.notify('pmtStatusChanged');
                end
            end
        end
        
        function val = get.pmtsPowerOn(obj)
            val = obj.power_;
        end
        
        function set.pmtsGain(obj,val)
            validateattributes(val,{'numeric'},{'vector','numel',obj.numPmts,'nonnegative'});
            
            chg = any(val ~= obj.gain_);
            obj.gain_ = max(min(val(:)',obj.mdfData.pmtMaxGainValue),0);
            
            if obj.pmtInitSuccessful
                if isempty(obj.hTaskAO)
                    obj.gain_ = nan(1,obj.numPmts);
                end
                
                obj.updateOutputs();
                if chg
                    obj.notify('pmtStatusChanged');
                end
            end
        end
        
        function val = get.pmtsGain(obj)
            val = obj.gain_;
        end
        
        function val = get.pmtsTripped(obj)
            if isempty(obj.hTaskDI)
                val = false(1,obj.numPmts);
            else
                val = obj.hTaskDI.readDigitalData();
                val = val(:)';
                obj.pmtsStatusLastUpdated = tic;
                
                if any(val ~= obj.tripped_)
                    obj.tripped_ = val;
                    obj.notify('pmtStatusChanged');
                end
            end
        end
        
        function set.pmtsOffsets(obj,val)
            % No-Op
        end
        
        function val = get.pmtsOffsets(obj)
            val = nan(1,obj.numPmts);
        end
        
        function set.pmtsBandwidths(obj,val)
            % No-Op
        end
        
        function val = get.pmtsBandwidths(obj)
            val = nan(1,obj.numPmts);
        end
        
        function updateOutputs(obj)
            if ~isempty(obj.hTaskAO)
                voltagerange = vertcat(obj.mdfData.pmtDaqAOVoltageRange{:})';
                ao = obj.pmtsGain .* diff(voltagerange,1) ./ obj.mdfData.pmtMaxGainValue + voltagerange(1,:);
                ao = ao .* obj.pmtsPowerOn;
                obj.hTaskAO.writeAnalogData(ao);
                % obj.hTaskAO.control('DAQmx_Val_Task_Unreserve');
            end
            
            if ~isempty(obj.hTaskDO)
                
                % Fix for single enable analog pmt controller i.e. Janelia
                % Controller.
%                 pmtsOn = obj.pmobj.pmtsPowerOn;
%                 pmtsOn(:) = any(pmtsOn);
%                 obj.hTaskDO.writeDigitalData(logical(pmtsOn));
                
                % Comment out the following line if using the above fix
                obj.hTaskDO.writeDigitalData(logical(obj.pmtsPowerOn));
                % obj.hTaskDO.control('DAQmx_Val_Task_Unreserve');
            end
        end
    end
    
    %% USER METHODS
    methods
        function resetPmtTripStatus(obj,pmtNum)
            if ~isempty(obj.hTaskDOTripReset)
                allOff = false(1,obj.numPmts);
                mask = allOff;
                mask(pmtNum) = true;
                obj.hTaskDOTripReset.writeDigitalData(mask);
                pause(0.25);
                obj.hTaskDOTripReset.writeDigitalData(allOff);
                % obj.hTaskAO.control('hTaskDOTripReset');
            else
                % perform a soft reset by powercycling the PMT
                pw = obj.pmtsPowerOn(pmtNum);
                obj.pmtsPowerOn(pmtNum) = false;
                
                if pw
                    pause(0.25);
                    obj.pmtsPowerOn(pmtNum) = true;
                end
            end
        end
        
        function [powerOn, gain, tripped, offsets, bandwidths] = getLastPmtStatus(obj)
            powerOn = obj.power_;
            gain = obj.gain_;
            tripped = obj.tripped_;
            offsets = nan(1,obj.numPmts);
            bandwidths = nan(1,obj.numPmts);
        end
        
        function setPmtPower(obj, pmtNum, val)
            obj.pmtsPowerOn(pmtNum) = val;
        end
        
        function setPmtGain(obj, pmtNum, val)
            obj.pmtsGain(pmtNum) = val;
        end
        
        function setPmtOffset(~, ~, ~)
            % no op
        end
        
        function setPmtBandwidth(~, ~, ~)
            % no op
        end
        
        function updatePmtsStatus(obj)
            [~] = obj.pmtsTripped(); %causes an update and event to be fired if there is a change
        end
    end
end



%--------------------------------------------------------------------------%
% GenericPmtController.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
