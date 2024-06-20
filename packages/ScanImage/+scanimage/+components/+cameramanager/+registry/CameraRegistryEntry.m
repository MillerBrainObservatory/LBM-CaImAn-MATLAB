classdef CameraRegistryEntry
    properties
        prettyNames = {};
        class = '';
        classConstructor = function_handle.empty(0,1);
    end
    
    methods
        function obj = CameraRegistryEntry(prettyNames,class)
            obj.prettyNames = prettyNames;
            obj.class = class;
        end
    end
    
    % Property Getter/Setter
    methods
        function obj = set.prettyNames(obj,val)
            assert(iscellstr(val) && ~isempty(val) && isrow(val), ...
                'Pretty Names must be a cell array of strings');
            obj.prettyNames = val;
        end
        
        function obj = set.class(obj,val)
            validateattributes(val,{'char'},{'row'});
            assert(logical(exist(val,'class')),'%val is not a valid class name',val);
            obj.class = val;
        end
        
        function val = get.classConstructor(obj)
            if isempty(obj.class)
                val = function_handle.empty(0,1);
            else
                val = str2func(obj.class);
            end
        end
    end
end


%--------------------------------------------------------------------------%
% CameraRegistryEntry.m                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
