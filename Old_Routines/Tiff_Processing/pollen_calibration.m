clc

addpath(genpath('C:\Users\myadmin\Documents\MATLAB\ScanImageTiffReader\share\matlab\'))

[filename,filepath] = uigetfile('*.tif','Select file:','E:\Data','MultiSelect','off');
filename = filename(1:end-4);

% filepath = '\\V-2PRAM2\Data\20190731\';

ny = 145;
nx = 144;
nc = 30;
nt = 50;

zoom = 2;

nz = 300;
DZ = 2;

dx = 600/zoom/nx;
dy = 600/zoom/ny;

amt = 4./DZ;
order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

if exist([filepath filename '.mat'], 'file') < 2

    vol = ScanImageTiffReader([filepath filename '.tif']).data();

    vol = reshape(vol,ny,nx,nc,nt,nz);

    vol = vol - mean(mean(mean(mean(mean(vol,1),2),3),4),5);

    vol = mean(vol,4);
    vol = reshape(vol,ny,nx,nc,nz);

    save([filepath filename '.mat'],'vol','-v7.3')

else
    load([filepath filename '.mat'])
end

Imax = max(movmean(movmean(vol,1),2),[],4);

figure(701)

for ijk = 1:nc
    subplot(5,6,ijk)
    imagesc(Imax(:,:,order(ijk))')
    axis equal
    xlim([1 ny])
    ylim([1 nx])
    colormap(gray)
    set(gca,'xtick',[],'ytick',[])
end

%% Select beams

num = 12;

xs = zeros(1,nc);
ys = zeros(1,nc);

Iz = zeros(nc,nz);

III = zeros(2*num+1,2*num+1,nc);

for kk = 1:nc

    figure(901)
    imagesc(Imax(:,:,order(kk)))
    axis equal
    xlim([1 ny])
    ylim([1 nx])
    colormap(gray)
    set(gca,'xtick',[],'ytick',[])
    [x,y] = ginput(1);
    indx = round(x); indy = round(y);
    
    Iz(order(kk),:) = reshape(max(max(movmean(movmean(vol(indy-num:indy+num,indx-num:indx+num,order(kk),:),3,1),3,2))),1,[]);
%     Iz(order(kk),:) = reshape(mean(mean(movmean(movmean(vol(indy-num:indy+num,indx-num:indx+num,order(kk),:),3,1),3,2))),1,[]);

    [mx,zoi] = max(movmean(Iz(order(kk),:),amt));
    
    figure(101)
    subplot(5,6,kk)
    imagesc(-num:num,-num:num,reshape(vol(indy-num:indy+num,indx-num:indx+num,order(kk),zoi),num*2+1,num*2+1))
    axis equal
    xlim([-num num])
    ylim([-num num])
    colormap(gray)
    set(gca,'ytick',[],'xtick',[])
    
    xs(kk) = x;
    ys(kk) = y;
    
    III(:,:,kk) = reshape(vol(indy-num:indy+num,indx-num:indx+num,order(kk),zoi),num*2+1,num*2+1);
    
end
    
%%
figure(99)
plot((0:(nz-1))*DZ,sqrt(movmean(Iz(order,:),amt,2)))
grid(gca,'on')
xlabel('Z (\mum)')
ylabel('2p signal (a.u.)')

Z = (1:nz);

zoi = zeros(1,nc);

for ii = 1:nc
    [mx,zoi(ii)] = max(movmean(Iz(ii,:),amt,2),[],2);
end

pp = max(movmean(Iz,amt,2),[],2);

figure(99)
hold on
plot(zoi*DZ,sqrt(pp),'k.','MarkerSize',10)


z1 = -(zoi(order(1:nc/2)) - zoi(nc/2))*DZ;
p1 = sqrt(pp(order(1:nc/2)));

z2 = -(zoi(order(nc/2+1:end)) - zoi(order(end)))*DZ;
p2 = sqrt(pp(order(nc/2+1:end)));

% z1 = fliplr(z1);
% p1 = fliplr(p1);
% 
% z2 = fliplr(z2);
% p2 = fliplr(p2);

figure
plot(z1,p1,'bo','MarkerSize',6)
hold on
plot(z2,p2,'bsquare','Color',[0 0.5 0],'MarkerSize',6)
xlabel('Z (\mum)')
ylabel('Power (a.u.)')
grid(gca,'on')
[ft1,g1] = fit(z1',p1,'exp1');
[ft2,g2] = fit(z2',p2,'exp1');

hold on
plot(DZ*linspace(0,nz-1,1001),ft1(DZ*linspace(0,nz-1,1001)),'r-')
plot(DZ*linspace(0,nz-1,1001),ft2(DZ*linspace(0,nz-1,1001)),'k-')
legend('Data (second cavity)','Data (first cavity)',['Fit (ls = ' num2str(1/ft1.b,3) ' um)'],['Fit (ls = ' num2str(1/ft2.b,3) ' um)'],'Location','NorthWest')


figure
semilogy(z1,p1,'bo','MarkerSize',6)
hold on
semilogy(z2,p2,'bsquare','Color',[0 0.5 0],'MarkerSize',6)
xlabel('Z (\mum)')
ylabel('Power (a.u.)')
% grid(gca,'on')
% [ft1,g1] = fit(z1',p1,'exp1');
% [ft2,g2] = fit(z2',p2,'exp1');

hold on
semilogy(DZ*linspace(0,nz-1,1001),ft1(DZ*linspace(0,nz-1,1001)),'r-')
semilogy(DZ*linspace(0,nz-1,1001),ft2(DZ*linspace(0,nz-1,1001)),'k-')
legend('Data (first cavity)','Data (second cavity)',['Fit (ls = ' num2str(1/ft1.b,3) ' um)'],['Fit (ls = ' num2str(1/ft2.b,3) ' um)'],'Location','NorthWest')
xlim([0 300])


figure
plot(1:(nc/2),DZ*zoi(order(1:nc/2)),'bo')
[ft2,goodness,~] = fit((1:nc)',DZ*zoi(order)','poly1');
bb = linspace(0,nc+1,101);
hold on
plot((nc/2)+1:nc,DZ*zoi(order((nc/2)+1:nc)),'gsquare','Color',[0 0.5 0],'markersize',6)
plot(bb,ft2(bb),'k-')
xlabel('Beam number')
ylabel('Z position (\mum)')
legend('Data',['Linear fit (r^2 = ' num2str(goodness.rsquare,3) ')'])

figure
plot(diff(DZ*zoi(order)),'k.','MarkerSize',14)



%% Calibration X, Y

xx = -num:num;
yy = xx;
[XX,YY] = meshgrid(xx,yy);

offx = zeros(1,nc);
offy = zeros(1,nc);

for zz = 1:nc
    IOI = III(:,:,zz);
    
    offx(zz) = round(trapz(trapz(XX.*IOI))./trapz(trapz(IOI)));
    offy(zz) = round(trapz(trapz(YY.*IOI))./trapz(trapz(IOI)));
    
    figure(101);
    subplot(5,6,zz)
    hold on
    plot(offx(zz),offy(zz),'rx','MarkerSize',10)

end

xs = xs+offx;
ys = ys+offy;

vx = (-floor(nx/2):floor(nx/2))*dx;
vy = (-floor(ny/2):floor(ny/2))*dy;

figure
plot(vx(round(xs(1:nc/2))),vy(round(ys(1:nc/2))),'ro','MarkerSize',6)
hold on
plot(vx(round(xs(nc/2+1:end))),vy(round(ys(nc/2+1:end))),'bsquare','MarkerSize',6)
xlabel('X (\mum)')
ylabel('Y (\mum)')
grid(gca,'on')
axis equal
xlim([min(vx) max(vx)])
ylim([min(vy) max(vy)])

diffx = vx(round(xs)); diffx = diffx - diffx(1);
diffy = vy(round(ys)); diffy = diffy - diffy(1);

save('pollen_sample_xy_calibration.mat','diffx','diffy')
