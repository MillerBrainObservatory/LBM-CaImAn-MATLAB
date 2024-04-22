classdef Photostim < scanimage.interfaces.Component & most.HasMachineDataFile

    %% Photostim Module
    properties (SetObservable)
        % Array of stimulus groups.
        stimRoiGroups = scanimage.mroi.RoiGroup.empty;
        
        % Specifies what mode the photostim module should operate in. This property is initialized to 'sequence'. 
        % 
        % Possible modes are:
        %   'sequence' - A sequence of stimulus patterns are loaded and each trigger begins the next pattern. Note, all
        %                patterns will be padded to have the same time duration as the longest.
        %   'onDemand' - A set of stimulus patterns are loaded and any pattern can be immediately output on demand by
        %                the user by gui/command line. PC performance may affect delay from when a stimulus is commanded
        %                to actual output but the sync trigger can still be used. If stimImmediately is false, it will
        %                also wait for the stim trigger after the user commands a stimulation.
        stimulusMode = 'sequence';
        
        % Sequence mode props

        % Array of the sequence of stimulus groups (represented as an index of the stimRoiGroups array) to load for a stimulus sequence. 
        % 
        % This is a sequence mode property.
        sequenceSelectedStimuli;        
 
        % The number of times the entire sequence will be repeated. 
        % 
        % This is a sequence mode property and is initialized to inf.
        numSequences = inf;             
        
        % OnDemand mode props
        
        % Flag that determines whether (true) or not (false) the selected on demand stimulus is allowed to be triggered multiple times.
        % 
        % This is an on demand mode property and is initialized to false.
        allowMultipleOutputs = false;   
        
        % Specifies the PFI terminal that should be used to trigger an on-demand stim selection. 
        % 
        % This is an on demand mode property.
        stimSelectionTriggerTerm = [];  
        
        % Name of the DAQ device to use for external stim selection. 
        % 
        % This is an on demand mode property.
        stimSelectionDevice = '';       

        % Array of the PFI terminals to use for stim selection. 
        % 
        % This is an on demand mode property.
        stimSelectionTerms = [];        
        
        % Array of stimulus group IDs to select that correspond to each terminal in stimSelectionTerms. 
        % 
        % This is an on demand mode property.
        stimSelectionAssignment = [];   
        
        % Both modes

        % Specifies the channel that should be used to trigger a stimulation. 
        % 
        % This property can be used for both sequence and on demand modes, and is initialized to 1.
        stimTriggerTerm = 1;            
        
        % Specifies a channel to sync the stimulation to. When a stimulus trigger occurs, 
        % the stimulus will begin at the next sync trigger. If this property is left empty, 
        % stimulus will begin immediately after a stimulus trigger. 
        % 
        % This property can be used for both sequence and on demand modes.
        syncTriggerTerm = [];           
                                        
        % Flag that determines whether (true) or not (false) the first stimulus in the sequence will be triggered 
        % immediately upon starting the experiment (eg. don't wait for stim trigger. sync trigger still applies). 
        % 
        % This property can be used for both sequence and on demand modes and is initialized to false.
        stimImmediately = false;        
                                        
        % Period, in seconds, of auto trigger. 
        % 
        % This property can be used for both sequence and on demand modes and is initialized to 0.
        autoTriggerPeriod = 0;          
        
        % Monitoring props

        % Flag that determines whether (true) or not (false) the AI5/AI6/AI7 of the photostim device will be used to 
        % read back the X/Y/beams channels of the photostimulation. 
        % 
        % This is a monitoring property and is initialized to false.
        monitoring = false;             
        
        % Flag that determines whether (true) or not (false) the monitored data is logged to the same folder as the Scan2D data. 
        % 
        % This is a monitoring property and is initialized to false.
        logging = false;                
        
        % Motion Compensation

        % Flag that determines whether (true) or not (false) the motion correction is enabled. 
        % If enabled (true), the motion data will be used to compensate for motion. 
        % 
        % This is a motion compensation property and is initialized to true.
        compensateMotionEnabled = true; 
        
        % Specifies whether or not to control Z focus with fast Z actuator.
        % Must be either '2D' or '3D'
        zMode = '2D';
        
        % Specifies time to advance signal that goes high when laser is
        % active
        laserActiveSignalAdvance = 0.001;
    end
    
    properties (Hidden, Dependent, Transient)        
        % these are now in mdf. kept here for legacy support
        monitoringXAiId;                % AI channel to be used for monitoring the X-galvo
        monitoringXTermCfg;             % AI terminal configuration to be used for monitoring the X-galvo
        monitoringYAiId;                % AI channel to be used for monitoring the Y-galvo
        monitoringYTermCfg;             % AI terminal configuration to be used for monitoring the Y-galvo
        monitoringBeamAiId;             % AI channel to be used for monitoring the Pockels cell output
    end
    
    properties (SetObservable, SetAccess = private)
        % Indicates status of photostim module. 
        %
        % Status values include:
        %   Offline
        %   Initializing...
        %   Ready
        %   Running
        %
        % This is a read-only property and is initialized to 'Offline'.
        status = 'Offline';             
        
        % The sequence position in the selected stimuli. 
        %
        % This is a read-only property and is initialized to 1.
        sequencePosition = 1;           
        
        % The next sequence position in the selected stimuli. 
        %
        % This is a read-only property and is initialized to 1.
        nextStimulus = 1;               
        
        % Number of completed sequences in the selected stimuli. 
        %
        % This is a read-only property and is initialized to 0.
        completedSequences = 0;         
        
        % Number of outputs for obtaining samples. Only relevant if the 'allowMultipleOutputs' flag is set to true. 
        %
        % This is a read-only property and is initialized to 0.
        numOutputs = 0;
        
        % The XY vector (in reference space) of the applied motion correction
        %
        % This is a read-only property and is initialized to [0 0].
        lastMotion = [0 0];
    end
    
    properties (SetObservable, SetAccess = private, Hidden)
        initInProgress = false;
        zMode3D = false;
        slmQueueActive = false;
    end
    
    properties (SetObservable, Dependent, Hidden)
        stimScannerset;                 % scannerset used for stimulation
    end
    
    % ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Photostim';           % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};       % Cell array of strings specifying properties that can be set while focusing
        PROP_TRUE_LIVE_UPDATE = {'monitoring'}; % Cell array of strings specifying properties that can be set while the component is active
        DENY_PROP_LIVE_UPDATE = {'logging'};    % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'park'};    % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};    % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};          % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
        graphics2014b = most.idioms.graphics2014b();
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Photostim';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    properties (Hidden, SetAccess = private)
        currentSlmPattern = [];
    end
    
    % Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'stimRoiGroups'};
    end

    %% INTERNAL PROPS
    properties (Hidden,SetAccess=private)
        hTaskGalvo;                     % Handle to DAQmx AO task used for galvo or galvo+beam control
        hTaskBeams;                     % Handle to DAQmx AO task used for beam control when a separate DAQ is used
        hTaskZ;                         % Handle to DAQmx AO task used for z control when a separate DAQ is used
        hTaskMain;                      % Handle to hTaskGalvo or hTaskBeams depending on whether galvos or beams are present
        hTaskAutoTrigger;               % Handle to DAQmx CO task for auto trigger
        hTaskArmedTrig;                 % Handle to DAQmx CO task used for start triggering
        hTaskSyncHelper;                % Handle to DAQmx CO task used for synced start triggering
        hTaskSoftPulse;                 % Handle to DAQmx DO task used to generate a pulse to issue a soft trigger or sync
        hTaskExtStimSel;                % Handle to DAQmx CO task used for hardware stim selection
        hTaskExtStimSelRead;            % Handle to DAQmx DI task used for hardware stim selection
        hTaskMonitoring;                % Handle to DAQmx AI task used for monitoring the X/Y galvos and beams output
        hTaskDigitalOut;                % Handle to DAQmx DO task used for outputting digital signals
        hScan;                          % Handle to scan2d component
        hRouteRegistry;                 % Handle to DAQmx route registry
        hRouteRegistrySlm;              % Handle to DAQmx route registry
        hListeners = [];
        
        simulatedDevice = false;        % Logical indicating whether or not the configured FastZ device is simulated.
        separateBeamDAQ = false;        % Indicates that beams are on a separate DAQ
        zWithGalvos = false;            % Indicates that Z is on same DAQ with galvos
        zWithBeams = false;             % Indicates that Z is on same DAQ with beams
        separateZDAQ = false;           % Indicates that Z is on its own DAQ
        parallelSupport = false;        % Dependent. Indicates that simultaneous imaging and stim are possible
        hasGalvos = false;
        hasBeams = false;
        hasZ = false;
        zActuatorId = [];
        hasSlm = false;
        
        sampleRates;
        stimAO;                         % Stores the last generated AO. In sequence mode this is a structure with fields for galvos and beams. In on demand mode
                                        % this is an array of structures (one for each stimulus group) with fields for galvos and beams
        stimPath;                        % Stores the last generated Path. In sequence mode this is a structure with fields for galvos and beams. In on demand mode
                                        % this is an array of structures (one for each stimulus group) with fields for galvos and beams
                                        
        primedStimulus;                 % For on demand mode. Indicates which stimulus is currently in the buffer ready to go
        
        softPulseTermString;
        trigTermString;
        syncTermString;
        
        stimScannersetCache = [];       % used to buffer the stim scannerset to improve performance
        hMonitoringFile = [];           % handle to the monitoring file
        
        currentlyMonitoring = false;
        currentlyLogging = false;
        
        monitoringRingBuffer;           % used to allow a trailing display of the laser path
        
        autoTrTerms = {};
        frameTrTerms = {};
        frameScTerms = {};
        
        beamIDs = [];                   % Beam IDs (as in hBeams) used by Photostim module
    end
    
    properties (Hidden,Dependent)
        hSlm;                           % Handle to SLM scanner
    end
    
    properties(SetObservable,Transient)
        % this should be included in the TIFF header
        
        monitoringSampleRate = 9000;        % [Hz] sample rate for the analog inputs. This is initialized to 9000.
    end
    
    properties(Constant, Hidden)
        monitoringEveryNSamples = 300;      % display rate = monitoringSampleRate/monitoringEveryNSamples
        monitoringBufferSizeSeconds = 10;    % [s] buffersize of the AI DAQmx monitoring task
        monitoringRingBufferSize = 10;      % number of callback data that can be stored in the ring buffer
    end

    %% LIFECYCLE
    methods(Hidden)
        function obj = Photostim(hSI)
            obj = obj@scanimage.interfaces.Component(hSI,false,true);
            
            try
                if isprop(hSI, 'hLinScan')
                    obj.hScan = hSI.hLinScan;
                    if ~isa(obj.hScan, 'scanimage.components.scan2d.LinScan')
                        return;
                    end
                elseif ~isempty(obj.mdfData.photostimScannerName)
                    obj.hScan = hSI.hScanner(obj.mdfData.photostimScannerName);
                    
                    assert(~isempty(obj.hScan),...
                        'Photostim: incorrect entry for MDF variable photostimScannerName. Scanner ''%s'' not available.',...
                        obj.mdfData.photostimScannerName);
                    
                    if isa(obj.hScan,'scanimage.components.scan2d.SlmScan')
                        if ~isempty(obj.hScan.hLinScan)
                            obj.hScan = obj.hScan.hLinScan;
                        end
                    end
                    
                    assert(ismember(class(obj.hScan), {'scanimage.components.scan2d.LinScan' 'scanimage.components.scan2d.SlmScan'}),...
                        'Invalid scanner choice ''%s'' for photostim. Must be a linear or SLM scanner.', obj.mdfData.photostimScannerName);
                else
                    return;
                end
                
                scannerMdf = obj.hScan.mdfData;
                beamMdf = hSI.hBeams.mdfData;
                
                if ~isempty(scannerMdf.beamDaqID) && numel(beamMdf.beamDaqDevices) >= scannerMdf.beamDaqID
                    obj.beamIDs = cell2mat(obj.hSI.hBeams.daqBeamIDs(scannerMdf.beamDaqID));
                    obj.hasBeams = ~isempty(obj.beamIDs);
                    beamDev = beamMdf.beamDaqDevices{scannerMdf.beamDaqID};
                    beamMdf = beamMdf.beamDaqs(scannerMdf.beamDaqID);
                end
                
                obj.hRouteRegistry = dabs.ni.daqmx.util.triggerRouteRegistry();
                obj.hRouteRegistrySlm = dabs.ni.daqmx.util.triggerRouteRegistry();
                
                obj.hasGalvos = isa(obj.hScan,'scanimage.components.scan2d.LinScan');
                if obj.hasGalvos
                    obj.hTaskGalvo = most.util.safeCreateTask('PhotostimTask');
                    obj.hTaskGalvo.createAOVoltageChan(scannerMdf.deviceNameGalvo, scannerMdf.XMirrorChannelID, 'PhotostimGalvoX');
                    obj.hTaskGalvo.createAOVoltageChan(scannerMdf.deviceNameGalvo, scannerMdf.YMirrorChannelID, 'PhotostimGalvoY');
                    
                    hDaqDev = dabs.ni.daqmx.Device(scannerMdf.deviceNameGalvo);
                    galvoBusType = get(hDaqDev,'busType');
                    
                    switch galvoBusType
                        case {'DAQmx_Val_PXI','DAQmx_Val_PXIe'}
                            set(obj.hTaskGalvo,'sampClkTimebaseRate',10e6);
                            set(obj.hTaskGalvo,'sampClkTimebaseSrc',['/' scannerMdf.deviceNameGalvo '/PXI_Clk10']);
                        otherwise
                            try
                                %try automatic routing
                                obj.hTaskGalvo.cfgSampClkTiming(1000,'DAQmx_Val_FiniteSamps',1000); % this is only preliminary, we need to set up timing or reserving the task will throw an error
                                set(obj.hTaskGalvo,'sampClkTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                                set(obj.hTaskGalvo,'sampClkTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                                obj.hTaskGalvo.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                                obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve');
                            catch ME
                                % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                                % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                                if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                                    rethrow(ME)
                                end
                                
                                most.idioms.warn('Photostim galvo task timebase could not be synchronized to reference clock.');
                                set(obj.hTaskGalvo,'sampClkTimebaseRate',100e6);
                                set(obj.hTaskGalvo,'sampClkTimebaseSrc','100MHzTimebase');
                            end
                    end
                    
                    obj.hTaskMain = obj.hTaskGalvo;
                end
                
                if isempty(obj.beamIDs)
                    obj.separateBeamDAQ = false;
                    assert(obj.hasGalvos, 'Operation without galvos OR beams is not yet supported.');
                elseif obj.hasGalvos && strcmp(beamDev, scannerMdf.deviceNameGalvo)
                    % Galvos and beams are on same DAQ
                    obj.separateBeamDAQ = false;
                    obj.hTaskGalvo.createAOVoltageChan(scannerMdf.deviceNameGalvo, beamMdf.chanIDs, 'PhotostimBeams');
                else
                    % Galvos and beams are on separate DAQ
                    obj.separateBeamDAQ = true;
                    obj.hTaskBeams = most.util.safeCreateTask('PhotostimBeamTask');
                    obj.hTaskBeams.createAOVoltageChan(beamDev, beamMdf.chanIDs, 'PhotostimBeams');
                    
                    if ~obj.hasGalvos
                        obj.hTaskMain = obj.hTaskBeams;
                    end
                end
                
                obj.zActuatorId = obj.hSI.hFastZ.zScannerId(obj.hScan.name);
                if obj.hSI.hFastZ.isSlms(obj.zActuatorId)
                    obj.zActuatorId = []; % don't use SLM as FastZ here
                end
                
                if ~isempty(obj.zActuatorId)
                    obj.hasZ = true;
                    zMdf = obj.hSI.hFastZ.mdfData.actuators(obj.zActuatorId);
                    % determine which task to add Z to
                    zDaq = zMdf.daqDeviceName;
                    zTask = [];
                    if obj.hasBeams
                        obj.zWithBeams = strcmp(zDaq,beamDev);
                        if obj.zWithBeams
                            if obj.separateBeamDAQ
                                zTask = obj.hTaskBeams;
                            else
                                obj.zWithGalvos = true;
                                zTask = obj.hTaskGalvo;
                            end
                        end
                    end
                    
                    if isempty(zTask)
                        galvoDaq = scannerMdf.deviceNameGalvo;
                        obj.zWithGalvos = strcmp(zDaq,galvoDaq);
                        if obj.zWithGalvos
                            zTask = obj.hTaskGalvo;
                        end
                    end
                    
                    if isempty(zTask)
                        obj.hTaskZ = most.util.safeCreateTask('PhotostimZTask');
                        zTask = obj.hTaskZ;
                    end
                    
                    zTask.createAOVoltageChan(zDaq, zMdf.cmdOutputChanID, 'PhotostimZ');
                    
                    if ~obj.zWithBeams && ~obj.zWithGalvos
                        obj.separateZDAQ = true;
                        configTaskSync(obj.hTaskZ, 'Z');
                    end
                end
                
                if obj.separateBeamDAQ
                    % this is done after adding z to the task if applicable
                    configTaskSync(obj.hTaskBeams, 'beams');
                end
                
                obj.hTaskMain.registerDoneEvent(@obj.taskDoneCallback);
                obj.hTaskMain.registerEveryNSamplesEvent(@obj.nSampleCallback,1000,false);
                obj.hTaskMain.cfgSampClkTiming(1000,'DAQmx_Val_FiniteSamps',1000);
                obj.hTaskMain.cfgDigEdgeStartTrig('Ctr0InternalOutput');
                
                obj.hTaskSoftPulse = most.util.safeCreateTask('PhotostimSoftTriggerTask');
                triggerChannel = scanimage.util.translateTriggerToPort('PFI8');
                obj.hTaskSoftPulse.createDOChan(obj.hTaskMain.deviceNames{1},triggerChannel);
                obj.softPulseTermString = ['/' obj.hTaskMain.deviceNames{1} '/PFI8'];
                
                obj.hTaskDigitalOut = most.util.safeCreateTask('PhotostimActiveSignalTask');
                obj.hTaskDigitalOut.createDOChan(obj.hTaskMain.deviceNames{1},'port0/line0');
                obj.hTaskDigitalOut.createDOChan(obj.hTaskMain.deviceNames{1},'port0/line1');
                obj.hTaskDigitalOut.cfgSampClkTiming(1000,'DAQmx_Val_FiniteSamps',1000);
                set(obj.hTaskDigitalOut,'sampClkTimebaseRate',get(obj.hTaskMain,'sampClkTimebaseRate'));
                set(obj.hTaskDigitalOut,'sampClkTimebaseSrc',get(obj.hTaskMain,'sampClkTimebaseSrc'));
                obj.hTaskDigitalOut.cfgDigEdgeStartTrig('Ctr0InternalOutput');
                
                obj.numInstances = 1;
                
                %hScan can be empty, so adding the following line to the
                %DependsOn Properties can throw an error
                %s.stimScannerset            = struct('DependsOn',{{'hScan.scannerset'}});
                lh = addlistener(obj.hScan,'scannerset','PostSet',@(src,evt)setStimScannerset(NaN));
                obj.hListeners = [obj.hListeners lh];
                
                lh = addlistener(obj.hSI.hConfigurationSaver,'cfgLoadingInProgress','PostSet',@(src,evt)cfgLoadingChanged());
                obj.hListeners = [obj.hListeners lh];
                
                lh = addlistener(obj.hSI,'imagingSystem','PreSet',@(src,evt)obj.stopMonitoring());
                obj.hListeners = [obj.hListeners lh];
                lh = addlistener(obj.hSI,'imagingSystem','PostSet',@(src,evt)cfgLoadingChanged());
                obj.hListeners = [obj.hListeners lh];
            catch ME
                obj.numInstances = 0;
                most.idioms.warn('Photostimulation module initialization failed. Error:\n%s', ME.message);
            end
            
            function setStimScannerset(val)
                obj.stimScannerset = val;
            end
            
            function cfgLoadingChanged()
                if obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                    obj.stopMonitoring();
                else
                    obj.monitoring = obj.monitoring;
                end
            end
            
            function configTaskSync(hTask,name)
                %%% configure reference clock sharing
                devName = hTask.deviceNames{1};
                hDaqDevice = dabs.ni.daqmx.Device(devName);
                busType = get(hDaqDevice,'busType');
                switch busType
                    case {'DAQmx_Val_PXI','DAQmx_Val_PXIe'}
                        term = ['/' devName '/PXI_Clk10'];
                        rate = 10e6;
                    otherwise
                        try
                            %try automatic routing
                            hTask.cfgSampClkTiming(1000,'DAQmx_Val_FiniteSamps',1000); % this is only preliminary, we need to set up timing or reserving the task will throw an error
                            set(hTask,'sampClkTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                            set(hTask,'sampClkTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                            hTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                            hTask.control('DAQmx_Val_Task_Unreserve');
                            term = obj.hScan.trigReferenceClkOutInternalTerm;
                            rate = obj.hScan.trigReferenceClkOutInternalRate;
                        catch ME
                            % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                            % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                            if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                                rethrow(ME)
                            end
                            
                            if strcmp(name,'beams')
                                term = beamMdf.referenceClockIn;
                                if isfield(beamMdf,'referenceClockRate') && ~isempty(beamMdf.referenceClockRate)
                                    rate = beamMdf.referenceClockRate;
                                else
                                    rate = 10e6;
                                end
                                msg = sprintf('Make sure to configure beamDaqs(%d).referenceClockIn in the Machine Data File',scannerMdf.beamDaqID);
                            else
                                term = [];
                                msg = 'Put Z DAQ in same PXI chassis or connect with RTSI cable to digital IO DAQ.';
                            end
                        end
                end
                
                if isempty(term)
                    most.idioms.warn(['Photostim ' name ' task timebase could not be synchronized to galvos. ' msg]);
                    set(hTask,'sampClkTimebaseRate',100e6);
                    set(hTask,'sampClkTimebaseSrc','100MHzTimebase');
                else
                    set(hTask,'sampClkTimebaseRate',rate);
                    set(hTask,'sampClkTimebaseSrc',term);
                end
                
                %%% route start trigger
                try
                    %try automatic routing
                    hTask.cfgDigEdgeStartTrig(sprintf('/%s/Ctr0InternalOutput', obj.hTaskMain.deviceNames{1}));
                    hTask.cfgSampClkTiming(1000,'DAQmx_Val_FiniteSamps',1000); % this is only preliminary, we need to set up timing or reserving the task will throw an error
                    hTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    hTask.control('DAQmx_Val_Task_Unreserve');
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    
                    if strcmp(name,'beams')
                        frClk = beamMdf.frameClockIn;
                        cfgName = sprintf('beamDaqs(%d)',scannerMdf.beamDaqID); 
                    else
                        frClk = zMdf.frameClockIn;
                        cfgName = sprintf('Fast Z actuators(%d)',obj.zActuatorId);
                    end
                    
                    if ~isempty(frClk)
                        hTask.cfgDigEdgeStartTrig(frClk);
                    else
                        most.idioms.warn(['Photostim ' name ' task start trigger could not be routed correctly - ', ...
                            'Photostim galvos and ' name ' are out of sync. ', ...
                            'Make sure to configure ' cfgName '.frameClockIn in the Machine Data File'])
                    end
                end
            end
        end                
        
        function delete(obj)
            obj.abort();
            most.idioms.safeDeleteObj(obj.hTaskGalvo);
            most.idioms.safeDeleteObj(obj.hTaskBeams);
            most.idioms.safeDeleteObj(obj.hTaskZ);
            most.idioms.safeDeleteObj(obj.hTaskAutoTrigger);
            most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
            most.idioms.safeDeleteObj(obj.hTaskSyncHelper);
            most.idioms.safeDeleteObj(obj.hTaskSoftPulse);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSel);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSelRead);
            most.idioms.safeDeleteObj(obj.hTaskMonitoring);
            most.idioms.safeDeleteObj(obj.hTaskDigitalOut);
            most.idioms.safeDeleteObj(obj.hRouteRegistry); % disconnects daqmx routes
            most.idioms.safeDeleteObj(obj.hRouteRegistrySlm);
            delete(obj.hListeners);
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@scanimage.interfaces.Component(obj);
            if obj.numInstances
                obj.hasSlm = ~isempty(obj.hSlm);
            end
        end
    end

    %% PROP ACCESS
    methods
        function set.stimTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('stimTriggerTerm',v);
            
            % triggering settings may have changed. clear the trigger task so that it is reconfigured at next start
            most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
            
            if obj.numInstances
                if v < 0
                    pfn = 1;
                else
                    pfn = v;
                end
                obj.trigTermString = sprintf('/%s/PFI%d',obj.hTaskMain.deviceNames{1},pfn);
                
                obj.stimTriggerTerm = v;
                
                if obj.autoTriggerPeriod
                    obj.autoTriggerPeriod = obj.autoTriggerPeriod;
                end
            end
        end
        
        function set.autoTriggerPeriod(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('autoTriggerPeriod',v);
            
            % triggering settings may have changed. clear the trigger task so that it is reconfigured at next start
            most.idioms.safeDeleteObj(obj.hTaskAutoTrigger);
            
            obj.autoTriggerPeriod = v;
            if obj.numInstances && v
                obj.hTaskAutoTrigger = most.util.safeCreateTask('PhotostimAutoTriggerTask');
                obj.hTaskAutoTrigger.createCOPulseChanTime(obj.hTaskMain.deviceNames{1}, 3, '', v/2, v/2, 0);
                obj.hTaskAutoTrigger.cfgImplicitTiming('DAQmx_Val_ContSamps');
                obj.hTaskAutoTrigger.channels(1).set('pulseTerm','');
            end
        end
        
        function set.syncTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('syncTriggerTerm',v);
            
            most.idioms.safeDeleteObj(obj.hTaskSyncHelper);
            
            % triggering settings may have changed. clear the trigger task so that it is reconfigured at next start
            most.idioms.safeDeleteObj(obj.hTaskArmedTrig);
            
            if isempty(v)
                obj.syncTriggerTerm = v;
                obj.syncTermString = v;
            elseif obj.numInstances
                if v < 0
                    pfn = 2;
                else
                    pfn = v;
                end
                obj.syncTermString = sprintf('/%s/PFI%d',obj.hTaskMain.deviceNames{1},pfn);
                
                obj.syncTriggerTerm = v;
            end
        end
        
        function set.stimSelectionTerms(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('stimSelectionTerms',v);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSelRead);
            obj.stimSelectionTerms = v;
        end
        
        function set.stimSelectionTriggerTerm(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            v = obj.validatePropArg('stimSelectionTriggerTerm',v);
            most.idioms.safeDeleteObj(obj.hTaskExtStimSel);
            obj.stimSelectionTriggerTerm = v;
        end
        
        function set.stimScannerset(obj,val)
            obj.mdlDummySetProp(val,'stimScannerset');
            obj.stimScannersetCache = obj.stimScannerset;
        end

        function val = get.stimScannerset(obj)
            if isempty(obj.hScan)
                val = [];
            else
                val = obj.hScan.scannerset;
                if isa(val, 'scanimage.mroi.scannerset.GalvoGalvo')
                    val.fillFractionSpatial = 1;
                    if ~isempty(val.beams)
                        val.beams.powerBoxes = [];
                    end
                    
                    if ~obj.hasZ
                        val.fastz = [];
                    end
                end
            end
        end
        
        function set.stimulusMode(obj, v)
            assert(~obj.active, 'Cannot change this property while active.');
            assert(ismember(v, {'sequence' 'onDemand'}), 'Invalid choice for stimulus mode.');
            if obj.numInstances
                obj.stimulusMode = v;
            end
        end
        
        function set.allowMultipleOutputs(obj, v)
            obj.allowMultipleOutputs = v;
            
            if obj.active && strcmp(obj.stimulusMode, 'onDemand')
                obj.clearOnDemandStatus();
                obj.primedStimulus = [];
                
                if obj.hasGalvos
                    obj.hTaskGalvo.set('startTrigRetriggerable', obj.allowMultipleOutputs);
                end
                if obj.separateBeamDAQ
                    obj.hTaskBeams.set('startTrigRetriggerable', obj.allowMultipleOutputs);
                end
                if obj.separateZDAQ && obj.zMode3D
                    obj.hTaskZ.set('startTrigRetriggerable', obj.allowMultipleOutputs);
                end
                obj.hTaskDigitalOut.set('startTrigRetriggerable', obj.allowMultipleOutputs);
            end
        end
        
        function val = get.hSlm(obj)
            val = [];
            if ~isempty(obj.hScan.scannerset)
                ss = obj.hScan.scannerset.slm;
                if most.idioms.isValidObj(ss)
                    val = ss.scanners{1};
                end
            end
        end
        
        function startMonitoring(obj,sync)
        %   Starts the monitoring process for the associated Photostim object.
        %   
        %   Parameters
        %       sync - Flag that determines whether (true) or not (false)
        %       to set up a start trigger and perform automatic routing.
        %   
        %   Syntax
        %       photostimObj.startMonitoring(sync)
            
            if nargin < 2 || isempty(sync)
                sync = false;
            end
            
            if obj.numInstances <= 0
                return
            end
            
            if ~most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.prepareMonitorTask();
            elseif ~obj.hTaskMonitoring.isTaskDone
                return
            else
                obj.hTaskMonitoring.abort();
            end
            
            if sync
                %%% set up start trigger
                try
                    %try automatic routing
                    obj.hTaskMonitoring.cfgDigEdgeStartTrig(obj.hSI.hScan2D.trigFrameClkOutInternalTerm);
                    obj.hTaskMonitoring.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTaskMonitoring.control('DAQmx_Val_Task_Unreserve');
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    if isempty(obj.mdfData.loggingStartTrigger)
                        most.idioms.warn('Could not sync photostim monitoring start trigger to imaging. Make sure to specify loggingStartTrigger in Photostim MDF');
                        obj.hTaskMonitoring.disableStartTrig()
                    else
                        obj.hTaskMonitoring.cfgDigEdgeStartTrig(obj.mdfData.loggingStartTrigger);
                    end
                end
                
                %%% set up timebase
                hDev = dabs.ni.daqmx.Device(obj.hTaskMonitoring.deviceNames{1});
                switch get(hDev,'busType')
                    case {'DAQmx_Val_PXI','DAQmx_Val_PXIe'}
                        set(obj.hTaskMonitoring,'sampClkTimebaseRate',10e6);
                        set(obj.hTaskMonitoring,'sampClkTimebaseSrc',['/' hDev.deviceName '/PXI_Clk10']);
                    otherwise
                        if isempty(obj.hScan.mdfData.referenceClockIn)
                            most.idioms.warn('Could not sync photostim monitoring timebase to ResScan. Make sure to specify referenceClockIn in LinScan MDF');
                        else
                            set(obj.hTaskMonitoring,'sampClkTimebaseRate',10e6);
                            set(obj.hTaskMonitoring,'sampClkTimebaseSrc',obj.hScan.mdfData.referenceClockIn);
                        end                        
                end
            else
                obj.hTaskMonitoring.disableStartTrig();
            end
            
            obj.monitoringRingBuffer = NaN(obj.monitoringRingBufferSize * obj.monitoringEveryNSamples,3);
            obj.hTaskMonitoring.start();
        end
        
        function maybeStopMonitoring(obj)
        %   Stops the monitoring process for the associated Photostim object only if no monitoring and 
        %   no logging processes are currently active.
        %   
        %   Syntax
        %       photostimObj.maybeStopMonitoring()
            if ~obj.currentlyMonitoring && ~obj.currentlyLogging
               obj.stopMonitoring();
            end
        end
        
        function stopMonitoring(obj)
        %   Stops the monitoring process for the associated Photostim object. 
        %   
        %   Syntax
        %       photostimObj.stopMonitoring()
            obj.currentlyMonitoring = false;
            obj.currentlyLogging = false;
            
            if obj.numInstances <= 0
                return
            end
            
            if ~most.idioms.isValidObj(obj.hTaskMonitoring)
                return;
            end
            
            try
                obj.hTaskMonitoring.abort();
                obj.hTaskMonitoring.control('DAQmx_Val_Task_Unreserve');
                obj.monitoringRingBuffer = [];
                if ~isempty(obj.hSI.hDisplay.hLinesPhotostimMonitor)
                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.patch],'Visible','off');
                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarker],'Visible','off');
                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],'Visible','off');
                end
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function set.monitoring(obj,val)
            val = obj.validatePropArg('monitoring',val);
            
            if obj.numInstances <= 0
                return
            end
            
            if val && val ~= obj.monitoring && ~obj.graphics2014b
                v = ver('MATLAB');
                v = strrep(strrep(v.Release,'(',''),')','');
                choice = questdlg(sprintf('Matlab version %s can become instable using photostim monitoring.\nMatlab version 2015a or later is recommended.\n\nDo you want to enable the feature anyway?',v),...
                    'Matlab version warning','Yes','No','No');
                if ~strcmpi(choice,'yes');
                    return
                end
            end
            
            assert(~val || (obj.hScan.xGalvo.feedbackCalibrated && obj.hScan.yGalvo.feedbackCalibrated), 'Photostim feedback calibration is invalid. Feedback sensors must be calibrated first.');
            
            if obj.componentUpdateProperty('monitoring',val)
                if val
                    obj.hSI.hDisplay.forceRoiDisplayTransform = true;
                    
                    if ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                        obj.currentlyMonitoring = true;
                        try
                            obj.startMonitoring();
                        catch ME
                            obj.currentlyMonitoring = false;
                            ME.rethrow;
                        end
                    end
                else
                    obj.currentlyMonitoring = false;
                    obj.maybeStopMonitoring();
                    obj.hSI.hDisplay.forceRoiDisplayTransform = false;
                end
                
                obj.monitoring = val;
            end
        end
        
        function set.logging(obj,val)
            val = obj.validatePropArg('logging',val);
            
            if obj.numInstances <= 0
                return
            end
            
            assert(~val || (obj.hScan.xGalvo.feedbackCalibrated && obj.hScan.yGalvo.feedbackCalibrated), 'Photostim feedback calibration is invalid. Feedback sensors must be calibrated first.');
            
            if obj.currentlyLogging
                error('Cannot disable logging while logging is in progress');
            end
            
            obj.logging = val;
        end
        
        function set.monitoringXAiId(obj, v)
            v = obj.validatePropArg('monitoringXAiId',v);
            assert(~obj.currentlyMonitoring && ~obj.currentlyLogging, 'Cannot change this property while monitoring or logging.');
            
            %Force this task to be recreated
            if most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.hTaskMonitoring.clear();
            end
            
            %write to mdf?
            if obj.hasGalvos
                obj.hScan.mdfData.XMirrorPosChannelID = v;
            end
        end
        
        function v = get.monitoringXAiId(obj)
            if ~obj.hasGalvos
                v = 2;
                return;
            end
            v = obj.hScan.mdfData.XMirrorPosChannelID;
            v(isempty(v)) = 2;
        end
        
        function set.monitoringXTermCfg(obj, v)
            v = obj.validatePropArg('monitoringXTermCfg',v);
            assert(~obj.currentlyMonitoring && ~obj.currentlyLogging, 'Cannot change this property while monitoring or logging.');
            
            %Force this task to be recreated
            if most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.hTaskMonitoring.clear();
            end
            
            %write to mdf?
            if obj.hasGalvos
                obj.hScan.mdfData.XMirrorPosTermCfg = v;
            end
        end
        
        function v = get.monitoringXTermCfg(obj)
            if ~obj.hasGalvos
                v = 'Differential';
                return;
            end
            v = obj.hScan.mdfData.XMirrorPosTermCfg;
        end
        
        function set.monitoringYAiId(obj, v)
            v = obj.validatePropArg('monitoringYAiId',v);
            assert(~obj.currentlyMonitoring && ~obj.currentlyLogging, 'Cannot change this property while monitoring or logging.');
            
            %Force this task to be recreated
            if most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.hTaskMonitoring.clear();
            end
            
            %write to mdf?
            if obj.hasGalvos
                obj.hScan.mdfData.YMirrorPosChannelID = v;
            end
        end
        
        function v = get.monitoringYAiId(obj)
            if ~obj.hasGalvos
                v = 3;
                return;
            end
            v = obj.hScan.mdfData.YMirrorPosChannelID;
            v(isempty(v)) = 3;
        end
        
        function set.monitoringYTermCfg(obj, v)
            v = obj.validatePropArg('monitoringYTermCfg',v);
            assert(~obj.currentlyMonitoring && ~obj.currentlyLogging, 'Cannot change this property while monitoring or logging.');
            
            %Force this task to be recreated
            if most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.hTaskMonitoring.clear();
            end
            
            %write to mdf?
            if obj.hasGalvos
                obj.hScan.mdfData.YMirrorPosTermCfg = v;
            end
        end
        
        function v = get.monitoringYTermCfg(obj)
            if ~obj.hasGalvos
                v = 'Differential';
                return;
            end
            v = obj.hScan.mdfData.YMirrorPosTermCfg;
        end
        
        function set.monitoringBeamAiId(obj, v)
            v = obj.validatePropArg('monitoringBeamAiId',v);
            assert(~obj.currentlyMonitoring && ~obj.currentlyLogging, 'Cannot change this property while monitoring or logging.');
            
            %Force this task to be recreated
            if most.idioms.isValidObj(obj.hTaskMonitoring)
                obj.hTaskMonitoring.clear();
            end
            
            %write to mdf?
            obj.mdfData.BeamAiId = v;
        end
        
        function v = get.monitoringBeamAiId(obj)
            v = obj.mdfData.BeamAiId;
        end
        
        function v = get.parallelSupport(obj)
            if obj.numInstances
                scannerMdf = obj.hScan.mdfData;
                
                aoCtrDaq = scannerMdf.deviceNameGalvo;
                aiDaq = obj.hScan.deviceNameGalvoFeedback;
                
                imagingScannerMdf = obj.hSI.hScan2D.mdfData;
                if isa(obj.hSI.hScanner, 'scanimage.components.scan2d.ResScan')
                    imagingAoCtrDaqs = unique({imagingScannerMdf.galvoDeviceName imagingScannerMdf.digitalIODeviceName});
                    imagingAiDaqs = {};
                elseif isa(obj.hSI.hScanner, 'scanimage.components.scan2d.LinScan')
                    imagingAoCtrDaqs = unique({imagingScannerMdf.deviceNameAux imagingScannerMdf.deviceNameGalvo});
                    imagingAiDaqs = {imagingScannerMdf.deviceNameAcq};
                else
                    v = false;
                    return;
                end
                
                v = isempty(intersect(aoCtrDaq, imagingAoCtrDaqs));
                v = v && isempty(intersect(aiDaq, imagingAiDaqs));
                v = v && ~obj.hasBeams || isempty(imagingScannerMdf.beamDaqID) || (scannerMdf.beamDaqID ~= imagingScannerMdf.beamDaqID);
            else
                v = false;
            end
        end
        
        function set.stimRoiGroups(obj,v)
            if isempty(v)
                obj.stimRoiGroups = scanimage.mroi.RoiGroup.empty;
            else
                assert(isa(v,'scanimage.mroi.RoiGroup'), 'Invalid setting for stimRoiGroups.');
                obj.stimRoiGroups = v;
            end
        end
        
        function set.zMode(obj,v)
            if obj.zWithBeams || obj.zWithGalvos
                % if z shares a daq with beams or galvos, must use 3d mode
                v = '3D';
            elseif ~obj.hasZ
                v = '2D';
            end
            obj.zMode = v;
            obj.zMode3D = strcmp(v,'3D');
        end
    end
    
    %% USER METHODS
    methods
        function start(obj)
        %   This 'start' method overrides the default implementation of scanimage.interfaces.Component.start. 
        %   Using the regular implementation of start is problematic because the photostim component
        %   can be started and stopped independently of the imaging components. 
        %   A failure in photostim should not necessarily affect imaging. 
        %
        %   -Make sure that the photostim component is configured and has
        %   been successfully initialized. Ensure LinScan is configured.
        %
        %   -If the photostim component is already active. You must first
        %   abort if you want to load new stimulus patterns.
        %   
        %   -Photostim can only be started in on demand mode while imaging/linear imaging is active. 
        %   
        %   Syntax
        %       photostimObj.start()
            
            assert(~obj.active, 'The photostim component is already active. You must first abort if you want to load new stimulus patterns.');
            assert(obj.numInstances > 0, 'The photostim component is not configured or failed to initialize. Ensure LinScan is configured.');
            assert(~obj.hSI.active || obj.parallelSupport || strcmp(obj.stimulusMode, 'onDemand'), 'This system does not support simultaneous imaging and stimulation. Photostim can only be started in on demand mode while imaging is active.');
            assert(~obj.hScan.active || strcmp(obj.stimulusMode, 'onDemand'), 'Photostim can only be started in on demand mode while linear imaging is active.');
            
            if obj.zMode3D
                imagingZid = obj.hSI.hFastZ.zScannerId(obj.hSI.hScan2D.name);
                assert(isempty(imagingZid) || ~obj.hScan.active || (imagingZid ~= obj.zActuatorId),...
                    'Cannot start in 3D mode because Z actuator is shared with imaging scanner which is currently imaging.');
            end
            
            try
                obj.status = 'Initializing...';
                obj.initInProgress = true;
                obj.completedSequences = 0;
                
                obj.park(); % also resets offsets
                
                [ao, triggerSamps, path] = obj.generateAO();
                
                if ~obj.hScan.simulated
                    % set up triggering
                    if ~isempty(obj.syncTriggerTerm) && ~most.idioms.isValidObj(obj.hTaskSyncHelper)
                        % Set up task to create 4 pulses on ctr1 for every sync rising edge
                        obj.hTaskSyncHelper = most.util.safeCreateTask('PhotostimSyncHelperTask');
                        obj.hTaskSyncHelper.createCOPulseChanTicks(obj.hTaskMain.deviceNames{1}, 1, '', '', 2, 2, 0);
                        obj.hTaskSyncHelper.channels(1).set('pulseTerm','');
                        obj.hTaskSyncHelper.set('startTrigRetriggerable',true);
                        obj.hTaskSyncHelper.cfgDigEdgeStartTrig(obj.syncTermString);
                        obj.hTaskSyncHelper.cfgImplicitTiming('DAQmx_Val_FiniteSamps',4);
                        obj.hTaskSyncHelper.start();
                    end
                    
                    if ~most.idioms.isValidObj(obj.hTaskArmedTrig)
                        obj.hTaskArmedTrig = most.util.safeCreateTask('PhotostimArmedTriggerTask');
                        
                        if isempty(obj.syncTriggerTerm)
                            % ctr0 is triggered by the stim trigger and internally timed. this
                            % counter isnt really needed. you could trigger the AO directly from
                            % the stim trigger. this is only here for consistency with syncd operation
                            obj.hTaskArmedTrig.createCOPulseChanTime(obj.hTaskMain.deviceNames{1}, 0, '', 1e-3, 1e-3, 0);
                        else
                            % ctr1 generates 4 pulses on every rising sync signal
                            % ctr1 is configured and started in the set method for sync channel
                            % ctr0 is triggered by the stim trigger and timed by ctr1
                            obj.hTaskArmedTrig.createCOPulseChanTicks(obj.hTaskMain.deviceNames{1}, 0, '', 'Ctr1InternalOutput', 2, 2, 0);
                        end
                        
                        obj.hTaskArmedTrig.set('startTrigRetriggerable',true);
                        obj.hTaskArmedTrig.cfgDigEdgeStartTrig(obj.trigTermString);
                        obj.hTaskArmedTrig.channels(1).set('pulseTerm',obj.hScan.hTrig.FRAME_CLOCK_TERM_OUT);
                    end
                    
                    % route frame clock
                    if obj.stimTriggerTerm < 0
                        trms = {obj.hSI.hScan2D.trigFrameClkOutInternalTerm, obj.trigTermString};
                        obj.hRouteRegistry.connectTerms(trms{1}, trms{2});
                        obj.frameTrTerms = trms;
                    end
                    if obj.syncTriggerTerm < 0
                        trms = {obj.hSI.hScan2D.trigFrameClkOutInternalTerm, obj.syncTermString};
                        obj.hRouteRegistry.connectTerms(trms{1}, trms{2});
                        obj.frameScTerms = trms;
                    end
                    
                    % route auto trigger
                    if obj.autoTriggerPeriod
                        trms = {sprintf('/%s/Ctr3InternalOutput',obj.hTaskMain.deviceNames{1}), obj.trigTermString};
                        obj.hRouteRegistry.connectTerms(trms{1}, trms{2});
                        obj.autoTrTerms = trms;
                    end
                    
                    if strcmp(obj.stimulusMode, 'onDemand')
                        if ~obj.hScan.active
                            obj.primedStimulus = 1;
                        else
                            obj.primedStimulus = [];
                        end
                        
                        % set up ext stim selection trigger
                        if ~isempty(obj.stimSelectionTerms)
                            %task that triggers a software callback when the trigger comes
                            if ~most.idioms.isValidObj(obj.hTaskExtStimSel)
                                obj.hTaskExtStimSel = most.util.safeCreateTask('PhotostimExtStimSelectionCOTask');
                                obj.hTaskExtStimSel.createCOPulseChanTime(obj.hTaskMain.deviceNames{1}, 2, '', 1e-3, 1e-3);
                                obj.hTaskExtStimSel.channels(1).set('pulseTerm','');
                                obj.hTaskExtStimSel.cfgImplicitTiming('DAQmx_Val_FiniteSamps',1);
                                obj.hTaskExtStimSel.registerDoneEvent(@obj.extStimSelectionCB);
                                obj.hTaskExtStimSel.cfgDigEdgeStartTrig(sprintf('PFI%d',obj.stimSelectionTriggerTerm));
                            end
                            
                            %task to actually read the digital lines
                            if ~most.idioms.isValidObj(obj.hTaskExtStimSelRead) 
                                if isempty(obj.stimSelectionDevice)
                                    dev = obj.hTaskMain.deviceNames{1};
                                else
                                    dev = obj.stimSelectionDevice;
                                end
                                
                                obj.hTaskExtStimSelRead = most.util.safeCreateTask('PhotostimExtStimSelectionDITask');
                                fcn = @(trm)obj.hTaskExtStimSelRead.createDIChan(dev,scanimage.util.translateTriggerToPort(trm));
                                arrayfun(fcn, obj.stimSelectionTerms, 'UniformOutput', false);
                            end
                            
                            obj.hTaskExtStimSelRead.control('DAQmx_Val_Task_Unreserve');
                            obj.hTaskExtStimSel.control('DAQmx_Val_Task_Unreserve');
                            obj.hTaskExtStimSel.start();
                        end
                    else
                        % sequence
                        obj.primedStimulus = [];
                        obj.sequencePosition = 1;
                        obj.nextStimulus = obj.sequenceSelectedStimuli(1);                        
                    end
                    
                    obj.hSI.hBeams.makeExtDaqReq(obj,obj.hScan.mdfData.beamDaqID);
                    
                    % prepare digital pulse task
                    obj.hTaskDigitalOut.set('startTrigRetriggerable',strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs);
                    obj.hTaskDigitalOut.cfgSampClkTiming(obj.sampleRates.digital,'DAQmx_Val_FiniteSamps',triggerSamps(1).D);
                    obj.hTaskDigitalOut.cfgOutputBuffer(size(ao(1).D,1));
                    if ~obj.hScan.active
                        obj.hTaskDigitalOut.control('DAQmx_Val_Task_Unreserve');
                        obj.hTaskDigitalOut.writeDigitalData(ao(1).D,[],false);
                    end
                    if strcmp(obj.stimulusMode, 'sequence')
                        obj.hTaskDigitalOut.start();
                    end
                    
                    % prepare galvo task
                    if obj.hasGalvos
                        obj.hTaskGalvo.set('startTrigRetriggerable',strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs);
                        obj.hTaskGalvo.cfgSampClkTiming(obj.sampleRates.galvo,'DAQmx_Val_FiniteSamps',triggerSamps(1).G);
                        obj.hTaskGalvo.cfgOutputBuffer(size(ao(1).G,1));
                        obj.hTaskGalvo.everyNSamples = triggerSamps(1).G;
                        
                        if ~obj.hScan.active
                            obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve');
                            buf = ao(1).G;
                            if obj.hasBeams && ~obj.separateBeamDAQ
                                buf = [buf ao(1).B];
                            end
                            if obj.zWithGalvos
                                buf = [buf ao(1).Z];
                            end
                            obj.hTaskGalvo.writeAnalogData(buf);
                        end
                        
                        if strcmp(obj.stimulusMode, 'sequence')
                            obj.hTaskGalvo.start();
                        end
                    end
                    
                    % prepare beam task
                    if obj.separateBeamDAQ
                        obj.hTaskBeams.set('startTrigRetriggerable',strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs);
                        obj.hTaskBeams.cfgSampClkTiming(obj.sampleRates.beams,'DAQmx_Val_FiniteSamps',triggerSamps(1).B);
                        obj.hTaskBeams.cfgOutputBuffer(size(ao(1).B,1));
                        
                        if ~obj.hasGalvos
                            obj.hTaskBeams.everyNSamples = triggerSamps(1).B;
                        end
                        
                        if ~obj.hScan.active
                            obj.hTaskBeams.control('DAQmx_Val_Task_Unreserve');
                            buf = ao(1).B;
                            if obj.zWithBeams
                                buf = [buf ao(1).Z];
                            end
                            obj.hTaskBeams.writeAnalogData(buf);
                        end
                        
                        if strcmp(obj.stimulusMode, 'sequence')
                            obj.hTaskBeams.start();
                        end
                    end
                    
                    % prepare z task
                    if obj.separateZDAQ && obj.zMode3D
                        obj.hTaskZ.set('startTrigRetriggerable',strcmp(obj.stimulusMode, 'sequence') || obj.allowMultipleOutputs);
                        obj.hTaskZ.cfgSampClkTiming(obj.sampleRates.fastz,'DAQmx_Val_FiniteSamps',triggerSamps(1).Z);
                        obj.hTaskZ.cfgOutputBuffer(size(ao(1).Z,1));
                        
                        if ~obj.hScan.active
                            obj.hTaskZ.control('DAQmx_Val_Task_Unreserve');
                            obj.hTaskBeams.writeAnalogData(ao(1).Z);
                        end
                        
                        if strcmp(obj.stimulusMode, 'sequence')
                            obj.hTaskZ.start();
                        end
                    end
                    
                    if obj.hasSlm && ~obj.hScan.active
                        obj.hSlm.writePhaseMaskRaw(ao(1).SLM(1).mask.phase,false);
                        obj.currentSlmPattern = path(1).SLM(1).pattern;
                        
                        
                        if strcmp(obj.stimulusMode, 'sequence')
                            % check for triggering
                            if obj.hSlm.queueAvailable && ~isempty(obj.hSlm.slmUpdateTriggerOutputTerm)
                                if ~strcmpi(obj.trigTermString,obj.hSlm.slmUpdateTriggerOutputTerm)
                                    obj.hRouteRegistrySlm.connectTerms(obj.trigTermString,obj.hSlm.slmUpdateTriggerOutputTerm);
                                end
                                
                                masks = arrayfun(@(ao_)ao_.mask.phase,obj.stimAO.SLM,'UniformOutput',false);
                                masks = cat(3,masks{:});
                                
                                obj.hSlm.resizeQueue(size(masks,3));
                                obj.hSlm.writeQueue(masks);
                                obj.hSlm.startQueue();
                                obj.slmQueueActive = true;
                            end
                        end                        
                    end
                    
                    % prepare slm
                    if strcmp(obj.stimulusMode, 'sequence')
                        if obj.hasBeams
                            obj.hSI.hBeams.updateBeamStatusFrac(obj.beamIDs,path(1).B);
                        end
                        obj.hTaskArmedTrig.start();
                        obj.hSI.hUserFunctions.notify('seqStimStart');
                    end
                end
                    
                obj.active = true;
                obj.lastMotion = [0 0];
                obj.initInProgress = false;
                
                obj.hSI.hShutters.shuttersTransition(obj.hScan.mdfData.shutterIDs, true); % opens shutters linked to scan systems in mdf?
                
                if strcmp(obj.stimulusMode, 'onDemand')
                    obj.status = 'Ready';
                elseif strcmp(obj.stimulusMode, 'sequence')
                    obj.status = 'Running';
                    if obj.stimImmediately
                        obj.triggerStim();
                    end
                end
                
                if most.idioms.isValidObj(obj.hTaskAutoTrigger)
                    try
                        obj.hTaskAutoTrigger.start();
                    catch
                        error('Failed to start auto trigger. DAQ route conflict.');
                    end
                end
            catch ME
                obj.initInProgress = false;
                obj.abort();
                ME.rethrow;
            end
        end
        
        function backupRoiGroups(obj)
        %   Saves the ROI (region of interest) groups defined in the associated Photostim object, 
        %   in a backup file in the filesystem directory where the scanimage application is currently running.
        %   
        %   The backup filename is 'roigroupsStim.backup'.
        %   
        %   Syntax
        %       photostimObj.backupRoiGroups()
            siDir = fileparts(which('scanimage'));
            filename = fullfile(siDir, 'roigroupsStim.backup');
            roigroupsStim = obj.stimRoiGroups; %#ok<NASGU>
            save(filename,'roigroupsStim','-mat');
        end 

        function triggerStim(obj)
        %   Triggers the stimulus for the associated Photostim object.
        %   
        %   -The Photostim module must be started before triggerStim() is called.
        %
        %   Syntax
        %       photostimObj.triggerStim()
            assert(obj.active, 'Photostim module must be started first.');
            
            if ~obj.hScan.simulated
                if ~isempty(obj.autoTrTerms)
                    obj.hRouteRegistry.disconnectTerms(obj.autoTrTerms{1}, obj.autoTrTerms{2});
                end
                if ~isempty(obj.frameTrTerms)
                    obj.hRouteRegistry.disconnectTerms(obj.frameTrTerms{1}, obj.frameTrTerms{2});
                end
                
                obj.hRouteRegistry.connectTerms(obj.softPulseTermString, obj.trigTermString);
                obj.hTaskSoftPulse.writeDigitalData([0;1;0],0.5,true);
                obj.hRouteRegistry.disconnectTerms(obj.softPulseTermString, obj.trigTermString);
                
                if ~isempty(obj.autoTrTerms)
                    obj.hRouteRegistry.connectTerms(obj.autoTrTerms{1}, obj.autoTrTerms{2});
                end
                if ~isempty(obj.frameTrTerms)
                    obj.hRouteRegistry.connectTerms(obj.frameTrTerms{1}, obj.frameTrTerms{2});
                end
            end
        end
        
        function triggerSync(obj)
        %   Triggers the synchronous stimulus for the associated Photostim object. 
        %   
        %   -The Photostim module must be started before triggerSync() is called.
        %
        %   Syntax
        %       photostimObj.triggerSync()
            assert(obj.active, 'Photostim module must be started first.');
            
            if ~obj.hScan.simulated && ~isempty(obj.syncTriggerTerm)
                if ~isempty(obj.frameScTerms)
                    obj.hRouteRegistry.disconnectTerms(obj.frameScTerms{1}, obj.frameScTerms{2});
                end
                
                obj.hRouteRegistry.connectTerms(obj.softPulseTermString, obj.syncTermString);
                obj.hTaskSoftPulse.writeDigitalData([0;1;0],0.5,true);
                obj.hRouteRegistry.disconnectTerms(obj.softPulseTermString, obj.syncTermString);
                
                if ~isempty(obj.frameScTerms)
                    obj.hRouteRegistry.connectTerms(obj.frameScTerms{1}, obj.frameScTerms{2});
                end
            end
        end
        
        function onDemandStimNow(obj, stimGroupIdx, verbose)
        %   Starts the stimulus process for the associated Photostim object, on demand. 
        %   
        %   -This method can only be used in onDemand mode.
        %
        %   -The Photostim module must be started before onDemandStimNow() is called. 
        %   
        %   -The linear scanner should not be actively imaging. Abort imaging to output a stimulation. 
        %
        %   Parameters
        %       stimGroupIdx - Stimulus group number.
        %       verbose - Flag that determines whether (true) or not (false) additional timing information 
        %       is to be written to the standard output.
        %   
        %   Syntax
        %       photostimObj.onDemandStimNow(stimGroupIdx, verbose)
            
            if nargin < 3 || isempty(verbose)
                verbose = false;
            end
            
            t = tic();
            assert(strcmp(obj.stimulusMode, 'onDemand'), 'This method can only be used in onDemand mode.');
            assert(obj.active, 'Photostim module must be started first.');
            assert(~obj.hScan.active, 'The linear scanner is actively imaging. Abort imaging to output a stimulation.');
            
            if ~strcmp(obj.status, 'Ready')
                if ~obj.allowMultipleOutputs
                    most.idioms.warn('The previous stimulus may not have completed output. Aborting to load new stimulus.');
                end
                obj.hTaskArmedTrig.abort();
                obj.hTaskDigitalOut.abort();
                
                if obj.hasGalvos
                    obj.hTaskGalvo.abort();
                end
                
                if obj.separateBeamDAQ
                    obj.hTaskBeams.abort();
                end
                
                if obj.separateZDAQ
                    obj.hTaskZ.abort();
                end
            end
            
            if obj.hasGalvos
                sz = size(obj.stimAO(stimGroupIdx).G,1);
            else
                sz = size(obj.stimAO(stimGroupIdx).B,1);
            end
            if ~isempty(obj.beamIDs)
                obj.hSI.hBeams.updateBeamStatusFrac(obj.beamIDs,obj.stimPath(stimGroupIdx).B);
            end
            if isempty(obj.primedStimulus) || obj.primedStimulus ~= stimGroupIdx
                assert(stimGroupIdx <= numel(obj.stimRoiGroups), 'Invalid stimulus group selection.');
                assert(sz > 0, 'The selected stimulus is empty. No output will be made.');
                
                obj.hTaskMain.everyNSamples = [];
                
                N = size(obj.stimAO(stimGroupIdx).D,1);
                obj.hTaskDigitalOut.control('DAQmx_Val_Task_Unreserve');
                obj.hTaskDigitalOut.cfgSampClkTiming(obj.sampleRates.digital,'DAQmx_Val_FiniteSamps',N);
                obj.hTaskDigitalOut.cfgOutputBuffer(N);
                obj.hTaskDigitalOut.writeDigitalData(obj.stimAO(stimGroupIdx).D,[],false);
                
                if obj.hasGalvos
                    obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve');
                    obj.hTaskGalvo.cfgSampClkTiming(obj.sampleRates.galvo,'DAQmx_Val_FiniteSamps',size(obj.stimAO(stimGroupIdx).G,1));
                    obj.hTaskGalvo.cfgOutputBuffer(sz);
                    
                    buf = obj.stimAO(stimGroupIdx).G;
                    if obj.hasBeams && ~obj.separateBeamDAQ
                        buf = [buf obj.stimAO(stimGroupIdx).B];
                    end
                    if obj.zWithGalvos
                        buf = [buf ao(1).Z];
                    end
                    obj.hTaskGalvo.writeAnalogData(buf);
                end
                
                if obj.separateBeamDAQ
                    obj.hTaskBeams.control('DAQmx_Val_Task_Unreserve');
                    obj.hTaskBeams.cfgSampClkTiming(obj.sampleRates.beams,'DAQmx_Val_FiniteSamps',size(obj.stimAO(stimGroupIdx).B,1));
                    obj.hTaskBeams.cfgOutputBuffer(sz);
                    
                    buf = obj.stimAO(stimGroupIdx).B;
                    if obj.zWithBeams
                        buf = [buf obj.stimAO(stimGroupIdx).Z];
                    end
                    obj.hTaskBeams.writeAnalogData(buf);
                end
                
                obj.hTaskMain.everyNSamples = sz;
                
                if obj.hasSlm
                    if ~obj.slmQueueActive
                        obj.hSlm.writePhaseMaskRaw(obj.stimAO(stimGroupIdx).SLM.mask.phase,false);
                    end
                    obj.currentSlmPattern = obj.stimPath(stimGroupIdx).SLM.pattern;
                end
                
                obj.primedStimulus = stimGroupIdx;
            end
            
            obj.numOutputs = 0;
            obj.hTaskMain.everyNSamples = sz;
            if obj.separateBeamDAQ
                obj.hTaskBeams.start();
            end
            if obj.separateZDAQ && obj.zMode3D
                obj.hTaskZ.start();
            end
            if obj.hasGalvos
                obj.hTaskGalvo.start();
            end
            obj.hTaskDigitalOut.start();
            obj.hTaskArmedTrig.start();
            
            obj.hSI.hUserFunctions.notify('onDmdStimStart');
            
            if obj.stimImmediately
                obj.triggerStim();
                obj.status = sprintf('Outputting stimulus group %d...', stimGroupIdx);
                if verbose
                    fprintf('It took %.4f seconds from the time you commanded to when the trigger was sent.\n',toc(t));
                end
            else
                obj.status = sprintf('Stimulus group %d waiting for trigger...', stimGroupIdx);
                if verbose
                    fprintf('It took %.4f seconds from the time you commanded to when the task was ready and started.\n',toc(t));
                end
            end
        end
        
        function abort(obj)
        %   Aborts any currently active tasks for the associated Photostim object. 
        %   
        %   -Aborted tasks include tasks associated with: auto triggers;
        %   armed triggers; beams; and external stimulus.
        %
        %   -The status of the associated Photostim object is set to 'Offline'. 
        %
        %   Syntax
        %       photostimObj.abort()            
        
            if obj.numInstances <= 0
                return
            end
            
            if ~isempty(obj.hScan)
                obj.hSI.hShutters.shuttersTransition(obj.hScan.mdfData.shutterIDs, false); % Close linked shutters
            end
            
            if most.idioms.isValidObj(obj.hTaskAutoTrigger)
                obj.hTaskAutoTrigger.abort();
            end
            
            if ~isempty(obj.autoTrTerms)
                obj.hRouteRegistry.disconnectTerms(obj.autoTrTerms{1}, obj.autoTrTerms{2});
                obj.autoTrTerms = {};
            end
            
            if ~isempty(obj.frameTrTerms)
                obj.hRouteRegistry.disconnectTerms(obj.frameTrTerms{1}, obj.frameTrTerms{2});
                obj.frameTrTerms = {};
            end
            
            if ~isempty(obj.frameScTerms)
                obj.hRouteRegistry.disconnectTerms(obj.frameScTerms{1}, obj.frameScTerms{2});
                obj.frameScTerms = {};
            end
            
            if most.idioms.isValidObj(obj.hTaskArmedTrig)
                obj.hTaskArmedTrig.abort();
            end
            
            if most.idioms.isValidObj(obj.hTaskDigitalOut)
                obj.hTaskDigitalOut.abort();
                obj.hTaskDigitalOut.control('DAQmx_Val_Task_Unreserve');
            end
            
            if obj.hasGalvos
                if most.idioms.isValidObj(obj.hTaskGalvo)
                    obj.park();
                end
            end
            
            if obj.hasSlm
                if obj.slmQueueActive
                    obj.hSlm.abortQueue();
                    obj.slmQueueActive = false;
                    obj.hRouteRegistrySlm.clearRoutes();
                end                
                
                obj.hSlm.parkScanner();
                obj.currentSlmPattern = [];
            end
            
            if obj.separateBeamDAQ
                obj.hTaskBeams.abort();
                obj.hTaskBeams.control('DAQmx_Val_Task_Unreserve');
            end
            
            if obj.separateZDAQ && obj.zMode3D
                obj.hTaskZ.abort();
                obj.hTaskZ.control('DAQmx_Val_Task_Unreserve');
            end
            
            obj.hSI.hBeams.clearExtDaqReqs(obj);
            
            if most.idioms.isValidObj(obj.hTaskExtStimSel)
                obj.hTaskExtStimSel.abort();
            end
            
            if any(obj.lastMotion)
                obj.hScan.hCtl.writeOffsetAngle([0 0]);
                obj.lastMotion = [0 0];
            end
            
            obj.status = 'Offline';
            obj.active = false;
            obj.lastMotion = [0 0];
            obj.primedStimulus = [];
            obj.hSI.hUserFunctions.notify('photostimAbort');
        end
        
        function calibrateMonitorAndOffset(obj)
        %   Calibrates the linear scanning mirror feedback (monitor) and offset. 
        %   
        %   -The associated Photostim object must be configured and
        %   successfully initialized before calibrateMonitorAndOffset() is
        %   called. Ensure LinScan is configured.
        %
        %   -Calibration cannot occur during an active photostimulation.
        %   
        %   -Calibration cannot occur while photostim logging is active.
        %
        %   Syntax
        %       photostimObj.calibrateMonitorAndOffset()            
            assert(obj.numInstances > 0, 'The photostim component is not configured or failed to initialize. Ensure LinScan is configured.');
            assert(~obj.active,'Cannot calibrate the monitor during active photostimulation');
            assert(~obj.currentlyLogging,'Cannot calibrate while photostim logging is active');
            
            monitoring_ = obj.monitoring;
            obj.monitoring = false;
            
            obj.hScan.calibrateGalvos();
                
            obj.monitoring = monitoring_;
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function compensateMotion(obj)
            if obj.active && obj.compensateMotionEnabled && ~isempty(obj.hSI.hMotionManager.motionHistory) && isa(obj.hScan, 'scanimage.components.scan2d.LinScan')
                absoluteMotion = obj.hSI.hMotionManager.motionCorrectionVector(1:2) .* strcmpi(obj.hSI.hMotionManager.correctionDeviceXY,'galvos');
                relativeMotion = obj.hSI.hMotionManager.motionHistory(end).drRef(1:2);
                motion = absoluteMotion + relativeMotion;
                if ~any(isnan(motion)) && ~isequal(obj.lastMotion,motion)                    
                    scannerOrigin_Ref = scanimage.mroi.util.xformPoints([0 0],obj.hScan.scannerToRefTransform);
                    motionPt_ref = scannerOrigin_Ref + motion;
                    motionPt_scanner = scanimage.mroi.util.xformPoints(motionPt_ref,obj.hScan.scannerToRefTransform,true);
                    
                    offsetAngleXY = motionPt_scanner;
                    obj.hScan.hCtl.writeOffsetAngle(offsetAngleXY);
                    
                    obj.lastMotion = motion;
                end  
            end
        end
        
        function park(obj)
            if obj.componentExecuteFunction('park')
                if obj.hasGalvos
                    obj.hTaskGalvo.abort();
                    obj.hTaskGalvo.control('DAQmx_Val_Task_Unreserve'); %should flush data
                end
                if ~obj.hScan.active
                    obj.hScan.parkScanner();
                end
            end
        end
        
        function [ao, samplesPerTrigger, path] = generateAO(obj)
            
            assert(~isempty(obj.stimRoiGroups),'There must be at least one stimulus group configured.');
            
            ss = obj.stimScannerset;
            obj.sampleRates.galvo = ss.scanners{1}.sampleRateHz;
            if obj.hasBeams
                obj.sampleRates.beams = ss.beams.sampleRateHz;
                obj.sampleRates.digital = obj.sampleRates.beams;
            else
                obj.sampleRates.digital = obj.sampleRates.galvo;
            end
            if obj.hasZ
                obj.sampleRates.fastz = ss.fastz.sampleRateHz;
            end
            advSamps = ceil(obj.laserActiveSignalAdvance * obj.sampleRates.digital);
            switch obj.stimulusMode
                case 'sequence'
                    assert(~isempty(obj.sequenceSelectedStimuli), 'At least one stimulus group must be selected for the sequence.');
                    assert(max(obj.sequenceSelectedStimuli) <= numel(obj.stimRoiGroups), 'Invalid stimulus group selection for sequence.');
                    %generate aos
                    
                    activeStimuli = sort(unique(obj.sequenceSelectedStimuli));
                    activeRoiGroups = obj.stimRoiGroups(activeStimuli);
                    indices = zeros(1,length(obj.stimRoiGroups));
                    indices(activeStimuli) = 1:length(activeStimuli);
                    
                    AOs = cell(1,length(activeRoiGroups));
                    paths = cell(1,length(activeRoiGroups));
                    for idx = 1:length(activeRoiGroups)
                        rg = activeRoiGroups(idx); 
                        [AOs{idx},~,~,paths{idx}] = rg.scanStackAO(ss,0,0,'',0,[],[],[]);
                        pause(0); % ensure the AO generation does not block Matlab for too long
                    end
                    
                    %make sure none are empty
                    if obj.hasGalvos
                        gSizes = cellfun(@(x)size(x.G,1), AOs);
                        assert(min(gSizes) > 0, 'One or more stimulus groups in the sequence were empty. Remove from the sequence to avoid unexpected results.');
                        
                        %pad AOs
                        [samplesPerTrigger.G, mi] = max(gSizes);
                        AOs = cellfun(@(x)setfield(x,'G',[x.G; repmat(x.G(end,:), samplesPerTrigger.G - size(x.G,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'G',[x.G; repmat(x.G(end,:), samplesPerTrigger.G - size(x.G,1), 1)]),paths,'UniformOutput',false);
                    else
                        bSizes = cellfun(@(x)size(x.B,1), AOs);
                        [~, mi] = max(bSizes);
                        assert(min(bSizes) > 0, 'One or more stimulus groups in the sequence were empty. Remove from the sequence to avoid unexpected results.');
                    end
                    
                    %pad AOs
                    if obj.hasBeams
                        bSizes = cellfun(@(x)size(x.B,1), AOs);
                        samplesPerTrigger.B = size(AOs{mi}.B, 1);
                        AOs = cellfun(@(x)setfield(x,'B',[x.B; repmat(x.B(end,:), samplesPerTrigger.B - size(x.B,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'B',[x.B; repmat(x.B(end,:), samplesPerTrigger.B - size(x.B,1), 1)]),paths,'UniformOutput',false);
                        
                        %digital
                        samplesPerTrigger.D = samplesPerTrigger.B;
                        for i = 1:numel(AOs)
                            AOs{i}.D = digitalSigs(paths{i}.B,bSizes(i));
                        end
                    else
                        %digital
                        samplesPerTrigger.D = samplesPerTrigger.G;
                        for i = 1:numel(AOs)
                            w = zeros(samplesPerTrigger.G,1);
                            w(1:gSizes(i)) = 1;
                            AOs{i}.D = digitalSigs(w,gSizes(i));
                        end
                    end
                    
                    %pad AOs
                    if obj.hasZ
                        samplesPerTrigger.Z = size(AOs{mi}.Z, 1);
                        AOs = cellfun(@(x)setfield(x,'Z',[x.Z; repmat(x.Z(end,:), samplesPerTrigger.Z - size(x.Z,1), 1)]),AOs,'UniformOutput',false);
                        paths = cellfun(@(x)setfield(x,'Z',[x.Z; repmat(x.Z(end,:), samplesPerTrigger.Z - size(x.Z,1), 1)]),paths,'UniformOutput',false);
                    end
                    
                    %concat
                    AOs = AOs(indices(obj.sequenceSelectedStimuli));
                    paths = paths(indices(obj.sequenceSelectedStimuli));
                    
                    ao = most.util.vertcatfields([AOs{:}]);
                    path = most.util.vertcatfields([paths{:}]);
                    
                    %multiple sequences
                    if obj.numSequences ~= inf
                        if obj.hasGalvos
                            ao.G = repmat(ao.G, obj.numSequences, 1);
                        end
                        if obj.hasBeams
                            ao.B = repmat(ao.B, obj.numSequences, 1);
                        end
                        if obj.hasZ
                            ao.Z = repmat(ao.Z, obj.numSequences, 1);
                        end
                    end
                    
                case 'onDemand'
                    ao = [];
                    path = [];
                    for x = obj.stimRoiGroups(:)'
                       [ao_,~,~,path_] = x.scanStackAO(ss,0,0,'',0,[],[],[]);
                       
                       if obj.hasBeams
                           ao_.D = digitalSigs(path_.B);
                       else
                           ao_.D = digitalSigs(path_.G);
                       end
                       
                       ao = [ao, ao_]; %#ok<AGROW>
                       path = [path, path_];
                       pause(0); % ensure the AO generation does not block Matlab for too long
                    end
                    
                    if obj.hasGalvos && obj.hasBeams
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.B,1), 'G', size(x.G,1), 'B', size(x.B,1)),ao);
                    elseif obj.hasGalvos
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.G,1), 'G', size(x.G,1)),ao);
                    else
                        samplesPerTrigger = arrayfun(@(x)struct('D', size(x.B,1), 'B', size(x.B,1)),ao);
                    end
                    if obj.hasZ
                        samplesPerTrigger = arrayfun(@(s,x)setfield(s,'Z', size(x.Z,1)),samplesPerTrigger,ao);
                    end
            end
            
            obj.stimAO = ao;
            obj.stimPath = path;
            
            function D = digitalSigs(beamPath,activeSamps)
                D = true(size(beamPath,1),2);
                
                if nargin > 1
                    D(activeSamps+1:end) = false;
                end
                
                % create laser active signal
                LA = sum(beamPath,2) > 0;
                
                % advance rising edges
                res = find((LA(2:end) - LA(1:end-1)) > 0);
                for re = res(:)'
                    LA(max(1,re-advSamps):re) = true;
                end
                
                D(:,2) = LA;
                D(end,:) = false;
            end
        end
    end
    
    methods (Hidden)
        function clearOnDemandStatus(obj)
            obj.hTaskArmedTrig.abort();
            obj.hTaskDigitalOut.abort();
            obj.status = 'Ready';
            if obj.separateBeamDAQ
                obj.hTaskBeams.abort();
            end
            if obj.separateZDAQ
                obj.hTaskZ.abort();
            end
            if obj.hasGalvos
                obj.hTaskGalvo.abort();
            end
            obj.hSI.hBeams.updateBeamStatusFrac(obj.beamIDs,0);
        end
        
        function taskDoneCallback(obj,~,~)
            if strcmp(obj.stimulusMode, 'onDemand')
                obj.clearOnDemandStatus();
                obj.hSI.hUserFunctions.notify('onDmdStimComplete');
            elseif obj.numSequences ~= inf
                obj.abort();
            end
        end
        
        function nSampleCallback(obj,~,~)
            if strcmp(obj.stimulusMode, 'sequence')
                if obj.sequencePosition == numel(obj.sequenceSelectedStimuli)
                    obj.completedSequences = obj.completedSequences + 1;
                    if obj.completedSequences >= obj.numSequences
                        obj.abort();
                        obj.hSI.hUserFunctions.notify('seqStimComplete');
                        return;
                    else
                        obj.sequencePosition = 1;
                        obj.hSI.hUserFunctions.notify('seqStimSingleComplete');
                    end
                else
                    obj.sequencePosition = obj.sequencePosition + 1;
                    obj.hSI.hUserFunctions.notify('seqStimAdvance');
                end
                
                obj.nextStimulus = obj.sequenceSelectedStimuli(obj.sequencePosition);
                obj.status = sprintf('Sequence #%d, position %d. Next stimulus: %d', obj.completedSequences + 1, obj.sequencePosition, obj.nextStimulus);
                if obj.hasSlm
                    if ~obj.slmQueueActive
                        obj.hSlm.writePhaseMaskRaw(obj.stimAO.SLM(obj.sequencePosition).mask.phase,false);
                    end
                    obj.currentSlmPattern = obj.stimPath.SLM(obj.sequencePosition).pattern;
                end
            elseif obj.allowMultipleOutputs
                obj.numOutputs = obj.numOutputs + 1;
                s = sprintf('%d time', obj.numOutputs);
                if obj.numOutputs > 1
                    s = [s 's'];
                end
                
                obj.hSI.hUserFunctions.notify('onDmdStimSingleComplete');
                obj.status = sprintf('Stimulus group %d output %s. Waiting for next trigger...', obj.primedStimulus, s);
            end
        end
        
        function nSampleCallbackMonitoring(obj,~,evt)
            numElements = size(evt.data,1);
            numDims = size(evt.data,2);
            
            if numElements == 0 || numDims < 3
                obj.stopMonitoring();
                obj.monitoring = false;
                most.idioms.warn('Photostim monitoring did not receive the expected ammount of data. Logging has been aborted (if active) and monitoring disabled.');
                return
            end
            
            pathAI = evt.data(:,1:2);
            beamAI = evt.data(:,3);
            
            % transform to degrees
            pathAI(:,1) = obj.hScan.xGalvo.feedbackVolts2Position(pathAI(:,1));
            pathAI(:,2) = obj.hScan.yGalvo.feedbackVolts2Position(pathAI(:,2));
            
            pathFOV = scanimage.mroi.util.xformPoints(pathAI,obj.hScan.scannerToRefTransform);
            
            if obj.currentlyMonitoring
                obj.monitoringRingBuffer = circshift(obj.monitoringRingBuffer,-numElements);
                obj.monitoringRingBuffer(end-numElements+1:end,1:2) = pathFOV(:,1:2);
                obj.monitoringRingBuffer(end-numElements+1:end,3)   = beamAI(:,1);
                
                if isvalid(obj.hSI.hDisplay) && ~isempty(obj.hSI.hDisplay.hLinesPhotostimMonitor)
                    minColor = [0 0 1]; %blue
                    maxColor = [1 0 0]; %red
                    
                    beamNumToMonitor = 1;
                    if length(obj.beamIDs >= beamNumToMonitor) %#ok<ISMT>
                        minB = obj.hSI.hBeams.calibrationMinCalVoltage(obj.beamIDs(beamNumToMonitor));
                        maxB = obj.hSI.hBeams.calibrationMaxCalVoltage(obj.beamIDs(beamNumToMonitor));
                        
                        useRejectedLight = obj.hSI.hBeams.mdfData.beamDaqs(obj.hScan.mdfData.beamDaqID).calUseRejectedLight;
                        if useRejectedLight
                            temp = maxB;
                            maxB = minB;
                            minB = temp;
                        end
                    else
                        minB = 0;
                        maxB = 1;
                    end
                    
                    XY = obj.monitoringRingBuffer(:,1:2);
                    
                    if isempty(obj.hScan.mdfData.beamDaqID)
                        b = maxB * ones(size(XY,1),1);
                    else
                        b = obj.monitoringRingBuffer(:,3);
                    end
                    
                    bdiff = b-minB;
                    color = zeros(length(bdiff),3);
                    for colIdx = 1:3;
                        color(:,colIdx) = bdiff * ((maxColor(colIdx) - minColor(colIdx)) ./(maxB-minB)) + minColor(colIdx);
                    end
                    color(color>1) = 1;
                    color(color<0) = 0;
                    
                    patchStruct = [];
                    if isempty(obj.currentSlmPattern)
                        patchStruct = addToPatch(XY,color,patchStruct);
                        markerC = color(end,:);
                        
                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],'Visible','off');
                    else 
                        zeroOrderCol = [0 1 0];
                        markerC = zeroOrderCol;
                        patchStruct = addToPatch(XY,repmat(zeroOrderCol,size(XY,1),1),patchStruct);
                        for idx = 1:size(obj.currentSlmPattern,1)
                            patchStruct = addToPatch(bsxfun(@plus,XY,obj.currentSlmPattern(idx,1:2)),color,patchStruct);
                        end
                        
                        set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarkerSlm],...
                            'XData', XY(end,1) + obj.currentSlmPattern(:,1),...
                            'YData', XY(end,2) + obj.currentSlmPattern(:,2),...
                            'MarkerEdgeColor', color(end,:),...
                            'Visible', 'on');
                    end
                    
                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.patch],...
                        'Faces', patchStruct.f,...
                        'Vertices', patchStruct.v,...
                        'FaceVertexCData', patchStruct.c,...
                        'Visible', 'on');
                    
                    set([obj.hSI.hDisplay.hLinesPhotostimMonitor.endMarker],...
                        'XData' ,obj.monitoringRingBuffer(end,1),...
                        'YData' , obj.monitoringRingBuffer(end,2),...
                        'MarkerEdgeColor', markerC,...
                        'Visible', 'on');
                end
            end
            
            if obj.currentlyLogging
                % save as single to save space
                % data is interleaved: X,Y,Beams,X,Y,Beams,X,Y,Beams...
                data = [single(pathFOV),single(beamAI)]';
                fwrite(obj.hMonitoringFile,data(:),'single');
            end
            
            %%% Local function
            function patchStruct = addToPatch(XY,color,patchStruct)
                if nargin<3 || isempty(patchStruct)
                    patchStruct = struct('f',[],'v',[],'c',[]);
                end
                
                previousNumV = size(patchStruct.v,1);
                newNumV = size(XY,1);
                
                if isempty(patchStruct.v)
                    patchStruct.v = XY;
                    patchStruct.c = color;
                else
                    patchStruct.v = vertcat(patchStruct.v,XY);
                    patchStruct.c = vertcat(patchStruct.c,color);
                end
                
                f = zeros(1,2*newNumV);
                f(1:newNumV) = 1:newNumV;
                f(newNumV+1:end) = newNumV:-1:1;
                f = f + previousNumV;
                
                if isempty(patchStruct.f)
                    patchStruct.f = f;
                else
                    if size(patchStruct.f,2) < length(f);
                        patchStruct.f(:,end+1:length(f)) = NaN;
                    elseif length(f) < size(patchStruct.f,2)
                        f(end+1:size(patchStruct.f,2)) = NaN;
                    end
                    
                    patchStruct.f = vertcat(patchStruct.f,f);
                end
            end
        end
        
        function extStimSelectionCB(obj,~,~)
            try
                data = obj.hTaskExtStimSelRead.readDigitalData();
                ind = find(data);
                if isempty(ind);
                    most.idioms.warn('External stimulus selection trigger came but no stimulus line was on. Ignoring.');
                elseif numel(ind) > 1
                    most.idioms.warn('External stimulus selection trigger came but multiple stimulus lines were on. Ignoring.');
                elseif ind > numel(obj.stimSelectionAssignment)
                    most.idioms.warn('No stimulus specified for PFI%d. Ignoring.', obj.stimSelectionTerms(ind));
                else
                    stm = obj.stimSelectionAssignment(ind);
                    fprintf('External stimulus selection trigger: stimulus %d\n', stm);
                    obj.hSI.hUserFunctions.notify('onDmdStimExtSel');
                    obj.onDemandStimNow(stm);
                end
            catch ME
                most.idioms.dispError('Error processing external on-demand stimulus trigger. Details:\n%s', ME.message);
            end
            obj.hTaskExtStimSel.abort();
            pause(0.1);
            obj.hTaskExtStimSel.start();
        end
        
        function startLogging(obj,sync)
            if nargin < 2 || isempty(sync)
                sync = true;
            end
            
            if obj.logging && obj.hSI.hChannels.loggingEnable
                obj.stopMonitoring();
                obj.prepareMonitoringFile();
                obj.currentlyLogging = true;
                obj.currentlyMonitoring = obj.monitoring;
                obj.startMonitoring(sync); %start logging
            end
        end
        
        function stopLogging(obj)
            if obj.currentlyLogging
                obj.currentlyLogging = false;
                obj.closeMonitoringFile();
                obj.stopMonitoring();
            end
            
            obj.monitoring = obj.monitoring;
        end
        
        function prepareMonitorTask(obj)
            most.idioms.safeDeleteObj(obj.hTaskMonitoring);
            
            obj.hTaskMonitoring = most.util.safeCreateTask('PhotostimMonitoringTask');
            obj.hTaskMonitoring.createAIVoltageChan(obj.hScan.deviceNameGalvoFeedback,obj.monitoringXAiId,'PhotostimGalvoXMonitoring',[],[],[],[],daqMxTermCfgString(obj.monitoringXTermCfg));
            obj.hTaskMonitoring.createAIVoltageChan(obj.hScan.deviceNameGalvoFeedback,obj.monitoringYAiId,'PhotostimGalvoYMonitoring',[],[],[],[],daqMxTermCfgString(obj.monitoringYTermCfg));
            obj.hTaskMonitoring.createAIVoltageChan(obj.hScan.deviceNameGalvoFeedback,obj.monitoringBeamAiId,'PhotostimBeamMonitoring');
            obj.hTaskMonitoring.cfgSampClkTiming(obj.monitoringSampleRate,'DAQmx_Val_ContSamps');
            obj.hTaskMonitoring.registerEveryNSamplesEvent(@obj.nSampleCallbackMonitoring,obj.monitoringEveryNSamples,true);
            obj.hTaskMonitoring.cfgInputBuffer(max(ceil(obj.monitoringSampleRate*obj.monitoringBufferSizeSeconds),obj.monitoringEveryNSamples*4));
            
            % configuration for timebase and start trigger are done in obj.startMonitoring()
            
            function cfg = daqMxTermCfgString(str)
                if length(str) > 4
                    str = str(1:4);
                end
                cfg = ['DAQmx_Val_' str];
            end
        end
        
        function prepareMonitoringFile(obj)
            filename = [obj.hSI.hScan2D.logFullFilename, sprintf('_%05d',obj.hSI.hScan2D.logFileCounter)];
            fileextension = '.stim';
            obj.hMonitoringFile = fopen([filename,fileextension],'W');
        end
        
        function closeMonitoringFile(obj)
            try
                fclose(obj.hMonitoringFile);
            catch ME
                most.idioms.reportError(ME);
            end
        end
    end

    %%% Abstract method implementation (scanimage.interfaces.Component)
    methods (Hidden, Access=protected)
        
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            % NOTE: The default implementation of scanimage.interfaces.Component.start is overridden above. See the
            % comments there. This code should never be reached.
            assert(false, 'Bad call.');
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            obj.abort();
        end
    end
   
    %% FRIEND EVENTS
    events (NotifyAccess = {?scanimage.interfaces.Class})
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct();
    
    s.stimTriggerTerm           = struct('Classes','numeric','Attributes',{{'nonzero' 'integer'}});
    s.autoTriggerPeriod         = struct('Classes','numeric','Attributes',{{'scalar' 'nonnegative'}});
    s.syncTriggerTerm           = struct('Classes','numeric','Attributes',{{'nonzero' 'integer'}},'AllowEmpty',true);
    s.stimImmediately           = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.numSequences              = struct('Classes','numeric','Attributes',{{'positive' 'integer'}});
    s.sequenceSelectedStimuli   = struct('Classes','numeric','Attributes',{{'vector' 'positive' 'integer' 'finite'}},'AllowEmpty',true);
    s.stimSelectionTriggerTerm  = struct('Classes','numeric','Attributes',{{'positive' 'integer'}},'AllowEmpty',true);
    s.stimSelectionTerms        = struct('Classes','numeric','Attributes',{{'vector' 'nonnegative' 'integer' 'finite'}},'AllowEmpty',true);
    s.stimSelectionAssignment   = struct('Classes','numeric','Attributes',{{'vector' 'nonnegative' 'integer' 'finite'}},'AllowEmpty',true);
    s.logging                   = struct('Classes','binaryflex','Attributes','scalar');
    s.monitoring                = struct('Classes','binaryflex','Attributes','scalar');
    s.monitoringXAiId           = struct('Classes','numeric','Attributes',{{'nonnegative' 'integer'}},'AllowEmpty',true);
    s.monitoringXTermCfg        = struct('Options',{{'Differential','RSE','NRSE'}});
    s.monitoringYAiId           = struct('Classes','numeric','Attributes',{{'nonnegative' 'integer'}},'AllowEmpty',true);
    s.monitoringYTermCfg        = struct('Options',{{'Differential','RSE','NRSE'}});
    s.monitoringBeamAiId        = struct('Classes','numeric','Attributes',{{'nonnegative' 'integer'}});
end

function s = defaultMdfSection()
    s = [...
        makeEntry('photostimScannerName','','Name of scanner (from first MDF section) to use for photostimulation. Must be a linear scanner')...
        makeEntry()... % blank line
        makeEntry('Monitoring DAQ AI channels')... % comment only
        makeEntry('BeamAiId',7,'AI channel to be used for monitoring the Pockels cell output')...
        makeEntry()... % blank line
        makeEntry('loggingStartTrigger','','one of {'''',''PFI#''} to which start trigger for logging is wired to photostim board. Leave empty for automatic routing via PXI bus')...
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
% Photostim.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
