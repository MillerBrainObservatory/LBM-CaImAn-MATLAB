function result=cellisequal(a,b)
    result=false(size(a));
    for i=1:numel(a) ,
        result(i)= isequal(a{i},b{i});
    end
end


%--------------------------------------------------------------------------%
% cellisequal.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
