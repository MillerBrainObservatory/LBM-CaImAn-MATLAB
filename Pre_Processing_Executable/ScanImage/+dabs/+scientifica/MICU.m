%% M.I.C.U. - Motorized Intensity Control Unit
% Handle class to implement commands for Scientifica 3 Axis Linear Card
% Controller unit. To be integrated into ScanImage in a similar manner to
% devices such as the half wave plate. Certain devices, including currently
% implemented Scientifica decvices, seem to implement this behavior
% already. 

classdef MICU < handle
    
   %% DEPENDENT GET-SET PROPERTIES
   properties(Dependent)
       axisPosition = []            % Dependent property that calls get & set methods for axis posistion. Array [X Y Z] containing axis position, not necessarily device position.
       linearSensorVals = [];       % Dependent property indicating the linear sensor values [X Y Z A]
       approachAngle;               % Dependent property indicating the approach angle of the approach axis
       motorStatus;                 % Dependent property indicating the motor status.
   end
   
   %% NON-DEPENDENT PROPERTIES
   % Used to formated date returned by serial commands.
   properties
       axisPosition_ = [];          % Array [X Y Z] containing axis position. Used to hold processed serial respone.
       axisPosition_ut = [];        % Time since last update.
       
       joystickReverseFlags = [];   % Logical Array [X Y Z] containing flags for whether joystick direction is reversed.
       revXFlag = false;            % Logical for whether X axis joystick direction is reversed.
       revYFlag = false;            % Logical for whether Y axis joystick direction is reversed.
       revZFlag = false;            % Logical for whether Z axis joystick direction is reversed.
       
       axisMultipliers = [];        % Array [X Y Z] containing axis step scaling multipliers
       multX = nan;                 % X Axis step scaling multiplier. Init to nan to avoid confusion with un-updated value. Call update on start?
       multY = nan;                 % Y Axis step scaling multiplier. * Ditto *
       multZ = nan;                 % Z Axis step scaling multiplier. * Ditto *
       
       acceleration = [];           % Array [X Y Z] containing axis acceleration settings for the manipulator
       accX = nan;                  % X Axis manipulator acceleration setting.
       accY = nan;                  % Y Axis manipulator acceleration setting.
       accZ = nan;                  % Z Axis manipulator acceleration setting.
       
       startSpeeds = [];            % Array [X Y Z] containing axis speed at which motion starts.
       startSpeedX;                 % X Axis motion start speed.
       startSpeedY;                 % Y Axis motion start speed.
       startSpeedZ;                 % Z Axis motion start speed.
       
       controlAcceleration;         % Acceleration value for the start and end of control input device motion.
       
       joystickSpeedScale;          % Joystick speed scaling value for when device is in fast mode.
       joystickSlowSpeedScale;      % Joystick speed scaling value for when device is in slow mode.
       topSpeedSetting;             % Value relating to the top speed of the motion device.
       
       limSwitchStatus = {};        % Cell array {X Y Z} containing string related to linear sensor limit switchs High, Low, None, Both.
       xLimSwitchStatus;            % Limit Switch status for X axis 
       yLimSwitchStatus;            % Limit switch status for Y axis
       zLimSwitchStatus;            % Limit switch status for Y axis
       
       highLimit;                   % Value of linear sensor high point
       lowLimit;                    % Value of linear sensor low point
       
       limitSwitchOprationMode;     % Value indicating mode of limit switches
       
       homeType;                    % Value indicating if home is fixed of dynamic
       homeOffset = [];             % Array containing offsets for homw posistion. Home command will return to home posistion minus these offsets.
       
       Current = [];                % Array [Run Standby] indicating the run and standby currents of the motion device.
       
       stageTypeNum;                % Numerical Value relating to stage type. See Scientifica documentation.
       Description;                 % String Describing controller.
       rotaryMapping;               % Value N relating to rotary wheel control mapping.
       
       linearSensorVals_ = [];      % Array [X Y Z A] containing values of the linear sensors.
       linearSensorVals_ut;         % Time since last sensor update
       
       approachAngle_;              % Contains the motio device appraoch angle for the approach axis
       approachAngle_ut;            % Time since last approach angle update
       
       approachEnabled;             % Logical indicating whether approach angle is enabled or disabled - Not functioning.
       firmwareDate;                % Cell array containing firmware version and date + time of update.
       firmware;                    % Numerical indicating the firmware version
       deadBand;                    % Value indicating central deadband of joysticks
       ID;                          % Value relating to ID of control card
       
       gotoRemap;                   % String indicating which command goto has been remapped into
       saveRemap;                   % String indicating which command save has been remapped into
       
       motorStatus_;                % Value indicating the current status of the motion device.
       motorStatus_ut;              % Time since last motor status update
       
       UMSscale;                    % Value indicating UMS Focus Speed scaling
   end
   
   %% CLASS-SPECIFIC PROPERTIES
   % Used for the serial connections and timer on initialization.
    properties (Constant,Hidden)
        SERIAL_BAUD_RATE   = 9600;
        SERIAL_TERMINATOR  = 'CR';
        SERIAL_TIMEOUT     = 0.5;
    end
   
   %% SERIAL PIPELINE AND CONTROL PROPERTIES
   % Used for the serial command pipeline.
   properties
       hSerial = [];
       TimeoutTimer;
       commandQueue = {};
       replyPending = false;
       lastCmd = '';
       asyncCallback = [];
       currentBaud;
   end
   
   
   %% Life Cycle
   methods
       function obj = MICU(hSI, comPort)
           fprintf(1,'Initializing Scientifica MICU interface...');
           try
                obj.hSerial = serial(sprintf('COM%d',comPort), 'BaudRate', obj.SERIAL_BAUD_RATE, 'Terminator', obj.SERIAL_TERMINATOR);
                obj.hSerial.BytesAvailableFcnMode = 'terminator';
                obj.hSerial.BytesAvailableFcn = @obj.replyAvailable;
                fopen(obj.hSerial);
                obj.TimeoutTimer = timer('Name','Scientifica MICU: Async Cmd Timout Timer');
                obj.TimeoutTimer.ExecutionMode = 'singleShot';
                obj.TimeoutTimer.StartDelay = obj.SERIAL_TIMEOUT;
                obj.TimeoutTimer.TimerFcn = @obj.TimeoutFcn;
           catch
               most.idioms.safeDeleteObj(obj.hSerial);
               error('FAILED!\nUnable to initialize Scientifica MICU interface.\nEnsure the MICU is connected and powered on and that the correct serial port is configured in the Machine Data File.\n'); 
           end
           fprintf(1,'Done!\n');
       end
       
       function delete(obj)
            
            if most.idioms.isValidObj(obj.TimeoutTimer)
                stop(obj.TimeoutTimer);
                delete(obj.TimeoutTimer);
            end
            
            if most.idioms.isValidObj(obj.hSerial)
                % Set some stuff first for safety
                flushinput(obj.hSerial);
                fclose(obj.hSerial);
                most.idioms.safeDeleteObj(obj.hSerial);
            end
            
        end
   end
   
   %% Position Command
   methods
       %Sets the current position on each axis to given values. The motion
       %device will not have moved the axis will have changed. Returns Ack
       function set.axisPosition(obj, pos)
           cmd = sprintf('P %d %d %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Ask Alex about units for this?
       %Changes the setting for the current axis posistion. The device will
       %not have moved only the axis location will have changed.
       function pos = get.axisPosition(obj)
           lut = obj.axisPosition_ut;
           obj.writeCommand('P', @obj.axisPositionCallback);
           
           startedWaiting = tic;
           while lut == obj.axisPosition_ut
               pause(0.1);
               if toc(startedWaiting) > 5
                   error('Timed out waiting for position update')
               end
           end
           
           pos = obj.axisPosition_;
       end
       
       % Can Reference individual axis with command 'PX #', 'PY #', and
       % 'PY #' command respectively. Not necessarily needed? 
       
       % There is also a zero command. Implemented in misc mehtods
   end
   
   %% Unit Commands
   methods
       
       % Reverses the direction of rotation of the joystick that results in
       % positive movement with the direction that results in negative
       % movement. 
       function reverseJoystickAxis(obj, axis)
           % Can also be achieved with JD[axis] 1 or 0, i.e. 'JDY 1'
           switch axis
               case {'x' 'X'}
                   cmd = 'JDX';
               case {'y' 'Y'}
                   cmd = 'JDY';
               case {'z' 'Z'}
                   cmd = 'JDZ';
               otherwise
                   % No Op.
           end
           
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to a prop a logical array of 1 or 0 for each axis X, Y, Z. 
       % A logic 1 means that joystick axis is reversed whereas a logical 0
       % means that joystick axis is not reversed.
       % Command on its own simply returns 1 or 0. Callback creates updated
       % array for all? Change this....
       function updateJoystickReverseFlag(obj, axis)
           switch axis
               case {'x' 'X'}
                   cmd = 'JDX ?';
               case {'y' 'Y'}
                   cmd = 'JDY ?';
               case {'z' 'Z'}
                   cmd = 'JDZ ?';
               otherwise
                   % No Op. 
           end
           obj.writeCommand(cmd, @obj.reverseFlagCallback);
           
       end
       
       % Sets the reverse flag. Returns A (acknowledged) if allowed or E if
       % not allowed. Reverse function will naturally do this so this seems
       % to have the exact same effect.....Redundant?
       function setJoystickReverseFlag(obj, axis, flagTF)
            switch axis
               case {'x' 'X'}
                   cmd = sprintf('JDX %d', flagTF);
               case {'y' 'Y'}
                   cmd = srintf('JDY %d', flagTF);
               case {'z' 'Z'}
                   cmd = sprintf('JDZ %d', flagTF);
               otherwise
                   % No Op. 
            end
           
            obj.writeCommand(cmd, @obj.doNothing);
            
       end
       
       % Returns to a property a multiplier used on the specified axis to 
       % scale the steps correctly. By default this value should be set set
       % so that steps are in 10th's of microns. Returns multiplier value 
       % to 2 decimal places.
       function updateAxisUserUnits(obj, axis)
           switch axis
               case {'x' 'X'}
                   cmd = 'UUX';
               case {'y' 'Y'}
                   cmd = 'UUY';
               case {'z' 'Z'}
                   cmd = 'UUZ';
               otherwise
                   % No Op. 
           end
            
           obj.writeCommand(cmd, @obj.userUnitsCallback);
       end
       
       % Sets the designated axis multiplier used to scale steps. Changing
       % this will affect posistions reported back. Response A if allowed E
       % if error.
       function setAxisUserUnits(obj, axis, mult)
           switch axis
               case {'x' 'X'}
                   cmd = sprintf('UUX %d', mult);
               case {'y' 'Y'}
                   cmd = sprintf('UUY %d', mult);
               case {'z' 'Z'}
                   cmd = sprintf('UUZ %d', mult);
               otherwise
                   % No Op. 
           end
           obj.writeCommand(cmd, @obj.doNothing);
       end
   end
   
   %% Move Commands
   methods
       
       % Moves the device to the given absolute posistion on the x,y, and z
       % axis. Input position should be an array containing the desired
       % posistions in formated as [X Y Z]. Returns Ack.
       function moveAllAbsolute(obj, pos)
           assert(~(length(pos) < 3), 'Not enough coordinates to move X, Y, and Z!');
           assert(~(length(pos) > 3), 'Too many coordinates! Only X, Y, and Z allowed!');
           assert(isnumeric(pos), 'Invalid Posistion! Values non-numeric!');
           assert(~(any(isnan(pos))), 'Commanded posistion is nan!');
           cmd = sprintf('ABS %d %d %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Moves the device to the given absolute posistion on the x and y
       % axis. Input position should be an array containing the desired
       % posistions in formated as [X Y]. Returns Ack.
       function moveXYAbsolute(obj, pos)
           assert(~(length(pos) < 2), 'Not enough coordinates to move X and Y!');
           assert(~(length(pos) > 2), 'Too many coordinates. X and Y only!');
           assert(isnumeric(pos), 'Invalid Posistion! Values non-numeric!');
           assert(~(any(isnan(pos))), 'Commanded posistion is nan!');
           cmd = sprintf('ABS %d %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Moves the device to the given absolute posistion on the Z axis
       % only. Input posistion should be a single value containing the
       % desired Z posistion. Returns Ack.
       function moveZAbsolute(obj, pos)
           assert(isnumeric(pos), 'Commanded posistion is not numeric!');
           assert(~isnan(pos), 'Commanded posistion is nan!');
           cmd = sprintf('ABSZ %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % A more generic implementation of the move commands that takes into
       % account the size of pos to decide the command. Returns Ack.
       function moveAbsolute(obj, pos)
           assert(~isempty(pos), 'Commanded position is empty!');
           assert(~(any(isnan(pos))), 'Commanded posistion is nan!');
           assert(isnumeric(pos), 'Commanded posistion is not numeric!');
           
           if length(pos) == 1                      % Move Z Absolute
               cmd = sprintf('ABSZ %d', pos);
           elseif length(pos) == 2                  % Move X & Y Absolute
               cmd = sprintf('ABS %d %d', pos);
           elseif length(pos) == 3                  % Move X, Y, & Z Absolute
               cmd = sprintf('ABS %d %d %d', pos);
           else
               error('Invalid posistion! Commanded posistion is either empty or has more than 3 axis values.');
           end
           
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Moves the posistion of the device along the X, Y, & Z axis by the
       % ammount given in pos relative to the current posistion. Desired
       % positions formated as an array [X Y Z]. Returns Ack.
       function moveAllRelative(obj, pos)
           assert(~(length(pos) < 3), 'Not enough coordinates to move X, Y, and Z!');
           assert(~(length(pos) > 3), 'Too many coordinates! Only X, Y, and Z allowed!');
           assert(isnumeric(pos), 'Invalid Posistion! Values non-numeric!');
           assert(~(any(isnan(pos))), 'Commanded posisition is nan!');
           cmd = sprintf('REL %d %d %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Moves the posistion of the device along the X & Y axis by the
       % ammount given in pos relative to the current posistion. Input
       % position is formated as an array with desired posistions [X Y].
       % Returns Ack.
       function moveXYRelative(obj, pos)
           assert(~(length(pos) < 2), 'Not enough coordinates to move X and Y!');
           assert(~(length(pos) > 2), 'Too many coordinates. X and Y only!');
           assert(isnumeric(pos), 'Invalid Posistion! Values non-numeric!');
           assert(~any(isnan(pos)), 'Commanded posistion is nan!');
           cmd = sprintf('REL %d %d', pos);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Moves the posistion of the device along the Z axis by the
       % ammount given in pos relative to the current posistion.
       % Returns Ack.
       function moveZRelative(obj, pos)
           assert(isnumeric(pos), 'Commanded posistion is not numeric!');
           assert(~isnan(pos), 'Commanded posistion is nan!');
           cmd = sprintf('RELZ %d', pos);
           obj.writeCommand(cmd, @obj.doNothing); 
       end
       
       % A more generic implementation of the move relative commands. Takes
       % into account size of pos. Returns Ack.
       function moveRelative(obj, pos)
           assert(~isempty(pos), 'Commanded position is empty!');
           assert(~(any(isnan(pos))), 'Commanded posistion is nan!');
           assert(isnumeric(pos), 'Commanded posistion is not numeric!');
           
           if length(pos) == 1                      % Move Z Relative
               cmd = sprintf('RELZ %d', pos);
           elseif length(pos) == 2                  % Move X & Y Relative
               cmd = sprintf('REL %d %d', pos);
           elseif length(pos) == 3                  % Move X, Y, & Z Relative
               cmd = sprintf('REL %d %d %d', pos);
           else
               error('Invalid posistion! Commanded posistion is either empty or has more than 3 axis values.');
           end
           
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Will continuously move the device at the specifed velocity for each axis.
       % Simulates joy stick usage with a computation control over speed of
       % movement. Speed should be an array containing the desired movement
       % speed for each axis. Sign changes the direction. 0 will stop.
       % Returns Ack.
       function virtualJoyMove(obj, speed)
           assert(~isempty(speed), 'Velocity command is empty!');
           assert(isnumeric(speed), 'Commanded velocity is not numeric!');
           assert(~(length(speed) < 3), 'Not enough arguments for axis velocity');
           assert(~(length(speed) > 3), 'Too many arguments for axis velocity');
           assert(~(any(isnan(speed))), 'Commanded speed is nan!');
           cmd = sprintf('VJ %d %d %d', speed);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Similar to above only 4th command is a speed scale. Valid values
       % are S for slow, F for fast, C for creep. In order of slowest to
       % fastest C, S, F. Creep seems to be the same speed as standard
       % (above). Returns Ack or Error. 
       function virtualJoyMoveScaled(obj, speed, scale)
           validScales = {'F' 'S' 'C'};
           assert(~isempty(speed), 'Velocity command is empty!');
           assert(isnumeric(speed), 'Commanded velocity is not numeric!');
           assert(~(length(speed) < 3), 'Not enough arguments for axis velocity');
           assert(~(length(speed) > 3), 'Too many arguments for axis velocity');
           assert(~(any(isnan(speed))), 'Commanded speed is nan!');
           assert(ischar(scale), 'Scaling factor invalid type. Must be character.');
           assert(any(find([validScales{:}] == str)), 'Invalid Scaling Factor!');
           
           cmd = sprintf('VJ %d %d %d %s', speed, scale);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % This function will move the device to the next saved point on the
       % device. Returns Ack.
       function gotoNextSavedPoint(obj)
          obj.writeCommand('GOTO', @obj.doNothing); 
       end
       
       % This function moves the device by a set distance along the
       % approach axis, or the z axis if approach is disabled. Returns Ack.
       function stepDevice(obj)
          obj.writeCommand('STEP', @obj.doNothing);
       end
       
       % This function stops all motion on the device. Returns Ack.
       function stopMotion(obj)
          obj.writeCommand('STOP', @obj.doNothing); 
       end
   end
   
   %% Speed Commands
   methods
       % Returns to property the acceleration and decceleration setting for
       % the manipulator. Returns a decimal value between 10 and 1000.
       % Acceleration in um^2/se (+/- 5%) is (250 * Value)/UU?. Where UU?
       % is the defauly user unit for the given axis (UUX, UUY, UUZ).
       function updateAcc(obj)
           obj.writeCommand('ACC', @obj.updateAccCallback);
       end
       
       % Sets the acceleration/decceleration setting for the manipulator.
       % Value must be a decimal between 10 and 1000. Acceleration is given
       % by the same equation as in the previous function documentation.
       % Returns Ack.
       function setAcc(obj, acc)
           assert(~isinf(acc), 'Commanded Acceleration constant is inf!');
           assert(~isnan(acc), 'Commanded Acceleration constant is nan!');
           assert(isnumeric(acc), 'Commanded acceleration constant is not numeric!');
           assert(~(acc < 10), 'Commanded acceleration constant is too low!');
           assert(~(acc > 1000), 'Commanded acceleration constant is too high!');
           cmd = sprintf('ACC %d', acc);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the speed at which motion starts. Value returned will be
       % between 1000 and 50,000 where speed in um/sec is equal to the the
       % equation Value/2*UU? where UU? is the user units for a given axis
       % UUX, UUY, UUZ.
       function updateStartSpeed(obj)
           obj.writeCommand('FIRST', @obj.updateStartSpeedCallback);
       end
       
       % Sets the speed at which motion starts. Value must be between 1000
       % and 50,000. Returns Ack.
       function setStartSpeed(obj, speed)
           asset(isnumeric(speed), 'Speed constant must be numeric!');
           assert(~isnan(speed), 'Commanded speed constant is nan!');
           assert(~isinf(speed), 'Commanded speed constant is inf!');
           assert(~(speed < 1000), 'Commanded speed constant must be > 1000');
           assert(~(speed > 50000), 'Commanded speed constant must be < 50,000');
           cmd = sprintf('FIRST %d', speed);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the acceleration/deceleration setting used at the start &
       % end of moves from control device inputs. Return value is between
       % 10 and 1000. 
       function updateControlAcc(obj)
          obj.writeCommand('JACC', @obj.updateControlAccCallback);
       end
       
       % Sets the acceleration/deceleration setting used at the start and
       % end of moves from control device inputs. Value must be between 10
       % and 1000. Returns Ack if allowed, E otherwise.
       function setContrlAcc(obj, acc)
           asset(isnumeric(acc), 'Acceleration constant must be numeric!');
           assert(~isnan(acc), 'Commanded Acceleration constant is nan!');
           assert(~isinf(acc), 'Commanded Acceleration constant is inf!');
           assert(~(acc < 10), 'Commanded Acceleration constant must be > 10');
           assert(~(acc > 1000), 'Commanded Acceleration constant must be < 1000');
           cmd = sprintf('JACC %d', acc);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the speed scaling for when input control devices are in
       % fast mode. Return is a decimal value between 1 and 250.
       function updateJoystickSpeedScaling(obj)
           obj.writeCommand('JSPEED', @obj.updateJoystickSpeedScalingCallback);
       end
       
       % Sets the speed scaling for when input control device is in fast
       % mode. Value must be between 1 and 250. Returns Ack or Error.
       function setJoystickSpeedScaling(obj, speed)
           asset(isnumeric(speed), 'speed scale constant must be numeric!');
           assert(~isnan(speed), 'Commanded speed scale constant is nan!');
           assert(~isinf(speed), 'Commanded speed scale constant is inf!');
           assert(~(speed < 1), 'Commanded speed scale constant must be > 1');
           assert(~(speed > 250), 'Commanded speed scale constant must be < 250');
           cmd = sprintf('JSPEED %d', speed);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the speed scaling for when the input control device is in
       % slow mode. Returns a value between 1 and 50.
       function updateJoystickSlowSpeedScaling(obj)
           obj.writeCommand('JSSPEED', @obj.updateJoystickSlowSpeedScalingCallback);
       end
       
       % Sets the speed scaling for when the input control device is in
       % slow mode. Returns Ack or Error. Value must be between 1 and 50.
       function setJoystickSlowSpeedScaling(obj, speed)
           asset(isnumeric(speed), 'speed scale constant must be numeric!');
           assert(~isnan(speed), 'Commanded speed scale constant is nan!');
           assert(~isinf(speed), 'Commanded speed scale constant is inf!');
           assert(~(speed < 1), 'Commanded speed scale constant must be > 1');
           assert(~(speed > 50), 'Commanded speed scale constant must be < 50');
           cmd = sprintf('JSSPEED %d', speed);
           obj.writeCommand(cmd, @obj.doNothing); 
       end
       
       % Returns to property the top speed setting for the motion device/ manipulator.
       % Value is between 1000 and 50,000. Speed in um/sec (+/- 5%) is
       % given by Value/(2*UU?) where UU? is the user units for the given
       % axis UUX, UUY, or UUZ.
       function updateTopSpeed(obj)
          obj.writeCommand('TOP', @obj.updateTopSpeedCallback);
       end
       
       % Sets the top speed setting for the motion device/manipulator.
       % Value must be between 1000 and 50,000. Speed is given by the
       % equation in the above function description. Returns Ack.
       function setTopSpeed(obj, speed)
           asset(isnumeric(speed), 'Top speed setting must be numeric!');
           assert(~isnan(speed), 'Commanded speed setting constant is nan!');
           assert(~isinf(speed), 'Commanded speed setting constant is inf!');
           assert(~(speed < 1000), 'Commanded speed setting constant must be > 1000');
           assert(~(speed > 50000), 'Commanded speed setting constant must be < 50,000');
           cmd = sprintf('TOP %d', speed);
           obj.writeCommand(cmd,@obj.doNothing);
       end
   end
   
   %% Limit Commands
   methods
       % Returns to property a hex value relating to the status of the limit switches
       % on the manipulator. First hex value is the pertinent value. Must
       % be converted to binary. Only bits 0 to 5 are pertinent.
       function updateLimitSwitched(obj)
          obj.writeCommand('LIMITS', @obj.updateLimitSwitchCallback);
       end
       
       % Returns to property the value relating to the high point on the linear sensor.
       function updateHighLimit(obj)
          obj.writeCommand('HIGHL',@obj.updateHighLimitCallback);
       end
       
       % Sets the value relating to the high point on the linear sensor.
       % Returns Ack
       function setHighLimit(obj, value)
          asset(isnumeric(value), 'Limit must be numeric!');
          assert(~isnan(value), 'Commanded limit is nan!');
          assert(~isinf(value), 'Commanded limit is inf!');
          cmd = sprintf('HIGHL %d', value);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the value relating to the low point on the linear sensor.
       function updateLowLimit(obj)
          obj.writeCommand('LOWL', @obj.updateLowLimitCallback);
       end
       
       % Sets the value relating to the low point on the linear sensor.
       % Returns Ack.
       function setLowLimit(obj, value)
          asset(isnumeric(value), 'Limit must be numeric!');
          assert(~isnan(value), 'Commanded limit is nan!');
          assert(~isinf(value), 'Commanded limit is inf!');
          
          cmd = sprintf('LOWL %d', value);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Returns to property the mode for limit switch operation. 
       % Return value is 0,1, or 2. 
       % 0 - Default mode, sed if driven device has limit switches
       % 1 - Used if device has linear sensors
       % 2 - Used if device has limit switch ring main
       function updateLimitSwitchOperationMode(obj)
           obj.writeCommand('MODE', @obj.updateLimitSwitchMdeCallback);
       end
       
       % Sets mode for limit switch operation according to above
       % description. Value must be 0,1, or 2. Reurns Ack.
       function setLimitSwitchOperationMode(obj, value)
           cmd = sprintf('MODE %d', value);
           obj.writeCommand(cmd, @obj.doNothing);
       end
   end
   
   %% Home Commands
   methods
       %% If there is a fixed home in position (set via the INSET command) 
       % then this will cause the motion device to move to this set 
       % position. If there is not a fixed home in position then if the 
       % OUT command was last issued the motion device will return to the 
       % position before the OUT command was issued. Returns Ack value.
       function goHome(obj)
           obj.writeCommand('IN', @obj.doNothing);
       end
       
       %% Returns values relating to whether fixed or dynamic home in is 
       % being used. 0 if dynamic home in is being used or 1 if fixed 
       % home in being used
       function updateHomeType(obj)
           obj.writeCommand('INSET', @obj.updateHomeTypeCallback);
       end
       
       %% Sets the type of home in that will be used by the IN command.
       % If 0 is given as the argument then dynamic home in is going to be
       % used and the motion device will return to the position before the
       % OUT command was issued. If 1 is given as the argument the motion
       % device’s current location will be set as the fixed home in 
       % position and when the IN command is used the motion device will 
       % return to the current position. Returns Ack.
       function setHomeType(obj, value)
          asset(isnumeric(value), 'Value must be numeric!');
          assert(~isnan(value), 'Value is nan!');
          assert(~isinf(value), 'Value is inf!');
          assert(value == 1 || value == 0, 'Value must be 1 or 0!');
          cmd = sprintf('INSET %d', value);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% This returns the amount of offset for each axis that is used by 
       % the IN command. When the IN command is send the motion device will
       % move to the stored home in position on each axis minus this 
       % offset. Response: Three tab separated values in tenths of microns 
       % relating to the x y and then z offset. 
       function updateHomeOffset(obj)
           obj.writeCommand('OFFSET', @obj.updateHomeOffsetCallback);
       end
       
       %% This sets the amount of offset for each axis that is used by the 
       % IN command. When the IN command is send the motion device will 
       % move to the stored home in position on each axis minus this 
       % offset. Returns Ack
       function setHomeOffset(obj, value)
          asset(isnumeric(value), 'Offset value must be numeric!');
          assert(~(any(isnan(value))), 'Offset value is nan!');
          assert(~(any(isinf(value))), 'Offset value is inf!');
          assert(~(length(value) < 3 ), 'Must contain offsets for each axis, not enough values!');
          assert(~(length(value) > 3 ), 'Offset contains too many values!');
          
          cmd = sprintf('OFFSET %d %d %d', value);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% This command sets the size of the step made when the STEP command
       % is sent. The value must be in tenths of microns. Returns Ack. Tnis
       % command with no arguments returns some array - undocumented?
       function setStepSize(obj, value)
           cmd = sprintf('SETSTEP %d', value);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% This causes the motion device to move to the home out position set
       % using the SET command. Returns Ack.
       function goToHomeOut(obj)
          obj.writeCommand('OUT', @obj.doNothing); 
       end
       
       %% This sets the current position to be the home out position.
       % Returns Ack.
       function setHomeOut(obj)
            obj.writeCommand('SET', @obj.doNothing);
       end
       
   end
   
   %% Setting Commands
   methods
       %% Returns to a property the run and standby current. Returns 2 values between 1
       % and 255. First value relates to run current, second value relates
       % to standby current. Need Formula.
       function updateCurrent(obj)
          obj.writeCommand('CURRENT', @obj.updateCurrentCallback);
       end
       
       %% Sets the run and standby current. Where the values are between 1
       % and 255. Returns Ack or E if not allowed.
       function setCurrent(obj, value)
           assert(isnumeric(value), 'Current value must be numeric!');
           assert(~any(isinf(value)), 'Current value can not be inf!');
           assert(~any(isnan(value)), 'Current value can not be nan!');
           assert(~any(value > 255), 'Current value can not be > 255!');
           assert(~any(value < 1), 'Current value can not be < 1!');
           cmd = sprintf('CURRENT %d %d', value);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% Returns to a property value relating to the type of stage the 
       % motion card is setup to use
       function updateStageType(obj)
           obj.writeCommand('TYPE', @obj.updateStageTypeCallback);
       end
       
       %% Changes the type of stage the motion card is setup to use. 
       % Argument should take one of the following values:
       % 1,2,3,4,5,6,7,1.08,1.09,1.10,1.11,1.12,1.13,1.14. Returns Ack.
       function setStageType(obj, type)
           valid = [1,2,3,4,5,6,7,1.08,1.09,1.10,1.11,1.12,1.13,1.14];
           assert(isnumeric(type), 'Type must be numeric value corresponding to stage type!');
           assert(any(find(valid == type)), 'Invalid type!');
           cmd = sprintf('TYPE %d', type);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % This will return the stored description the card has of itself. 
       function updateDesc(obj)
          obj.writeCommand('DESC', @obj.updateDescCallback);
       end
       
       %% This will set the description of the card. This is used by LinLab 
       % to give more meaningful descriptions to tabs and windows. Returns
       % Ack
       function setDescription(obj, str)
           cmd = sprintf('DESC %s', str);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% This remaps which rotary wheel moves which axis on control cubes
       % and patch pads. Returns current mapping if no argument provided.
       % Returns Ack otherwise.
       % Mapping Table:
       % n   |   Control Cube   |       PatchPad          |
       % 0   | X-R   Y-Fr  Z-T  | X-R     Y-Cent   Z-L    |
       % 1   | X-R   Y-T   Z-Fr | X-R     Y-L      Z-Cent |
       % 2   | X-Fr  Y-R   Z-T  | X-Cent  Y-R      Z-L    |
       % 3   | X-T   Y-R   Z-Fr | X-L     Y-R      Z-Cent |
       % 4   | X-Fr  Y-T   Z-R  | X-Cent  Y-L      Z-R    |
       % 5   | X-T   Y-Fr  Z-R  | X-L     Y-Cent   Z-R    |
       %%
       function remapRotaryWheel(obj, val)
           valid = [0,1,2,3,4,5];
           assert(isnumeric(val), 'Value must be numeric & correspond to control mapping!');
           assert(any(find(valid == val)), 'Invalid maping!');
           cmd = sprintf('PPLMAP %d', val);
           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %% Returns to a property a value indicating the rotary wheel mapping 
       % for control devices
       function updateRotaryMapping(obj)
          obj.writeCommand('PPLMAP', @obj.updateRotaryMappingCallback);
       end
       
   end
   
   %% Misc Commands
   methods
       
       % Sets the current posistio to (0,0,0) as long as device not moving.
       % Command S returns 0. Returns A if allowed, E otherwise.
       function zeroAzisPosistion(obj)
          obj.writeCommand('ZERO', @obj.doNothing); 
       end
       
       % Saves the current point to the motion card. Returns A.
       function savePoint(obj)
          obj.writeCommand('SAVE', @obj.doNothing); 
       end
       
       % Clears the list of saved points. Returns Ack.
       function clearSavedPoints(obj)
          obj.writeCommand('CLEAR',@obj.doNothing); 
       end
       
       %Returns the values on the linear motion sensors. 4 tab separated 
       %values relating to the values of the linear sensors where the first
       %value is x followed byy, z then a.
       function v = get.linearSensorVals(obj)
           lut = obj.linearSensorVals_ut;
           obj.writeCommand('?', @obj.getLinearSensorValsCallback);
           
           startedWaiting = tic;
           while lut == obj.linearSensorVals_ut
               pause(0.1);
               if toc(startedWaiting) > 5
                   error('Timed out waiting for sensor update')
               end
           end
           v = obj.linearSensorVals_;
       end
       
       function set.linearSensorVals(obj, v)
           % No Op - Can Not Set Sensor Values.
       end
       
       %Returns a decimal value relating to the andle be used to determine
       %the approach axis.
       function v = get.approachAngle(obj)
           lut = obj.approachAngle_ut;
           obj.writeCommand('ANGLE', @obj.getApproachAngleCallback);
           
           startedWaiting = tic;
           
           while lut == obj.approachAngle_ut
               pause(0.1)
               if toc(startedWaiting) > 5
                   error('Timed out waiting for approach angle update')
               end
           end
           v = obj.approachAngle_;
       end
       
       %Sets the angle in degrees of the approach axis to the given value.
       %If the motion device has a rotary sensor then A can be used as the
       %angle which tells the card to automatically detect the angle of the
       %approach axis. Returns Ack.
       function set.approachAngle(obj, value)
          cmd = sprintf('ANGLE %d', value);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %Returns a value 1 or 0 indicating whether or not the approach axis
       %is enable. Did not function in tests. Returns E,3.
       function v = getApproachEnable(obj)
%           obj.writeCommand('APPROACH', @obj.getApproachEnableCallback);
%           v = obj.approachEnabled;
       end
       
       %Sets whether the approach axis is enabled or disabled. Returns Ack.
       % Also does not work.
       function setApproachEnable(obj, val)
%           assert(isnumeric(val), 'Value must be numeric!');
%           assert(val ==1 || val == 0, 'Value must be 1 or 0');
%           cmd = sprintf('APPROACH %d', val);
%           obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %This returns the firmware version, compile date and compile time
       %separated by tabs.
       function updateFirmwareDate(obj)
          obj.writeCommand('DATE', @obj.updateFirmwareCallback);
       end
       
       %Returns the firmware version. Sort of redundant.
       function updateFirmware(obj)
          obj.writeCommand('VER', @obj.updateFirmwareCallback);
       end
       
       %Returns the value for the central dead band of joysticks in
       %positive decimal values.
       function updateDeadBand(obj)
          obj.writeCommand('DEAD', @obj.updateDeadBandCallback);
       end
       
       %Sets the joystick deadband. Undocumented. Returns Ack.
       function setDeadBand(obj, val)
          assert(isnumeric(val), 'Deadband value must be numeric!');
          assert(~isnan(val), 'Deadband value can''t be nan!');
          assert(~isinf(val), 'Deadband value can''t be inf!');
          cmd = sprinft('DEAD %d', val);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %Returns a decimal value relating to the ID of the card which is
       %determined by the rotary switch on the rack it is connected to and
       %not the card itself.
       function updateID(obj)
           obj.writeCommand('ID', @obj.updateIDCallback);
       end
       
       % This puts the card into programming mode ready for firmware
       % updates. This is to be used with EXTREME caution. Hide?. Card will
       % need to be power cycled in order to exit this mode.
       function enterProgramMode(obj)
          warning('This function enables programming mode! This will allow you to reprogram the Scientifica MICU control card! USE WITH EXTREME CAUTION OR IMMEDIATELY POWER CYCLE YOUR CONTROLLER!');
          obj.writeCommand('PROG', @obj.ProgramModeCallback);
       end
       
       % This command changes the function when the goto command is sent
       % from the joystick or control software. It may be followed by any
       % of the commands and that command will replace the existing
       % functionality. Returns Ack.
       function remapGOTO(obj, arg)
          assert(ischar(arg), 'Command argument must be a character');
          obj.gotoRemap = arg;
          cmd = sprintf('REGOTO %s', arg);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %This command is used to change the function when the save command
       %is sent from the joystick or control software. It may be followed
       %by any valid command and that command will replace the existing
       %functionality.
       function remapSAVE(obj, arg)
          obj.saveRemap = arg;
          cmd = sprintf('RESAVE %s', arg);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       %Restores the default vales for speed, current, posistion and resets
       %the controller. 
       function reset(obj)
          obj.writeCommand('RESET', @obj.doNothing);
       end
       
       %Returns a decimal value relating to the status of the card as per
       %the following table:
       % 0 - Motors Idle
       % 1 - Start Speed (point to point moves)
       % 2 - Acceleration (point to point moves)
       % 3 - Max Speed (point to point moves)
       % 4 - Deceleration (point to point moves)
       % 5 - Stopping (point to point moves)
       % 6 - Input Device Moves (point to point moves)
       % 7 - Constant Velocity Moves (point to point moves)
       function v = get.motorStatus(obj) % Might need to make this faster?
          lut = obj.motorStatus_ut;
          obj.writeCommand('S', @obj.getStatusCallback);
          
          startedWaiting = tic;
           
           while lut == obj.motorStatus_ut
               pause(0.1)
               if toc(startedWaiting) > 5
                   error('Timed out waiting for motor status update')
               end
           end
          v = obj.motorStatus_;
       end
       
       function set.motorStatus(obj, v)
          % No Op - Can not set motor status. 
       end
       
       % Returns the UMS focus speed scaling as a value between 1 and 10
       function updateUMS(obj)
          obj.writeCommand('ZSCALE', @obj.updateUMSCallback);
       end
       
       % Sets the UMS focus speed scaling. Value must be decimale between 1
       % and 10. Returns ACK.
       function setUMS(obj, val)
          assert(isnumeric(val), 'Value must be numeric for UMS Scale!');
          assert(~isnan(val), 'Value for UMS Scale can not be nan!');
          assert(~isinf(val), 'Value for UMS scale can not be inf!');
          assert(~(val < 1), 'UMS scale value can not be < 1');
          assert(~(val > 10), 'UMS Scale value can not be > 10');
          cmd = sprintf('ZSCALE %d', val);
          obj.writeCommand(cmd, @obj.doNothing);
       end
       
       % Sets teh baud rate of the controller to either 9600 or 38400 by
       % entering either 96 or 38 respectively. Returns Ack.
       function setBaudRate(obj, baud)
          assert(isnumeric(baud), 'Baud rate must be numeric!');
          assert(~isnan(baud), 'Commanded baud rate is nan!');
          assert(~isinf(baud), 'Commanded baud rate is inf!');
          assert(baud == 96 || baud == 38, 'Invalid baud! Baud must either be 96 for 9600 or 38 for 38400!');
          cmd = sprintf('BAUD %d', baud);
          if baud == 38
              obj.currentBaud = 38400;
          elseif baud == 96
              obj.currentBaud = 9600;
          else
              obj.currentBaud = obj.currentBaud;
          end
          obj.writeCommand(cmd, @obj.setBaudRateCallback);
       end
   end
   
   %% Internal Commands
   methods
       
       % Framework borrowed from other serial controllers. Used to send
       % serial commands in a controlled non-blocking fashion for error
       % mitigation. 
       
       % Function to fire if serial command results in a response
       function replyAvailable(obj,~,~)
           try
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
       
       % Function to fire if serial command does not respond withing time
       % limit
       function TimeoutFcn(obj, ~,~,~,~)
            if obj.hSerial.BytesAvailable
                obj.replyAvailable();
            else
                stop(obj.TimeoutTimer);
                most.idioms.warn(['Timeout occurred while waiting for reply to ''' obj.lastCmd ''' cmd from Scientifica MICU']);
                obj.replyPending = false;
                obj.lastCmd = '';
                pause(obj.SERIAL_TIMEOUT);
                flushinput(obj.hSerial);
                
                % send next command in commandQueue
                obj.sendNextCmd(obj);
           end
       end
       
       % Function to send serial commands and callbacks to uniquely handle
       % the reponse from those commands to a queue for writing to device.
       function writeCommand(obj, cmd, callback)
            assert(isa(cmd,'char'));
           
            obj.commandQueue{end + 1} = {cmd, callback};
            obj.sendNextCmd();
       end
       
       % Function to write serial commands to device if no previous
       % command has a pending reply and their are commands in the queue.
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
                    obj.replyPending = true;
                end
            end
       end
       
       %% Callback functions to process serial response
       % Consider consolidating these into a single response callback.
       function axisPositionCallback(obj,reply)
           
           reply = strsplit(reply);
           reply = [str2double(reply{1}) str2double(reply{2}) str2double(reply{3})];
           obj.axisPosition_ = reply;
           obj.axisPosition_ut = tic;
           
       end
       
       function reverseFlagCallback(obj, reply)
           switch obj.lastCmd
               case 'JDX ?'
                   obj.revXFlag = logical(str2double(reply));
               case 'JDY ?'
                   obj.revYFlag = logical(str2double(reply));
               case 'JDZ ?'
                   obj.revZFlag = logical(str2double(reply));
               otherwise
                   
           end
           obj.joystickReverseFlags = [obj.revXFlag, obj.revYFlag, obj.revZFlag];
       end
       
       function userUnitsCallback(obj, reply)
           switch obj.lastCmd
               case 'UUX'
                   obj.multX = str2double(reply);
               case 'UUY'
                   obj.multY = str2double(reply);
               case 'UUZ'
                   obj.multZ = str2double(reply);
               otherwise   
           end
           obj.axisMultipliers = [obj.multX obj.multY obj.multZ];
       end
       
       function updateAccCallback(obj, reply)
           obj.accX = (250*str2double(reply))/obj.multX;
           obj.accY = (250*str2double(reply))/obj.multY;
           obj.accZ = (250*str2double(reply))/obj.multZ;
           obj.acceleration = [obj.accX obj.accY obj.accZ];
       end
       
       function updateStartSpeedCallback(obj, reply)
           obj.startSpeedX = str2double(reply)/(2*obj.multX);
           obj.startSpeedY = str2double(reply)/(2*obj.multY);
           obj.startSpeedZ = str2double(reply)/(2*obj.multZ);
           obj.startSpeeds = [obj.startSpeedX obj.startSpeedY obj.startSpeedZ];
       end
       
       function updateControlAccCallback(obj, reply)
           obj.controlAcceleration = str2double(reply);
       end
       
       function updateJoystickSpeedScalingCallback(obj,reply)
           obj.joystickSpeedScale = str2double(reply);
       end
       
       function updateJoystickSlowSpeedScalingCallback(obj, reply)
           obj.joystickSlowSpeedScale = str2double(reply);
       end
       
       function updateTopSpeedCallback(obj, reply)
           obj.topSpeedSetting = str2double(reply);
       end
       
       function updateLimitSwitchCallback(obj, reply)
           bin = most.util.hex2bin(reply);
           zBin = [bin(1) bin(2)];
           yBin = [bin(3) bin(4)];
           xBin = [bin(5) bin(6)];
           
           switch xBin
               case '00'
                   obj.xLimSwitchStatus = 'None';
               case '01'
                   obj.xLimSwitchStatus = 'Low';
               case '10'
                   obj.xLimSwitchStatus = 'High';
               case '11'
                   obj.xLimSwitchStatus = 'Both';
               otherwise
           end
           
           switch yBin
               case '00'
                   obj.yLimSwitchStatus = 'None';
               case '01'
                   obj.yLimSwitchStatus = 'Low';
               case '10'
                   obj.yLimSwitchStatus = 'High';
               case '11'
                   obj.yLimSwitchStatus = 'Both';
               otherwise
           end
           
           switch zBin
               case '00'
                   obj.zLimSwitchStatus = 'None';
               case '01'
                   obj.zLimSwitchStatus = 'Low';
               case '10'
                   obj.zLimSwitchStatus = 'High';
               case '11'
                   obj.zLimSwitchStatus = 'Both';
               otherwise
           end
           
           obj.limSwitchStatus = {obj.xLimSwitchStatus, obj.yLimSwitchStatus, obj.zLimSwitchStatus};
       end
       
       function updateHighLimitCallback(obj, reply)
          obj.highLimit = str2double(reply); 
       end
       
       function updateLowLimitCallback(obj, reply)
          obj.lowLimit = str2double(reply); 
       end
       
       function updateLimitSwitchMdeCallback(obj,reply)
          obj.limitSwitchOprationMode = str2double(reply); 
       end
       
       function updateHomeTypeCallback(obj,reply)
          obj.homeType = str2double(reply); 
       end
       
       function updateHomeOffsetCallback(obj, reply)
           reply = strsplit(reply);
           obj.homeOffset = [str2double(reply{1}) str2double(reply{2}) str2double(reply{3})];
       end
       
       function updateCurrentCallback(obj, reply)
           reply = strsplit(reply);
           obj.Current = [str2double(reply{1}) str2double(reply{2})];
       end
       
       function updateStageTypeCallback(obj, reply)
          obj.stageTypeNum = str2double(reply); 
       end
       
       function updateDescCallback(obj, reply)
           obj.Description = reply;
       end
       
       function updateRotaryMappingCallback(obj, reply)
          obj.rotaryMapping = str2double(reply); 
       end
       
       function getLinearSensorValsCallback(obj, reply)
           reply = strsplit(reply);
           obj.linearSensorVals_ = [str2double(reply{1}) str2double(reply{2}) str2double(reply{3}) str2double(reply{4})];
           obj.linearSensorVals_ut = tic;
       end
       
       function getApproachAngleCallback(obj, reply)
           obj.approachAngle_ = str2double(reply);
           obj.approachAngle_ut = tic;
       end
       
       function getApproachEnabledCallback(obj, reply)
          obj.approachEnabled = str2double(reply);
       end
       
       function updateFirmwareCallback(obj, reply)
           switch obj.lastCmd
               case 'DATE'
                   reply = strsplit(reply, '\t');
                   obj.firmwareDate = reply;
               case 'VER'
                   obj.firmware = str2double(reply);
               otherwise
           end
       end
       
       function updateDeadBandCallback(obj,reply)
          obj.deadBand = str2double(reply); 
       end
       
       function updateIDCallback(obj, reply)
           % Documentation says it returns a single deccimal value. 
           % Experiments show it return 'ID = #'.
           reply = strsplit(reply);
           obj.ID = str2double(reply{end});
       end
       
       function ProgramModeCallback(obj, reply)
          fprintf('\n%s\n\n',reply); 
       end
       
       function getStatusCallback(obj, reply)
          obj.motorStatus_ = str2double(reply); 
          obj.motorStatus_ut = tic;
       end
       
       function updateUMSCallback(obj, reply)
          obj.UMSscale = str2double(reply); 
       end
       
       function setBaudRateCallback(obj, ~)
          obj.hSerial.BaudRate = obj.currentBaud; 
       end
       
       % Call back function for when serial reponse is unimportant.
       function doNothing(obj, ~, ~, ~)
          % No Op. 
       end
       
   end
   
end

%--------------------------------------------------------------------------%
% MICU.m                                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
