classdef FastZ < handle & matlab.mixin.Heterogeneous
    properties
        flybackTime;
        actuatorLag;
        enableFieldCurveCorr;
        fieldCurveParams;
        impulseResponseDuration = 0.1;
        zAlignment = scanimage.mroi.util.zAlignmentData();
		scannerID = NaN;
    end
    
    properties (Abstract)
        positionUnits;
        hDevice;
        calibrationData;
        sampleRateHz;
        simulated;
        name;
    end
    
    methods (Static)
        function obj = default()
            obj = scanimage.mroi.scanners.FastZAnalog();
        end
    end
    
    methods
        function obj=FastZ()
            obj.zAlignment = scanimage.mroi.util.zAlignmentData();
        end
    end
    
    methods (Abstract)
        path_FOV = scanPathFOV(obj,ss,zPowerReference,actz,dzdt,seconds,slowPathFov)
        path_FOV = scanStimPathFOV(obj,ss,startz,endz,seconds,maxPoints)
        path_FOV = interpolateTransits(obj,ss,path_FOV,tune,zWaveformType)
        path_FOV = transitNaN(obj,ss,dt)
        path_FOV = zFlybackFrame(obj,ss,frameTime)
        path_FOV = padFrameAO(obj, ss, path_FOV, frameTime, flybackTime, zWaveformType)
        samplesPerTrigger = samplesPerTriggerForAO(obj,ss,outputData)
        
        volts = refPosition2Volts(obj,zs);
        zs = volts2RefPosition(obj,volts);
        zs = feedbackVolts2RefPosition(obj,volts);
    end
    
    %% Property Getter/Setter
    methods
        function set.zAlignment(obj,val)
            assert(isa(val,'scanimage.mroi.util.zAlignmentData'));
            val = obj.accessZAlignmentPreSet(val);
            obj.zAlignment = val;
        end
        
        function val = get.zAlignment(obj)
            val = obj.zAlignment;
            val = obj.accessZAlignmentPostGet(val);
        end
    end
    
    
    %% Methods to overload by child classes
    methods
        function val = accessZAlignmentPreSet(obj,val)
            % No Op
        end
        
        function val = accessZAlignmentPostGet(obj,val)
            % No Op
        end        
    end
end


%--------------------------------------------------------------------------%
% FastZ.m                                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
