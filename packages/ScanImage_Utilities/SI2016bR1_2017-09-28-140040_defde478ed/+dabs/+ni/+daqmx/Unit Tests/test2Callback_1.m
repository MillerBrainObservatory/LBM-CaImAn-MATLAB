function test1Callback_1()
global CBDATA

'yo'
CBDATA.count = CBDATA.count + 1;


idx = 1;
%%%Put this section in, if using 2 tasks...need this for demo purposes, until we implement passing the task handle as an argument to callback
if ~mod(CBDATA.count,2)
    idx = 2;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
task = CBDATA.task(idx);
everyNSamples = CBDATA.everyNSamples(idx);

disp(['Visit #' num2str(CBDATA.count) ' to callback']);

[sampsRead, outputData] = readAnalogData(task, everyNSamples, everyNSamples, 'native', 2);
disp(['Read ' num2str(sampsRead) ' samples into a ' num2str(size(outputData,1)) ' X ' num2str(size(outputData,2)) ' matrix of CLASS ''' class(outputData) '''']);
% sampsRead = readAnalogData(CBDATA.task, CBDATA.everyNSamples, CBDATA.everyNSamples, 'scaled', 2);
% disp(['Read ' num2str(sampsRead) ' samples']);

assignin('base','outputData',outputData);




end



%--------------------------------------------------------------------------%
% test2Callback_1.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
