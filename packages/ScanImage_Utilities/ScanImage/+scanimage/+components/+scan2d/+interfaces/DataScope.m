classdef DataScope < handle   
    properties (Abstract, SetObservable)
        trigger;
        triggerLineNumber;
        triggerSliceNumber;
        acquisitionTime;
        channel;
        triggerHoldOffTime;
        callbackFcn;
    end
    
    properties (Abstract, SetAccess = protected, SetObservable)
        active;
        triggerAvailable;
        channelsAvailable;
    end
    
    methods (Abstract)
        start(obj);
        abort(obj);
        acquire(obj);
        mouseHoverInfo2Pix(obj);
    end
end



%--------------------------------------------------------------------------%
% DataScope.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
