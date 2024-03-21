function selection = selectImages(vararguments,selectionFlags, numItems, flags, flagIndices)
    if any(ismember(selectionFlags,flags))
        selection = scanimage.util.private.getArg(vararguments,selectionFlags, flags, flagIndices);
        %Handle 'inf' specifier in slice array
        if find(isinf(selection))
            selection(isinf(selection)) = [];
            if max(selection) < numItems
                selection = [selection (max(selection)+1):numItems];
            end
        end
        if max(selection) > numItems
            error('Frame, slice or volume values specified are not found in file');
        end
    else
        selection = 1:numItems;
    end
end


%--------------------------------------------------------------------------%
% selectImages.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
