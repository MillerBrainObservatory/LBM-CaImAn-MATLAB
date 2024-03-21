function coeff = getAITaskScalingCoefficients(hTask)
% Outputs a 4xN array with scalingcoefficients for each of the N Tasks
% such that f(X) = coeff(1,N)*X^0 + coeff(2,N)*X^1 + coeff(3,N)*X^2 + coeff(4,N)*X^3

% More information:
% Is NI-DAQmx Read Raw Data Calibrated and/or Scaled in LabVIEW?
% http://digital.ni.com/public.nsf/allkb/0FAD8D1DC10142FB482570DE00334AFB?OpenDocument

assert(isa(hTask.channels,'dabs.ni.daqmx.AIChan'),'hTask does not contain AI channels');
channelNames = arrayfun(@(ch)ch.chanName,hTask.channels,'UniformOutput',false);

numCoeff = 4;

coeff = zeros(numCoeff,numel(channelNames));
for idx = 1:length(channelNames)
    chName = channelNames{idx};
    a = zeros(numCoeff,1);
    ptr = libpointer('voidPtr',a);
    hTask.apiCallRaw('DAQmxGetAIDevScalingCoeff',hTask.taskID,chName,ptr,numCoeff);
    coeff(:,idx) = ptr.Value;
    ptr.delete();
end

end

%--------------------------------------------------------------------------%
% getAITaskScalingCoefficients.m                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
