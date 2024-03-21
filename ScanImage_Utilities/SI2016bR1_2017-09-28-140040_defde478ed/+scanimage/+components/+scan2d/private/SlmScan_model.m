%% SlmScan
slmType = '';   % one of {'dummy','generic','meadowlark.ODP'}

linearScannerName = '';             % Name of galvo-galvo-scanner (from first MDF section) to use in series with the SLM. Must be a linear scanner
deviceNameAcq   = 'PXI1Slot3';      % String identifying NI DAQ board for PMT channels input
deviceNameAux   = 'PXI1Slot3';      % String identifying NI DAQ board where digital triggers are wired

channelIDs = [];                    % Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)
channelsInvert = false;             % Scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels

slmUpdateTriggerInputTerm = '';     % Terminal on aux device, to which the SLM updated trigger is connected (e.g. 'PFI1'). Leave empty if SLM does not provide this trigger.
slmUpdateTriggerPolarity = 'rising';% Trigger polarity of the SLM updated trigger one of {'rising','falling'}

shutterIDs = [];                    % Array of the shutter IDs that must be opened for linear scan system to operate
beamDaqID  = [];                    % Numeric: ID of the beam DAQ to use with the linear scan system

focalLength = 100;                  % [mm] Effective focal length of the optical path
zeroOrderBlockRadius = 0.1;         % [mm] Radius of area at center of SLM FOV that cannot be excited, usually due to presence of zero-order beam block

parkPosition = [0 0 0];             % [x,y,z] SLM park position in microns
staticOffset = [0 0 0];             % [x,y,z] Offset applied to SLM coordinates in microns