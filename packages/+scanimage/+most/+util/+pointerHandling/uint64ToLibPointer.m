function myLibPointer = uint64ToLibPointer(pointerUint64)
if ~libisloaded('pointerHandling')
    p = fileparts(mfilename('fullpath'));
    p = fullfile(p,'dll');
    
    currentDirectory = pwd();
    try
        cd(p);
        loadlibrary('pointerHandling',@pointerHandling);
        cd(currentDirectory);
    catch ME
        cd(currentDirectory);
        rethrow(ME);
    end
end

assert(isa(pointerUint64,'uint64'),'Expected input to be a uint64');
myLibPointer = calllib('pointerHandling','uint64ToLibPointer',pointerUint64);
end



%--------------------------------------------------------------------------%
% uint64ToLibPointer.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
