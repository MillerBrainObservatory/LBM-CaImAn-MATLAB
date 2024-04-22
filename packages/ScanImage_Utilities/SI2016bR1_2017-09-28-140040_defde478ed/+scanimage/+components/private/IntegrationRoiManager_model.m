%% IntegrationRoiOutputs
channelNames = {};                      % User defined name for each output channels e.g. {'My first channel','My second channel','My third channel'}
deviceNames = {};                       % Names of DAQ device for each channel, use 'none' if no physical device is used e.g. {'Dev1','Dev1','none'}
deviceChannels = {};                    % Channel index for each channel: numeric values for analog outputs, strings for digital outputs, use 'none' for software output; e.g {0, 'port0/line0', 'none'} for AO0, port0/line0 and a software output