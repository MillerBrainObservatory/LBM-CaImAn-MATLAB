function data = expInterpolateCircularNaNRanges(data,expCnst)
nanRanges = scanimage.mroi.util.findNaNRanges(data);
if isempty(nanRanges);return;end % Nothing to interpolate

if isnan(data(1)) && isnan(data(end))
    shifted = nanRanges(end,2)-nanRanges(end,1)+1;
    data = circshift(data,shifted);
    nanRanges = scanimage.mroi.util.findNaNRanges(data);
else
    shifted = 0;
end

for i = 1:size(nanRanges,1)
    istrt = nanRanges(i,1);
    iend = nanRanges(i,2);
    
    if istrt == 1
        ystrt = data(end);
    else
        ystrt = data(istrt-1);
    end
    
    if iend == numel(data)
        yend = data(1);
    else
        yend = data(iend+1);
    end
    
    if ystrt == yend
        data(istrt:iend) = ystrt;
    else
        npts = iend-istrt+1;
        if isinf(expCnst)
            data(istrt:iend) = linspace(ystrt,yend,npts);
        else
            dz = expCnst*log(yend/ystrt);
            zs = linspace(dz/npts,dz*(1-1/npts),npts);
            data(istrt:iend) = ystrt * exp(zs/expCnst);
        end
    end
end


if shifted ~= 0
    data = circshift(data,-shifted); % shift data back
end
end


%--------------------------------------------------------------------------%
% expInterpolateCircularNaNRanges.m                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
