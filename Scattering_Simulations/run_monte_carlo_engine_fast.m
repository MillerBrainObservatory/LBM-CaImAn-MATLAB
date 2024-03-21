clear 
close all
clc

Nr = 1e7; % number of photon packets
w0 = 0.6005e-6; % target spot size in sample
tau = 100e-15; % pulse duration
n = 1.36; % refractive index
lambda0 = 0.96e-6; % wavelength
g = 0.9; % anisotropy parameter
ls = 166e-6; % scattering length

zR = n*pi*w0^2/lambda0; % Rayleigh range
nax = 1; % number of axial points for axial PSF calculation
axial_range = 0;% linspace(-2*zR,2*zR,nax); % range to compute axial PSF over


zs = (100:100:900).*1e-6; % depth of focal point in sample
nz = numel(zs);

wFWHM = zeros(nz,nax);
zFWHM = zeros(nz,1);

axFlag = 0;

for ijk = 1:nz
    
    zfocal = zs(ijk);
    disp(['BEGINNING CALCULATIONS FOR Z = ' num2str(zfocal*1e6,3) ' um DEPTH...'])
    
    for abc = 1:nax
        
        disp(['Calculating axial slice # ' num2str(abc) ' of ' num2str(numel(axial_range)) '...'])
    
        ztarget = zfocal + axial_range(abc); % depth of plane of interest in sample
        [xout,yout,zout] = gaussian_informed_monte_carlo_engine_fast(Nr,w0,zfocal,ztarget,ls,g,n,lambda0); % calculate scatter

        r = sqrt(xout.^2 + yout.^2); % calculate radial distribution
        rmx = 100*w0; % max radial position to consider
        res = w0/101; % resolution with which to analyze the distribution
        Nbins = ceil(rmx/res); % number of bins for histogram
        r(r>rmx) = NaN; % ignore data beyond max radial position

        [counts,pos] = histcounts(r.*1e6,Nbins); % histogram of radial distribution
        psf2p = counts.^4; % 2p PSF is proportional to E^4
        pos = pos(2:end) - pos(2)/2; % radial position vector
        ft = fit(pos', psf2p','gauss1','Lower',[-Inf 0 -Inf],'Upper',[Inf 0 Inf]); % Gaussian fit
        wFWHM(ijk,abc) = 2*ft.c1; % FWHM predicted by fit

        %% Display
        if ztarget == zfocal

            % Histogram of radial distribution
%             figure;
%             hr = histogram(r.*1e6,Nbins);
%             rvec = hr.BinEdges;
%             rvec = rvec(2:end) - rvec(2)/2;
%             Er = hr.Values;
%             ftr = fit(rvec',Er.^4','gauss1','Lower',[-Inf 0 -Inf],'Upper',[Inf 0 Inf]);
%             set(gca,'FontSize',14)
%             set(gcf,'Color',[1 1 1])
%             xlabel('r (\mum)')
%             ylabel('Number of incident photons')
%             xlim([0 rmx*1e6])
    
            % 2p PSF with Gaussian fit
            figure(100)
            subplot(floor(sqrt(nz)),ceil(sqrt(nz)),ijk)
            plot(pos,psf2p,'r.','MarkerSize',6)
            hold on
            plot(pos,ft(pos),'k-')
            set(gca,'Fontsize',10)
            set(gcf,'Color',[1 1 1])
            xlabel('r (\mum)')
            ylabel('Intensity (a.u.)')
            legend('Data',['Fit (FWHM = ' num2str(2*sqrt(log(2))*ft.c1,3) ' \mum)'])
            xlim([0 2])
            title(['z = ' num2str(ztarget*1e6,3) ' \mum'])
 
            % Determine encircled energy
            FWHM = w0/1.2011;
            r(r>1.5*FWHM) = NaN;
            p(ijk) = sum(~isnan(r))/Nr;

            % Form an image
            xymx = 3*FWHM;
            resxy = w0/11;
            nbins = round(2*xymx/resxy);
            xxx = xout;
            xxx(abs(xout)>xymx) = NaN;
            yyy = yout;
            yyy(abs(yout)>xymx) = NaN;

            [Exy,xg,yg] = histcounts2(xxx,yyy,nbins);

            figure(101)
            subplot(floor(sqrt(nz)),ceil(sqrt(nz)),ijk)
            imagesc(xg.*1e6,yg.*1e6,Exy)
            set(gca,'FontSize',10)
            set(gcf,'Color',[1 1 1])
            xlabel('X (\mum)')
            ylabel('Y (\mum)')
            axis equal
            colormap(fire)
            xlim([min(xg).*1e6 max(xg).*1e6])
            ylim([min(yg).*1e6 max(yg).*1e6])
            title(['z = ' num2str(ztarget*1e6,3) ' \mum'])

        end
    end

    if axFlag > 0
        s2p = 1./(wFWHM(ijk,:)).^2;
        val = 1e-2 * max(s2p);
        s2p(s2p<val) = NaN;

    %     figure
    %     plot(axial_range.*1e6,s2p,'b.','MarkerSize',14)

        c = linspace(0.5,2,101);
        d = linspace(0.5,2,101);
        rms = zeros(numel(c),numel(d));

        for xx = 1:numel(c)
            for yy = 1:numel(d)
                fc = d(yy).*max(s2p)./(1 + c(xx).*axial_range.^2./zR.^2);
                e = s2p - fc;
                rms(xx,yy) = sqrt(nanmean(e.^2));
            end
        end

        [mn,inds] = min2d(rms);
        indx = inds(1);
        indy = inds(2);
        zz = linspace(min(axial_range),max(axial_range),101);
        ff = d(indx).*max(s2p)./(1 + c(indy).*zz.^2./zR.^2);

    %     hold on
    %     plot(zz.*1e6,ff,'k-')
    %     set(gca,'FontSize',14)
    %     set(gcf,'Color',[1 1 1])
    %     xlabel('z (\mum)')
    %     ylabel('2p signal (a.u.)')

        zFWHM(ijk) = 2/sqrt(c(indy))*zR;

    %     legend('Data',['Fit (FWHM = ' num2str(zFWHM(ijk)*1e6,3) ' \mum)'])
    end
end

figure;
plot(zs.*1e6,zFWHM.*1e6,'r.','MarkerSize',14)
set(gca,'FontSize',14)
set(gcf,'Color',[ 1 1 1])
xlabel('z (\mum)')
ylabel('Axial FWHM (\mum)')
legend('Data')

ind = ceil(nax/2);

figure
plot(zs.*1e6,sqrt(log(2)).*wFWHM(:,ind),'b.','MarkerSize',14)
set(gca,'FontSize',14)
set(gcf,'Color',[1 1 1])
xlabel('z (\mum)')
ylabel('Lateral FWHM (\mum)')
legend('Data')

figure
semilogy(zs.*1e6,p.*100,'LineStyle','none','Marker','.','Color',[0 0.5 0],'MarkerSize',14)
hold on
semilogy(zs.*1e6,100*exp(-zs./ls),'k-')
set(gca,'FontSize',14)
set(gcf,'Color',[1 1 1])
xlabel('z (\mum)')
ylabel('Proporiton of ballistic photons (%)')
legend('Data',['Fit (l_s = ' num2str(ls*1e6) ' \mum)'])