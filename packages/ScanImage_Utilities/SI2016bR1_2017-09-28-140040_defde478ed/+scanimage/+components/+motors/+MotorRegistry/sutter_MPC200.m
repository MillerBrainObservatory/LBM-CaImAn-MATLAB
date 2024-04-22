function s = sutter_MPC200

s = struct();
s.Names = {'mpc200' 'sutter.mpc200' 'sutter.MPC200'};
s.Class = 'dabs.sutter.MPC200';
s.ListName = 'Sutter MPC200';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false; 
%s.TwoStep.FastLSCPropVals = struct('resolutionMode','coarse');
%s.TwoStep.SlowLSCPropVals = struct('resolutionMode','fine');
s.SafeReset = false;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% sutter_MPC200.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
