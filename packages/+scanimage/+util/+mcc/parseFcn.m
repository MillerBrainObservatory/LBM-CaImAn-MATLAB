function parsed = parseFcn(filename)
%this function parses the headers of a given function file and returns a struct
%with fields:
% argnames = {argument names}
% outnames = {output names}
% persistnames = {persistent var names}
% fcn = char vector containing the body of the function
% name = char vector containing the name of the function
parsed = struct();
if exist(filename, 'file') ~= 2
    warning([filename ' does not exist as a readable file.']);
    return;
end
fid = fopen(filename);
scriptText = fread(fid, '*char')';
fclose(fid);
if isempty(strfind(scriptText, sprintf('\n')))
    warning([filename ' might not be a matlab function file.']);
    return;
end

nlIndices = strfind(scriptText, sprintf('\n'));

parsed.argnames = {};
%find function args and name
closeBraceIndices = strfind(scriptText(1:nlIndices(1)), ')');
if ~isempty(closeBraceIndices)
    argEndIdx = closeBraceIndices(1)-1;
    openBraceIndices = strfind(scriptText(1:closeBraceIndices(1)), '(');
    argStartIdx = openBraceIndices(1)+1;
    
    parsed.argnames = strip(split(...
        scriptText(argStartIdx:argEndIdx), ','));
end

parsed.outnames = {};
%find output args if exists
eqIdx = strfind(scriptText(1:nlIndices(1)), '=');
if ~isempty(eqIdx)
    openBracketIdx = strfind(scriptText(1:eqIdx), '[');
    if isempty(openBracketIdx)
        parsed.outnames = regexp(scriptText(1:eqIdx), 'function\s+(\S+)\s+=', 'tokens', 'once');
    else
        endBracketIdx = strfind(scriptText(1:eqIdx), ']');
        parsed.outnames = strip(split(...
            scriptText(openBracketIdx+1:endBracketIdx-1), ','));
    end
end

%find name
[~, parsed.name, ~] = fileparts(filename);

%find persistent variables
parsed.persistnames = {};
if ~isempty(strfind(scriptText, 'persistent'))
    persist_pat = '^\s*persistent\s+([^;\n]+)';
    persist_lines = regexp(scriptText, persist_pat, 'tokens', 'lineanchors');
    if ~isempty(persist_lines)
        persist_vars = strip(split([persist_lines{:}], ','));
        parsed.persistnames = reshape(persist_vars, numel(persist_vars), 1);
    end
end

endIndices = strfind(scriptText, 'end');
endIndex = endIndices(end);
fcn = strip(scriptText(nlIndices(1)+1:endIndex-1));
parsed.fcn = regexprep(fcn, '^\s*persistent\s+[\w,\s]+;\s*$', '', 'lineanchors');
end

%--------------------------------------------------------------------------%
% parseFcn.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
