function [shifts,peak_xc,ex_lim] = rigid_mcorr(frames,opts)
% Optimized rigid motion correction.
arguments
    frames				(:,:,:)	single
    opts.max_shift		(1,1)	single = 20 % in pixels
    opts.upsampling		(1,1)	single = 50 % e.g. if upsampling = 50 then the smallest possible shift is 1/50th of a pixel
    opts.batchsize		(1,1)	single = 200 % Number of frames to process at once. Does not affect results, only memory usage. Larger values may cause the process to run out of memory.
    opts.usegpu			(1,1)	logical = false
    opts.template		(:,:)	single	% Template will be calculated if none is supplied
    opts.channel_mask	(:,1)	logical	% Logical mask where false values indicate frames that do NOT belong to the channel of interest and should be ignored
    opts.subtract_median(1,1)	logical	= true
end
    
    %%
    H = height(frames);
    W = width(frames);
    nf = size(frames,3);
    
    ups_factor = opts.upsampling;
    %% Compute template
    
    if isfield(opts,'template')
        Y_template = opts.template;
    elseif isfield(opts,'channel_mask')
        Ychan = frames(:,:,opts.channel_mask);
        Ysub = Ychan(3:3:end-2,3:3:end-2,:);
        Y_temp_corr = corr(reshape(median(Ysub,3),[],1), reshape(Ysub,[],sum(opts.channel_mask)));
        Y_samp = (Y_temp_corr>=max(prctile(Y_temp_corr,90),0.6));
        assert(mean(Y_samp)>=0.05 && sum(Y_samp)>=10, "Insufficient sample frames to compute template")
        Y_template = median(Ychan(:,:,Y_samp),3);
    else
        Ysub = frames(3:3:end-2,3:3:end-2,:);
        Y_temp_corr = corr(reshape(median(Ysub,3),[],1), reshape(Ysub,[],nf));
        Y_samp = (Y_temp_corr>=max(prctile(Y_temp_corr,90),0.6));
        assert(mean(Y_samp)>=0.05 && sum(Y_samp)>=10, "Insufficient sample frames to compute template")
        Y_template = median(frames(:,:,Y_samp),3);
    end
    
    %%
    
    if opts.usegpu
        template_fft = gpuArray(fft2(Y_template));
    else
        template_fft = fft2(Y_template);
    end
    
    
    block_index = discretize(1:nf,ceil(nf/opts.batchsize));
    shifts = nan(nf,2,'single');
    peak_xc = nan(nf,1,'single');
    ex_lim = false(nf,1);
    for xf = 1:max(block_index)
    
        % Do FFT
        if opts.usegpu
            frames_fft = fft2(gpuArray(frames(:,:,block_index==xf)));
            frame_xcorr = fftshift(fftshift(template_fft.*conj(frames_fft),1),2);
        else
            frames_fft = fft2(frames(:,:,block_index==xf));
            frame_xcorr = fftshift(fftshift(template_fft.*conj(frames_fft),1),2);
        end
        batch_nf = sum(block_index==xf);
    
        % FFT array padding
    
        Nin = size(frame_xcorr,[1 2]);
        outsize = [2*H,2*W];
        center = floor(Nin/2)+1;
        
        Yxcup = zeros([outsize,batch_nf],'like',frames_fft);
        centerout = floor(size(Yxcup,[1 2])/2)+1;
        
        cenout_cen = centerout - center;
        
        Yxcup(max(cenout_cen(1)+1,1):min(cenout_cen(1)+Nin(1),outsize(1)),max(cenout_cen(2)+1,1):min(cenout_cen(2)+Nin(2),outsize(2)),:) ...
            = frame_xcorr(max(-cenout_cen(1)+1,1):min(-cenout_cen(1)+outsize(1),Nin(1)),max(-cenout_cen(2)+1,1):min(-cenout_cen(2)+outsize(2),Nin(2)),:);
        clear frame_xcorr
        Yxcup = ifftshift(ifftshift(Yxcup,2),1)*outsize(1)*outsize(2)/(Nin(1)*Nin(2));
    
        % Compute cross-correlation and part-pixel shifts
        CC = ifft2(Yxcup);
        CCabs = abs(CC);
        [~,Yx_ind] = max(reshape(CCabs,[],batch_nf),[],1);
        [row_shift,col_shift,~] = ind2sub(size(CCabs,[1 2]), (Yx_ind));
    
    
        % Check for shifts greater than max allowable shift
        
        Nr2 = ifftshift(-fix(H):ceil(H)-1);
        Nc2 = ifftshift(-fix(W):ceil(W)-1);
        
        if opts.usegpu
            shift_lim_exceeded = (max(abs(Nr2(gather(row_shift))./2),abs(Nc2(gather(col_shift))./2))>opts.max_shift);
        else
            shift_lim_exceeded = (max(abs(Nr2(row_shift)./2),abs(Nc2(col_shift)./2))>opts.max_shift);
        end
    
        if any(shift_lim_exceeded)
            disp("WARNING: shift limit exceeded")
            CCabs2 = CCabs(:,:,shift_lim_exceeded);
            CCabs2(Nr2/2>opts.max_shift,:,:) = 0;
            CCabs2(:,Nc2/2>opts.max_shift,:) = 0;
            CCabs2(Nr2/2<-opts.max_shift,:,:) = 0;
            CCabs2(:,Nc2/2<-opts.max_shift,:) = 0;
            CCabs(:,:,shift_lim_exceeded) = single(CCabs2);
            [~,Yx_ind] = max(CCabs,[],[1 2],'linear');
            [row_shift,col_shift,~] = ind2sub(size(CCabs), squeeze(Yx_ind));
            ex_lim(block_index==xf) = shift_lim_exceeded;
        end
        
        
        row_shift = Nr2(row_shift)./2;
        col_shift = Nc2(col_shift)./2;
        row_shift = single(round(row_shift*ups_factor)/ups_factor); 
        col_shift = single(round(col_shift*ups_factor)/ups_factor);     
        dftshift = fix(ceil(ups_factor*1.5)/2);
        
        roff = dftshift-reshape(row_shift,1,1,[])*ups_factor;
        coff = dftshift-reshape(col_shift,1,1,[])*ups_factor;
        nor = ceil(ups_factor*1.5);
        noc = ceil(ups_factor*1.5);
    
        kernc=exp((-1i*2*pi/(W*ups_factor)).*( ifftshift(0:W-1).' - floor(W/2) ).*( (0:noc-1) - coff ));
        kernr=exp((-1i*2*pi/(H*ups_factor)).*( (0:nor-1).' - roff ).*( ifftshift([0:H-1]) - floor(H/2)  ));
        
        CC = single(frames_fft.*conj(template_fft));
    
        if opts.usegpu
            CC = pagemtimes(pagemtimes(gpuArray(kernr),CC),gpuArray(kernc));
        else
            CC = pagemtimes(pagemtimes(kernr,CC),kernc);
        end
    
        [pxc,cc_loc] = max(abs(CC),[],[1 2],'linear'); % could extract correlation here to measure goodness of fit per frame
        % alternatively, could try for measure that is more robust to sparse signals
        
        [rloc,cloc,~] = ind2sub(size(CC), squeeze(cc_loc));
        
        rloc = rloc - dftshift - 1;
        cloc = cloc - dftshift - 1;
        row_shift = row_shift + rloc.'/ups_factor;
        col_shift = col_shift + cloc.'/ups_factor;  
        if opts.usegpu
            batch_shifts = [gather(col_shift(:)) gather(row_shift(:))];
            pxc = gather(pxc);
        else
            batch_shifts = [col_shift(:) row_shift(:)];
        end
    
        shifts(block_index==xf,:) = batch_shifts;
        peak_xc(block_index==xf) = pxc;
    end
    
    peak_xc = peak_xc./(H*W*squeeze(sqrt(sum(frames.^2,[1 2]).*sum(Y_template.^2,[1 2]))));
    if opts.subtract_median
	    if isfield(opts,'channel_mask')
    	    shifts = shifts - median(shifts(opts.channel_mask,:),1);
	    else
    	    shifts = shifts - median(shifts,1);
	    end
    end
end