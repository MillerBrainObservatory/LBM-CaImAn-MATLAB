classdef Heterogeneous < handle & matlab.mixin.Heterogeneous
    %Heterogeneous 
    
    methods (Sealed = true)
        % See method dispatching rules and heterogenous class arrays for why these
        % functions must be redefined as sealed.
        function out = ne(self, obj1)
            out = ne@handle(self, obj1);
        end
        function out = eq(self, obj1)
            out = eq@handle(self, obj1);
        end
    end
end


%--------------------------------------------------------------------------%
% Heterogeneous.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
