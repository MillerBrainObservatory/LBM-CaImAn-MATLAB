function s = vertcatfields(X)
    % Returns a single structure that concatenates each field of the
    % structures in the structure array X.
    
    assert(isa(X, 'struct'),'X must be a structure array.')
    
    s = X(1);
    fields = fieldnames(s);
    
    for i = 1:numel(fields)
       s.(fields{i}) = vertcat(X.(fields{i}));
    end
end


%--------------------------------------------------------------------------%
% vertcatfields.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
