classdef SlmRegistry < scanimage.interfaces.Class
    
    properties (Constant, Hidden)
        slmMap = zlclInitSlmMap();
    end
    
    methods (Static)
        function info = getSlmInfo(type)
            assert(ischar(type),'''type'' must be a stage controller type.');
            m = scanimage.components.scan2d.slmscan.SlmRegistry.slmMap;
            
            type = lower(type);
            if m.isKey(type)
                info = m(type);
            else
                info = [];
            end
        end
    end
end

function m = zlclInitSlmMap
    m = containers.Map();
    
    s = struct();
    s.Names = {'dummy' 'simulated'};
    s.DisplayName = 'Simulated SLM';
    s.Class = 'dabs.simulated.SLM';
    zlclAddSlm(m,s);
    
    s = struct();
    s.Names = {'generic'};
    s.DisplayName = 'Generic Monitor SLM';
    s.Class = 'dabs.generic.GenericSLM';
    zlclAddSlm(m,s);
    
    list = what('scanimage/components/scan2d/slmscan/SlmRegistry');
    if numel(list)
        assert(numel(list)<2,'Multiple SLM registries found on path. Make sure only one scanimage installation is on the path.');
        
        [~,list] = cellfun(@fileparts,list.m,'UniformOutput',false);
        list = strcat('scanimage.components.scan2d.slmscan.SlmRegistry.',list);
        for i = 1:numel(list)
            mtr = eval(list{i});
            zlclAddSlm(m,mtr);
        end
    else
        most.idioms.warn('SLM registry not found.');
    end
end

function zlclAddSlm(m,s)
    names = s.Names;
    for c = 1:length(names)
        m(lower(names{c})) = s;
    end
end


%--------------------------------------------------------------------------%
% SlmRegistry.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
