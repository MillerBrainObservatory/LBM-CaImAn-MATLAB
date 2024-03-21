function todoNotice(varargin)
    stack  = dbstack();
    mFile = stack(2).name;      % caller name
    lineNumber = stack(2).line; % line number of caller
    
    fprintf('%s:%d: Todo: ',mFile,lineNumber);
    fprintf(varargin{:});
    fprintf('\n');
end


%--------------------------------------------------------------------------%
% todoNotice.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
