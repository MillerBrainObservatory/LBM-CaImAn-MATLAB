function setLegendEntryVisible(handles,status)
% array of graphics objects in a figure
% status = 'off' or 'on'
%
% Note: after calling this function, the legend must be updated to reflect
% the change
% 
% for more details, see matlab doc:
% http://www.mathworks.com/help/releases/R2012a/techdoc/creating_plots/braliom.html#bram7nu
if ~ischar(status)
    if status
        status = 'on';
    else
        status = 'off';
    end
end

for h = handles
    hAnnotation = get(h,'Annotation');
    hLegendEntry = get(hAnnotation','LegendInformation');
    set(hLegendEntry,'IconDisplayStyle',status);
end
end



%--------------------------------------------------------------------------%
% setLegendEntryVisible.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
