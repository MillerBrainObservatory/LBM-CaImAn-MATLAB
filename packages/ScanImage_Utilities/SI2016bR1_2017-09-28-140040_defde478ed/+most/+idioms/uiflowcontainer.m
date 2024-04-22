% uiflowcontainer
%  A stub function for calling HG uiflowcontainer()

function h = uiflowcontainer(varargin)
persistent MATLABPre2008b

if isempty(MATLABPre2008b)    
    MATLABPre2008b = verLessThan('matlab', '7.7');
end

if MATLABPre2008b
    h = uiflowcontainer(varargin{:});
else
    h = uiflowcontainer('v0', varargin{:});
end


%--------------------------------------------------------------------------%
% uiflowcontainer.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
