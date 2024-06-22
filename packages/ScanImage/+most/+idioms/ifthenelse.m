function out = ifthenelse(if_,then_,else_)
    validateattributes(if_,{'logical','numeric'},{'scalar','nonnan'});
    
    if if_
        out = then_;
    else
        out = else_;
    end
end

%--------------------------------------------------------------------------%
% ifthenelse.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
