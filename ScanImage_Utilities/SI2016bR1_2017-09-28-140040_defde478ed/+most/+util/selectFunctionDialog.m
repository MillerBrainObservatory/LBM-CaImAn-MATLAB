function fh = selectFunctionDialog(varargin)
fh = [];
[fileName,pathName] = uigetfile({'*.m','*.p'},varargin{:});
if isnumeric(fileName) && fileName == 0
    return % user cancelled
end

packageName = regexp(pathName,'(?<=\\\+).*$','match','once');
packageName = regexprep(packageName,'\\\+','.');
packageName = regexprep(packageName,'\\','');

fileName = regexprep(fileName,'(\.m|\.p)$','');

if isempty(packageName)
    functionName = fileName;
else
    functionName = strjoin({packageName,fileName},'.');
end

fh = str2func(functionName);
end

%--------------------------------------------------------------------------%
% selectFunctionDialog.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
