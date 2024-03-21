function s = thor_mcm3000
s = struct();
s.Names = {'mcm3000' 'thorlabs.mcm3000'};
s.Class = 'dabs.thorlabs.MCM3000';
s.ListName = 'Thorlabs MCM3000';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% thor_mcm3000.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
