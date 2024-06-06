classdef IMotionEstimatorResult < handle & matlab.mixin.Heterogeneous
    %% IMethodEstimatorResult
    % Interface is modeled after Matlab's parallel.FevalFuture interface.
    
    properties (SetAccess = immutable)
        hMotionEstimator;   % motion estimator that instantiates result
        roiData;            % roiData object for which the motion estimate was calculated (i.e. the incoming frame during the acquisition, not the reference)
    end
    
    properties (SetAccess = protected)
        %%% these properties should be set in the fetch method
        dr;          % 1x3 numeric vector containing the xyz motion offset. xy is in pixel unitx, z is in microns
        confidence;  % (optional) 1x3 numeric vector containing the confidence of the estimate for each axis (in arbitrary units)
        correlation; % (optional) 1x3 cell array of correlation vectors for each axes, used for plotting in the User Interface
        userData;    % (optional) set to any value to pass data into motion estimator. overload function userData2Str to plot to motion output file
    end
    
    properties (SetAccess = ?scanimage.interfaces.Class)
        callback;    % set by ScanImage; (optional) execute this function handle to notify ScanImage that a result is available. If this callback is not executed, ScanImage polls the result in regular intervals using
    end
    
    methods
        function obj = IMotionEstimatorResult(hMotionEstimator,roiData)
            assert(isa(hMotionEstimator,'scanimage.interfaces.IMotionEstimator') && isscalar(hMotionEstimator) && most.idioms.isValidObj(hMotionEstimator), ...
                'IMotionEstimatorResult could not be constructed. Received invalid MotionEstimator');
            assert(isa(roiData,'scanimage.mroi.RoiData') && isscalar(roiData) && most.idioms.isValidObj(roiData), ...
                'IMotionEstimatorResult could not be constructed. Received invalid roiData');
            obj.hMotionEstimator = hMotionEstimator;
            obj.roiData = roiData;
        end
    end
    
    methods(Abstract)        
        %% tf=wait(obj,timeout_s)
        % Wait till estimated translation is available or timeout
        % expires.  Returns TRUE if the wait completed successfully.
        % Returns FALSE if the timeout was exceeded.
        % This function is used to poll the result, and needs to be fast
        % 
        % timeout_s should be specified in seconds.        
        tf=wait(obj,timeout_s)
        
        
        %% dr = fetch(obj)
        % Waits for the estimated translation to become available.
        % Returns the result as a 1x3 numeric vector for the [x,y,z]
        % translation coordinates, where x and y are pixel coordinates, and
        % z is microns. For invalid results, set the vector entries to NaN
        % i.e. [0 0 NaN] means that the z-coordinate does not contain a
        % valid result, [NaN NaN NaN] means that none of the results are
        % valid.
        % if dr is empty, the result is discarded
        %
        % pixel coordinates are defined as
        %   +------> X
        %   |
        %   |
        %   |
        %   V  Y
        %
        % note that ScanImage receives transposed image data, such that
        % the effective image coordinate system is
        %   +------> Y
        %   |
        %   |
        %   |
        %   V  X
        %
        dr = fetch(obj)
    end
    
    %% Optional methods 
    methods
        %% str = userData2Str(obj)
        %
        % (Optional) Overload this function to generate a string that logs user data
        % to the motion correction log file
        % Returns a string that is logged to the motion correction log file
        %
        function str = userData2Str(obj)
            str = '';
        end
    end
    
    %% Setter methods for property validation
    methods
        function set.confidence(obj,val)
            if ~isempty(val)
                validateattributes(val,{'numeric'},{'vector','row','numel',3});
            end
            obj.confidence = val;
        end
        
        function set.correlation(obj,val)
            if ~isempty(val)
                validateattributes(val,{'cell'},{'vector','row','numel',3});
            end
            obj.correlation = val;
        end    
    end
end

%--------------------------------------------------------------------------%
% IMotionEstimatorResult.m                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
