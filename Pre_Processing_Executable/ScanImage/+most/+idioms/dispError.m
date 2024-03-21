function dispError(varargin)
% DISPERROR  Show an error to the user without throwing one 
%   The main purpose of this function is to allow itself to be overriden by 
%   a testing framework. 
%   fprintf(2,...) only displays an error but does not throw any, at least on Windows,
%   This function will replace all those instances to allow tests to catch such messages
%   but still allow the user to run most of the code without halting the program.

    assert(~isempty(varargin) && ischar(varargin{1}));
    if isempty(regexp(varargin{1},'\\n$', 'once'));
        varargin{1} = [varargin{1},'\n'];
    end    
    fprintf(2, varargin{:});
end

%--------------------------------------------------------------------------%
% dispError.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
