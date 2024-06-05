function s = prior_proscan3

s = struct();
s.Names = {'proscan3' 'prior.proscan3' 'prior.proscaniii' 'prior.ProScan3' 'prior.ProScanIII'};
s.Class = 'dabs.prior.proscan3.LinearStageController';
s.ListName = 'Prior ProScan III';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% prior_proscan3.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
