function Counter_Measure_Pulse_Separation_Time()
%% On Demand Pulse Separation Measurement
% This examples demonstrates an on demand pulse separation measurement
% using the dabs.ni.daqmx adapter

%% Parameters for the acquisition
devName = 'Dev1'; % the name of the DAQ device as shown in MAX

% Channel configuration
ctrID = 0;                   % a scalar identifying the counter
sampleInterval = 1;          % sample interval in seconds

units = 'DAQmx_Val_Seconds'; % one of {'DAQmx_Val_Seconds' 'DAQmx_Val_Ticks' 'DAQmx_Val_FromCustomScale'}

minSeparation = 0.000001;   % The minimum value, in units, that you expect to measure.
maxSeparation = 0.100000;   % The maximum value, in units, that you expect to measure.

polarityFirstEdge = 'DAQmx_Val_Rising';     % one of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}
polaritySecondEdge = 'DAQmx_Val_Rising';    % one of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}

twoEdgeSepFirstTerm = 'PFI1';   % the terminal used for the input of the first pulse; refer to "Terminal Names" in the DAQmx help for valid values
twoEdgeSepSecondTerm = 'PFI2';  % the terminal used for the input of the second pulse; refer to "Terminal Names" in the DAQmx help for valid values


%% Perform the acquisition

import dabs.ni.daqmx.* % import the NI DAQmx adapter
try
    % create and configure the task
    hTask = Task('Task');
    hChannel = hTask.createCITwoEdgeSepChan(devName,ctrID,[], ...
        polarityFirstEdge,polaritySecondEdge,minSeparation,maxSeparation,units);
    
    % define the terminals for the two pulses to measure
    hChannel.set('twoEdgeSepFirstTerm',twoEdgeSepFirstTerm);
    hChannel.set('twoEdgeSepSecondTerm',twoEdgeSepSecondTerm);
        
    hTask.start();
    
    % read and display the edge separation time
    for i = 0:10
       data = hTask.readCounterDataScalar(10);
       disp(['Edge Separation: ' num2str(data)]);
       pause(sampleInterval);  % the read interval is determined by software
    end
    
    % clean up task 
    hTask.stop();
    delete(hTask);
    clear hTask;
    
    disp('Acquisition Finished');
    
catch err % clean up task if error occurs
    if exist('hTask','var')
        delete(hTask);
        clear hTask;
    end
    rethrow(err);
end
end


%--------------------------------------------------------------------------%
% Counter_Measure_Pulse_Separation_Time - Copy.m                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
