classdef DMC4040 < dabs.interfaces.LSCSerial & most.HasMachineDataFile
    %DMC4040 Class encapsulating DMC4040 device from Galil Motion Control
    
    % currently implemented for Stepper motor control only!!!!
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant,Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'DMC4040';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (Devices.Interfaces.LinearStageController)    
    properties (Constant,Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'poll';
    end
  
    properties (SetAccess=protected,Dependent)
        isMoving;
        infoHardware;
    end
    
    properties (SetAccess=protected,Dependent,Hidden)
        positionAbsoluteRaw;
        velocityRaw;
        accelerationRaw;
        invertCoordinatesRaw = false;
        maxVelocityRaw;
        
        resolutionRaw; %Resolution, in um, in the current resolutionMode
    end    

    properties (SetAccess=protected,Hidden)
        positionDeviceUnits = 1e-6; % default to 1 micron per microstep
        velocityDeviceUnits = nan;
        accelerationDeviceUnits = nan;
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (Devices.Interfaces.LSCSerial)    
    properties (Constant)
        availableBaudRates = [9600 19200 38400 115200];
        defaultBaudRate = 115200;
    end
    
    %% CLASS-SPECIFIC PROPERTIES       
    properties (SetAccess = private, SetObservable)
        activeAxes;
        initted = false;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = DMC4040(varargin)
            lscArgs = most.util.filterPVArgs(varargin,{'numDeviceDimensions'});
            if isempty(lscArgs)
                lscArgs = {'numDeviceDimensions' 3};
            end
            
            obj = obj@dabs.interfaces.LSCSerial('defaultTerminator',{'CR/LF','CR'},lscArgs{:},varargin{:});

            axes = {'A','B','C','D'};
            obj.activeAxes = axes(1:obj.numDeviceDimensions);
            
            args = most.util.filterPVArgs(varargin,{'positionDeviceUnits'});
            if ~isempty(args)
                assert(numel(args)==2);
                posUnits = args{2};
                if ~isempty(posUnits)
                    assert(isscalar(posUnits)||length(posUnits)==obj.numDeviceDimensions);
                    obj.positionDeviceUnits = posUnits;
                end
            end            
            
            obj.init();
        end
        
        function delete(obj)
            obj.deinit();
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        % throws
        function tf = get.isMoving(obj)
            profilerActive = obj.profilerActive();
            %refPos = obj.getReferencePosition();
            %stepCount = obj.getStepperCount();
            
            tf = any(profilerActive);% || ~isequal(refPos,stepCount);
        end
        
        function axMoving = profilerActive(obj)
            axMoving = [];
            for idx = 1:length(obj.activeAxes)
                obj.hRS232.flushInputBuffer();
                cmd = sprintf('MG _BG%s',obj.activeAxes{idx});
                obj.hRS232.sendCommand(cmd);
                mv = obj.hRS232.readStringRaw();
                obj.readCommandConfirmation();
                
                mv = strrep(mv,cmd,''); % filter cmd
                mv = strtrim(mv);       % remove whitespaces
                axMoving(end+1) = str2double(mv);
            end
        end
        
        
        function data = getStatusRecord(obj)
            obj.hRS232.flushInputBuffer();
            obj.hRS232.sendCommand('QR');
            headerSizeBytes = 4;
            header = obj.hRS232.readBinaryRaw(headerSizeBytes);
            
            numBytesToRead = double(typecast(uint8(header(3:4)),'uint16'))-headerSizeBytes;
            data = obj.hRS232.readBinaryRaw(numBytesToRead);
            data = uint8(vertcat(header,data));
        end

        % throws
        function v = get.infoHardware(obj)
           obj.hRS232.sendCommand('ID');
           pause(0.1);
           v = char(obj.hRS232.flushInputBuffer())';
           v = strrep(v,':','');
        end

        % throws
        function v = get.positionAbsoluteRaw(obj)
            v = obj.getStepperCount();
        end
        
        function posn = getEncoderPosition(obj)
            cmd = sprintf('TP %s;',strjoin(obj.activeAxes,''));
            obj.hRS232.sendCommand(cmd);
            posn = obj.hRS232.readStringRaw;            
            obj.readCommandConfirmation();
            
            posn = strrep(posn,cmd,''); % filter cmd echo
            posn = strtrim(posn); % remove white space
            posn = strsplit(posn,{',',' '});
            posn = str2double(posn);
            
            posn = posn(:)';            
        end
        
        function posn = getReferencePosition(obj)
            cmd = sprintf('RP %s;',strjoin(obj.activeAxes,''));
            obj.hRS232.sendCommand(cmd);
            posn = obj.hRS232.readStringRaw;            
            obj.readCommandConfirmation();
            
            posn = strrep(posn,cmd,''); % filter cmd echo
            posn = strtrim(posn); % remove white space
            posn = strsplit(posn,{',',' '});
            posn = str2double(posn);
            
            posn = posn(:)';            
        end
        
        function position = getStepperCount(obj)
            position = [];
            for idx = 1:length(obj.activeAxes)
                obj.hRS232.flushInputBuffer();
                cmd = sprintf('MG _TD%s',obj.activeAxes{idx});
                obj.hRS232.sendCommand(cmd);
                mv = obj.hRS232.readStringRaw();
                obj.readCommandConfirmation();
                
                mv = strrep(mv,cmd,''); % filter cmd
                mv = strtrim(mv);       % remove whitespaces
                position(end+1) = str2double(mv);
            end
        end

        function v = get.invertCoordinatesRaw(obj)
            obj.invertCoordinatesRaw;
        end
        
        function set.velocityRaw(obj,val)
            if isscalar(val)
                val = repmat(val,1,length(obj.activeAxes));
            else
                assert(length(val) == length(obj.activeAxes));
            end
            
            for idx = 1:length(obj.activeAxes)
                obj.hRS232.sendCommand(sprintf('SP%s= %f',obj.activeAxes{idx},val(idx)));
                obj.readCommandConfirmation();
            end
        end
        
        function val = get.velocityRaw(obj)
            val = [];
            for idx = 1:length(obj.activeAxes)
                cmd = sprintf('MG _SP%s',obj.activeAxes{idx});
                obj.hRS232.sendCommand(cmd);
                sp = obj.hRS232.readStringRaw();                
                obj.readCommandConfirmation();
                
                sp = strrep(sp,cmd,''); % filter cmd echo
                sp = strtrim(sp);
                sp = str2double(sp);
                val(end+1) = sp;
            end
        end       
        
        function set.accelerationRaw(obj,val)
            if isscalar(val)
                val = repmat(val,1,length(obj.activeAxes));
            else
                assert(length(val) == length(obj.activeAxes));
            end
            
            for idx = 1:length(obj.activeAxes)
                obj.hRS232.sendCommand(sprintf('AC%s= %f',obj.activeAxes{idx},val(idx)));
                obj.readCommandConfirmation();
                obj.hRS232.sendCommand(sprintf('DC%s= %f',obj.activeAxes{idx},val(idx)));
                obj.readCommandConfirmation();
            end
        end
        
        function val = get.accelerationRaw(obj)
            val = [];
            for idx = 1:length(obj.activeAxes)
                cmd = sprintf('MG _AC%s',obj.activeAxes{idx});
                obj.hRS232.sendCommand(cmd);
                sp = obj.hRS232.readStringRaw();
                obj.readCommandConfirmation();
                
                sp = strrep(sp,cmd,'');
                sp = strstrim(sp);
                sp = str2double(sp);
                val(end+1) = sp;
            end
        end
       
        function v = get.resolutionRaw(obj)
            v = NaN;
        end
        
        function v = get.maxVelocityRaw(obj)
            v = NaN;
        end
    end
        
    %% ABSTRACT METHOD IMPLEMENTATIONS
    methods (Access=protected,Hidden)
        function moveStartHook(obj,absTargetPosn)
            assert(obj.initted,'Motor is not initted');

            axes = strjoin(obj.activeAxes,'');
            
            stop = sprintf('ST %s;',axes); % stop all axes
            afterMove = sprintf('AM %s;',axes); % after move completes  
            
            axCmds = '';
            for idx = 1:length(obj.activeAxes);
                axCmd = sprintf('PA%s= %f;',obj.activeAxes{idx},absTargetPosn(idx)); % define new absolute position
                axCmds = horzcat(axCmds,axCmd);
            end
            
            beginMove = sprintf('BG %s;',axes); % begin move
            
            cmdString = [stop,afterMove,axCmds,beginMove];
            obj.hRS232.sendCommand(cmdString);
            
            numCommands = sum(cmdString==';'); % all commands should be terminated with semicolon
            response = obj.readCommandConfirmation(numCommands);
            
            %fprintf('Start Move: %s %s\n',cmdString,response);
        end
        
        function interruptMoveHook(obj)
            if ~obj.initted
                most.idioms.warn('Motor is not initted');
                return
            end

            obj.hRS232.sendCommand('ST');
            obj.readCommandConfirmation();
        end
        
        function resetHook(obj)
            if ~obj.initted
                most.idioms.warn('Motor is not initted');
                return
            end
            
            obj.hRS232.sendCommand('RS');
            obj.init();
        end
        
        function recoverHook(obj)
            obj.resetHook();
        end
    end
    
    methods
        function init(obj)
            if ~isempty(obj.mdfData.initCmd);
                obj.hRS232.sendCommand(obj.mdfData.initCmd);
                pause(1);
                obj.hRS232.flushInputBuffer();
                obj.hRS232.sendCommand('EO 0');
                pause(1);
                obj.hRS232.flushInputBuffer();
            end
            obj.initted = true;
        end
        
        function deinit(obj)
            if obj.initted && ~isempty(obj.mdfData.deinitCmd);
                obj.hRS232.sendCommand(obj.mdfData.deinitCmd);
                pause(1);
                obj.hRS232.flushInputBuffer();
            end
            obj.initted = false;
        end
        
        function val = readCommandConfirmation(obj,num)
            % After the instruction is decoded, the DMC-40x0 returns a response to the port from which the command was
            % generated. If the instruction was valid, the controller returns a colon (:) or the controller will respond with a
            % question mark (?) if the instruction was not valid.
            %             
            % For instructions that return data, such as Tell Position (TP), the DMC-40x0 will return the data followed by a
            % carriage return, line feed and :
            
            if nargin < 2 || isempty(num)
                num = 1;
            end
            val = char(obj.hRS232.readBinaryRaw(num));
            success = val==':';
            if any(~success)
                most.idioms.warn('Galil: Last command was not understood correctly. Response: %s',val);
            end
        end
    end
end

%--------------------------------------------------------------------------%
% DMC4040.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
