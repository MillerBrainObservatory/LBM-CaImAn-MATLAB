function fileHeader = decodeHeaderLines(rows)
    for idxLine = 1:numel(rows)
        % deal with nonscalar nested structs/objs
        pat = '([\w]+)__([0123456789]+)\.';
        replc = '$1($2).';
        row = regexprep(rows{idxLine},pat,replc);
        
        if idxLine > 1 && isempty(row)
            return % an empty line indicates the transition into mROI data
        end

        % handle unencodeable value or nonscalar struct/obj
        unencodeval = '<unencodeable value>';
        if strfind(row,unencodeval)
            row = strrep(row,unencodeval,'[]');
        end

        % Handle nonscalar struct/object case
        nonscalarstructobjstr = '<nonscalar struct/object>';
        if strfind(row,nonscalarstructobjstr)
            row = strrep(row,nonscalarstructobjstr,'[]');
        end

        % handle ND array format produced by most.util.array2Str
        try
            if ~isempty(strfind(row,'&'))
                equalsIdx = strfind(row,'=');
                [dimArr,rmn] = strtok(row(equalsIdx+1:end),'&');
                arr = strtok(rmn,'&');
                arr = reshape(str2num(arr),str2num(dimArr)); %#ok<NASGU,ST2NM>
                eval(['fileHeader.' row(1:equalsIdx+1) 'arr;']);
            else
                eval(['fileHeader.' row ';']);
            end
        catch ME %Warn if assignments to no-longer-extant properties are found
            equalsIdx = strfind(row,'=');
            if strcmpi(ME.identifier,'MATLAB:noPublicFieldForClass')
                warnMsg = sprintf(1,'Property ''%s'' was specified, but does not exist for class ''%s''\n', deblank(row(3:equalsIdx-1)),class(s));
                most.idioms.warn(warnMsg);
            else
                most.idioms.warn('Could not decode header line: %s', row);
            end
        end
    end
end



%--------------------------------------------------------------------------%
% decodeHeaderLines.m                                                      %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
