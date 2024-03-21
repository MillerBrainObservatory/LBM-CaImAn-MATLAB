classdef SerializeTester < most.Model
%     properties(SetObservable,Dependent)
%         data
%     end
    properties        
        R = scanimage.mroi.scanfield.fields.Rectangle([1 2 3 4]);
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct(); %struct('data',struct('Classes','uint8'));
        
        mdlHeaderExcludeProps = {};
    end
    
    methods 
%         function set.data(obj,val)
%             obj.R=scanimage.mroi.util.deserialize(val);
%         end
%         
%         function val=get.data(obj)
%             val=scanimage.mroi.util.serialize(obj.R);
%         end
    end
end


%--------------------------------------------------------------------------%
% SerializeTester.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
