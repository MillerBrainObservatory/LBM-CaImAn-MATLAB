function tf = graphics2014b()
    % Matlab introduced the HG2 graphics engine in Matlab 2014b
    % this function returns true if Matlab 2014b or later is currently used
    %
    % Performance tip: if called frequently, cache the return value of this
    %     function (e.g. in a constant property of a class)
    tf = ~verLessThan('matlab', '8.4');
end


%--------------------------------------------------------------------------%
% graphics2014b.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
