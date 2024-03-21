function s = scientifica

s = struct();
s.Names = {'scientifica'};
s.Class = 'dabs.scientifica.LinearStageController';
s.ListName = 'Scientifica';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = true;
s.TwoStep.FastLSCPropVals = struct(); %Velocity is switched between fast/slow, but determined programatically for each stage type
s.TwoStep.SlowLSCPropVals = struct(); %Velocity is switched between fast/slow, but determined programatically for each stage type
s.TwoStep.InitSlowLSCProps = false;
s.SafeReset = false;
s.NumDimensionsPreset = true;


%--------------------------------------------------------------------------%
% scientifica.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
