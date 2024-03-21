function h = cycleModeControlsV5(policy, visible, controller)
% CYCLEMODECONTROLSV5 GUI for setting cycle-mode options
%
    if nargin < 3 || isempty(visible) || ~visible
        visible = 'off';
    else
        visible = 'on';
    end

    delListener = [];
    delayedListener = [];

    h = cycleModeControlsV5_fig('new',visible,controller); % Return the handle

end


%--------------------------------------------------------------------------%
% cycleModeControlsV5.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
