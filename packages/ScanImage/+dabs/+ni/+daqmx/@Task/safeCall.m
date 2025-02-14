function ok = safeCall(errCode)
%SAFECALL Utility function for calls to DAQmx driver, displaying error information if error is encountered

persistent dummyString
if isempty(dummyString)
    dummyString = repmat('a',[1 512]);
end
if errCode
    [err,errString] = calllib(dabs.ni.daqmx.System.driverLib,'DAQmxGetErrorString',errCode,dummyString,length(dummyString));
    most.idioms.dispError('DAQmx ERROR: %s\n', errString);
    ok = false; %
else
    ok = true; %No error
end
end





%--------------------------------------------------------------------------%
% safeCall.m                                                               %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
