function makeMovie(data, filename, x, y, frameRate, avgs, cax, scaleBar, rect, zoom, decenter, buffer, crf)

%% Parse inputs

do_zoom = 1;

if isempty(cax)
    [N,bns] = histcounts(data(:),'normalization','cdf');
    ind1 = dsearchn(N',0.1);
    ind2 = dsearchn(N',0.995);
    cax = [bns(ind1) bns(ind2)];
elseif cax(2) < 1
    [N,bns] = histcounts(data(:),'normalization','cdf');
    ind1 = dsearchn(N',cax(1));
    ind2 = dsearchn(N',cax(2));
    cax = [bns(ind1) bns(ind2)];
end

if isempty(buffer)
    buffer = 3;
end

if isempty(crf)
    crf = 17;
end

if isempty(avgs)
    avgs = 1;
end

if isempty(x) || isempty(y)
    x = 1:size(data,2);
    y = 1:size(data,1);
end

if isempty(rect)
    rect = [];
    do_zoom = 0;
end

if isempty(decenter)
    decenter = [];
    do_zoom = 0;
else
    xp = x(rect(3):rect(4));
    xp = xp-mean(xp);
    yp = y(rect(1):rect(2));
    yp = yp-mean(yp);
end

if isempty(zoom)
    do_zoom = 0;
end



%% begin processing

data = movmean(data,avgs,3);

numFrames = size(data,3);

writerObj = VideoWriter(filename,'Uncompressed AVI');
writerObj.FrameRate = frameRate;
open(writerObj)


h = figure;
set(h,'Position',[50 50 max(x)/max(y)*900+100 900])
imagesc(x,y,data(:,:,1))
axis image
axis off
colormap(gray)
caxis(cax)
hold on

if ~isempty(scaleBar)
    plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
end

set(gca,'YDir','normal','XDir','reverse')
frame = getframe;
siz = size(frame.cdata);

sizY = siz(1)-2*buffer; if sizY/2 ~= round(sizY/2); sizY = sizY-1; end
sizX = siz(2)-2*buffer; if sizX/2 ~= round(sizX/2); sizX = sizX-1; end

clf(h)

kfreeze = 0;

if do_zoom == 0 
    zoom = ones(1,numFrames);
end

for k = 1:numFrames
        
    if do_zoom == 0 || zoom(k) == 1
        imagesc(x,y,data(:,:,k))
        axis image
        axis off
        colormap(gray)
        caxis(cax)
        hold on
        if ~isempty(scaleBar)
            plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
        end
        set(gca,'YDir','normal','XDir','reverse')
        
        frame = getframe;
        I = frame.cdata(buffer+1:sizY+buffer,buffer+1:sizX+buffer,:);
        writeVideo(writerObj,I);
        clf(h)
        
    elseif do_zoom == 1 && zoom(k) > 1
        
        if kfreeze == 0 
            kfreeze = k;
        end
        
        imagesc(x,y,data(:,:,kfreeze))
        axis image
        axis off
        colormap(gray)
        caxis(cax)
        hold on
        if ~isempty(scaleBar)
            plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
        end
        set(gca,'YDir','normal','XDir','reverse')
        
        dp = data(rect(1):rect(2),rect(3):rect(4),k);
        imagesc(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp+decenter(k,1),dp)
        plot(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp(1).*ones(size(xp))+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp(end).*ones(size(xp))+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp(1).*ones(size(yp))+decenter(k,2),zoom(k,1).*yp+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp(end).*ones(size(yp))+decenter(k,2),zoom(k,1).*yp+decenter(k,1),'r-','LineWidth',2)
        
        frame = getframe;
        I = frame.cdata(buffer+1:sizY+buffer,buffer+1:sizX+buffer,:);
        writeVideo(writerObj,I);
        clf(h)

        
    end
end

close(writerObj)
close(h)

ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'none', 'VideoCodec', 'x264', 'x264Tune', 'film', 'x264Preset', 'veryslow', 'x264Crf', crf);
