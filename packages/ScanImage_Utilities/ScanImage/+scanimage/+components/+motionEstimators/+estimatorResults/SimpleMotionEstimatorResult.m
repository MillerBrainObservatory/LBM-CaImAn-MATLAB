classdef SimpleMotionEstimatorResult < scanimage.interfaces.IMotionEstimatorResult    
    properties (SetAccess = protected)
    end
    
    methods
        function obj = SimpleMotionEstimatorResult(hMotionEstimator,roiData,dr,confidence,correlation)
            obj = obj@scanimage.interfaces.IMotionEstimatorResult(hMotionEstimator,roiData);
            obj.dr = dr;
            obj.confidence = confidence;
            obj.correlation = correlation;
        end
        
        function delete(obj)
            % No-op
        end
        
        function tf = wait(obj,timeout_s)
            tf = true; % Synchronous operation
        end
        
        function dr = fetch(obj)
            dr = obj.dr;
        end
    end
end

%--------------------------------------------------------------------------%
% SimpleMotionEstimatorResult.m                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
