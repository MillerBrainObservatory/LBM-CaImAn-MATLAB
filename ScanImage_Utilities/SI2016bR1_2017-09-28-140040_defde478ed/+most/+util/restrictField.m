function snew = restrictField(s,flds)
% snew = restrictField(s,flds)
% Restrict fields of structure s to those in the cellstr flds. The fields
% of snew are the intersection of the fields of s and flds.

assert(isstruct(s));
assert(iscellstr(flds));

fldsToRemove = setdiff(fieldnames(s),flds);
snew = rmfield(s,fldsToRemove);

end


%--------------------------------------------------------------------------%
% restrictField.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
