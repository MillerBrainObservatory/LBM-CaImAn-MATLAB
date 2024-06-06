classdef ParallelMotionEstimator < scanimage.interfaces.IMotionEstimator
    %% Abstract Property realization
    properties (SetAccess = immutable)
        zs;
        channels;
    end
    
    %% User properties
    properties (SetObservable)
        % Place any user accessible properties into a SetObservable
        % property block in the class implementation. These properties will
        % show in the table of the Motion Display GUI
        
        phaseCorrelation = true;
        localDebugging = false;
        maxQueueSize;
    end
    
    %% Internal properties    
    properties (SetAccess = private, Hidden)
        refData;
        refData_pool;
        pool;
        eps = single(1e-10);
    end
    
    %% Lifecycle
    methods
        function obj=ParallelMotionEstimator(referenceRoiData)
            obj = obj@scanimage.interfaces.IMotionEstimator(referenceRoiData);
            
            obj.pool = scanimage.util.ParallelPool();
            
            hRoi = referenceRoiData.hRoi;
            obj.zs = referenceRoiData.zs;
            scanfields = arrayfun(@(z)hRoi.get(z),obj.zs,'UniformOutput',false);
            assert(~isempty(scanfields),'Incorrect z selection for ROI'); % sanity check
            
            % current ROI restrictions for this estimator:
            %  - the pixel resolution at each z needs to be the same
            %  - the scanfield at each z needs to be the same
            %  - only one channel can be selected for motion estimation
            if ~isscalar(scanfields)
                affines = cellfun(@(scanfield)scanfield.affine,scanfields,'UniformOutput',false);
                pixelResolutionsXY = cellfun(@(scanfield)scanfield.pixelResolutionXY,scanfields,'UniformOutput',false);
                assert(isequal(affines{:}),'All scanfields in the ROI need to have the same geometry');
                assert(isequal(pixelResolutionsXY{:}),'All scanfields in the ROI need to have the same pixel resolution');
            end
            
            channels = referenceRoiData.channels;
            assert(numel(channels) == 1,'This estimator currently does not support multiple channels');
            obj.channels = channels;
            
            obj.preprocessVolume(referenceRoiData);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.refData_pool);
        end
    end
    
    %% Abstract Methods realization
    methods (Access = protected)
        function startInternal(obj)
            % No-Op
        end
        
        function abortInternal(obj)
            % No-Op
        end
        
        function motion_estimator_result = estimateMotionInternal(obj,roiData)
            chIdx = find(roiData.channels == obj.channels);
            zIdx = find(roiData.zs == obj.zs);
            if isempty(chIdx) || isempty(zIdx) % reference channel or reference z is currently not imaged
                motion_estimator_result = [];
                return
            end
            
            % limit queuesize
            if ~isinf(obj.maxQueueSize)                
                if obj.pool.getQueueSize() >= obj.maxQueueSize
                    motion_estimator_result = [];
                    return
                end
            end
            
            imData = roiData.imageData{chIdx}{1};
            
            numOutputs = 3;
            estimatorFcnHdl = @scanimage.components.motionEstimators.ParallelMotionEstimator.estimationFcn;
            
            params = struct();
            params.phaseCorrelation = obj.phaseCorrelation;
            params.eps = obj.eps;
            
            if obj.localDebugging
                [dr,confidence,correlation] = estimatorFcnHdl(obj.refData,params,imData,zIdx);
                motion_estimator_result = scanimage.components.motionEstimators.estimatorResults.SimpleMotionEstimatorResult(obj,roiData,dr,confidence,correlation);
            else
                fevalFuture = parfeval(obj.pool,estimatorFcnHdl,numOutputs,obj.refData_pool,params,imData,zIdx);
                motion_estimator_result = scanimage.components.motionEstimators.estimatorResults.ParallelMotionEstimatorResult(obj,roiData,fevalFuture);
            end
        end
    end
    
    %% Internal Methods
    methods        
        function preprocessVolume(obj,referenceRoiData)
            % roiData.imageData{chidx}{zidx}
            channelidx = 1;
            refIms = referenceRoiData.imageData{channelidx}; % get first and only channel
            refIms = cat(3,refIms{:});
            refIms = single(refIms);
            
            for zidx = 1:size(refIms,3)
                im = refIms(:,:,zidx);
                refIms(:,:,zidx) = ( im-mean(im(:)) ) ./ std(im(:)); % normalize images
            end
            
            refImagesConjFft = conj(fft2(refIms)); % refIms is a 3D array. fft2 takes the 2-D fourier transform for each slice
            
            obj.refData = struct();
            obj.refData.zs = obj.zs;
            obj.refData.refImagesConjFft = refImagesConjFft;
            
            %make data persistent on worker
            obj.refData_pool = parallel.pool.Constant(obj.refData);
        end
    end
    
    %% Static methods
    methods (Static)
        % Performance note: the function evaluated by parfeval
        % should not be a local function, but accessible through the Matlab Path
        % Reason: all data passed to parfeval (including the function handle)
        % is serialized by the function parallel.internal.pool.serialize
        % if the function handle passed to parfeval is a local function,
        % the serialization is slow. Making the function static solves this issue
        function [dr,confidence,correlation] = estimationFcn(refData,params,image,zidx)
            if isa(refData,'parallel.pool.Constant')
                refData = refData.Value;
            end
            
            % images are transposed
            image = single(image);
            image = ( image-mean(image(:)) ) ./ std(image(:)); % normalize image
            imageFft = fft2(image);
            
            cc = bsxfun(@times,refData.refImagesConjFft,imageFft); % calculate correlation;
            if params.phaseCorrelation
                cc = cc./(abs(cc)+params.eps); % phase correlation, add eps to avoid division by zero
            end
            cc = ifft2(cc,'symmetric'); % cc is a 3D array. ifft2 takes the 2-D fourier transform for each slice
            
            % correlation side projections
            cxxs = max(cc,[],2);
            cyys = max(cc,[],1);
            
            % remove singleton dimensions
            % don't use squeeze here, it doesn't work on arrays where size(x,3) == 1
            cxxs = permute(cxxs,[1 3 2]);
            cyys = permute(cyys,[2 3 1]);
            
            cxxs = fftshift(cxxs,1);
            cyys = fftshift(cyys,1);
            
            % find z idx
            czz = max(cxxs,[],1);
            [confidence,zIdxMaxCorr] = max(czz);
            
            cxx = cxxs(:,zIdxMaxCorr);
            cyy = cyys(:,zIdxMaxCorr);
            
            [~,xIdx] = max(cxx);
            [~,yIdx] = max(cyy);
            
            imSize = size(image);
            dx = xIdx-1-floor(imSize(1)/2);
            dy = yIdx-1-floor(imSize(2)/2);
            dz = refData.zs(zidx)-refData.zs(zIdxMaxCorr);
            
            dr = [dx dy dz];
            confidence = [confidence confidence confidence];
            correlation = {cxx, cyy, czz};
        end
        
        function checkSystemRequirements()
            assert(most.util.parallelComputingToolboxAvailable(),'''%s'' requires the Matlab Parallel Computing Toolbox. This toolbox is not installed/licensed on this computer.',mfilename('class'));
            assert(~verLessThan('matlab','8.6'),'%s requires Matlab 2015b or later',mfilename('class')); % requirement for parallel.pool.Constant
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.maxQueueSize(obj,val)
            obj.pool.maxQueueSize = val;
        end
        
        function val = get.maxQueueSize(obj)
            val = obj.pool.maxQueueSize;
        end
        
        function set.localDebugging(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.localDebugging = logical(val);
        end
        
        function set.phaseCorrelation(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.phaseCorrelation = logical(val);
        end
    end
end

%--------------------------------------------------------------------------%
% ParallelMotionEstimator.m                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
