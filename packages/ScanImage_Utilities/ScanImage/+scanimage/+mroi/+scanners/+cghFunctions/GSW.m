function [phi,I] = GSW(scanner,xm,ym,zm,wm)
    if nargin < 5 || isempty(wm)
        wm = ones(size(xm));
    end
        
    zeroPowerMask = find(wm<=0);
    if ~isempty(zeroPowerMask)
        xm(zeroPowerMask) = [];
        ym(zeroPowerMask) = [];
        zm(zeroPowerMask) = [];
        wm(zeroPowerMask) = [];
    end
    
    M = numel(xm);
    wm = wm/sum(wm); % normalize so that sum(wm)=1
    
    ptPhaseMask = scanner.computeSinglePointPhaseMask(xm,ym,zm);
    ptPhaseMask_c = exp(1i*ptPhaseMask);
    ptPhaseMask_c_inv_beamProfile = bsxfun(@rdivide,scanner.geometryBuffer.beamProfileNormalized,ptPhaseMask_c);
    
    phi_c = SR(ptPhaseMask_c); % initial guess
    
    wk_c = ones(M,1);
    Vk_c = V(phi_c,ptPhaseMask_c_inv_beamProfile);
    
    numIterations = 15;
    if M<=2
        numIterations = 1;
    end
    
    for k = 1:numIterations % iterative optimization
        Vk_c_w = Vk_c ./ sqrt(wm);
        wk_c = wk_c .* mean(abs(Vk_c_w)) ./ abs(Vk_c_w); % calculate new weights
        phi_c(:,:) = 0;
        for m = 1:M
            phi_c = phi_c + ptPhaseMask_c(:,:,m)*(wk_c(m)*Vk_c(m)/abs(Vk_c(m)));
        end
        phi_c = phi_c ./ abs(phi_c); % normalize
        Vk_c = V(phi_c,ptPhaseMask_c_inv_beamProfile);
        
        [I,e,u,s] = stats(Vk_c,wm);
        fprintf('Iteration %d: efficiency=%f  uniformity=%f  std= %f\n',k,e,u,s);
    end
    phi = angle(phi_c);
end

function V_c = V(phi_c,ptPhaseMask_c_inv_beamProfile)
    M = size(ptPhaseMask_c_inv_beamProfile,3);
    V_c = zeros(M,1);
    for m_ = 1:M
        v_c = phi_c .* ptPhaseMask_c_inv_beamProfile(:,:,m_);
        V_c(m_) = sum(sum(v_c));
    end
end

function phaseMask_c = SR(ptPhaseMask_c)
    % superposition with random phase offset
    M = size(ptPhaseMask_c,3);
    phi_rand = exp(1i*2*pi*rand(M,1));
    phaseMask_c = zeros(size(ptPhaseMask_c,1),size(ptPhaseMask_c,2));
    for m = 1:M
        phaseMask_c = phaseMask_c + ( ptPhaseMask_c(:,:,m) * phi_rand(m) );
    end
    phaseMask_c = phaseMask_c ./ abs(phaseMask_c); % normalize
end

function [I,e,u,s] = stats(V_c,w)
I = abs(V_c).^2; % intensity
e = sum(I);      % efficiency
I_ = I./w;       % respect weights for calculating uniformity and standard deviation
u = 1-(max(I_)-min(I_))/(max(I_)+min(I_));
s = 100 * sqrt(mean((I_-mean(I_)).^2))/mean(I_);
end

%--------------------------------------------------------------------------%
% GSW.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
