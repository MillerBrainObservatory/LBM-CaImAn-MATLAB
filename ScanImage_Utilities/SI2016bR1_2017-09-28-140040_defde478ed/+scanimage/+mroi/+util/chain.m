function out=chain(in)
    % form pairs out of input data
    %% (1,2,...,N) -> {{1,2},{2,3},...,{N-1,N}}
    out = cell(numel(in)-1,1);
    for i=1:numel(in)-1
        out{i}={in{i},in{i+1}};
    end
end


%--------------------------------------------------------------------------%
% chain.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
