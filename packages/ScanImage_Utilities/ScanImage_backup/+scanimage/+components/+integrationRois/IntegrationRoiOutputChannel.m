classdef IntegrationRoiOutputChannel < handle
    properties
        enable = false;
        hIntegrationRois = scanimage.mroi.Roi.empty(1,0);       % array of integration Rois to be used for generating the output
        outputFunction;         % handle to function that generates output from roi integrators
    end
    
    properties (SetAccess = private)
        hTask;
        outputMode; % digital or analog
        channelName;
        physicalChannelName;
        hIntegrationRoisUuiduint64 = uint64([]);
        lastWrittenVal = [];
    end
    
    events
        changed;
    end
    
    %% Lifecycle
    methods
        function obj = IntegrationRoiOutputChannel(channelName,deviceName,channelId)
            if isempty(channelName)
                channelName = most.util.generateUUID();
                channelName = channelName(1:8);
            end
            obj.channelName = channelName;
            
            if isempty(deviceName) || isempty(channelId) || strcmpi(deviceName,'none') || strcmpi(channelId,'none')
                obj.outputMode = 'software';
                obj.outputFunction = @(vals,varargin)fprintf('Mean integration value %f\n',mean(vals));
                obj.physicalChannelName = 'software';
            else
                obj.hTask = most.util.safeCreateTask(sprintf('Integration Roi Output %s',channelName));
                
                if isnumeric(channelId) || (ischar(channelId) && ~isempty(stringToAOChannel(channelId)))
                    if ischar(channelId)
                        channelId = stringToAOChannel(channelId);
                    end
                    obj.outputMode = 'analog';
                    obj.hTask.createAOVoltageChan(deviceName,channelId,obj.channelName);
                    obj.outputFunction = @(vals,varargin)mean(vals);
                    obj.physicalChannelName = sprintf('%s/AO%d',deviceName,channelId);
                else
                    obj.outputMode = 'digital';
                    if ~isempty(strfind(lower(channelId),'pfi'))
                        channelId = scanimage.util.translateTriggerToPort(channelId);
                    end
                    obj.hTask.createDOChan(deviceName,channelId,obj.channelName);
                    obj.outputFunction = @(vals,varargin)mean(vals)>100;
                    obj.physicalChannelName = sprintf('%s/%s',deviceName,channelId);
                end
            end
            
            function chan = stringToAOChannel(str)
                str = regexp(str,'(?<=^AO)[0-9]+$','match','once');
                if isempty(str)
                    chan = [];
                else
                    chan = str2double(str);
                end
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hTask);      
        end
    end
    
    %% User Functions
    methods        
        function start(obj)
            % No-op
        end
        
        function abort(obj)
            obj.resetOutput();
        end
        
        function updateOutput(obj,integrationRois,integrationDone,integrationValuesHistory,timestampHistory,arrayIdxs)
            if ~obj.enable || isempty(obj.hIntegrationRois)
                return
            end
            
            uuiduint64s = [integrationRois.uuiduint64];
            if ~issorted(uuiduint64s) % should be pre-sorted already, but just to make sure
                [uuiduint64s,sortIdxs] = sort(uuiduint64s);
                idxs = ismembc2(obj.hIntegrationRoisUuiduint64,uuiduint64s);
                idxs = sortIdxs(idxs);
            else
                idxs = ismembc2(obj.hIntegrationRoisUuiduint64,uuiduint64s);
            end
            
            if any(idxs<=0)
                most.idioms.warning('Not all IntegrationRois found need for output');
            end
            integrationDone = integrationDone(idxs);
            
            if any(integrationDone)
                arrayIdxs = arrayIdxs(idxs);
                values = integrationValuesHistory(arrayIdxs);
                timestamps = timestampHistory(arrayIdxs);                
                try
                    newVal = obj.outputFunction(values,timestamps,obj.hIntegrationRois,integrationValuesHistory,timestampHistory,idxs);
                    obj.writeOutputValue(newVal);
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
        
        function deleteOutdatedRois(obj,roiGroup)
            [~,idx] = setdiff(obj.hIntegrationRois,roiGroup.rois);
            obj.hIntegrationRois(idx) = []; %remove non-existing rois            
        end
        
        function resetOutput(obj)
            obj.writeOutputValue(0,true);
        end
        
        function writeOutputValue(obj,val,force)
            if nargin < 3 || isempty(force)
                force = false;
            end
            
            if isempty(val) || ~(isnumeric(val)||islogical(val)) || isnan(val(1))
                return
            end
            
            val = val(1); % in case the output is a matrix
            
            if isequal(obj.lastWrittenVal,val) && ~force
                return
            end            
                
            switch obj.outputMode
                case 'analog'
                    val = min(max(val,-10),10); % coerce to output range
                    obj.hTask.writeAnalogData(val);
                case 'digital'
                    val = logical(val);
                    obj.hTask.writeDigitalData(val);
                case 'software'
                    %No-op
                otherwise
                    assert(false);
            end
            obj.lastWrittenVal = val;
        end
    end
    
    
    %% Property setter/getter
    methods        
        function set.outputMode(obj,val)
            val = lower(val);
            assert(ismember(val,{'analog','digital','software'}));
            obj.outputMode = val;
        end
        
        function set.enable(obj,val)
            obj.enable = val;
            notify(obj,'changed');
        end
        
        function set.outputFunction(obj,val)
            if isempty(val)
                val = @(varargin)0;
            elseif ischar(val)
                val = str2func(val);
            else
                assert(isa(val,'function_handle'),'The property ''outputFunction'' needs to be a string or a function handle');
            end
            
            validateattributes(val,{'function_handle'},{'scalar'});
            obj.outputFunction = val;
            notify(obj,'changed');
        end
        
        function set.hIntegrationRois(obj,val)
            if isempty(val)
                val = scanimage.mroi.Roi.empty(1,0);
            end
            validateattributes(val,{'scanimage.mroi.Roi'},{});
            obj.hIntegrationRois = val;
            obj.hIntegrationRoisUuiduint64 = uint64([obj.hIntegrationRois.uuiduint64]); % pre cache for performance
            notify(obj,'changed');
        end
    end
end



%--------------------------------------------------------------------------%
% IntegrationRoiOutputChannel.m                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
