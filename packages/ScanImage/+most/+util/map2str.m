function s = map2str(m)
%MAP2STR Convert a containers.Map object to a string
% s = map2str(m)
%
% Empty maps are converted to the empty string ''.

keyType = m.KeyType;
keys = m.keys;
Nkey = numel(keys);

s = '';
if Nkey > 0
    for c = 1:Nkey
        ky = keys{c};
        val = m(ky);
        switch keyType
            case 'char'
                keystr = ky;
            otherwise
                keystr = num2str(ky); % currently, ky must be a numeric scalar (see help containers.Map)
        end
        str = sprintf('%s: %s | ',keystr,most.util.toString(val));
        s = [s str]; %#ok<AGROW>
    end
    s = s(1:end-3); % take off last |
end

end


%--------------------------------------------------------------------------%
% map2str.m                                                                %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
