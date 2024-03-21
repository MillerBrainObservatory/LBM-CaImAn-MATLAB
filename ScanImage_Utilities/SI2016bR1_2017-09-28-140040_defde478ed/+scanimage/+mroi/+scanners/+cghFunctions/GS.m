function phi =  GS(scanner,target)
target = cast(target,scanner.computationDatatype);
target = target / sum(sum(target));
target_ifftshift = ifftshift(target);
source = cast(scanner.geometryBuffer.beamProfileNormalized,scanner.computationDatatype);

% figure
% hAx = subplot(1,2,2);
% imhol = imagesc('Parent',hAx);
% axis(hAx,'image');
% title('Simulation');
% 
% hAx = subplot(1,2,1);
% imphasemask = imagesc('Parent',hAx);
% colormap gray;
% axis(hAx,'image');
% title('Phase mask');

A = ifft2_(target);

for i = 1:10
    B = source .* exp(1i.*angle(A));
    C = fft2(B);
    
    %imhol.CData = abs(C);
    
    D = target_ifftshift .* exp(1i.*angle(C));
    A = ifft2(D);
    
    %imphasemask.CData = angle(A);
    %drawnow('limitrate');
end
%drawnow();

phi = angle(A);
end

function out = fft2_(in)
out = fftshift(fft2(in));
end

function out = ifft2_(in)
out = ifft2(ifftshift(in));
end

%--------------------------------------------------------------------------%
% GS.m                                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
