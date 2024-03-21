function s = zaber_multidevice
s = struct();
s.Names = {'multidevice' 'zaber.multidevice'};
s.Class = 'dabs.zaber.MultiDevice';
s.ListName = 'Zaber MultiDevice';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false;
s.SafeReset = true;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% zaber_multidevice.m                                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
