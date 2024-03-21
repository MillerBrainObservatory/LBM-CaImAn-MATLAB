function [digitalLineStr, portNumber, lineNumber] = translateTriggerToPort(triggerLine)
    if ischar(triggerLine)
        assert(~isempty(regexpi(triggerLine,'^PFI[0-9]{1,2}$')),'triggerLine must be in the format ''PFI#''');
        [startIndex,endIndex] = regexp(triggerLine,'[0-9]+$');
        triggerLine = triggerLine(startIndex:endIndex);
        triggerNumber = str2double(triggerLine);
    else
        triggerNumber = triggerLine;
    end

    lineNumber = mod(triggerNumber,8);
    portNumber = floor(triggerNumber/8) + 1;
    digitalLineStr = sprintf('port%d/line%d',portNumber,lineNumber);
end


%--------------------------------------------------------------------------%
% translateTriggerToPort.m                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
