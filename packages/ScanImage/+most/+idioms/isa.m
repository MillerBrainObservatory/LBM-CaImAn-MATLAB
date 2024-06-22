function tf = isa(obj,ClassName)
    if ischar(obj)
        assert(logical(exist(obj,'class')),'''%s'' is not a valid class name',obj),
        mc = meta.class.fromName(obj);
        tf = strcmp(mc.Name,ClassName);
        
        if ~tf
            for idx = 1:numel(mc.SuperclassList)
                tf = tf || most.idioms.isa(mc.SuperclassList(idx).Name,ClassName); % call recursively
            end
        end
    else 
        tf = isa(obj,ClassName);
    end
end

%--------------------------------------------------------------------------%
% isa.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
