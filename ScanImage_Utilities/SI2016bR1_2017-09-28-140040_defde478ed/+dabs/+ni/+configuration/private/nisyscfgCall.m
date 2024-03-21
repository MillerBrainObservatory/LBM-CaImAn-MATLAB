function varargout = nisyscfgCall(funcName,varargin)
    if ~libisloaded('nisyscfg')
        loadnisyscfg
    end

    varargout = cell(nargout,1);
    [status,varargout{:}] = calllib('nisyscfg',funcName,varargin{:});
    assert(strcmpi(status,'NISysCfg_OK'),'Function call %s in nisyscfg.dll failed with code %s',funcName,status);
end


%--------------------------------------------------------------------------%
% nisyscfgCall.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
