%% LinScan
deviceNameAcq   = 'PXI1Slot3';      % string identifying NI DAQ board for PMT channels input
deviceNameGalvo = 'PXI1Slot3';      % string identifying NI DAQ board for controlling X/Y galvo. leave empty if same as deviceNameAcq
deviceNameAux   = 'PXI1Slot3';      % string identifying NI DAQ board for outputting clocks. leave empty if unused. Must be a X-series board

%Optional
channelsInvert = false;             % scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels
beamDaqID = [];                     % Numeric: ID of the beam DAQ to use with the linear scan system
shutterIDs = 1;                     % Array of the shutter IDs that must be opened for linear scan system to operate

referenceClockIn = '';              % one of {'',PFI14} to which 10MHz reference clock is connected on Aux board. Leave empty for automatic routing via PXI bus
enableRefClkOutput = false;         % Enables/disables the export of the 10MHz reference clock on PFI14

%Acquisition
channelIDs = [];                    % Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)

%Scanner position feedback
deviceNameGalvoFeedback = '';       % string identifying NI DAQ board that reads the galvo position feedback signals. Leave empty if they are on deviceNameGalvo. Cannot be the same as deviceNameAcq when using for line scanning
XMirrorPosChannelID = [];           % The numeric ID of the Analog Input channel to be used to read the X Galvo position (optional).
YMirrorPosChannelID = [];           % The numeric ID of the Analog Input channel to be used to read the y Galvo position (optional).

%Scanner control
XMirrorChannelID = 0;               % The numeric ID of the Analog Output channel to be used to control the X Galvo.
YMirrorChannelID = 1;               % The numeric ID of the Analog Output channel to be used to control the y Galvo.

xGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for x galvo
yGalvoAngularRange = 15;            % max range in optical degrees (pk-pk) for y galvo

voltsPerOpticalDegreeX = 1;         % galvo conversion factor from optical degrees to volts (negative values invert scan direction)
voltsPerOpticalDegreeY = 1;         % galvo conversion factor from optical degrees to volts (negative values invert scan direction)

scanParkAngleX = -7.5;              % Numeric [deg]: Optical degrees from center position for X galvo to park at when scanning is inactive
scanParkAngleY = -7.5;              % Numeric [deg]: Optical degrees from center position for Y galvo to park at when scanning is inactive

%Optional: mirror position offset outputs for motion correction
deviceNameOffset = '';              % string identifying NI DAQ board that hosts the offset analog outputs
XMirrorOffsetChannelID = 0;         % numeric ID of the Analog Output channel to be used to control the X Galvo offset.
YMirrorOffsetChannelID = 1;         % numeric ID of the Analog Output channel to be used to control the y Galvo offset.

XMirrorOffsetMaxVoltage = 1;        % maximum allowed voltage output for the channel specified in XMirrorOffsetChannelID
YMirrorOffsetMaxVoltage = 1;        % maximum allowed voltage output for the channel specified in YMirrorOffsetChannelID
