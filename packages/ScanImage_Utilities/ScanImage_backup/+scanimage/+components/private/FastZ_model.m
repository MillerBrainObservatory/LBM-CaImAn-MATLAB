%% FastZ
%FastZ hardware used for fast axial motion, supporting fast stacks and/or volume imaging

actuators(1).controllerType = '';           % If supplied, one of {'pi.e665', 'pi.e816', 'npoint.lc40x', 'analog'}.
actuators(1).comPort = [];                  % Integer identifying COM port for controller, if using serial communication
actuators(1).customArgs = {};               % Additional arguments to stage controller
actuators(1).daqDeviceName = '';            % String specifying device name used for FastZ control
actuators(1).frameClockIn = '';             % One of {PFI0..15, ''} to which external frame trigger is connected. Leave empty for automatic routing via PXI/RTSI bus
actuators(1).cmdOutputChanID = [];          % AO channel number (e.g. 0) used for analog position control
actuators(1).sensorInputChanID = [];        % AI channel number (e.g. 0) used for analog position sensing
actuators(1).commandVoltsPerMicron = .1;    % Conversion factor for desired command position in um to output voltage
actuators(1).commandVoltsOffset = 0;        % Offset in volts for desired command position in um to output voltage
actuators(1).sensorVoltsPerMicron = [];     % Conversion factor from sensor signal voltage to actuator position in um. Leave empty for automatic calibration
actuators(1).sensorVoltsOffset = [];        % Sensor signal voltage offset. Leave empty for automatic calibration
actuators(1).maxCommandVolts = [];          % Maximum allowable voltage command
actuators(1).maxCommandPosn = [];           % Maximum allowable position command in microns
actuators(1).minCommandVolts = [];          % Minimum allowable voltage command
actuators(1).minCommandPosn = [];           % Minimum allowable position command in microns
actuators(1).optimizationFcn = '';          % Function for waveform optimization
actuators(1).affectedScanners = {};         % If this actuator only changes the focus for an individual scanner, enter the name
