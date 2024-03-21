clear
close all
clc

[file,path]  = uigetfile('*.mat');

load([path file])

Cn = Cn./max(Cn(:));
CnC = repmat(Cn,[1 1 3]);

if exist('Ac_keep','var') > 0
    num = size(Ac_keep,1);
    A_keep = zeros(2*num+size(Cn,1),2*num+size(Cn,2),size(Ac_keep,3),'single');

    for k = 1:Km
        syk = acy(k)-floor(num/2)+num;
        sxk = acx(k)-floor(num/2)+num;
        A_keep(syk+1:syk+num,sxk+1:sxk+num,k) = Ac_keep(:,:,k);
    end

    A_keep = A_keep(num+1:end,num+1:end,:);
    A_keep = A_keep(1:size(Cn,1),1:size(Cn,2),:);

end

A = mean(reshape(full(A_keep),size(Cn,1),size(Cn,2),[]),3);
A(A>0) = 1;
Ac = repmat(A,[1 1 3]);
Ac(:,:,2:3) = 0;

figure(100);
set(gcf,'Position',[600 50 600 600]);
imagesc(Cn)
axis image

figure(101);
set(gcf,'Position',[50 50 600 600])
imagesc(CnC)
hold on
im = imagesc(Ac);
im.AlphaData = 0.3.*A;
axis image

good = 1;
count = 0;
lim = 500;

Akm = reshape(full(A_keep),size(Cn,1),size(Cn,2),[]);

keep_list = false(1,size(T_keep,1));

Asel = zeros(size(Cn));

while good == 1
    
    count = count+1;
    
    [x,y] = ginput(1);
    
    x = round(x);
    y = round(y);
    
    if x<size(Cn,2) && y<size(Cn,1) 
        ind = find(Akm(y,x,:));

        clf;
    
        if size(ind,1)>0

            if size(ind,1)>1
                [mx,in] = max(rval_space(ind));
                ind = ind(in);
            end

            Ak = reshape(full(A_keep(:,:,ind)),size(Cn,1),size(Cn,2));
            Ak(Ak>0) = 1;
            A = A-Ak;
            Ac_temp = repmat(A,[1 1 3]);
            Ac_temp(:,:,2:3) = 0;
            Asel = Asel+Ak;
            Ac_temp(:,:,2) = Asel;

            figure(101);
            set(gcf,'Position',[50 50 900 900])
            imagesc(CnC)
            hold on
            im = imagesc(Ac_temp);
            im.AlphaData = 0.3.*(A+Asel);
            axis image

            keep_list(ind) = true;
        end
        
    else
        good = 0;
    end

    if count>lim
        good = 0;
    end
    
end

Ag = A_keep(:,keep_list);
Tg = T_keep(keep_list,:);

save([file(1:end-20) 'ground_truth.mat'],'Ag','Tg');
