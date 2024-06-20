function s = thor_mcm6000

s = struct();
s.Names = {'mcm6000' 'thorlabs.mcm6000'};
s.Class = 'dabs.thorlabs.MCM6000';
s.ListName = 'Thorlabs MCM6000';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;

%--------------------------------------------------------------------------%
% thor_mcm6000.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
