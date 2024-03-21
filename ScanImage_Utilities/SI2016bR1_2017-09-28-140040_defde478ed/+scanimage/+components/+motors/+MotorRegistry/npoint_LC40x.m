function s = npoint_LC40x

s = struct();
s.Names = {'npoint.lc40x' 'npoint.LC40x'};
s.Class = 'dabs.npoint.LinearStageController';
s.ListName = 'nPoint LC40x';
s.SupportFastZ = true;
s.SubType = 'LC40x';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% npoint_LC40x.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
