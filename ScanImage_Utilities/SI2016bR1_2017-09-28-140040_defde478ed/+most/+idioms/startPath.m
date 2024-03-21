function startPath = startPath()
%STARTPATH Gives path simply of drive on which Matlab is installed
%   This can be useful as input to uiputfile,uigetfile,uigetdir, rather than using the Matlab current directory

mlroot = matlabroot();
startPath = mlroot(1:3); %e.g. c:\

end



%--------------------------------------------------------------------------%
% startPath.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
