load('pollen_calibration_MAxiMuM_30x_00001.mat')


%%

BG = vol(1:10,1:10,:,:);
BG = mean(BG(:));
vol = vol-BG;

volV = zeros(size(vol,1)*5, size(vol,2)*6,size(vol,4));

order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

for aa = 1:5
    for bb = 1:6
        ys = (aa-1)*145+1;
        ye = 145*aa;
        xs = (bb-1)*144+1;
        xe = 144*bb;
        p = (aa-1)*6 + bb;
        poi = vol(:,:,order(p),:);
        poi = movmean(poi,5,3);
        poi = poi./max(poi(:));
        volV(ys:ye,xs:xe,:) = poi;
        
    end
end


%%

figure;
imagesc(volV(:,:,1))
axis image
colormap(gray)
set_caxis(volV)

%%

filename = 'pollen_movie.avi';
x = 1:size(volV,2);
y = 1:size(volV,1);
frameRate = 24;
avgs = 1;

make__Movie(volV, filename, x, y, frameRate, avgs, [0 1], [], [], [], [], [], [])