function s = thor_mcm5000

s = struct();
s.Names = {'mcm5000' 'thorlabs.mcm5000'};
s.Class = 'dabs.thorlabs.MCM5000';
s.ListName = 'Thorlabs MCM5000';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% thor_mcm5000.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
