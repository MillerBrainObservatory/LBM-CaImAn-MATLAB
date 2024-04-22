function result = ismemberOfCellArray(A,B)
    % Like ismember(A,B), but assumes that A and B are cell arrays, and
    % that their elements should be compared after being accessed with {}.
    result=false(size(A));
    for i=1:numel(A) ,
        result(i)=isSingletonMemberOfCellArray(A{i},B);
    end
end

function result = isSingletonMemberOfCellArray(a,B)
    isMatch=cellfun(@(element)(element==a),B);
    result=any(isMatch);
end


%--------------------------------------------------------------------------%
% ismemberOfCellArray.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
