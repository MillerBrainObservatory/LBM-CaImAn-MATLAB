function hTask = ClockDivider()
deviceName = 'PXI1Slot3';
ctrNumber = 3;
clockSource = '/PXI1Slot3/PXI_CLK10';
outputTerminal = 'PFI14';
clkDivisor = 4;

assert(mod(clkDivisor,1)==0 && clkDivisor>=4,'Divisor must be an integer >= 4'); % lowTicks and highTicks must be >= 2

lowTicks = ceil(clkDivisor/2);
highTicks = floor(clkDivisor/2);

hTask = most.util.safeCreateTask('Clock Divider');
hTask.createCOPulseChanTicks(deviceName, ctrNumber, '', clockSource, lowTicks, highTicks);
hTask.channels(1).set('pulseTerm',outputTerminal);
hTask.channels(1).set('pulseTicksInitialDelay',2); % minimum of 2
hTask.cfgImplicitTiming('DAQmx_Val_ContSamps');

hTask.start();
end

%--------------------------------------------------------------------------%
% ClockDivider.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
