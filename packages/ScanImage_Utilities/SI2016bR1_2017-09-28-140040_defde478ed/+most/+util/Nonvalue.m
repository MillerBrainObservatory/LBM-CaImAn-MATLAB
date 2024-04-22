classdef Nonvalue < double
    %most.app.Nonvalue  This is an enumeration with only one value.  If you
    %set a model property to this value, the convention is that the property will not be set
    %to this "nonvalue", but will retain its original value.  Thus the only affect of the set
    %will be to fire the PreSet and PostSet events.  This is often a useful
    %thing to do, especially in the context of property bindings, and
    %particularly for dependent properties.
    
    enumeration
        The (nan) % The only possible value
    end    
end


%--------------------------------------------------------------------------%
% Nonvalue.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
