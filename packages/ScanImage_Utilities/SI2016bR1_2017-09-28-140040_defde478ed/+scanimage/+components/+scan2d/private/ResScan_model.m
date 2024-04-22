%% ResScan
nominalResScanFreq = 7910;          % [Hz] nominal frequency of the resonant scanner
beamDaqID = [];                     % Numeric: ID of the beam DAQ to use with the resonant scan system
shutterIDs = 1;                     % Array of the shutter IDs that must be opened for resonant scan system to operate

digitalIODeviceName = 'PXI1Slot3';  % String: Device name of the DAQ board or FlexRIO FPGA that is used for digital inputs/outputs (triggers/clocks etc). If it is a DAQ device, it must be installed in the same PXI chassis as the FlexRIO Digitizer

fpgaModuleType = 'NI7961';          % String: Type of FlexRIO FPGA module in use. One of {'NI7961' 'NI7975'}
digitizerModuleType = 'NI5732';     % String: Type of digitizer adapter module in use. One of {'NI5732' 'NI5734'}
rioDeviceID = 'RIO0';               % FlexRIO Device ID as specified in MAX. If empty, defaults to 'RIO0'
channelsInvert = false;             % Logical: Specifies if the input signal is inverted (i.e., more negative for increased light signal)

externalSampleClock = false;        % Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module
externalSampleClockRate = [];       % [Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA

enableRefClkOutput = false;         % Enables/disables the 10MHz reference clock output on PFI14 of the digitalIODevice

%Galvo mirror settings
galvoDeviceName = 'PXI1Slot3';      % String identifying the NI-DAQ board to be used to control the galvo(s). The name of the DAQ-Device can be seen in NI MAX. e.g. 'Dev1' or 'PXI1Slot3'. This DAQ board needs to be installed in the same PXI chassis as the FPGA board specified in section
galvoAOChanIDX = [];                % The numeric ID of the Analog Output channel to be used to control the X Galvo. Can be empty for standard Resonant Galvo scanners.
galvoAOChanIDY = 1;                 % The numeric ID of the Analog Output channel to be used to control the Y Galvo.

galvoAIChanIDX = [];                % The numeric ID of the Analog Input channel for the X Galvo feedback signal.
galvoAIChanIDY = [];                % The numeric ID of the Analog Input channel for the Y Galvo feedback signal.

xGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for x galvo if present
yGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for y galvo

galvoVoltsPerOpticalDegreeX = 1.0;  % galvo conversion factor from optical degrees to volts (negative values invert scan direction)
galvoVoltsPerOpticalDegreeY = 1.0;  % galvo conversion factor from optical degrees to volts (negative values invert scan direction)

galvoParkDegreesX = -8;             % Numeric [deg]: Optical degrees from center position for X galvo to park at when scanning is inactive
galvoParkDegreesY = -8;             % Numeric [deg]: Optical degrees from center position for Y galvo to park at when scanning is inactive

%Resonant mirror settings
resonantZoomDeviceName = '';        % String identifying the NI-DAQ board to host the resonant zoom analog output. Leave empty to use same board as specified in 'galvoDeviceName'
resonantZoomAOChanID = 0;           % resonantZoomAOChanID: The numeric ID of the Analog Output channel to be used to control the Resonant Scanner Zoom level.

resonantAngularRange = 15;          % max range in optical degrees (pk-pk) for resonant
rScanVoltsPerOpticalDegree = 0.33333333;  % resonant scanner conversion factor from optical degrees to volts

resonantScannerSettleTime = 0.5;    % [seconds] time to wait for the resonant scanner to reach its desired frequency after an update of the zoomFactor
