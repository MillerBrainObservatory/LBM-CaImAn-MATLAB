function outstr = fixsymbols(instr)

% Convert < and > to html-friendly characters; but do not convert them
% if they are part of an html tag, because then they will show up as
% symbols rather than links inside the Help browser.  So, we need to first
% split the string up so that we don't look at the html tags when replacing
% the symbols with the html-friendly characters.

%   Copyright 2007-2012 The MathWorks, Inc.

instr  = strrep(instr, '&', '&amp;');
expr = '<a\shref\s?=\s?.*?>.*?</a>';
[startpos, endpos, matches] = regexp(instr, expr,'start','end','match');

if ~isempty(startpos)
    startpos = [startpos-1 length(instr)];
    endpos = [1 endpos+1];
    outstr = '';
    for i=1:length(startpos)
        % convert < and > to html-friendly characters
        segment = instr(endpos(i):startpos(i));
        segment = strrep(segment, '<', '&lt;');
        segment = strrep(segment, '>', '&gt;'); 
                
        if i<=length(matches)
            % if there are any help links, convert them to helpwin
            outstr  = [outstr segment regexprep(matches{i}, '\<matlab:help\>', 'matlab:helpwin')];
        else
            % append the rest of the help text
            outstr = [outstr segment];
        end
    end
else
    instr  = strrep(instr, '<', '&lt;');
    outstr = strrep(instr, '>', '&gt;'); 
end



%--------------------------------------------------------------------------%
% fixsymbols.m                                                             %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
