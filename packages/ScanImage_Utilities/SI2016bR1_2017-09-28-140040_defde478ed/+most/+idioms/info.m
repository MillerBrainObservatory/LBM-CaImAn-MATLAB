function info(infoStr)
    if ~isempty(infoStr) && ischar(infoStr)
        %colorizedstring = ['<font color=''green''>', 'Information: ', infoStr, '</font>'];
        fprintf('%s\n', ['ScanImage INFORMATION: ', infoStr]);
    end
end




%--------------------------------------------------------------------------%
% info.m                                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
