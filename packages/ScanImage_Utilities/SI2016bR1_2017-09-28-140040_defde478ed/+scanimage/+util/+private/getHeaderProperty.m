function val = getHeaderProperty(imdescription,propfullname)
%
    try
        str = regexpi(imdescription,sprintf('(?<=%s ?= ?).*$',propfullname),'match','once','lineanchors','dotexceptnewline');
    catch
        str = [''''';'];
    end
    if isempty(str);
        str = [''''';'];
    end
    val = eval(str);
end



%--------------------------------------------------------------------------%
% getHeaderProperty.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
