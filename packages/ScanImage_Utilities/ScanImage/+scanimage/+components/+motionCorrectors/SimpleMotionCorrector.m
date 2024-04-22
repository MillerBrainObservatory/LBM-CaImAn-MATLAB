classdef SimpleMotionCorrector < scanimage.interfaces.IMotionCorrector    
    properties (SetObservable)
        runningAverageLength_s = 3;     % running average length in seconds for motion correction value
        correctionInterval_s = 10;      % interval for motion correction events in secondes
        correctionThreshold = [1 1 10]; % units are in [degrees degrees micron]
        thresholdExceedTime_s = 0;
    end
    
    properties (SetObservable, Dependent)
        plotConfidence;
    end
    
    properties (Access = private)
        motionHistory;  % stores the motion history
        lastUpdate;     % stores the time the last motion update happened
        drRefHistory;
        drRefHistoryTimestamps;
        drRefNeedsUpdate = true;
        lastDrRef = [];
        hConfidencePlot;
    end
        
    methods
        function obj = SimpleMotionCorrector()
            obj.hConfidencePlot = most.util.TimePlot('Confidence Time Plot',false);
            obj.hConfidencePlot.xLabel = 'Acquisition Time [s]';
            obj.hConfidencePlot.yLabel = 'Confidence Value';
            obj.hConfidencePlot.changedCallback = @eigensetPlots;
            
            function eigensetPlots(varargin)
                % this is to update the user interface
                obj.plotConfidence = obj.plotConfidence;
            end
        end
        
        function start(obj)
            obj.lastUpdate = tic();
            obj.drRefNeedsUpdate = true;
            obj.resetRefHistory();
            obj.hConfidencePlot.reset();
        end
        
        function abort(obj)
            % No-op
        end
        
        function updateMotionHistory(obj,motionHistory)
            % Note: in future releases the motionHistory might not be
            % sorted anymore. Use [motionHistory.historyIdx] to get the
            % history indices
            obj.motionHistory = motionHistory;
            obj.drRefNeedsUpdate = true;
            
            drRef = obj.getCorrection(); % update correction            
            
            timeToUpdate = toc(obj.lastUpdate) > obj.correctionInterval_s;
            if ~timeToUpdate
                return
            end
            
            historyMask = obj.drRefHistoryTimestamps >= obj.drRefHistoryTimestamps(end)-obj.thresholdExceedTime_s;
            
            drRefs = obj.drRefHistory(historyMask,:);
            threshExceed = false(1,3);
            for axIdx = 1:3
                da = drRefs(:,axIdx);
                da = da(~isnan(da));
                threshExceed(axIdx) = all(abs(da) >= obj.correctionThreshold(axIdx));
            end
            aboveCorrectionThreshold = any(threshExceed);
            
            if aboveCorrectionThreshold && timeToUpdate
                obj.lastUpdate = tic();
                obj.notify('correctNow');
            end
        end
        
        function drRef = getCorrection(obj)
            if ~obj.drRefNeedsUpdate
                drRef = obj.lastDrRef;
                return
            end
            
            if isempty(obj.motionHistory)
                drRef = [NaN NaN NaN];
                return
            end
            
            histLength = numel(obj.motionHistory);
            
            timestamps = [obj.motionHistory.frameTimestamp];
            drRefs = vertcat(obj.motionHistory.drRef);
            
            timestamp = timestamps(end);
            % filter for runningAverageLength
            historymask = timestamps>=timestamp-obj.runningAverageLength_s;
            
            if any(historymask)
                drRef = drRefs(historymask,:);
                drRef = mean(drRef,1,'omitnan');
                
                obj.drRefHistory = append(obj.drRefHistory,drRef,histLength);
                obj.drRefHistoryTimestamps = append(obj.drRefHistoryTimestamps,timestamp,histLength);
                
                drRef(isnan(drRef)) = 0;
            else
                drRef = [0 0 0];
            end
            
            obj.lastDrRef = drRef;            
            obj.drRefNeedsUpdate = false;
            
            % update confidence values
            if obj.plotConfidence
                historymask = timestamps == timestamp;
                confidence = {obj.motionHistory.confidence};
                confidence = vertcat(confidence{:});
                confidence = mean(confidence,1,'omitnan');
                obj.hConfidencePlot.addTimePoint(confidence,timestamp);
            end
        end
        
        function correctedMotion(obj,dr,motionCorrectionVector)
            %No-op
        end
    end
    
    %% Internal methods
    methods (Access = private)        
        function resetRefHistory(obj)
            obj.drRefHistory = [];
            obj.drRefHistoryTimestamps = [];
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.runningAverageLength_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','real','finite'});
            obj.runningAverageLength_s = val;
        end
        
        function set.correctionInterval_s(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','real','finite'});
            obj.correctionInterval_s = val;
        end
        
        function set.correctionThreshold(obj,val)
            validateattributes(val,{'numeric'},{'vector','row','numel',3,'nonnegative','nonnan','real'});
            obj.correctionThreshold = val;
        end
        
        function set.plotConfidence(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.hConfidencePlot.visible = logical(val);
        end
        
        function val = get.plotConfidence(obj)
            val = obj.hConfidencePlot.visible;
        end
    end
end

function vec = append(vec,v,veclength)
if isempty(vec)
    vec = v;
elseif size(vec,1) < veclength
    vec(end+1,:) = v;
else
    if size(vec,1) > veclength
        vec = vec(end-veclength+1:end,:);
    end
    vec = circshift(vec,-1,1);
    vec(end,:) = v;
end
end


%--------------------------------------------------------------------------%
% SimpleMotionCorrector.m                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
