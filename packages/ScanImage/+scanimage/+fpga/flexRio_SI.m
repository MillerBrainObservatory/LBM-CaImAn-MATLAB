classdef flexRio_SI < dabs.ni.rio.NiFPGA
    
    properties
        adapterModuleName;
        adapterModuleChannelCount;
        
        rawSampleRateAcq;
        externalSampleClock;
        
        amCmdSent = false;
        
        channelsInvert;
        channelInputRanges = [];
    end
    
    properties (SetAccess = immutable)
        simulated = false;
    end
    
    %% CONSTANTS
    properties (Hidden, Constant)
        HW_DETECT_POLLING_INTERVAL = 0.1;   %Hardware detection polling interval time (in seconds)
        HW_DETECT_TIMEOUT = 5;              %Hardware detection timeout (in seconds)
        HW_POLLING_INTERVAL = 0.01;         %Hardware polling interval time (in seconds)
        HW_TIMEOUT = 5;                     %Hardware timeout (in seconds)
        
        ADAPTER_MODULE_RAW_SAMPLING_RATE_MAP = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{80e6,120e6,120e6,50e6,250e6,1.5e9,1.5e9,0.8e9});
        ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{[20e6 80e6],[50e6 120e6],[50e6 120e6],[50e6 50e6],[20e6 125e6],[850e6 1.5e9],[850e6 1.5e9],[400e6 800e9]});
        ADAPTER_MODULE_CHANNEL_COUNT = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{2,2,4,4,4,4,16,32});
        FPGA_RAW_ACQ_LOOP_ITERATIONS_COUNT_FACTOR = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5772'},{1,1,1,1,2,8,4});
        ADAPTER_MODULE_ADC_RAW_BIT_DEPTH = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{14,16,16,14,14,8,8,12});
        CHANNEL_INPUT_RANGE_FPGA_COMMAND_DATA_MAP = containers.Map({1,0.5,0.25},{0,1,2});
        
        FPGA_SYS_CLOCK_RATE = 200e6;        %Hard coded on FPGA[Hz]
    end
    
    %% LIFECYCLE
    methods
        function obj = flexRio_SI(bitFileName,simulated,digitizerType)
            obj = obj@dabs.ni.rio.NiFPGA(bitFileName);
            
            if nargin > 1
                obj.simulated = simulated;
            end
            
            if nargin > 2
                obj.adapterModuleName = digitizerType;
                obj.rawSampleRateAcq = obj.ADAPTER_MODULE_RAW_SAMPLING_RATE_MAP(digitizerType);
            end
        end
    end
    
    %% FRIEND METHODS
    methods
        function fpgaCheckAdapterModuleInitialization(obj)
            timeout = obj.HW_TIMEOUT;           %timeout in seconds
            pollinginterval = obj.HW_DETECT_POLLING_INTERVAL; %pollinginterval in seconds
            while obj.AdapterModuleInitializationDone == 0
                pause(pollinginterval);
                timeout = timeout - pollinginterval;
                if timeout <= 0
                    error('Initialization of adapter module timed out')
                end
            end
        end
        
        function checkAdapterModuleErrorState(obj)
            if ~obj.simulated
                loopRateRange = obj.ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP(obj.adapterModuleName);
                assert(obj.AdapterModuleUserError == 0,...
                    'Fatal error: The FlexRio adapter module became instable and needs to be reset. Please restart ScanImage to reinitialize the module. If you use an external sample clock, do not disconnect the clock while ScanImage is running and ensure the clock rate is within the range %.1E - %.1E Hz',...
                    loopRateRange(1),loopRateRange(2));
            end
        end
		
        function idle = waitModuleUserCommandIdle(obj)
            % Wait for FPGA to be ready to accept user command inputs
            idle = true;
            start = tic();
            while obj.AdapterModuleUserCommandIdle == 0
                if toc(start) > obj.HW_TIMEOUT
                    idle = false;
                    return;
                else
                    pause(obj.HW_POLLING_INTERVAL);
                end
            end
            
            status = obj.AdapterModuleUserCommandStatus;
            if status && obj.amCmdSent
                cmd = int2str(obj.AdapterModuleUserCommand);
                most.idioms.warn(['Previous FPGA adapter module command (''' cmd ''') failed with status code ''' int2str(status) '''.']);
            end
        end
        
        function sendNonBlockingAdapterModuleUserCommand(obj,userCommand,userData0,userData1)
            if obj.simulated
                return
            end
            
            if isempty(strfind(obj.adapterModuleName,'NI573'))
                return
            end
            
            obj.fpgaCheckAdapterModuleInitialization();
            obj.checkAdapterModuleErrorState();
            
            % Wait for module to be ready to accept user command input
            assert(obj.waitModuleUserCommandIdle(),'Module is not idle - failed to send command');
            
            % Execute user command
            obj.AdapterModuleUserCommand = userCommand;
            obj.AdapterModuleUserData0 = userData0;
            obj.AdapterModuleUserData1 = userData1;
            obj.AdapterModuleDoUserCommandCommit = true;
            obj.amCmdSent = true;
        end
        
        function status = sendAdapterModuleUserCommand(obj,userCommand,userData0,userData1)
            if obj.simulated
                status = 0;
                return
            end
            
            if isempty(regexpi(obj.adapterModuleName,'NI573|NI577'))
                status = 0;
                return
            end
            
            obj.fpgaCheckAdapterModuleInitialization();
            obj.checkAdapterModuleErrorState();
            
            % Wait for module to be ready to accept user command input
            checkModuleIdle();
            
            % Execute user command
            obj.AdapterModuleUserCommand = userCommand;
            obj.AdapterModuleUserData0 = userData0;
            obj.AdapterModuleUserData1 = userData1;
            obj.AdapterModuleDoUserCommandCommit = true;
            obj.amCmdSent = false;
            
            % Check user command return value
            checkModuleIdle();
            status = obj.AdapterModuleUserCommandStatus;
            
            % nested function
            function checkModuleIdle()
                moduleIsIdle = obj.waitModuleUserCommandIdle();
                if ~moduleIsIdle
                    if obj.externalSampleClock
                        most.idioms.dispError(['Sending a user command to the FPGA failed. ',...
                            'This can be caused by an unstable external sample clock.\n']);
                        %obj.measureExternalSampleClockRate;
                    end
                    assert(obj.waitModuleUserCommandIdle(),'Module is not idle - failed to send command');
                end
            end
        end
        
        function val = setInputRanges(obj,val)
            switch obj.adapterModuleName
                case {'NI5732','NI5733','NI5734'}
                    for channelNumber = 1:obj.adapterModuleChannelCount
                        channelRange = val{channelNumber};
                        validateattributes(channelRange,{'numeric'},{'numel', 2});
                        channelUpperLimit = channelRange(2);
                        
                        % Execute user command
                        userCommand = 2; % User command for gain settings (Refer to FlexRIO help)
                        userData0 = channelNumber - 1; %channel Number on FPGA is zero-based
                        userData1 = obj.CHANNEL_INPUT_RANGE_FPGA_COMMAND_DATA_MAP(channelUpperLimit);
                        
                        obj.sendNonBlockingAdapterModuleUserCommand(userCommand,userData0,userData1);
                        
                        val{channelNumber} = channelRange;
                    end
                case 'NI5751'
                    % the input range of the 5751 is fixed at 2Vpp
                    channelRanges = {};
                    for channelNumber = 1:obj.adapterModuleChannelCount
                        channelRanges{channelNumber} = [-1,1];
                    end
                    val = channelRanges;
                case 'NI517x'
                    obj.configOscopeChannels(val);
                case {'NI5771' 'NI5772'}
                    % NoOp
                otherwise
                    assert(false);
            end
            
            obj.channelInputRanges = val;
        end
        
        function resetDcOvervoltage(obj)
            % sets adapter module to DC coupling mode
            switch obj.adapterModuleName
                case 'NI5751'
                    % 5751 does not support setting channels coupling
                    % (always runs in DC mode)
                case 'NI517x'
                    obj.configOscopeChannels();
                case {'NI5771' 'NI5772'}
                    % 5771 and 5772 do not support setting channels coupling
                    % (always run in DC mode)
                otherwise
                    setCoupling573x('AC'); % setting coupling mode to AC clears overvoltageStatus
                    setCoupling573x('DC');
            end
            
            %Helper function
            function setCoupling573x(mode)
                switch upper(mode)
                    % 0 = AC coupling, nonzero = DC coupling
                    case 'AC'
                        userData1 = 0;
                    case 'DC'
                        userData1 = 1;
                    otherwise
                        assert(false);
                end
                
                for channelNumber = 0:(obj.adapterModuleChannelCount-1)
                    % Execute user command
                    userCommand = 3; % User command for coupling settings (Refer to FlexRIO help)
                    userData0 = channelNumber; %channel Number on FPGA is zero-based
                    
                    status = obj.sendAdapterModuleUserCommand(userCommand,userData0,userData1);
                    assert(status == 0,'Setting DC coupling for channel %d returned fpga error code %d',channelNumber,status);
                end
            end
        end
        
        function configOscopeChannels(obj,newInputRange)
            if nargin > 1 && ~isempty(newInputRange)
                rg = newInputRange;
            else
                rg = obj.channelInputRanges;
            end
            
            if isempty(rg)
                rg = repmat({[0 5]}, 1, 4);
            end
            
            coupling = false; % false = DC coupling; true = AC coupling
            
            for ch = 0:3
                r = rg{ch+1};
                r = r(2) - r(1);
                err = dabs.ni.oscope.configureChannel(ch, r, true, coupling);
                assert(err == 0, 'Error when attempting to configure NI 517x device. Code = %d', err);
            end
        end
        
        function val = setChannelFilter(obj,val)
            switch lower(val)
                case {'bypass','none',''}
                    filterType = 0;
                case 'elliptic'
                    filterType = 1;
                case 'bessel'
                    filterType = 2;
                otherwise
                    assert(false,'Not a valid filter type: %s. Valid types are ''None'' ''Elliptic'' ''Bessel''',val);
            end
            
            userCommand = 1; % User command for filter settings (Refer to FlexRIO help)
            
            if ~isempty(regexpi(obj.adapterModuleName,'NI577'))
                val = 'none';
                return 
            end
            
            if ~obj.simulated
                for channelNumber = 0:(obj.adapterModuleChannelCount - 1)
                    status = obj.sendAdapterModuleUserCommand(userCommand,channelNumber,filterType);
                    assert(status == 0,'Setting filter type for channel %d returned fpga error code %d',channelNumber,status);
                end
            end
        end
        
        function configureAdapterModuleInternalSampleClock(obj)
            if strcmp(obj.adapterModuleName, 'NI517x')
                dabs.ni.oscope.configureSampleClock(false,0);
            else
                command   = 0; % 0 = Clock Settings
                userData0 = 3; % 3 = Internal Sample Clock locked to an external Reference Clock through Sync Clock <- FPGA hardcoded to use PXIe_Clk10 as Sync Clock
                userData1 = 0; % unused
                
                status = obj.sendAdapterModuleUserCommand(command,userData0,userData1);
                assert(status == 0,'Configuring internal sample clock for FlexRio digitizer module failed with status code %d',status);
            end
            
            obj.rawSampleRateAcq = obj.ADAPTER_MODULE_RAW_SAMPLING_RATE_MAP(obj.adapterModuleName);
            obj.externalSampleClock = false;
        end
        
        function configureAdapterModuleExternalSampleClock(obj,externalSampleClockRate)
            fprintf('Setting up external sample clock for FPGA digitizer module.\n');
            obj.externalSampleClock = true; %This needs to be set before the call of sendAdapterModuleUserCommand
            
            assert(~isempty(regexpi(obj.adapterModuleName,'NI573|NI577')),...
                'External sample clock unsupported for digitizer module %s. Please set the machine data file property ''externalSampleClockRate'' to false and restart ScanImage',...
                obj.adapterModuleName);
            
            loopRateRange = obj.ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP(obj.adapterModuleName);
            assert(( min(externalSampleClockRate) >= loopRateRange(1) ) && ...
                ( max(externalSampleClockRate) <= loopRateRange(2) ),...
                'The sample rate specified in the machine data file ( %.3fMHz ) is outside the supported range of the %s FPGA digitizer module ( %.1f - %.1fMHz )',...
                externalSampleClockRate/1e6,obj.adapterModuleName,loopRateRange(1)/1e6,loopRateRange(2)/1e6);
            
            if strcmp(obj.adapterModuleName, 'NI517x')
                dabs.ni.oscope.configureSampleClock(true,externalSampleClockRate);
            else
                command   = 0; % 0 = Clock Settings
                userData0 = 2; % 2 = External Sample Clock through the CLK IN connector
                userData1 = 0; % unused
                
                status = obj.sendAdapterModuleUserCommand(command,userData0,userData1);
                assert(status == 0,'Configuring external sample clock for FlexRio digitizer module failed with status code %d',status);
            end
            
            obj.rawSampleRateAcq = externalSampleClockRate; %preliminary, actual loop rate measured later
        end
        
        function measureExternalRawSampleClockRate(obj)
            measurePeriod     = 1e-3;   % [s] count sample clock edges for measurePeriod of time
            numMeasurements   = 100;    % number of measurement repeats to calculate mean and standard deviation
            allowOverClocking = 0.01;   % allow to overclock the digitizer by 1%
            loopRateRange   = obj.ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP(obj.adapterModuleName);
            maxLoopRateStd  = 50e4;    % [Hz] TODO: need to fine tune this value (somewhat of a guess right now)
            
            obj.checkAdapterModuleErrorState();
            
            % start measuring the sample rate
            fprintf('Measuring FPGA digitizer sample clock frequency...\n');
            obj.AcqStatusAcqLoopMeasurePeriod = round(measurePeriod * obj.FPGA_SYS_CLOCK_RATE);
            measurePeriod = double(obj.AcqStatusAcqLoopMeasurePeriod) / obj.FPGA_SYS_CLOCK_RATE; %read measure period back to account for rounding errors
            
            loopIterationsCountFactor = obj.FPGA_RAW_ACQ_LOOP_ITERATIONS_COUNT_FACTOR(obj.adapterModuleName);
            
            measurements = zeros(numMeasurements,1);
            for iter = 1:numMeasurements
                measurements(iter) = obj.AcqStatusAcqLoopIterationsCount / measurePeriod * loopIterationsCountFactor;
                most.idioms.pauseTight(measurePeriod);
            end
            
            loopRateMean = mean(measurements);
            loopRateStd  = std(measurements);
            
            if loopRateMean < 1e3
               most.idioms.dispError(['The external sample rate frequency %.1fHz is suspiciously low. ',...
                   'Is the clock connected and running?\n\n'],loopRateMean) ;
            end
            
            if ( loopRateMean < loopRateRange(1)*(1-allowOverClocking) ) || ...
               ( loopRateMean > loopRateRange(2)*(1+allowOverClocking) )
                
               plotMeasurement(measurements);
               error('The external sample clock frequency %.3fMHz is outside the supported range of the %s FPGA digitizer module (%.1f - %.1fMHz).',...
                      loopRateMean/1e6,obj.adapterModuleName,loopRateRange(1)/1e6,loopRateRange(2)/1e6);
            end
               
            if loopRateStd > maxLoopRateStd
                plotMeasurement(measurements);
                error('The external sample clock of the FPGA digitizer module is unstable. Sample frequency mean: %.3EHz, SD: %.3EHz. Please make sure the sample clock is connected and running.',...
                    loopRateMean,loopRateStd); % GJ 2015-03-01 <- if this check fails, we might have to adjust maxLoopRateStd
            end
            
            %if all checks passed, save sample rate to property            
            obj.rawSampleRateAcq = loopRateMean;            
            fprintf('FPGA digitizer module external sample clock is stable at %.3fMHz (SD: %.0fHz)\n',obj.rawSampleRateAcq/1e6,loopRateStd);
            
            %local function
            function plotMeasurement(measurements)
                persistent hFig
                if isempty(hFig) || ~ishghandle(hFig)
                    hFig = figure('Name','FPGA digitizer module sample frequency','NumberTitle','off','MenuBar','none');
                end
                
                clf(hFig);
                figure(hFig); %bring to front
                
                hAx = axes('Parent',hFig);
                plot(hAx,linspace(1,measurePeriod * numMeasurements,numMeasurements),measurements);
                title(hAx,'FPGA digitizer module sample frequency');
                xlabel(hAx,'Time [s]');
                ylabel(hAx,'Sample Frequency [Hz]');
            end
        end
    end
    
    %% PROP ACCESS
    methods
        function set.channelsInvert(obj,val)
            validateattributes(val,{'logical','numeric'},{'vector'});
            val = logical(val);
            
            if ~obj.simulated
                if length(val) == 1
                    val = repmat(val,1,obj.adapterModuleChannelCount);
                elseif length(val) < obj.adapterModuleChannelCount
                    val(end+1:end+obj.adapterModuleChannelCount-length(val)) = val(end);
                    most.idioms.warn('Setting for channelsInvert had less entries than physical channels are available. Set to %s',mat2str(val));
                elseif length(val) > obj.adapterModuleChannelCount
                    val = val(1:obj.adapterModuleChannelCount);
                    most.idioms.warn('Setting for channelsInvert had more entries than physical channels are available.');
                end
                
                valFpga = val; % fpga always expects a vector of length 4
                valFpga(end+1:end+4-length(valFpga)) = false;
                obj.AcqParamLiveInvertChannels = valFpga;
            end
            
            obj.channelsInvert = val;
        end
        
        function val = get.adapterModuleChannelCount(obj)
            val = obj.ADAPTER_MODULE_CHANNEL_COUNT(obj.adapterModuleName);
        end
    end
    
end



%--------------------------------------------------------------------------%
% flexRio_SI.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
