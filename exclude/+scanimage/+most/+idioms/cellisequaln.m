function result=cellisequaln(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)= isequaln(a{i},b{i});
    end
end



%--------------------------------------------------------------------------%
% cellisequaln.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
