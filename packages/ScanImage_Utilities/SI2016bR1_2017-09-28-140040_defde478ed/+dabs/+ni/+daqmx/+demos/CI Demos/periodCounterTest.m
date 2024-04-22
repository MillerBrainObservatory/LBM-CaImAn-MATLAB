import dabs.ni.daqmx.*

ctrValues = [];

hNext = nextTrigInit();

hCtr = Task('Period counter');
hCtr.createCIPeriodChan('Dev3',0);
hCtr.cfgImplicitTiming('DAQmx_Val_ContSamps');


hCtr.start();
hNext.go(); %first pulse


periodValues = [1:10 30];

for i=1:length(periodValues);
    pause(periodValues(i));
    hNext.go();
    ctrValues(end+1) = hCtr.readCounterDataScalar();
    fprintf(1,'Read period value: %g\n',ctrValues(end));
end

delete(hCtr);
delete(hNext);


%--------------------------------------------------------------------------%
% periodCounterTest.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
