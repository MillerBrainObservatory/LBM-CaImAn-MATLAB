function handles = setHandleStructGuideStyle(hFig)
% generates the handle_struct (as known for guide GUIs) for a figure and
% set it as guidata for the figure. Only objects with the property 'Tag'
% set are included

hFig = ancestor(hFig,'figure'); % ensure h is a figure handle
objs = findobj(hFig); % get all children of figure
objs = [hFig,objs(:)']; % include figure itself is an object as well

handles = struct();

% find all objects with property 'Tag' set and add to handles struct
for idx = 1:length(objs)
    obj = objs(idx);
    tag = get(obj,'Tag');
    if ~isempty(tag)
        handles.(tag) = obj;
    end
end

% set handles as guidata for figure
guidata(hFig,handles);
end

%--------------------------------------------------------------------------%
% setHandleStructGuideStyle.m                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
