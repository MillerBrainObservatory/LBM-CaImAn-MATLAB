function DaqmxAsyncWriteDemo
    global hTask;
    global taskReadyForNewWrite;
    taskReadyForNewWrite = true;
    hTask = dabs.ni.daqmx.Task();
    hTask.createAOVoltageChan('Dev1',0);
    hTask.cfgSampClkTiming(1000,'DAQmx_Val_ContSamps');
    hTask.writeAnalogData(rand(10000,1),[],[],[]);
    hTask.start();
    
    hTimer = timer();
    hTimer.TimerFcn = @writeNewData;
    hTimer.Period = 0.5;
    hTimer.ExecutionMode = 'fixedSpacing';
    
    start(hTimer);
    assignin('base','hTimer',hTimer);
    assignin('base','hTask',hTask);
end

function writeNewData(src,evt)
    global taskReadyForNewWrite
    global hTask
    if taskReadyForNewWrite
       taskReadyForNewWrite = false;
       start = tic;
       hTask.writeAnalogDataAsync(rand(5000,1),[],[],[],@callback);
       fprintf('Timer is sending new data: (took %fs)\n',toc(start));
    end
end


function callback(src,evt)
    global taskReadyForNewWrite
    sampsWritten = evt.sampsWritten;
    status = evt.status;
    errorString = evt.errorString;
    extendedErrorInfo = evt.extendedErrorInfo;
    
    fprintf('Task %d refreshed %d samples\n',src.taskID,sampsWritten);
    if status
        fprintf(2,'writeAnalogData encountered an error: %d\n%s\n=============================\n%s\n',status,errorString,extendedErrorInfo);
    else
        taskReadyForNewWrite = true;
    end
end

%--------------------------------------------------------------------------%
% DaqmxAsyncWriteDemo.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
