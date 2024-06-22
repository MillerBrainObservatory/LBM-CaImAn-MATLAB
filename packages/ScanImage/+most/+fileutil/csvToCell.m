function str = csvToCell(filename, delimiter, delimiterIsRegex)
if nargin < 2 || isempty(delimiter)
    delimiter = ',';
end

if nargin < 3 || isempty(delimiterIsRegex)
    delimiterIsRegex = false;
end

validateattributes(delimiter,{'char'},{'row'});
validateattributes(delimiterIsRegex,{'numeric','logical'},{'scalar','binary'});

if ~delimiterIsRegex
    delimiter = regexptranslate('escape',delimiter);
end

str = readFileContent(filename);

% split into lines
str = regexp(str,'\s*[\r\n]+\s*','split')';
if isempty(str{end})
    str(end) = [];
end

% split at delimiter into cells
delimiter = ['\s*' delimiter '\s*']; % ignore white space characters around delimiter
str = regexp(str,delimiter,'split');
str = vertcat(str{:});
end

function str = readFileContent(filename)
    assert(exist(filename,'file')~=0,'File %s not found',filename);
    hFile = fopen(filename,'r');
    try
        % read entire content of file
        str = fread(hFile,'*char')';
        fclose(hFile);
    catch ME
        % clean up in case of error
        fclose(hFile);
        rethrow(ME);
    end
end

%--------------------------------------------------------------------------%
% csvToCell.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
