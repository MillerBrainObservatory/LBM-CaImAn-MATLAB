function pointerUint64 = libPointerToUint64(myLibPointer)
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

assert(isa(myLibPointer,'lib.pointer'),'Expected input to be a lib.pointer');
myUint64Ptr = libpointer('uint64Ptr',0);
calllib('pointerHandling','libPointerToUint64',myLibPointer,myUint64Ptr);

pointerUint64 = myUint64Ptr.Value;
end




%--------------------------------------------------------------------------%
% libPointerToUint64.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
