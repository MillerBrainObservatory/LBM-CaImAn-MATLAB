function valid = str2validName(propname, prefix)
% CONVERT2VALIDNAME
% Converts the property name into a valid matlab property name.
% propname: the offending propery name
% prefix: optional prefix to use instead of the ambiguous "dyn"
valid = propname;
if isvarname(valid) && ~iskeyword(valid)
    return;
end

if nargin < 2 || isempty(prefix)
    prefix = 'dyn_';
else
    if ~isvarname(prefix)
        warning('Prefix contains invalid variable characters.  Reverting to "dyn"');
        prefix = 'dyn_';
    end
end

% general regex /[a-zA-Z]\w*/

%find all alphanumeric and '_' characters
valididx = isstrprop(valid, 'alphanum');
valididx(strfind(valid, '_')) = true;

% replace all invalid characters with '_' for now
valid(~valididx) = '_';

if isempty(valid) || ~isstrprop(valid(1), 'alpha') || iskeyword(valid)
    valid = [prefix valid];
end
end

%--------------------------------------------------------------------------%
% str2validName.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
