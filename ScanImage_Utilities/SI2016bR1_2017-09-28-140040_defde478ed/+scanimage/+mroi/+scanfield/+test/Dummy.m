classdef Dummy < scanimage.mroi.scanfield.ScanField
    %% Dummy implementation of ScanField interface (and constructor)
    %  For testing purposes

    methods

        function out=interpolate(obj,other,frac)
            out=obj;
        end
        
        function rect=boundingbox(obj)
            rect=[0 0 1 1];
        end
        
        function bw=hit(obj,xs,ys)
            bw=ones(size(xs));
        end

        function [xs,ys]=transform(obj,xs,ys)
            xs=xs;
            ys=ys;
        end
    end

end


%--------------------------------------------------------------------------%
% Dummy.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
