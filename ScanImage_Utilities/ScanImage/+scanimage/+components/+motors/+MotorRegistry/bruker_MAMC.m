function s = bruker_MAMC

s = struct();
s.Names = {'bruker.MAMC' 'bruker.mamc' 'mamc' 'MAMC'};
s.Class = 'dabs.bruker.MAMC';
s.ListName = 'Bruker MAMC';
s.SupportFastZ = false;
s.SubType = '';
s.TwoStep.Enable = false; 
s.SafeReset = true;
s.NumDimensionsPreset = true;

%--------------------------------------------------------------------------%
% bruker_MAMC.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
