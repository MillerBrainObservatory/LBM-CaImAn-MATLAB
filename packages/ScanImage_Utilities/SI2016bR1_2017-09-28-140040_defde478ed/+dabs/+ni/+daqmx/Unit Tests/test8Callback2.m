function test8Callback2()
%   Function called at end of each iteration

global callbackStruct8

%Increment iteration counter
callbackStruct8.iterationCounter2 = callbackStruct8.iterationCounter2 + 1;

%Prepare the data for the next iteration, and start the tasks
if callbackStruct8.iterationCounter2 < callbackStruct8.numIterations
    
    %Stop the tasks -- this is needed so they can be restarted
    callbackStruct8.hCtr(2).stop()
    callbackStruct8.hAI(2).stop();
    callbackStruct8.hAO(2).stop();
    callbackStruct8.hDO(2).stop()
            
    %Determine which signal to draw from during this iteration
    signalIdx = mod(callbackStruct8.iterationCounter2-1,callbackStruct8.numSignals)+1;

    %Write AO data for rig 2 (signals are 2x wrt first)
    callbackStruct8.hAO(2).writeAnalogData(2*callbackStruct8.aoSignals{signalIdx});

    %Write DO data for 2 rigs; 2'nd rig signals are inverted wrt first 
    callbackStruct8.hDO(2).writeDigitalData(uint32(~callbackStruct8.doSignals{signalIdx}));
    
    %Start the tasks so they can await trigger. 
    callbackStruct8.hAI(2).start();
    callbackStruct8.hAO(2).start();
    callbackStruct8.hDO(2).start();
    callbackStruct8.hCtr(2).start()
    
end




%--------------------------------------------------------------------------%
% test8Callback2.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
