classdef PMT < scanimage.interfaces.PmtController
 %% User Props
    properties (SetAccess = immutable)
        manufacturer = [];
        model = [];
        serialNumber = [];
        firmware = [];
        UID = [];
        desc = [];
    end
    
    properties (SetAccess = private)
        statusLastUpdated = struct('enable', [0 0], 'gains', [0 0], 'bandwidth', [nan nan], 'gainOffset', [nan nan], 'trippedc', [0 0], 'trippedv', [0 0]);
    end
        
    properties (Dependent)
        enable;
        gains;
        bandwidth;
        gainOffset;
        pmtType;
    end
    
    properties (SetAccess = private, Dependent);
        tripped;
        tripCount;
    end
    
    %% CLASS-SPECIFIC PROPERTIES
    properties (Constant,Hidden)
        SERIAL_BAUD_RATE   = 9600;
        SERIAL_TERMINATOR  = 'CR';
        SERIAL_TIMEOUT     = 0.5;
    end
    
 %%% ABSTRACT PROPERTY REALIZATIONS (scaniamge.interfaces.PmtController)   
    properties (SetAccess = protected, Hidden)
        numPmts = 2;                    % [numerical] number of PMTs managed by the PMT controller -- THis needs to be 2
        pmtNames = {'A' 'B'};           % Cell array of strings with a short name for each PMT
        pmtInitSuccessful = true;       % Indicates PMT control is ready
        pmtsStatusLastUpdated;          % time of last pmt status update
    end
    
    % The get methods for these properties seem to be the only ones which
    % update the GUI.
    properties (Dependent, Hidden)
        pmtsPowerOn;             % [logical]   array containing power status for each PMT 
        pmtsGain;                % [numerical] array containing gain setting for each PMT
        pmtsOffsets;             % [numeric] array containing offset for each PMT
        pmtsBandwidths           % [numeric] array containing amplifier bandwidth for each PMT
    end
    
    properties (Dependent, SetAccess=private, Hidden)
        pmtsTripped;            % [logical] array containing trip status for each PMT
    end

    %% Internal Properties
    properties (SetAccess = private, Hidden)
        hSerial = [];
        currentTripped;
        voltageTripped;
        
        enable_ = [0 0];
        gains_ = [0 0];
        bandwidth_ = [nan nan];
        gainOffset_ = [nan nan];
        trippedc_ = [0 0];
        trippedv_ = [0 0];
        pmtType_ = '';

        enable_ut = uint64(0);
        gains_ut = uint64(0);
        bandwidth_ut = uint64(0);
        gainOffset_ut = uint64(0);
        trippedc_ut = uint64(0);
        trippedv_ut = uint64(0);
        
        replyPending = false;
        commandQueue = {};
        asyncCallback;
        lastCmd = '';
        TimeoutTimer;
    end
    
    properties
       mode = 0;
       logic = 0;
       currentBaud = 9600;
    end
    
    %% Lifecycle
    methods
        function obj = PMT(hSI,comPort)
            fprintf(1,'Initializing Scientifica PMT interface...');
            try
                obj.hSerial = serial(sprintf('COM%d',comPort), 'BaudRate',obj.SERIAL_BAUD_RATE, 'Terminator', obj.SERIAL_TERMINATOR);
                obj.hSerial.BytesAvailableFcnMode = 'terminator';
                obj.hSerial.BytesAvailableFcn = @obj.replyAvailable;
                fopen(obj.hSerial);
                obj.TimeoutTimer = timer('Name','Scientifica MDU: Async Cmd Timout Timer');
                obj.TimeoutTimer.ExecutionMode = 'singleShot';
                obj.TimeoutTimer.StartDelay = obj.SERIAL_TIMEOUT;
                obj.TimeoutTimer.TimerFcn = @obj.TimeoutFcn;
            catch 
                most.idioms.safeDeleteObj(obj.hSerial);
                error('\nError during initialization of Scientifica PMT interface.\nEnsure the MDU PMT Controller is powered on, the USB cable is connected and the right serial port is configured in the Machine Data File.\nDisabling Scientifica PMT interface.\nError report:\n%s\n',ME.message);
            end
            
            try
                fprintf(obj.hSerial, 'SCIENTIFICA');
                response = fgetl(obj.hSerial);
            catch
                response = [];
            end
            
            if ~isempty(response) && strcmp(response, 'Y519')
                fprintf(1,'...Scientifica PMT interface initialized.\n');
                obj.model = response;
                obj.manufacturer = 'SCIENTIFICA';
            elseif ~isempty(response) && strcmp(response, 'E,1')
                fprintf(1,'...Intitialization Error! Handshake Failed. Device may or may not have initialized properly.\n');
            else
                fclose(obj.hSerial);
                most.idioms.safeDeleteObj(obj.hSerial);
                error('...Initialization Failed! This not a Scientifica PMT Controller or it is not powered on.');
            end
            
            try
                fprintf(obj.hSerial, 'SERIAL');
                obj.serialNumber = fgetl(obj.hSerial);
            catch
                obj.serialNumber = [];
                warning('Failed to get MDU Serial #. Device connection suspect!');
            end
            
            try
                fprintf(obj.hSerial, 'VER');
                obj.firmware = fgetl(obj.hSerial);
            catch
                obj.firmware = [];
                warning('Failed to get MDU Firmware Ver. Device connection suspect!');
            end
            
            try
                fprintf(obj.hSerial, 'UID');
                obj.UID = fgetl(obj.hSerial);
            catch
                obj.UID = [];
                warning('Failed to get MDU UID. Device connection suspect!');
            end
            
            try
                fprintf(obj.hSerial, 'DESC');
                obj.desc = fgetl(obj.hSerial);
            catch
                obj.desc = [];
                warning('Failed to get MDU Description. Device connection suspect!');
            end
            
            try
                obj.setMode(3);
            catch
                warning('Failed to set MDU Gain Control Mode. Device connection suspect!');
            end

        end
        
        function delete(obj)
            try
                obj.enable = false;
            catch
            end
            
            if most.idioms.isValidObj(obj.TimeoutTimer)
                stop(objTimeoutTimer);
                delete(obj.TimeoutTimer);
            end
            
            if most.idioms.isValidObj(obj.hSerial)
                % Set some stuff first for safety
                fclose(obj.hSerial);
                most.idioms.safeDeleteObj(obj.hSerial);
            end
        end
    end
    %% USER METHODS
    methods
        function resetPmtTripStatus(obj,~)
%             fprintf(1,'\nScientifica MDU Restarting....');
            obj.writeCommand('RESTART', []);
        end
        
        function updatePmtsStatus(obj)
            % enable
            obj.writeCommand('ENABLE',@obj.processPMTUpdate);
            
            % gain
            obj.writeCommand('A',@obj.processPMTUpdate);
            obj.writeCommand('B',@obj.processPMTUpdate);

            % current tripped
            obj.writeCommand('V',@obj.processPMTUpdate);
            
            % Mode
            obj.writeCommand('SOURCE', @obj.processPMTUpdate);
        end
        
        function [powerOn, gains, tripped, offsets, bandwidths] = getLastPmtStatus(obj)
            powerOn = obj.enable_;
            gains = obj.gains_;
            tripped = obj.trippedc_;
            offsets = obj.gainOffset_;
            bandwidths = obj.bandwidth_;
        end
        
        % These set methods fire when GUI buttons are clicked.
        function setPmtPower(obj, ~, val)
            obj.pmtsPowerOn = val;
        end
        
        function setPmtGain(obj, id, val)
            obj.pmtsGain(id) = val;
        end
        
        function setPmtOffset(obj, ~, val)
            obj.pmtsOffsets = val;
        end
        
        function setPmtBandwidth(obj, ~, val)
            obj.pmtsBandwidths = val;
        end
    end
    
    %% Prop Access and Control
    methods
        function v = get.pmtsStatusLastUpdated(obj)
            v = min([obj.enable_ut obj.gains_ut obj.trippedc_ut]);
        end
        
        function v = get.enable(obj)
            if toc(obj.pmtsStatusLastUpdated) > .5
                obj.updatePmtsStatus();
                
                t = tic;
                while toc(obj.pmtsStatusLastUpdated) > .5
                    pause(0.00001);
                    assert(toc(t) < 1, 'Timed out waiting for pmt status.');
                end
            end
            
            v = obj.statusLastUpdated.enable;
        end
        
        function set.enable(obj, v)
            if any(v) == 1
                obj.writeCommand('ENABLE 1', []);
                obj.logic = 1;
            else
                obj.writeCommand('ENABLE 0', []);
                obj.logic = 0;
            end
            if obj.mode ~= 3
                obj.setMode(3);
            end
        end
        
        function v = get.pmtType(obj)
            % Not Supported in this model
        end
        
        function set.pmtType(obj, v)
            % Not Supported in this model
        end
        
        function v = get.bandwidth(obj)
            v = [nan nan];
        end
        
        function set.bandwidth(obj, v)
            % Not Supported in this model
        end
        
        function v = get.gains(obj)
            if toc(obj.pmtsStatusLastUpdated) > .5
                obj.updatePmtsStatus();
                
                t = tic;
                while toc(obj.pmtsStatusLastUpdated) > .5
                    pause(0.00001);
                    assert(toc(t) < 1, 'Timed out waiting for pmt status.');
                end
            end
            
            v = obj.statusLastUpdated.gains;
        end
        
        function set.gains(obj,v)
            
            cmdA = sprintf('A %d', v(1));
            cmdB = sprintf('B %d', v(2));
            
            obj.writeCommand(cmdA, []);
            obj.writeCommand(cmdB, []);
        end
        
        function v = get.gainOffset(obj)
            v = [nan nan];
        end
        
        function set.gainOffset(obj,v)
            % Not Supported in this model
        end
        
        function v = get.tripped(obj)
            v = obj.currentTripped;
        end
        
        function v = get.currentTripped(obj)
            
            if toc(obj.pmtsStatusLastUpdated) > .5
                obj.updatePmtsStatus();
                
                t = tic;
                while toc(obj.pmtsStatusLastUpdated) > .5
                    pause(0.00001);
                    assert(toc(t) < 1, 'Timed out waiting for pmt status.');
                end
            end
            v = obj.statusLastUpdated.trippedc;
        end
        
        function v = get.voltageTripped(obj)
            v = nan;
        end
        
        function v = get.tripCount(obj)
            v = nan;
        end
        
        
        %these methods are redundant to support PmtController interface
        function set.pmtsPowerOn(obj,v)
            obj.enable = v;
        end
        
        function v = get.pmtsPowerOn(obj)
            v = obj.enable;
        end
        
        function set.pmtsGain(obj,v)
            obj.gains = v;
        end
        
        function v = get.pmtsGain(obj)
            v = obj.gains;
        end
        
        function set.pmtsTripped(~,~)
            % Not Supported in this model
        end
        
        function v = get.pmtsTripped(obj)
            v = obj.tripped;
        end
        
        function set.pmtsOffsets(obj,v)
            % Not Supported in this model
        end
        
        function v = get.pmtsOffsets(obj)
            v = obj.gainOffset;
        end
        
        function set.pmtsBandwidths(obj,v)
            % Not Supported in this model
        end
        
        function v = get.pmtsBandwidths(obj)
            v = obj.bandwidth;

        end
        
    end
    
    %% Internal methods
    methods (Hidden)
        function setMode(obj, mode)
            assert(isnumeric(mode) && mode < 4 && mode >= 0, '\nSource must be 0, 1, 2, or 3. Please refer to documentation for further details.\n');
            cmd = sprintf('SOURCE %d',mode);
            obj.writeCommand(cmd, []);
        end
        
        function reconnect(obj)
            fopen(obj.hSerial);
            obj.setMode(3);
        end
        
        function TimeoutFcn(obj, ~,~)
            if obj.hSerial.BytesAvailable
                obj.replyAvailable();
            else
                stop(obj.TimeoutTimer);
%                 most.idioms.warn(['Timeout occurred while waiting for reply to ''' obj.lastCmd ''' cmd from Scientifica MDU']);
                obj.replyPending = false;
                obj.lastCmd = '';
                pause(obj.SERIAL_TIMEOUT);
                flushinput(obj.hSerial);
                
                % send next command in commandQueue
                obj.sendNextCmd(obj);
            end
        end
        
        function writeCommand(obj, cmd, callback)
            assert(isa(cmd,'char'));
           
            obj.commandQueue{end + 1} = {cmd, callback};
            obj.sendNextCmd();
        end
        
        function sendNextCmd(obj)
            if ~obj.replyPending
                % send next command in commandQueue
                if ~isempty(obj.commandQueue)
                    nextCommand = obj.commandQueue{1};
                    obj.commandQueue(1) = [];
                    
                    obj.lastCmd = nextCommand{1};
                    obj.asyncCallback = nextCommand{2};
                    
                    flushinput(obj.hSerial);
                    fprintf(obj.hSerial, obj.lastCmd);
                    stop(obj.TimeoutTimer);
                    start(obj.TimeoutTimer);
                    if strcmp(obj.lastCmd, 'RESTART')
                        obj.replyPending = false;
                        pause(5.5);
%                         fprintf(1, '...Done\n');
                    else
                        obj.replyPending = true;
                    end
                end
            end
        end
        
        function replyAvailable(obj,~,~)
            try
                if strcmp(obj.lastCmd, 'RESTART')
                    obj.replyPending = false;
                    obj.commandQueue = {};
                    flushinput(obj.hSerial);
                end
                
                if obj.replyPending
                    stop(obj.TimeoutTimer);
                    reply = fgetl(obj.hSerial);
                    obj.replyPending = false;

                    % process answer
                    if ~isempty(obj.asyncCallback)
                        obj.asyncCallback(reply);
                        obj.asyncCallback = [];
                    end
                    obj.lastCmd = '';
                    obj.replyPending = false;
                end
                
                obj.sendNextCmd();
            catch ME
                ME.stack(1)
                fprintf(2,'Error while processing response from PMT: %s\n', ME.message);
            end
        end
        
        function processPMTUpdate(obj,reply)
            
            switch(obj.lastCmd)
                case 'ENABLE'
                    if obj.statusLastUpdated.enable ~= [str2double(reply) str2double(reply)]
                        obj.statusLastUpdated.enable = [str2double(reply) str2double(reply)];
                        obj.enable_ = obj.statusLastUpdated.enable;
                        obj.notify('pmtStatusChanged');
                    end
                case 'A'
                    if obj.statusLastUpdated.gains(1) ~= str2double(reply)
                        obj.statusLastUpdated.gains(1) = str2double(reply);
                        obj.gains_ = obj.statusLastUpdated.gains;
                        obj.notify('pmtStatusChanged');
                    end
                    
                case 'B'
                    if obj.statusLastUpdated.gains(2) ~= str2double(reply)
                        obj.statusLastUpdated.gains(2) = str2double(reply);
                        obj.gains_ = obj.statusLastUpdated.gains;
                        obj.notify('pmtStatusChanged');
                    end
                case 'V'
                    volatile = str2double(reply(end));
                    volatile = dec2bin(volatile, 9);
                    v = [str2double(volatile(4)) str2double(volatile(3))];
                    if obj.statusLastUpdated.trippedc ~= v
                        obj.statusLastUpdated.trippedc = v;
                        obj.trippedc_ = obj.statusLastUpdated.trippedc;
                        obj.notify('pmtStatusChanged');
                    end
                case 'SOURCE'
                    obj.mode = str2double(reply);
            end
            
            obj.enable_ut = tic;
            obj.gains_ut = tic;
            obj.trippedc_ut = tic;
        end
    end

end

%--------------------------------------------------------------------------%
% PMT.m                                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
