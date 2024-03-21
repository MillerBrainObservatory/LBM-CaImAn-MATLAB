function correction = returnScanOffset(Iin,dim)

offsets = -10:10;

fft_val = zeros(size(offsets));

for ijk = 1:numel(offsets)

    Itest = fixScanPhase(Iin,offsets(ijk),dim);
    
    Ifft = abs(fftshift(fft(Itest,[],1))).^2;
    
    ifft = mean(Ifft',dim);
    
    fft_val(ijk) = ifft(end);

end

coeff = polyfit(offsets,fft_val,2);
ft = polyval(coeff,offsets);

[~,ind] = min(ft);
correction = offsets(ind);