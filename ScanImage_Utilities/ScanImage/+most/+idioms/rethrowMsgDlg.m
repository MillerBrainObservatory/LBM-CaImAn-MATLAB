function rethrowMsgDlg(ME,showDlg)
if nargin < 2 || isempty(showDlg)
    showDlg = true;
end

if showDlg
    errmsg = most.idioms.reportError(ME);
    errordlg(errmsg,'Error','modal');
end

rethrow(ME);
end

%--------------------------------------------------------------------------%
% rethrowMsgDlg.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
