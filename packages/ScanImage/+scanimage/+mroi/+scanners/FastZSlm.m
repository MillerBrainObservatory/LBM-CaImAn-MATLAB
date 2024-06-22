classdef FastZSlm < scanimage.mroi.scanners.FastZ
    properties
        hSlm;
        hDevice;
        sampleRateHz; % generally ignored in SLM FastZ scanning
        simulated = false;
        positionUnits = 1;
        name;
    end
    
    properties (Dependent)
        calibrationData;
    end
    
    methods
        function obj=FastZSlm(hSlm)
            obj = obj@scanimage.mroi.scanners.FastZ();
            obj.hSlm = hSlm;
            assert(hSlm.queueAvailable,'Cannot use SLM as a FastZ device because of lack of triggering capabilities');
        end
        
        function path_FOV = scanPathFOV(obj,ss,zPowerReference,actz,dzdt,seconds,slowPathFov)
            path_FOV = actz(:);
        end
        
        function path_FOV = scanStimPathFOV(obj,ss,startz,endz,seconds,maxPoints)
            error('Stimulation with SLM as FastZ device is unsupported');
        end
        
        function path_FOV = interpolateTransits(obj,ss,path_FOV,tune,zWaveformType)
            % No-op
        end
        
        function path_FOV = transitNaN(obj,ss,dt)
            path_FOV =  [];
        end
        
        function path_FOV = zFlybackFrame(obj,ss,frameTime)
            path_FOV = 0;
        end
        
        function path_FOV = padFrameAO(obj, ss, path_FOV, frameTime, flybackTime, zWaveformType)
            % No-op
        end
        
        function samplesPerTrigger = samplesPerTriggerForAO(obj,ss,outputData)
            samplesPerTrigger = 1;
        end
        
        function output = refPosition2Volts(obj,zs)
            numPoints = numel(zs);
            output = zeros(numPoints,3);
            output(:,3) = zs(:);
            
            %Convert from position units to meters
            output = output * obj.positionUnits;
            
            output = obj.zAlignment.compensateScannerZ(output); % apply z alignment, caluclated in meters

            output = obj.hSlm.computeSinglePointPhaseMaskScalarDiffraction(output(:,1),output(:,2),output(:,3));
            output = obj.hSlm.rad2PixelVal(output);
        end
        
        function zs = volts2RefPosition(obj,volts)
            error('Not implemented in FastZSlm');
        end
        
        function zs = feedbackVolts2RefPosition(obj,volts)
            error('Not implemented in FastZSlm');
        end
        
        function [metaData,ao_volts] = getCachedOptimizedWaveform(obj,sampleRateHz,ao_volts)
            metaData = [];
        end
    end
    
    methods
        function val = get.calibrationData(obj)
           val = [];
        end
        
        function set.calibrationData(obj,val)
            %No-op
        end        
    end
    
    %%% Overloaded functions from scanimage.mroi.scanners.FastZ
    methods
        function val = accessZAlignmentPreSet(obj,val)
            obj.hSlm.zAlignment = val;
        end
        
        function val = accessZAlignmentPostGet(obj,~)
            val = obj.hSlm.zAlignment;
        end        
    end
end


%--------------------------------------------------------------------------%
% FastZSlm.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
