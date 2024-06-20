function tf = isunique(A,varargin)
tf = numel(unique(A,varargin{:})) == numel(A);
end



%--------------------------------------------------------------------------%
% isunique.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
