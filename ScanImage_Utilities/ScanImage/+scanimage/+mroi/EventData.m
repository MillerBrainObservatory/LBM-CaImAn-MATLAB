 classdef EventData < event.EventData
     
    properties
        changeType;
        propertyName;
        oldValue;
        newValue;
        srcObj;
        srcObjParent;
    end
    
    methods
        function obj = EventData(srcObj, changeType, propertyName, oldValue, newValue, srcObjParent)
            obj.changeType = changeType;
            obj.srcObj = srcObj;
            obj.propertyName = propertyName;
            obj.oldValue = oldValue;
            obj.newValue = newValue;
            
            if nargin > 5
                obj.srcObjParent = srcObjParent;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% EventData.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
