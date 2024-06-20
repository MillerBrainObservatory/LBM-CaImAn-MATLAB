classdef GenericPage < scanimage.guis.configuration.ConfigurationPage
    
    properties (Constant)
        modelClass = '';
    end
    
    methods
        function obj = GenericPage(hConfigEditor,heading)
            obj = obj@scanimage.guis.configuration.ConfigurationPage(hConfigEditor,false,true,heading);
        end
    end
end


%--------------------------------------------------------------------------%
% GenericPage.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
