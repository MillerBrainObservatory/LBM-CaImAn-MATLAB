classdef Resonant < handle
    properties
        sampleRateHz;
        fullAngleDegrees;
        fov2VoltageFunc;
        bidirectionalScan;
        scannerPeriod;
        fillFractionSpatial;
    end
    
    properties (Dependent, SetAccess = private)
        fillFractionTemporal;
    end
    
    properties (Hidden)
        fillFractionTemporal_ = [];
    end

    methods(Static)
        function obj = default
            obj=scanimage.mroi.scanners.Resonant(15,5/15,true,7910,0.7,1e5);
        end
    end

    methods
        function obj=Resonant(fullAngleDegrees,fov2VoltageFunc,bidirectionalScan,scannerPeriod,fillFractionSpatial,sampleRateHz)
            obj.fullAngleDegrees = fullAngleDegrees;
            obj.fov2VoltageFunc   = fov2VoltageFunc;
            obj.bidirectionalScan = bidirectionalScan;
            obj.scannerPeriod  = scannerPeriod;
            obj.fillFractionSpatial = fillFractionSpatial;
            obj.sampleRateHz = sampleRateHz;
        end
        
        function val = get.fillFractionTemporal(obj)
            if isempty(obj.fillFractionTemporal_)
                obj.fillFractionTemporal_ = 2/pi * asin(obj.fillFractionSpatial);
            end
            val = obj.fillFractionTemporal_;
        end
        
        function set.fillFractionSpatial(obj,val)
            obj.fillFractionSpatial = val;
            obj.fillFractionTemporal_ = [];
        end
    end
end


%--------------------------------------------------------------------------%
% Resonant.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
