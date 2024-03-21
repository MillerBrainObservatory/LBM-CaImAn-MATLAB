function off = returnScanOffset3(I,dim,siz)

if nargin < 3
    siz = 15;
end

Iz = I;
Iz(1:siz,:) = 0;
Iz(:,1:siz) = 0;
Iz(end-siz+1:end,:) = 0;
Iz(:,end-siz+1:end) = 0;

offset = zeros(1,3);

for abc = 1:3

    [~,ind] = max(Iz(:));
    [iy,ix] = ind2sub(size(I),ind);

    Iz(iy-siz:iy+siz,ix-siz:ix+siz) = 0;

    os = -4:4;
    ft_val = zeros(size(os));

    for ijk = 1:numel(os)

        o = os(ijk);
        
        switch dim
            case 1
                Iv1 = I(iy-siz:iy+siz,ix-siz:ix+siz); Iv1(1:2:end,:) = 0;
                Iv2 = I(iy-siz:iy+siz,(ix-siz+o:ix+siz+o)); Iv2(2:2:end,:) = 0;
                Iv = Iv1+Iv2;     
                ft = mean(abs(fftshift(fft(fftshift(Iv,1),[],1),1)).^2,2);     
                
            case 2
                Iv1 = I(iy-siz:iy+siz,ix-siz:ix+siz); Iv1(:,1:2:end) = 0;
                Iv2 = I((iy-siz+o):(iy+siz+o),ix-siz:ix+siz); Iv2(:,2:2:end) = 0;
                Iv = Iv1+Iv2;     
                ft = mean(abs(fftshift(fft(fftshift(Iv,2),[],2),2)).^2,1);    
        end

        ft_val(ijk) = ft(end);
        
    end
    
    try
        vec = -ft_val; vec = vec-min(vec);
        ftt = fit(os',vec','gauss1');
        offset(abc) = ftt.b1;
    catch
        [~,in] = min(ft_val);
        offset(abc) = os(in);
    end
    
    
end

off = round(mean(offset));