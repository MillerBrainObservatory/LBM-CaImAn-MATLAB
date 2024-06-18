function [tf,gpu] = gpuComputingAvailable()
tf = false;
gpu = [];

toolboxinstalled = most.util.parallelComputingToolboxAvailable();

if toolboxinstalled && gpuDeviceCount > 0
    try
        startTic = tic();
        gpu = gpuDevice();
        tf = true;
        duration = toc(startTic);
        if duration > 5
            url = 'https://www.mathworks.com/matlabcentral/answers/309235-can-i-use-my-nvidia-pascal-architecture-gpu-with-matlab-for-gpu-computing';
            disp(['Note: The initialization of the GPU device seems is unusually slow. Please visit this <a href = "matlab:web(''' url ''',''-browser'')">Mathworks Forum thread</a> for a solution.';]);
        end
    catch ME
        most.idioms.warn('Initializing GPU failed');
        most.idioms.reportError(ME);
    end
end
end 

%--------------------------------------------------------------------------%
% gpuComputingAvailable.m                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
