%% Thorlabs BScope2
scannerName = '';                   % Scanner name (from first MDF section) to link to. Must be a resonant scanner. Leave empty if not using a resonant scanner
ecuComPort = [];                    % Numeric: Serial COM port for ECU2 commands

galvoGalvoMirrorComPort = [];       % Numeric: Serial COM port for controlling Galvo-Galvo mirror. Leave empty is mirrors are connected to stage controller (MCM5000)
galvoResonantMirrorComPort = [];    % Numeric: Serial COM port for controlling Galvo-Resonant mirror. Leave empty is mirrors are connected to stage controller (MCM5000)
flipperMirrorComPort = [];          % Numeric: Serial COM port for controlling Flipper mirror. Leave empty is mirrors are connected to stage controller (MCM5000)

pmtDevAddresses = {[] [] [] []};     % Numeric serial number or string VISA addresses of USB PMT controllers. For each of 4 PMTs leave empty if controlled by ECU or enter address
