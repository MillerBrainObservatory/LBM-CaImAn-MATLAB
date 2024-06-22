function c = vidrioBlue(class_)
    if nargin<1 || isempty(class_)
        class_ = 'double';
    end
    
    c = [85, 152, 216];
    
    switch class_
        case 'uint8'
            c = uint8(c);
        otherwise
            c = c/255;
    end
end



%--------------------------------------------------------------------------%
% vidrioBlue.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
