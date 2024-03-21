classdef StreamInterface < handle
  events (NotifyAccess = protected)
    Updated;
  end
  
  methods (Abstract)
    %returns the buffer's string as cell array
    str = getString(obj)
    doClc(obj)
  end
end

%--------------------------------------------------------------------------%
% StreamInterface.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
