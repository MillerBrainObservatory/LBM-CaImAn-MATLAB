classdef Triggering < scanimage.interfaces.Class
    %% FRIEND PROPS
    
    %%% The ScanImage timing signals
    properties
        % Specifiy external timing signal inputs and outputs of the PXI system
        % Empty string ('')            specifies that the signal is unused/not connected
        % Value 'PFI0..15' or 'DIO0.1' specifies that the signal is connected to the primary IO DAQ device / the FPGA
        % Value '/PXIxSlotx/PFIx'      specifies that the signal is connected to the daq device with the name 'PXIxSlotx'. This device must be installed in the same PXI chassis as the main DAQ device
        % Value '/FPGA/DIOx.x'         specifies that the signal is connected to the AUX connector of the FlexRIO Digitizer Module (requires a NI SCB-19 breakout box)
        
        %%% Core timing signals required for SI operation(including beams/fastZ features)
        periodClockIn = '';             % one of {'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        frameClockOut = '';             % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', /FPGA/DIO1.0..3'}
        beamModifiedLineClockOut = '';  % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO1.0..3'}
        volumeTriggerOut = '';          % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO1.0..3'}
 
        %%% Acquisition flow external trigger inputs
        acqTriggerIn = '';              % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        nextFileMarkerIn = '';          % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        acqStopTriggerIn = '';          % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO0.0..3'}
        
        %%% Exported timing signals for external use
        acqTriggerOut = '';             % one of {'', 'PFI0..15', '/PXIxSlotx/PFIx', '/FPGA/DIO1.0..3'}
        periodClockOut = '';            % one of {'', '/FPGA/DIO1.0..3'}
        referenceClockOut = '';         % one of {'', 'PFI0..15}
        
        overrideTriggers = repmat(struct('trig','','val',''),0,1);
    end
    
    %%% Acq flow trigger input polarity 
    properties (Hidden)    
        periodClockOnFallingEdge = false;
        acqTriggerOnFallingEdge = false;
        nextFileMarkerOnFallingEdge = false;
        acqStopTriggerOnFallingEdge = false;
    end
    
    properties (Hidden, SetAccess = private)
        digitalIODaqName;
        digitalIODeviceType;
    end
    
    properties (Hidden, SetAccess = {?scanimage.interfaces.Class}, Dependent)
        externalTrigTerminalOptions;
    end

    %% INTERNAL PROPERTIES
    
    properties (Hidden, SetAccess=immutable)
        hScan;
        hAcq;
        hCtl;
        
        hRouteRegistry;
        hFpgaRouteRegistry;
        
        hPrimaryIODaqDevice;
        primaryIoDaqPxiSlot;
        primaryIoDaqPxiChassisNum;        
        primaryPxiChassisDeviceNames;        
        fpgaDeviceName;     
        
        simulated = false;
    end
    
    
     %%% Constants
    properties (Constant,Hidden)
        % PXI_TRIGGER_MAP: Assignment of trigger signals on PXI backplane
        PXI_TRIGGER_MAP = containers.Map(...
            {'periodClockIn' , 'frameClockOut' , 'beamModifiedLineClockOut', 'acqTriggerIn' , 'nextFileMarkerIn' , 'acqStopTriggerIn' , 'acqTriggerOut', 'volumeTriggerOut'},...
            {'PXI_Trig0'     , 'PXI_Trig1'     , 'PXI_Trig2'               , 'PXI_Trig3'    , 'PXI_Trig4'        , 'PXI_Trig5'        , 'PXI_Trig6'    , ''});
                
        STATIC_TRIGGER_FPGA = struct('periodClockIn','/primaryIODaq/PFI0','beamModifiedLineClockOut','/FPGA/DIO1.0','frameClockOut','/FPGA/DIO1.1','acqTriggerOut','/FPGA/DIO1.2','referenceClockOut','/primaryIODaq/PFI14','volumeTriggerOut','');
        STATIC_TRIGGER_DAQ =  struct('periodClockIn','/primaryIODaq/PFI0','beamModifiedLineClockOut','/primaryIODaq/PFI5','frameClockOut','/primaryIODaq/PFI6','acqTriggerOut','/primaryIODaq/PFI7','referenceClockOut','/primaryIODaq/PFI14','volumeTriggerOut','');
        
        % list of allowed terminal names for Acq/Next/Stop trigger
        TRIGGER_IN_TERMINALS_FPGA_NAMES  = {'DIO0.0' 'DIO0.1' 'DIO0.2' 'DIO0.3'};
        TRIGGER_IN_TERMINALS_DAQ_NAMES   = {'PFI1' 'PFI2' 'PFI3' 'PFI4'};
        
        % names to qualify terminal names for Acq/Next/Stop trigger
        TRIGGER_PREFIX_FPGA = 'FPGA';
        TRIGGER_PREFIX_DAQ = 'primaryIODaq';
        
        % maps to qualify terminal names for Acq/Next/Stop trigger
        %TRIGGER_IN_TERMINALS_FPGA_MAP = containers.Map({'' 'DIO0.0' 'DIO0.1' 'DIO0.2' 'DIO0.3'},{'' '/FPGA/DIO0.0' '/FPGA/DIO0.1' '/FPGA/DIO0.2' '/FPGA/DIO0.3'});
        %TRIGGER_IN_TERMINALS_DAQ_MAP = containers.Map({'' 'PFI1' 'PFI2' 'PFI3' 'PFI4'},{'' '/primaryIODaq/PFI1' '/primaryIODaq/PFI2' '/primaryIODaq/PFI3' '/primaryIODaq/PFI4'});
                
        debugOutput = false;
    end
    
    
    %% Lifecycle
    methods
        function obj = Triggering(hScan,simulated)
            % Validate input arguments
            obj.hScan = hScan;           
            obj.hAcq = obj.hScan.hAcq;
            obj.hCtl = obj.hScan.hCtl;

            obj.simulated = simulated;
            obj.hRouteRegistry = dabs.ni.daqmx.util.triggerRouteRegistry();
            obj.hFpgaRouteRegistry = scanimage.components.scan2d.resscan.FpgaTriggerRouteRegistry(obj.hAcq.hFpga);
            
            % get information about device with trigger connectivity
            
            if strcmp(obj.hScan.mdfData.digitalIODeviceName,obj.hScan.mdfData.rioDeviceID)
                obj.digitalIODaqName = obj.hScan.mdfData.galvoDeviceName;
                obj.digitalIODeviceType = 'FPGA';
            else
                obj.digitalIODaqName = obj.hScan.mdfData.digitalIODeviceName;
                obj.digitalIODeviceType = 'DAQ';
            end
            
            obj.hPrimaryIODaqDevice = dabs.ni.daqmx.Device(obj.digitalIODaqName);
            assert(ismember(get(obj.hPrimaryIODaqDevice,'busType'),{'DAQmx_Val_PXI','DAQmx_Val_PXIe'}),...
                'Error: the primary IO DAQ board ''%s'' must be installed in the same PXI chassis as the FPGA',obj.digitalIODaqName);

            [obj.primaryIoDaqPxiChassisNum,obj.primaryIoDaqPxiChassisNum] = obj.getPxIChassisAndSlot(obj.digitalIODaqName);
            obj.primaryPxiChassisDeviceNames = obj.listDaqDevicesInPxiChassis(obj.primaryIoDaqPxiChassisNum);
        end
        
        function delete(obj)            
            try
                obj.ziniResetDefaultTriggerMap(); % Disconnect all FPGA trigger routes - just to make sure
                most.idioms.safeDeleteObj(obj.hFpgaRouteRegistry);
                most.idioms.safeDeleteObj(obj.hRouteRegistry);
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function initialize(obj)            
            obj.ziniResetDefaultTriggerMap(); %Disconnect all FPGA trigger routes
            
            %Set up static trigger routes            
            switch obj.digitalIODeviceType
                case 'FPGA'
                    staticTrigger = obj.STATIC_TRIGGER_FPGA;                    
                case 'DAQ'
                    staticTrigger = obj.STATIC_TRIGGER_DAQ;
                otherwise
                    error('mdf Entry digitalIODeviceType must be one of {''FPGA'',''DAQ''}. Current value: %s',...
                        obj.digitalIODeviceType);
            end
            
            for i = 1:numel(obj.overrideTriggers)
                tr = obj.overrideTriggers(i);
                staticTrigger.(tr.trig) = tr.val;
            end
            
            if ~obj.hScan.simulated
                trigTerms = fieldnames(staticTrigger);
                for idx = 1:length(trigTerms)
                    trigTerm = trigTerms{idx};
                    obj.(trigTerm) = staticTrigger.(trigTerm);
                end
            end
            
            %Configure hCtl to use PXI trigger lines
            if ~obj.hScan.simulated
                obj.hCtl.frameClockIn  = obj.readInternalTerminalName('frameClockOut');
            end
            
            %clear routes because this may not actually be the active imaging system
            obj.deinitRoutes();
        end
        
        function start(obj)
            % valid values for obj.hFpga.AdvanceTriggerType and obj.hFpga.StopTriggerType:
            % {'External','External or Software','Immediate','None','Software'}
            if obj.hScan.trigNextStopEnable
                if obj.hScan.trigAcqTypeExternal
                    obj.hAcq.hFpga.AdvanceTriggerType = 'External or Software';
                    obj.hAcq.hFpga.StopTriggerType = 'External or Software';
                else
                    obj.hAcq.hFpga.AdvanceTriggerType = 'Software';
                    obj.hAcq.hFpga.StopTriggerType = 'Software';
                end
            else
                obj.hAcq.hFpga.AdvanceTriggerType = 'None';
                obj.hAcq.hFpga.StopTriggerType = 'None';
            end
            
            if obj.hScan.trigAcqTypeExternal
                obj.hAcq.hFpga.AcqTriggerType = 'External or Software';
            else
                obj.hAcq.hFpga.AcqTriggerType = 'Software';
            end
            
            % Configure Trigger Lines
            %%% 2016-04-04 Vijay's code. don't really understand why this
            %%% was rewritten to be set on every start
            obj.hFpgaRouteRegistry.connectTerms('PeriodClockTerminalIn',obj.getPXITerminal('periodClockIn'));
            
            if strcmp(obj.hScan.hTrig.digitalIODeviceType, 'FPGA')
                obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',obj.hScan.trigAcqInTerm);
                obj.hFpgaRouteRegistry.connectTerms('AdvanceTriggerTerminalIn',obj.hScan.trigNextInTerm);
                obj.hFpgaRouteRegistry.connectTerms('StopTriggerTerminalIn',obj.hScan.trigStopInTerm);
            else
                obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',obj.getPXITerminal('acqTriggerIn'));
                obj.hFpgaRouteRegistry.connectTerms('AdvanceTriggerTerminalIn',obj.getPXITerminal('nextFileMarkerIn'));
                obj.hFpgaRouteRegistry.connectTerms('StopTriggerTerminalIn',obj.getPXITerminal('acqStopTriggerIn'));
            end
            
            obj.hAcq.hFpga.PeriodClockOnFallingEdge = obj.periodClockOnFallingEdge;
            obj.hAcq.hFpga.AcqTriggerOnFallingEdge = obj.acqTriggerOnFallingEdge;
            obj.hAcq.hFpga.AdvanceTriggerOnFallingEdge = obj.nextFileMarkerOnFallingEdge;
            obj.hAcq.hFpga.StopTriggerOnFallingEdge = obj.acqStopTriggerOnFallingEdge;
            
            %TODO: This never changes right? If so, we should set outside of this start() helper fcn
            obj.hFpgaRouteRegistry.connectTerms('FrameClockTerminalOut',obj.getPXITerminal('frameClockOut'));
            obj.hFpgaRouteRegistry.connectTerms('BeamClockTerminalOut',obj.getPXITerminal('beamModifiedLineClockOut'));
            obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalOut',obj.getPXITerminal('acqTriggerOut'));
             
            %set up resonant timebase
            obj.hAcq.hFpga.MaxResonantPeriodTicks = floor(obj.hScan.nomResPeriodTicks*1.1);
            obj.hAcq.hFpga.MinResonantPeriodTicks = floor(obj.hScan.nomResPeriodTicks*0.9);
            obj.hAcq.hFpga.SettlingPeriods = obj.hScan.resonantSettlingPeriods;
            obj.hAcq.hFpga.ResonantTimeBasePulsesPerPeriod = obj.hScan.resonantTimebaseTicksPerPeriod;
            if obj.hScan.useResonantTimebase
                obj.hFpgaRouteRegistry.disconnectTerms('BeamClockTerminalOut');
                obj.hFpgaRouteRegistry.connectTerms('ResonantTimebaseTerminalOut',obj.getPXITerminal('beamModifiedLineClockOut'));
            end
        end
    end
    
    methods (Hidden)
        function deinitRoutes(obj)
            obj.hRouteRegistry.deinitRoutes();
            obj.hFpgaRouteRegistry.deinitRoutes();
        end
        
        function reinitRoutes(obj)
            obj.hRouteRegistry.reinitRoutes();
            obj.hFpgaRouteRegistry.reinitRoutes();
        end        
    end
    
    methods (Access = private)        
        function ziniResetDefaultTriggerMap(obj)
            % Reset FPGA routes
            obj.dispDbgMsg('Reset FPGA Trigger lines');
            
            obj.periodClockIn = '';
            obj.frameClockOut = '';
            obj.acqTriggerIn = '';
            obj.nextFileMarkerIn = '';
            obj.acqStopTriggerIn = '';
            obj.beamModifiedLineClockOut = '';
            obj.acqTriggerOut = '';
            obj.referenceClockOut = '';
            obj.volumeTriggerOut = '';
        end
    end
    
    %% Property Setter Methods
    methods
        function val = get.externalTrigTerminalOptions(obj)
            switch obj.digitalIODeviceType
                case 'FPGA' 
                    val = obj.TRIGGER_IN_TERMINALS_FPGA_NAMES;
                case 'DAQ'
                    val = obj.TRIGGER_IN_TERMINALS_DAQ_NAMES;
                otherwise
                    assert(false);
            end            
            val = [{''} val];
        end
        
        function set.referenceClockOut(obj,newTerminal)
            if ~obj.hScan.mdfData.enableRefClkOutput
                newTerminal = '';
            end
            
            oldTerminal = obj.referenceClockOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            assert(~strcmpi(newDevice,'FPGA'),'Cannot output reference Clock on FPGA');

            switch oldDevice
                case ''
                    % no route was connected
                otherwise
                    refSrcTerm = obj.qualifyTerminalName('PXI_Clk10',oldDevice);
                    obj.connectDaqTerminals(refSrcTerm,oldTerminal,false);
            end

            switch newDevice
                case ''
                    % nothing to do
                case 'FPGA'
                    error('Cannot output reference Clock on FPGA');
                otherwise
                    refSrcTerm = obj.qualifyTerminalName('PXI_Clk10',newDevice);
                    obj.connectDaqTerminals(refSrcTerm,newTerminal,true);
            end
            obj.referenceClockOut = newTerminal;
        end        
        
        function set.periodClockIn(obj,newTerminal)
            %assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('periodClockIn');
            
            % first disconnect the existing route
            oldTerminal = obj.periodClockIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hFpgaRouteRegistry.connectTerms('PeriodClockTerminalIn',pxiTriggerLine);
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('PeriodClockTerminalIn',pxiTriggerLine);
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldTerminal,oldPxiTriggerLineDaq,false);
            end
            obj.periodClockIn = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                    fpgaTerm = pxiTriggerLine;
                case {'FPGA'}
                    fpgaTerm = newTerminalOnly;
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newTerminal,newPxiTriggerLineDaq,true);
                    fpgaTerm = pxiTriggerLine;
            end
            obj.hFpgaRouteRegistry.connectTerms('PeriodClockTerminalIn',fpgaTerm);
            
            %set property value
            obj.periodClockIn = newTerminal;
        end
        
        function set.frameClockOut(obj,newTerminal)
            assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');

            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('frameClockOut');
            
            % first disconnect the existing route
            oldTerminal = obj.frameClockOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.disconnectTerms('FrameClockTerminalOut2');
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldPxiTriggerLineDaq,oldTerminal,false);
            end
            obj.frameClockOut = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('FrameClockTerminalOut2',newTerminalOnly);
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);            
                    obj.connectDaqTerminals(newPxiTriggerLineDaq,newTerminal,true);
            end
            
            %set property value
            obj.frameClockOut = newTerminal;
        end
        
        function set.acqTriggerIn(obj,newTerminal)
            if ~obj.isTerminalNameQualified(newTerminal)
                newTerminal = obj.qualifyTerminalName(newTerminal);
            end
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqTriggerIn');
            
            % first disconnect the existing route
            oldTerminal = obj.acqTriggerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',pxiTriggerLine);
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',pxiTriggerLine);
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldTerminal,oldPxiTriggerLineDaq,false);
            end
            obj.acqTriggerIn = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',pxiTriggerLine);
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',newTerminalOnly);
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newTerminal,newPxiTriggerLineDaq,true);
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalIn',pxiTriggerLine);
            end
            
            %set property value
            obj.acqTriggerIn = newTerminal;
        end
        
        function set.nextFileMarkerIn(obj,newTerminal)
            if ~obj.isTerminalNameQualified(newTerminal)
                newTerminal = obj.qualifyTerminalName(newTerminal);
            end
            
            hFpga = obj.hAcq.hFpga;
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('nextFileMarkerIn');
            
            % first disconnect the existing route
            oldTerminal = obj.nextFileMarkerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hFpgaRouteRegistry.connectTerms('AdvanceTriggerTerminalIn',pxiTriggerLine);
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('AdvanceTriggerTerminalIn',pxiTriggerLine);
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldTerminal,oldPxiTriggerLineDaq,false);
            end
            obj.nextFileMarkerIn = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                    fpgaTerm = pxiTriggerLine;
                case {'FPGA'}
                    fpgaTerm = newTerminalOnly;
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newTerminal,newPxiTriggerLineDaq,true);
                    fpgaTerm = pxiTriggerLine;
            end
            obj.hFpgaRouteRegistry.connectTerms('AdvanceTriggerTerminalIn',fpgaTerm);
            
            %set property value
            obj.nextFileMarkerIn = newTerminal;
        end
        
        function set.acqStopTriggerIn(obj,newTerminal)
            if ~obj.isTerminalNameQualified(newTerminal)
                newTerminal = obj.qualifyTerminalName(newTerminal);
            end
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqStopTriggerIn');
            
            % first disconnect the existing route
            oldTerminal = obj.acqStopTriggerIn;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                    obj.hFpgaRouteRegistry.connectTerms('StopTriggerTerminalIn',pxiTriggerLine);
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('StopTriggerTerminalIn',pxiTriggerLine);
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldTerminal,oldPxiTriggerLineDaq,false);
            end
            obj.acqStopTriggerIn = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                    fpgaTerm = pxiTriggerLine;
                case {'FPGA'}
                    fpgaTerm = newTerminalOnly;
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newTerminal,newPxiTriggerLineDaq,true);
                    fpgaTerm = pxiTriggerLine;
            end
            obj.hFpgaRouteRegistry.connectTerms('StopTriggerTerminalIn',fpgaTerm);
            
            %set property value
            obj.acqStopTriggerIn = newTerminal;
        end
        
        function set.beamModifiedLineClockOut(obj,newTerminal)
            assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('beamModifiedLineClockOut');
            
            % first disconnect the existing route
            oldTerminal = obj.beamModifiedLineClockOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.disconnectTerms('BeamClockTerminalOut2');
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldPxiTriggerLineDaq,oldTerminal,false);
            end
            obj.beamModifiedLineClockOut = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('BeamClockTerminalOut2',newTerminalOnly);
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newPxiTriggerLineDaq,newTerminal,true);
            end
            
            %set property value
            obj.beamModifiedLineClockOut = newTerminal;
        end
        
        function set.volumeTriggerOut(obj,newTerminal)
            assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('volumeTriggerOut');
            
            % first disconnect the existing route
            oldTerminal = obj.volumeTriggerOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.disconnectTerms('VolumeTriggerTerminalOut2');
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldPxiTriggerLineDaq,oldTerminal,false);
            end
            obj.volumeTriggerOut = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('VolumeTriggerTerminalOut2',newTerminalOnly);
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newPxiTriggerLineDaq,newTerminal,true);
            end
            
            %set property value
            obj.volumeTriggerOut = newTerminal;
        end
        
        function set.acqTriggerOut(obj,newTerminal)
            assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');
            
            % get pxi trigger line assignment
            pxiTriggerLine = obj.PXI_TRIGGER_MAP('acqTriggerOut');
            
            % first disconnect the existing route
            oldTerminal = obj.acqTriggerOut;
            [oldDevice,oldTerminalOnly] = obj.getDeviceAndTerminal(oldTerminal);
            switch oldDevice
                case ''
                    % terminal was unconnected already
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.disconnectTerms('AcqTriggerTerminalOut2');
                otherwise
                    oldPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,oldDevice);
                    obj.connectDaqTerminals(oldPxiTriggerLineDaq,oldTerminal,false);
            end
            obj.acqTriggerOut = '';
            
            % try connecting the new Route
            newTerminal = obj.qualifyTerminalName(newTerminal);
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            switch newDevice
                case ''
                    % No Route to set
                case {'FPGA'}
                    obj.hFpgaRouteRegistry.connectTerms('AcqTriggerTerminalOut2',newTerminalOnly);
                otherwise
                    newPxiTriggerLineDaq = obj.qualifyTerminalName(pxiTriggerLine,newDevice);
                    obj.connectDaqTerminals(newPxiTriggerLineDaq,newTerminal,true);
            end
            
            %set property value
            obj.acqTriggerOut = newTerminal;
        end
        
        function set.periodClockOut(obj,newTerminal)
            assert(obj.isTerminalNameQualified(newTerminal),'Terminal Name must follow format /DevName/TermName');
            
            [newDevice,newTerminalOnly] = obj.getDeviceAndTerminal(newTerminal);
            assert(strcmp(newDevice,'FPGA'),'The period clock can only be mirrored on the FPGA connector block');
            obj.hFpgaRouteRegistry.connectTerms('PeriodClockTerminalOut',newTerminalOnly);
            obj.periodClockOut = newTerminal;
        end
    end
    
    %% Dependent Properties Access methods
    methods
        function set.periodClockOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.periodClockOnFallingEdge = val;
        end
        
        function set.acqTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.acqTriggerOnFallingEdge = val;
        end        
        
        function set.nextFileMarkerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.nextFileMarkerOnFallingEdge = val;
        end
        
        function set.acqStopTriggerOnFallingEdge(obj,val)
            validateattributes(val,{'logical'},{'scalar','nonempty'});
            obj.acqStopTriggerOnFallingEdge = val;
        end

    end
    
    %% Friend Methods
    methods (Hidden)
        function termName = readInternalTerminalName(obj,triggerName)
            termName = obj.qualifyTerminalName(obj.PXI_TRIGGER_MAP(triggerName),obj.digitalIODaqName);
        end
        
        function [pxiTermName, qualPxiTermName] = getPXITerminal(obj,timingSignalName)
            pxiTermName =  obj.PXI_TRIGGER_MAP(timingSignalName);
            qualPxiTermName = obj.qualifyTerminalName(pxiTermName,obj.digitalIODaqName);
        end
        
        function termName = readTrigInputTerminalName(obj,termName)
            %Convert terminal name as stored by this class into NI terminal name suitable for 
        
            if obj.isTerminalNameQualified(termName)
                termName = strrep(termName,'/FPGA/','');
            else
                termName = obj.qualifyTerminalName(termName,obj.digitalIODaqName);
            end            
        end
    end
    
    %% Internal Methods
    methods (Hidden, Access=private)
        function connectDaqTerminals(obj,srcTerm,destTerm,connect)
            % srcTerm:   a string specifiying the source e.g. 'PFI0'
            % destTerms: a cell array specifiying the route endpoint e.g. 'PFI1'
            % connect:   (Optional) if empty or true, the route is
            %               connected, otherwise it is disconnected
            if nargin < 4 || isempty(connect)
                connect = true;
            end
            
            if isempty(srcTerm) || isempty(destTerm)
                return;
            end
            
            if ~obj.isTerminalNameQualified(srcTerm)
                srcTerm = obj.qualifyTerminalName(srcTerm);
            end
            
            if ~obj.isTerminalNameQualified(destTerm)
                destTerm = obj.qualifyTerminalName(destTerm);
            end
            
            if strcmp(srcTerm,destTerm)
                return; % if the two terminals are the same return
            end
            
            if ~obj.simulated
                try
                if connect
                    obj.hRouteRegistry.connectTerms(srcTerm,destTerm);
                    obj.dispDbgMsg('DAQmx connect Route %s to %s',srcTerm,destTerm);
                else
                    obj.hRouteRegistry.disconnectTerms(srcTerm,destTerm);
                    obj.dispDbgMsg('DAQmx disconnect Route %s to %s',srcTerm,destTerm);
                end
                catch ME
                    fprintf('Error connecting DAQmx terminals %s -> %s\n',srcTerm,destTerm);
                    rethrow(ME);
                end
            end
        end
        
        %%% terminal name formatting functions
        
        function tf = isTerminalNameQualified(obj,terminalName)
            if isempty(terminalName)
                tf = true;
            else
                startindex = regexpi(terminalName,'^/[^/\s]+/[^/\s]+$');
                tf = ~isempty(startindex);
            end
        end
        
        function tf = checkTerminalNameFormat(obj,terminalName)
            % returns true if the terminal Name is empty, qualified or unqualified
            % checkTerminalNameFormat('')                 -> true
            % checkTerminalNameFormat('PFI0')             -> true
            % checkTerminalNameFormat('/PXI1Slot3/PFI0')  -> true
            % rejects wrong pattern of slashes and spaces
            % checkTerminalNameFormat('PXI1Slot3/PFI0')   -> false
            % checkTerminalNameFormat('PXI1 Slot3/PFI0')  -> false
            
            qualified = obj.isTerminalNameQualified(terminalName); % checks if terminalName
            unqualified = regexpi(terminalName,'^[^/\s]+$');       % we do not allow 'half-qualified' terminal names (e.g. 'PXI1Slot3/PFI0' <- the first slash is missing)
            tf = qualified || unqualified;            
        end
        
        function fullTerm = qualifyTerminalName(obj,terminalName,deviceName)
            % Append deviceName to terminalName to create fully-qualified terminal name
            % usage:
            % qualifyTerminalName('')                       -> ''
            % qualifyTerminalName('/PXI1Slot3/PFI0')        -> '/PXI1Slot3/PFI0'
            % qualifyTerminalName('PFI0')                   -> '/PXI1Slot3/PFI0' (in case digitalIODeviceType == 'DAQ')
            % qualifyTerminalName('DIO0')                   -> '/FPGA/PFI0'      (in case digitalIODeviceType == 'FPGA')
            % qualifyTerminalName('DIO0','FPGA')            -> '/FPGA/DIO0'
            % qualifyTerminalName('/PXI1Slot3/PFI0','FPGA') -> '/PXI1Slot3/PFI0'
            
            assert(obj.checkTerminalNameFormat(terminalName),'Incorrect input format for terminalName: %s',terminalName);
            
            if isempty(terminalName)
                fullTerm = '';
            elseif ~obj.isTerminalNameQualified(terminalName)
                if nargin < 3 || isempty(deviceName)
                    switch obj.digitalIODeviceType
                        case 'FPGA'
                            deviceName = 'FPGA';
                        case 'DAQ'
                            deviceName = 'primaryIODaq';
                        otherwise
                            error('Unknown digitalIODeviceType: %s',obj.digitalIODeviceType);
                    end
                end      
                fullTerm = sprintf('/%s/%s',deviceName,terminalName);
            else
                fullTerm = terminalName;
            end
            
            fullTerm = strrep(fullTerm,'/primaryIODaq/',['/' obj.digitalIODaqName '/']);
            
            % sanity check
            assert(obj.isTerminalNameQualified(fullTerm),'Qualifying terminal %s returned incorrect format: %s',terminalName,fullTerm);
        end
        
        function [deviceName,terminalName] = getDeviceAndTerminal(obj,fullTerm)
            if isempty(fullTerm)
                deviceName   = '';
                terminalName = '';
            else
                assert(obj.isTerminalNameQualified(fullTerm),'Cannot split terminal ''%s'' into device name and terminal name',fullTerm);
                deviceName   = regexpi(fullTerm,'(?<=^/)[^/\s]+(?=/[^/\s]+$)','match','once');
                terminalName = regexpi(fullTerm,'(?<=^/[^/\s]+/)[^/\s]+$','match','once');
            end
        end
        
        %%% PXI chassis specific helper methods
        
        function tf = isDeviceInPrimaryPxiChassis(obj,deviceName)
            tf = any(ismember(obj.primaryPxiChassisDeviceNames,deviceName));
        end
        
        function [daqPxiChassisNum,daqPxiSlot] = getPxIChassisAndSlot(obj,devName)
            daqPxiChassisNum = [];
            daqPxiSlot = [];
            hDaq = dabs.ni.daqmx.Device(devName);
            if ~obj.simulated
                daqDevBusType = get(hDaq,'busType');
                if any(strcmp(daqDevBusType,{'DAQmx_Val_PXI','DAQmx_Val_PXIe'}))
                    daqPxiChassisNum = get(hDaq,'PXIChassisNum');
                    daqPxiSlot = get(hDaq,'PXISlotNum');
                end
            else
                daqPxiChassisNum = 1;
                daqPxiSlot = 3;
            end
        end
        
        function pxiDaqDeviceNames = listDaqDevicesInPxiChassis(obj,pxiChassisNum)
            hDaqSystem = dabs.ni.daqmx.System();
            devNames = get(hDaqSystem,'devNames');
            
            if isempty(devNames)
                devNames = {};
            else
                devNames = most.idioms.strsplit(devNames,','); % native strsplit is not available pre Matlab 2013
            end
            
            pxiDaqDeviceNames = {};
            
            for i = 1:length(devNames)
                devName = devNames{i};
                hDaqDevice = dabs.ni.daqmx.Device(devName);
                daqDevBusType = get(hDaqDevice,'busType');
                if(any(strcmp(daqDevBusType,{'DAQmx_Val_PXI','DAQmx_Val_PXIe'})))
                    devPxiChassisNum = get(hDaqDevice,'PXIChassisNum');
                    if devPxiChassisNum == pxiChassisNum
                        pxiDaqDeviceNames = [pxiDaqDeviceNames,{devName}];
                    end
                end
            end
        end
    end
    
    %% Private Methods for Debugging
    methods (Access = private)
        function dispDbgMsg(obj,varargin)
            if obj.debugOutput
                fprintf(horzcat('Class: ',class(obj),': ',varargin{1},'\n'),varargin{2:end});
            end
        end
    end
end


%--------------------------------------------------------------------------%
% Triggering.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
