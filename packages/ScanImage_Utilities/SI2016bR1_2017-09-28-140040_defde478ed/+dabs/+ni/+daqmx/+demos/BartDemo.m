function BartDemo()

%%%%EDIT IF NEEDED%%%%
devName = 'PXI1Slot3';
aiChans = 0:2;
sampRate = 1000;
everyNSamples = 2000;
acqTime=10; %seconds
%%%%%%%%%%%%%%%%%%%%%%

import dabs.ni.daqmx.*

hTask = Task('Bart Task1');
hTask.createAIVoltageChan(devName,aiChans);

hTask.cfgSampClkTiming(sampRate,'DAQmx_Val_ContSamps');

hTask.registerEveryNSamplesEvent(@BartCallback,everyNSamples);

hTimer = timer('StartDelay',acqTime,'TimerFcn',@timerFcn);

hTask.start();
start(hTimer);

    function BartCallback(~,~)
        persistent hFig
        
        if isempty(hFig)
            hFig = figure;
        end       
        
        d = hTask.readAnalogData(everyNSamples);
        figure(hFig);
        plot(d);
        drawnow expose;                
    end

    function timerFcn(~,~)
        hTask.stop();
        delete(hTask); 
        delete(hTimer);
        disp('All done!');
    end
end




%--------------------------------------------------------------------------%
% BartDemo.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
