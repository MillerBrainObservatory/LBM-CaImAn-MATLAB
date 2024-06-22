function [functionName,localFunctionName,packageName] = getFunctionInfo(fileName)
    functionName = '';
    packageName = '';
    localFunctionName = '';
    
    if nargin<1 || isempty(fileName)
        stack = dbstack('-completenames');
        if numel(stack) < 2
            return % called from command window
        end
        fileName = stack(2).file;
        localFunctionName = stack(2).name;
    end
    
    [filepath,functionName,~] = fileparts(fileName);
    fsep = regexptranslate('escape',filesep());
    packageName = regexpi(filepath,['(' fsep '\+[^' fsep '\+]*)*$'],'match','once');
    packageName = regexprep(packageName,[fsep '\+'],'.');
    packageName = regexprep(packageName,'^\.','');

    if strcmpi(functionName,localFunctionName)
        localFunctionName = '';
    end
end

%--------------------------------------------------------------------------%
% getFunctionInfo.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
