%% ScanImage

%Global microscope properties
objectiveResolution = 15;           % Resolution of the objective in microns/degree of scan angle

%Scanner systems
scannerNames = {'ResScanner'};      % Cell array of string names for each scan path in the microscope
scannerTypes = {'Resonant'};        % Cell array indicating the type of scanner for each name. Current options: {'Resonant' 'Linear' 'SLM'}

%Simulated mode
simulated = false;                  % Boolean for activating simulated mode. For normal operation, set to 'false'. For operation without NI hardware attached, set to 'true'.

%Optional components
components = {};                    % Cell array of optional components to load. Ex: {'dabs.thorlabs.ECU1' 'dabs.thorlabs.BScope2'}

%Data file location
dataDir = '[MDF]\ConfigData';       % Directory to store persistent configuration and calibration data. '[MDF]' will be replaced by the MDF directory
