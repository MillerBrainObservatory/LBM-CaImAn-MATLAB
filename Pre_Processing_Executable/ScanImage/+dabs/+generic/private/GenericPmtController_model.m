%% GenericPmtController
pmtNames = {'Green' 'Red'};                                 % cell array of names for PMTs e.g.

pmtDaqDeviceName = {'Dev1' 'Dev1'};                         % cell array of NI-DAQ devices to control each PMT channel. If only one device is given, all channels will be mapped onto that one device
pmtDaqGainAOChannels = [0 1];                               % <optional> array of numeric analog output channel IDs to control the gain for each PMT; if set to empty array, functionality is disabled
pmtDaqPowerDOChannels = {'port0/line0' 'port0/line3'};      % <optional> cell array of strings specifying the digital port name to switch each PMT on/off; if set to empty cell array, functionality is disabled
pmtDaqTrippedDIChannels = {'port0/line1' 'port0/line4'};    % <optional> cell array of strings specifying the digital port name to detect the trip status for each PMT; if set to empty cell array, functionality is disabled
pmtDaqTripResetDOChannels = {'port0/line2' 'port0/line5'};  % <optional> cell array of strings specifying the digital port name to reset the trip status for each PMT; if set to empty cell array, functionality is disabled

pmtDaqAOVoltageRange = {[0 5],[0 5]};                       % <required if pmtDaqGainAOChannels is defined> cell array of 1x2 numeric array specifying the minimum and maximum analog output voltage on the NI-DAQ board that controls the PMT gain. If only one numeric array is given, this value is used for all PMT channels
pmtMaxGainValue = [1250 1250];                              % <required if pmtDaqGainAOChannels is defined> array specifying the maximum display value for the PMT gain. If only one value is given, this value is used for all PMT channels