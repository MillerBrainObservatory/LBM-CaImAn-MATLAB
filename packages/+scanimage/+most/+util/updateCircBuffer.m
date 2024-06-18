function updated = updateCircBuffer(buffer,newVal,bufferSize)
    if ~iscolumn(buffer)
       buffer = buffer'; 
    end
    
    if length(buffer) < bufferSize
       buffer(end+1) = newVal;
       updated = buffer;
    else
        buffer = circshift(buffer,-1,1);
        buffer(end) = newVal;
        updated = buffer;
    end
    
end
    

%--------------------------------------------------------------------------%
% updateCircBuffer.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
