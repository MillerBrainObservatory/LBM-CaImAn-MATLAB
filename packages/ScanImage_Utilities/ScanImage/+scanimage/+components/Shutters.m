classdef Shutters < scanimage.interfaces.Component & most.HasMachineDataFile
% Shutters     Functionality for managing shutters and shutter state transitions.
    properties (SetObservable,SetAccess = private,Transient)
        status = [];                                       % Indicates for each shutter if it is currently opened. 1 for open 0 for close.
    end

    %% INTERNAL PROPS
    properties (Hidden,SetAccess=private)
        hTasks;                                            % Handle to NI DAQmx DO Task(s) for 'DAQ' type shutter operation
        hShutterTransitionFuncs;                           % function handle to shutter transition handle for a specific shutter output device
    end
    
    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Shutters';                       % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                        % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                        % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'shuttersTransition'}; % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};               % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                     % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    % Abstract prop realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Shutters';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    % Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps = 'status';
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = Shutters(hSI)
            if nargin < 1 || isempty(hSI)
                hSI = [];
            end
            obj = obj@scanimage.interfaces.Component(hSI);
        end
        
        function delete(obj)
            % Close shutters at deletion
            obj.shuttersTransitionAll(false);
            
            while numel(obj.hTasks)
                obj.hTasks{1}.stop();
                delete(obj.hTasks{1});
                obj.hTasks(1) = [];
            end
        end
    end
    
    methods (Access=protected, Hidden)
        %Abstract method implementation (most.Model)
        function mdlInitialize(obj)
            try
                % Verify MDF vars
                numShutters = numel(obj.mdfData.shutterDaqDevices);
                
                assert(numShutters == numel(obj.mdfData.shutterChannelIDs), 'Number of shutter channel IDs does not match number of devices. The two lists must correspond.');
                
                obj.zprvMDFScalarExpand('shutterOpenLevel',numShutters);
                obj.zprvMDFScalarExpand('shutterOpenTime',numShutters);
                obj.zprvMDFVerify('shutterOpenLevel',{{'numeric' 'logical'},{'binary' 'vector'}},@(x)numel(x)==numShutters);
                obj.zprvMDFVerify('shutterOpenTime', {{'numeric'},{'nonnegative' 'finite'}},@(x)numel(x)==numShutters);
                
                dmx = dabs.ni.daqmx.System;
                daqs = strsplit(dmx.devNames,',\s*','DelimiterType','RegularExpression');
                
                for i = 1:numShutters
                    dev = obj.mdfData.shutterDaqDevices{i};
                    chan = obj.mdfData.shutterChannelIDs{i};
                    
                    if isprop(obj.hSI, 'hResScan') && strcmp(obj.hSI.hResScan.mdfData.rioDeviceID,dev)
                        obj.hSI.hResScan.fpgaShutterOutTerm = chan;
                        obj.hShutterTransitionFuncs{i} = @(openTF)eval(['obj.hSI.hResScan.fpgaShutterOut = ' int2str(logical(openTF) == obj.mdfData.shutterOpenLevel(i)) ';']);
                    elseif most.idioms.isRioName(dev)
                        obj.hShutterTransitionFuncs{i} = @(openTF)obj.fpgaTransition(dev,chan,logical(openTF) == obj.mdfData.shutterOpenLevel(i));
                    else
                        assert(ismember(dev,daqs), 'Specified device ''%s'' not found in system.', dev);
                        hTask =  most.util.safeCreateTask(['Shutter ' int2str(i) ' Task']);
                        obj.hTasks{end+1} = hTask;
                        hTask.createDOChan(dev,chan);
                        obj.hShutterTransitionFuncs{i} = @(openTF)writeDigitalData(hTask, logical(openTF) == obj.mdfData.shutterOpenLevel(i));
                    end
                end
                
                obj.status = true(1,numShutters); % we don't know the status, so assume open
                
                if isempty(obj.mdfData.shutterNames) || length(obj.mdfData.shutterNames) ~= numShutters
                    % truncate if too many entries
                    obj.mdfData.shutterNames(numShutters+1:end) = [];
                    
                    % truncate if not enough entries
                    for idx = length(obj.mdfData.shutterNames)+1:numShutters
                        obj.mdfData.shutterNames{idx} = sprintf('Shutter %d',idx);
                    end
                end
            catch ME
                most.idioms.dispError('Error occurred during shutter initialization. Incorrect MachineDataFile settings likely cause.\nDisabling shutter feature.\nError stack:\n');
                most.idioms.reportError(ME);
                numShutters = 0;
                obj.status = [];
            end
            
            obj.numInstances = numShutters;
            obj.shuttersTransitionAll(false);
            mdlInitialize@most.Model(obj);
        end
    end
    
    methods (Hidden)
        function fpgaTransition(obj,dev,chan,val)
            hFpga = obj.hSI.fpgaMap(dev).hFpga;
            hFpga.(['DIO' num2str(chan)]) = val;
        end
    end
    
    %% USER METHODS
    methods
        function shuttersTransition(obj,shutterIDs,openTF,applyShutterOpenTime)
        %   Handles shutter state transitions. 
        %   A shutter state transitions from open to close or from close to open. 
        %   
        %   Parameters
        %       shutterIDs - Array of IDs of shutters that will have their state transitioned to open or close. 
        %       openTF - Array of Flags that determine whether (true) or not (false) the associated shutter in the 
        %           ShutterID array should have its state transitioned to open. 
        %       applyShutterOpenTime - Time, in seconds, to apply towards waiting after a transition open is applied.  
        %
        %   Syntax
        %       shuttersObj.shuttersTransition(shutterIDs,openTF,applyShutterOpenTime)
        
            % Necessary to treat empty as no action -> no shutters linked
            % in mdf, no beam shutter open for calibration and a few other
            % situations should result in NO shutter action; previous logic
            % would interpret this as ALL shutter action.
            if isempty(shutterIDs)
               return; 
            end
        
            if nargin < 2 %|| isempty(shutterIDs)
                shutterIDs = 1:obj.numInstances;
            else
                shutterIDs(shutterIDs > obj.numInstances) = []; % Whats the motivation for this protective logic? Should not depend on arg provided.
            end

            % Originally no logic for if TF not supplied. Made logic for
            % shutter ID's superfluous...
            if nargin < 3 || isempty(openTF)
                warning('Shutter motion not specified! Shutters will toggle state.');
                openTF = ~obj.status;
            else
                % Not sure this should actually be done... At least not
                % here.
                if isscalar(openTF)
                    openTF = repmat(openTF, 1, numel(shutterIDs));
                end
            end
            
            if nargin < 4 || isempty(applyShutterOpenTime)
                applyShutterOpenTime = false;
            end
            
            if obj.componentExecuteFunction('shuttersTransition',shutterIDs,openTF,applyShutterOpenTime)
                
                for i = 1:numel(shutterIDs)
                    try
                        obj.hShutterTransitionFuncs{shutterIDs(i)}(openTF(i));
                        obj.status(shutterIDs(i)) = openTF(i); % only is set if transition successful
                    catch ME
                        obj.status(shutterIDs(i)) = true; % unknown shutter status. assume open
                        most.idioms.warn('Shutter transition for shutter %d failed. Error:\n%s', i, ME.message);
                    end
                end
                
                most.idioms.pauseTight(applyShutterOpenTime * max(obj.mdfData.shutterOpenTime(shutterIDs(openTF ~= 0))));
            end
        end
        
        function shuttersTransitionAll(obj, openTF, applyShutterOpenTime)
            shutterIDs = 1:obj.numInstances;
            if nargin < 2 || isempty(openTF)
                warning('Shutter motion not specified! Shutters will toggle state.');
                openTF = ~obj.status;
            else
                % Not sure this should actually be done... At least not
                % here.
                if isscalar(openTF)
                    openTF = repmat(openTF, 1, numel(shutterIDs));
                end
            end
            
            if nargin < 3 || isempty(applyShutterOpenTime)
                applyShutterOpenTime = false;
            end
            
            if obj.componentExecuteFunction('shuttersTransition',shutterIDs,openTF,applyShutterOpenTime)
                
                for i = 1:numel(shutterIDs)
                    try
                        obj.hShutterTransitionFuncs{shutterIDs(i)}(openTF(i));
                        obj.status(shutterIDs(i)) = openTF(i); % only is set if transition successful
                    catch ME
                        obj.status(shutterIDs(i)) = true; % unknown shutter status. assume open
                        most.idioms.warn('Shutter transition for shutter %d failed. Error:\n%s', i, ME.message);
                    end
                end
                
                most.idioms.pauseTight(applyShutterOpenTime * max(obj.mdfData.shutterOpenTime(shutterIDs(openTF ~= 0))));
            end
        end
    end
    
    %% INTERNAL METHODS
    % Abstract method implementation (scanimage.interfaces.Component)
    methods (Hidden, Access=protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command. Note: For this component see shuttersTransition method
            assert(false, 'Shutters nolonger implements start/abort functionality. Use the shutters transition function instead.');
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            obj.shuttersTransitionAll(false); % Close all shutters
        end
    end
end

%% LOCAL 
function s = zlclInitPropAttributes()
    s = struct();
end

function s = defaultMdfSection()
    s = [...
        makeEntry('Shutter(s) used to prevent any beam exposure from reaching specimen during idle periods. Multiple')... % comment only
        makeEntry('shutters can be specified and will be assigned IDs in the order configured below.')... % comment only
        makeEntry('shutterNames',{{'Main Shutter'}},'Cell array specifying the display name for each shutter eg {''Shutter 1'' ''Shutter 2''}')...
        makeEntry('shutterDaqDevices',{{'PXI1Slot3'}},'Cell array specifying the DAQ device or RIO devices for each shutter eg {''PXI1Slot3'' ''PXI1Slot4''}')...
        makeEntry('shutterChannelIDs',{{'PFI12'}},'Cell array specifying the corresponding channel on the device for each shutter eg {''PFI12''}')...
        makeEntry()... % blank line
        makeEntry('shutterOpenLevel',1,'Logical or 0/1 scalar indicating TTL level (0=LO;1=HI) corresponding to shutter open state for each shutter line. If scalar, value applies to all shutterLineIDs')...
        makeEntry('shutterOpenTime',0.1,'Time, in seconds, to delay following certain shutter open commands (e.g. between stack slices), allowing shutter to fully open before proceeding.')...
        ];
    
    function se = makeEntry(name,value,comment,liveUpdate)
        if nargin == 0
            name = '';
            value = [];
            comment = '';
        elseif nargin == 1
            comment = name;
            name = '';
            value = [];
        elseif nargin == 2
            comment = '';
        end
        
        if nargin < 4
            liveUpdate = false;
        end
        
        se = struct('name',name,'value',value,'comment',comment,'liveUpdate',liveUpdate);
    end
end


%--------------------------------------------------------------------------%
% Shutters.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
