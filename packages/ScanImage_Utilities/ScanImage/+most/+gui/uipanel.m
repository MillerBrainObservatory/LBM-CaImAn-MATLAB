function h = uipanel(varargin)
    ip = most.util.InputParser;
    ip.addOptional('WidthLimits',[]);
    ip.addOptional('HeightLimits',[]);
    ip.parse(varargin{:});
    [~,otherPVArgs] = most.util.filterPVArgs(varargin,{'WidthLimits' 'HeightLimits'});
    
    h = uipanel(otherPVArgs{:});
    
    if ~isempty(ip.Results.WidthLimits)
        lms = [ip.Results.WidthLimits ip.Results.WidthLimits(1)];
        set(h, 'WidthLimits', lms(1:2));
    end
    if ~isempty(ip.Results.HeightLimits)
        lms = [ip.Results.HeightLimits ip.Results.HeightLimits(1)];
        set(h, 'HeightLimits', lms(1:2));
    end
end


%--------------------------------------------------------------------------%
% uipanel.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
