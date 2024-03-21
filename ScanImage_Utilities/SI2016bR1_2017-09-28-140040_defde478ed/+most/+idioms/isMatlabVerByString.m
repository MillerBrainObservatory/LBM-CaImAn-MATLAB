function tf = isMatlabVerByString(queryString)
% ISMATLABVERBYSTRING  Returns true if the current matlab version is the one specified by the string. Returns false otherwise.
%   The main purpose of this function is to evaluate a specific matlab version instead of relying
%   on Matlab's native isVerLessThan method so we can add some specific optimizations and later 
%   aid us in isolating sections to remove when support for older versions is deprecated
%   NOTE: The query string must be in the same format as the following examples:
%       '(R2013a)'
%       '(R2015a)'
%       '(R2015b)'
%
    tf = false;

    matlabVer = ver('MATLAB');

    if strcmp(matlabVer.Release, queryString)
        tf = true;
    end
end



%--------------------------------------------------------------------------%
% isMatlabVerByString.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
