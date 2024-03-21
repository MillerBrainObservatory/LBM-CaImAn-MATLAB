function tf = transitArgumentTypeCheck(scanfield_from,scanfield_to)
from = isa(scanfield_from,'scanimage.mroi.scanfield.ScanField') || isnan(scanfield_from);
to   = isa(scanfield_to,'scanimage.mroi.scanfield.ScanField')   || isnan(scanfield_to);
bothempty = isempty(scanfield_from) && isempty(scanfield_to);
%bothnan = isnan(scanfield_from) && isnan(scanfield_to); %both nan is currently allowed
tf = from && to && ~bothempty; %&& ~bothnan;
end


%--------------------------------------------------------------------------%
% transitArgumentTypeCheck.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
