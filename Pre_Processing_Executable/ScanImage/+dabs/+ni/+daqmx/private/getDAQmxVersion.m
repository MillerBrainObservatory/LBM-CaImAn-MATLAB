function [majorVer,minorVer,updateVer] = getDAQmxVersion()
if libisloaded('nicaiu')
    unloadlibrary('nicaiu');
end

switch computer('arch')
    case 'win32'
        loadlibrary('nicaiu',@apiVersionDetect);
    case 'win64'
        loadlibrary('nicaiu',@apiVersionDetect64);
    otherwise
        error('NI DAQmx: Unknown computer architecture :%s',computer(arch));
end

[code,majorVer] = calllib('nicaiu','DAQmxGetSysNIDAQMajorVersion',0);
assert(code==0);
[code,minorVer] = calllib('nicaiu','DAQmxGetSysNIDAQMinorVersion',0);
assert(code==0);

if ismember('DAQmxGetSysNIDAQUpdateVersion',libfunctions('nicaiu'))
    [code,updateVer] = calllib('nicaiu','DAQmxGetSysNIDAQUpdateVersion',0);
else
    updateVer = 0;
end

unloadlibrary('nicaiu');
end


%--------------------------------------------------------------------------%
% getDAQmxVersion.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
