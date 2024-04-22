% this code was developed by Marius Pachitariu and Carsen Stringer as part of the software package Suite2p

function x = gather_try(x)

try
    x = gather(x);
catch
end

%--------------------------------------------------------------------------%
% gather_try.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
