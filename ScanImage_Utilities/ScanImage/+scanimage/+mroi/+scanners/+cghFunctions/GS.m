function phi =  GS(scanner,target_intensity)

target_intensity = cast(target_intensity,scanner.computationDatatype);
source_intensity = cast(scanner.geometryBuffer.beamProfileNormalized,scanner.computationDatatype);

target_intensity = abs(target_intensity); % cannot achieve negative intensity

targetSum = sum(sum(target_intensity));
if targetSum ~= 0
    target_intensity = target_intensity / targetSum;
end

target_intensity_ifftshift = ifftshift(target_intensity);

A = ifft2(target_intensity_ifftshift);

for i = 1:10
    B = source_intensity .* exp(1i.*angle(A));
    C = fft2(B);
    
    D = target_intensity_ifftshift .* exp(1i.*angle(C));
    A = ifft2(D);
end

phi = angle(A);
end

%--------------------------------------------------------------------------%
% GS.m                                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
