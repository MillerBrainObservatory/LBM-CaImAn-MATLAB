function lh = addweaklistener(varargin)%
% the function addweaklistener mimics the built in matlab function addlistener
% in contrast to addlistener, this function generates a listener object
% which does not add to the reference count of the owning object - it
% creates a 'weak reference'
%
% Usage
% el = ADDLISTENER(hSource, 'Eventname', Callback)
% el = ADDLISTENER(hSource, PropName, 'Eventname', Callback)
%
% review the matlab documentation page 'Listener Lifecycle' for more
% information on the topic

if length(varargin) == 3
    % mimics lh = addlistener(Hsource,EventName,callback)
    Hsource   = varargin{1};
    EventName = varargin{2};
    callback  = varargin{3};
    lh = event.listener(Hsource,EventName,callback);    
elseif length(varargin) == 4
    % mimics lh = addlistener(Hsource,property,EventName,callback)
    Hsource   = varargin{1};
    property  = varargin{2};
    EventName = varargin{3};
    callback  = varargin{4};
    % get meta property objects for given event names
    mps = cellfun(@(propname)findprop(Hsource,propname),cellstr(property),'UniformOutput',false);
    lh = event.proplistener(Hsource,mps,EventName,callback);
else
    error('Incorrect use of ''addweaklistener'': Expect 3 or 4 input arguments');
end
end

%--------------------------------------------------------------------------%
% addweaklistener.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
