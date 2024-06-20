classdef GpuMotionEstimator < scanimage.interfaces.IMotionEstimator
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
    properties (SetAccess = private, Hidden)
        refImagesConjFft_gpu;
        sz
        szPad
        szPadHalf
    end
    
    %% Lifecycle
    methods
        function obj=GpuMotionEstimator(referenceRoiData)
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
                % normalize reference
                im = refIms(:,:,zidx);
                refIms(:,:,zidx) = (im-mean(im(:))) ./ std(im(:));
            end
            
            obj.sz = [size(refIms,1), size(refIms,2), size(refIms,3)]; % size(refIms) does not return 3rd dim if 3rd dim is one            
            % calculate optimal fft sizes for performance
            obj.szPad(1) = most.util.nextCufftSize(obj.sz(1), 1, 'even');
            obj.szPad(2) = most.util.nextCufftSize(obj.sz(2), 1, 'even');
            obj.szPad(3) = obj.sz(3);
            obj.szPadHalf = [floor(obj.szPad(1:2)/2)+1 obj.szPad(3)];
            
            refImagesConjFft = conj(fft2(refIms,obj.szPad(1),obj.szPad(2))); % refIms is a 3D array. fft2 takes the 2-D fourier transform for each slice
            obj.refImagesConjFft_gpu = gpuArray(refImagesConjFft(1:obj.szPadHalf(1),:,:)); % fft is symmetric, only store half of it. note: GPU requires [1:( (floor(m/2)+1) ), :], CPU requires [: ,1:( (floor(n/2)+1 )]
        end
        
        function [dr,confidence,correlation] = estimationFcn(obj,image,zidx)            
            % images are transposed
            image = single(image);
            image_gpu = gpuArray(image);            
            imageFft_gpu = fft2(image_gpu,obj.szPad(1),obj.szPad(2));
            imageFft_gpu = imageFft_gpu(1:obj.szPadHalf(1),:); % fft is symmetric, only store half of it. note: GPU requires [1:( (floor(m/2)+1) ), :], CPU requires [: ,1:( (floor(n/2)+1 )]
            
            % begin GPU processing
            cc_gpu = bsxfun(@times,obj.refImagesConjFft_gpu,imageFft_gpu); % calculate correlation; imageFft is automatically transferred to the GPU with this call
            if obj.phaseCorrelation
                cc_gpu = cc_gpu./(abs(cc_gpu)+eps('single')); % phase correlation, add eps to avoid division by zero
            end
            cc_gpu = ifft2(cc_gpu,obj.szPad(1),obj.szPad(2),'symmetric'); % cc_gpu is a 3D array. ifft2 takes the 2-D fourier transform for each slice
            
            % correlation side projections
            cxxs_gpu = max(cc_gpu,[],2);
            cyys_gpu = max(cc_gpu,[],1);
            
            % fetch data from the GPU
            cxxs = permute(gather(cxxs_gpu),[1 3 2]);
            cyys = permute(gather(cyys_gpu),[2 3 1]);
            
            cxxs = fftshift(cxxs,1);
            cyys = fftshift(cyys,1);
            
            % find z idx
            czz = max(cxxs,[],1);
            [confidence,zIdxMaxCorr] = max(czz);
            
            cxx = cxxs(:,zIdxMaxCorr);
            cyy = cyys(:,zIdxMaxCorr);
            
            cxx = unpadCorrelation(cxx,obj.sz(1));
            cyy = unpadCorrelation(cyy,obj.sz(2));
            
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
            
            function cc = unpadCorrelation(cc,sz)
                dpad = numel(cc)-sz;
                if dpad > 0
                    cc = cc(1+floor(dpad/2):end-ceil(dpad/2));
                else
                    cc = [ nan(ceil(-dpad/2),1); cc; nan(floor(-dpad/2),1) ];
                end
            end
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
    
    %% Static methods
    methods (Static)
        function checkSystemRequirements()
            assert(most.util.gpuComputingAvailable,'''%s'' requires a GPU for processing. No compatible GPU was found in this computer.',mfilename('class'));
        end
    end
    
    methods
        function set.phaseCorrelation(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.phaseCorrelation = logical(val);
        end
    end
end

%--------------------------------------------------------------------------%
% GpuMotionEstimator.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
