function A = inPlaceTranspose(A)
ASize = size(A);
frameSize = [size(A,1), size(A,2)];
frameNumPixels = prod(frameSize);

if frameSize(1) > 1 && frameSize(2) > 1
    frame = zeros(frameSize,'like',A);
    frame = frame + 1; % to ensure nothing else references frame
    for startIdx = 1:frameNumPixels:numel(A)
        frame = reshape(frame,frameSize);
        most.memfunctions.inplacewrite(frame,A,1,startIdx,frameNumPixels);
        frame = frame';
        most.memfunctions.inplacewrite(A,frame,startIdx,1,frameNumPixels);
    end
end

A = reshape(A,ASize([2 1,3:end]));
end

%--------------------------------------------------------------------------%
% inPlaceTranspose.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
