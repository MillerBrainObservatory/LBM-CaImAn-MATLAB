classdef ParallelMotionEstimatorResult < scanimage.interfaces.IMotionEstimatorResult    
    properties (SetAccess = private)
        futureFinished = false;
        fevalFuture
    end
    
    methods
        function obj = ParallelMotionEstimatorResult(hMotionEstimator,roiData,fevalFuture)
            obj = obj@scanimage.interfaces.IMotionEstimatorResult(hMotionEstimator,roiData);
            obj.fevalFuture = fevalFuture;
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.fevalFuture);
        end
        
        function tf = wait(obj,timeout_s)
            tf = obj.futureFinished || ~isempty(regexpi(obj.fevalFuture.State,'^finished.*','once'));
            if ~tf && timeout_s>0
                % performance fix: only call wait method on fevalFuture if necessary
                tf = obj.fevalFuture.wait('finished',timeout_s);
            end
        end
        
        function dr=fetch(obj)
            if ~obj.futureFinished
                obj.wait(Inf);
                [obj.dr,obj.confidence,obj.correlation] = obj.fevalFuture.fetchOutputs;
            end
            dr = obj.dr;
        end
    end
end

%--------------------------------------------------------------------------%
% ParallelMotionEstimatorResult.m                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
