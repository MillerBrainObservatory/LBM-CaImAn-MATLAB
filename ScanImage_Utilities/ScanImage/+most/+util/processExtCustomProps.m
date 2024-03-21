function out = processExtCustomProps(proplist)
    assert(iscell(proplist), 'List must be a cell array');
    tempBuf = [];
    for i = 1:length(proplist)
       if  isstruct(proplist{i})
           tempBuf = [tempBuf most.util.structOrObj2Assignments(proplist{i},[],[])];
       elseif ischar(proplist{i})
           tempBuf = [tempBuf [proplist{i} sprintf('\n')]];
       end
    end
    out = tempBuf;
end

%--------------------------------------------------------------------------%
% processExtCustomProps.m                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
