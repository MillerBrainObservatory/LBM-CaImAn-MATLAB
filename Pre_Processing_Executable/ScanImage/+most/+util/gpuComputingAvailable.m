function [tf,gpu] = gpuComputingAvailable()
tf = false;
gpu = [];

v = ver();
toolboxinstalled = any(strcmpi('Parallel Computing Toolbox',{v.Name}));

if toolboxinstalled && gpuDeviceCount > 0
    try
        gpu = gpuDevice();
        tf = true;
    catch ME
        most.idioms.warn('Initializing GPU failed');
        most.idioms.reportError(ME);
    end
end
end


%--------------------------------------------------------------------------%
% gpuComputingAvailable.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
