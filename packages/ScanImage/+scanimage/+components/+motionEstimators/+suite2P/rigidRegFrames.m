% this code was developed by Marius Pachitariu and Carsen Stringer as part of the software package Suite2p

% rigid registration of frames with offsets ds
function dreg = rigidRegFrames(data, ops, ds)

[~,~,packageName] = most.idioms.getFunctionInfo();
import([packageName '.*']);

% compute maximum batch size for GPU
[h, w, nFrames] = size(data);
if getOr(ops, 'useGPU', 0)
    nFramesPerBatch = getBatchSize(w*h);
else
    nFramesPerBatch = 1000; % if not on GPU, should have plenty of RAM available
end
%%
nFramesPerBatch = 8;

nBatches = ceil(nFrames/nFramesPerBatch);
startFrame = 1:nFramesPerBatch:nFrames;
endFrame = min(startFrame+nFramesPerBatch-1, nFrames);
dreg = zeros(size(data), 'single');


for iBatch = 1:nBatches
    idx = startFrame(iBatch):endFrame(iBatch);
    if ops.useGPU
        dataBatch = gpuArray(single(data(:,:,idx)));
    else
        dataBatch = single(data(:,:,idx));
    end
    [Ly, Lx, NT] = size(dataBatch);
    
    Ny = ifftshift([-fix(Ly/2):ceil(Ly/2)-1]);
    Nx = ifftshift([-fix(Lx/2):ceil(Lx/2)-1]);
    [Nx,Ny] = meshgrid(Nx,Ny);
    Nx = Nx / Lx;
    Ny = Ny / Ly;

    if ops.useGPU
        dsBatch = gpuArray(permute(ds(idx, :), [3, 2, 1]));
        Nx = gpuArray(single(Nx));
        Ny = gpuArray(single(Ny));
    else
        dsBatch = ds(idx, :);
    end
    
    if ops.useGPU % do it batch-by-batch
        dph         = 2*pi*(bsxfun(@times, dsBatch(1,1,:), Ny) + ...
            bsxfun(@times, dsBatch(:,2,:), Nx));
        fdata       = fft2(dataBatch);
        dregBatch   = gather_try(real(ifft2(fdata .* exp(1i * dph))));
    else % do it frame-by-frame
        dregBatch = zeros(size(dataBatch), 'single');
        for i = 1:NT
            dph         = 2*pi*(dsBatch(i,1)*Ny + dsBatch(i,2)*Nx);
            fdata       = fft2(single(dataBatch(:,:,i)));
            dregBatch(:,:,i) = real(ifft2(fdata .* exp(1i * dph)));
        end
    end
    
    dreg(:,:,idx) = dregBatch;
end


%--------------------------------------------------------------------------%
% rigidRegFrames.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
