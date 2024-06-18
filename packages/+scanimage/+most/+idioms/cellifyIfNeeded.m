function result = cellifyIfNeeded(thing)
    % If thing is a cell array, returns thing.  Otherwise, returns {thing}.
    % Useful for function args where generally the argument is a cell
    % array, but sometimes the caller wants to call it with a single
    % element.
    if iscell(thing) ,
        result=thing;
    else
        result={thing};
    end
end


%--------------------------------------------------------------------------%
% cellifyIfNeeded.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
