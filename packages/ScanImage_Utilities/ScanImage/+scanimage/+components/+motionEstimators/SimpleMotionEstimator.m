classdef SimpleMotionEstimator < scanimage.interfaces.IMotionEstimator
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
    end
    
    %% Internal properties
    properties (SetAccess = private)
        refImagesConjFft;
        eps = single(1e-10);
    end
    
    %% Lifecycle
    methods
        function obj=SimpleMotionEstimator(referenceRoiData)
            obj = obj@scanimage.interfaces.IMotionEstimator(referenceRoiData);
            
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
            assert(numel(channels) == 1,'Estimator %s does not support multiple channels',class(obj));
            obj.channels = channels;
            
            obj.preprocessVolume(referenceRoiData);
        end
        
        function delete(obj)
            % No-Op
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
            
            imData = roiData.imageData{chIdx}{1};
            
            [dr,confidence,correlation] = obj.estimationFcn(imData,zIdx);
            motion_estimator_result = scanimage.components.motionEstimators.estimatorResults.SimpleMotionEstimatorResult(obj,roiData,dr,confidence,correlation);
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
            
            obj.refImagesConjFft = conj(fft2(refIms)); % refIms is a 3D array. fft2 takes the 2-D fourier transform for each slice
        end
        
        function [dr,confidence,correlation] = estimationFcn(obj,image,zidx)            
            % images are transposed
            image = single(image);
            image = ( image-mean(image(:)) ) ./ std(image(:)); % normalize image
            imageFft = fft2(image);
            
            cc = bsxfun(@times,obj.refImagesConjFft,imageFft); % calculate correlation;
            if obj.phaseCorrelation
                cc = cc./(abs(cc)+obj.eps); % phase correlation, add eps to avoid division by zero
            end
            cc = ifft2(cc,'symmetric'); % cc is a 3D array. ifft2 takes the 2-D fourier transform for each slice
            
            % correlation side projections
            cxxs = max(cc,[],2);
            cyys = max(cc,[],1);
            
            % remove singleton dimensions
            % don't use squeeze here, it doesn't work on arrays where
            % size(x,3) == 0
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
            dz = obj.zs(zidx)-obj.zs(zIdxMaxCorr);
            
            dr = [dx dy dz];
            confidence = [confidence confidence confidence];
            correlation = {cxx, cyy, czz};
            
            %%% debugging code
            %obj.plotCorrelations(cxxs,cyys);
        end
        
        function plotCorrelations(obj,cxxs,cyys)
            persistent hIm_x hIm_y
            
            if isempty(hIm_x) || isempty(hIm_y) || ~isvalid(hIm_x) || ~isvalid(hIm_y)
                hFig = figure();
                hAx_x = subplot(2,1,1);
                hAx_y = subplot(2,1,2);
                view(hAx_x,90,90);
                view(hAx_y,90,90);
                hIm_x = imagesc('Parent',hAx_x,'CData',cxxs);
                hIm_y = imagesc('Parent',hAx_y,'CData',cyys);
                axis(hAx_x,'tight');
                axis(hAx_y,'tight');
                title(hAx_x,'X Correlation');
                title(hAx_y,'Y Correlation');
                ylabel(hAx_x,'X [pixels]');
                xlabel(hAx_x,'Z index');
                ylabel(hAx_y,'Y [pixels]');
                xlabel(hAx_y,'Z index');
            end
            
            hIm_x.CData = cxxs;
            hIm_y.CData = cyys;
        end
    end
    
    %% Property Getter/Setter
    methods
        function set.phaseCorrelation(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.phaseCorrelation = logical(val);
        end
    end
    
    %% Static methods
    methods (Static)
        function checkSystemRequirements()
            % no special system requirements
        end
    end
end

%--------------------------------------------------------------------------%
% SimpleMotionEstimator.m                                                  %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
