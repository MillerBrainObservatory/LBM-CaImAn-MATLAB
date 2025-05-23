function Voltage_Continuous_Output_Register_Event()
%% Continuous Voltage Output
% This examples demonstrates a continuous buffered analog output using the dabs.ni.daqmx adapter

%% Parameters for the output
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
physicalChannels = 0; % a scalar or an array with the channel numbers
minVoltage = -10;       % channel input range minimum
maxVoltage = 10;        % channel input range maximum

% Task configuration
sampleClockSource = 'OnboardClock'; % the terminal used for the sample Clock; refer to "Terminal Names" in the DAQmx help for valid values
sampleRate = 1000;                  % sample Rate in Hz
numberOfSamplesToWrite = 1000;       % number of samples to read in one loop iteration

% Trigger configuration
triggerType = 'DigEdgeStartTrig'; % one of {'DigEdgeStartTrig', 'AnlgEdgeStartTrig', 'None'}

% Parameters for digital triggering
dTriggerSource = 'PFI1';           % the terminal used for the digital trigger; refer to "Terminal Names" in the DAQmx help for valid values
dTriggerEdge = 'DAQmx_Val_Rising'; % one of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}

% Parameters for analog triggering
aTriggerSource = 'AI1';                  % channel to be monitored for the analog trigger
aTriggerLevel = 5;                       % analog trigger level
aTriggerSlope = 'DAQmx_Val_RisingSlope'; % one of {'DAQmx_Val_RisingSlope', 'DAQmx_Val_FallingSlope'}

outputData = linspace(0,10,numberOfSamplesToWrite); % generate data for output

import dabs.ni.daqmx.* % import the NI DAQmx adapter

try
    % create and configure the task
    hTask = Task('Task'); 
    hTask.createAOVoltageChan(devName,physicalChannels,[],minVoltage,maxVoltage);
    hTask.cfgSampClkTiming(sampleRate,'DAQmx_Val_ContSamps',numberOfSamplesToWrite,sampleClockSource);
    
    switch triggerType
        case 'DigEdgeStartTrig'
            hTask.cfgDigEdgeStartTrig(dTriggerSource,dTriggerEdge);
        case 'AnlgEdgeStartTrig'
            hTask.cfgAnlgEdgeStartTrig(aTriggerSource,aTriggerLevel,aTriggerSlope);
        case 'None'
            % do not configure trigger, start acquisition immediately
    end

    hTask.cfgOutputBuffer(2*numberOfSamplesToWrite);
    hTask.writeAnalogData(outputData, 5)
    hTask.start();

    %while task is generating, check for errors
    disp('Generating Output');
    for i = 0:9
        hTask.isTaskDone();
    	pause(0.5);
    end
    
    % clean up task 
    hTask.stop();
    delete(hTask);
    clear hTask;
    
    disp('Output Finished');
    
catch err % clean up task if error occurs
    if exist('hTask','var')
        delete(hTask);
        clear hTask;
    end
    rethrow(err);
end
end


%--------------------------------------------------------------------------%
% Voltage_Continuous_Output_Register_Event.m                               %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
