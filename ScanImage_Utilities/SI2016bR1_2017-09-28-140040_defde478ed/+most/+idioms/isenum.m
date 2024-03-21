function out = isenum(value)
%ISENUM Returns true if the class contains an enumeration.
%
%   OUT = isenum(OBJ) returns true if the object, OBJ, is a class containing
%   enumeration values.
%
%   OBJ may be a meta.class object for the class of interest, or an instance of
%   the class.
%
%   OUT = isenum(CLASSNAME) treats the string, CLASSNAME, as the name of the
%   class.

if ischar(value)
    value = eval(['?' value]);
end

if ~isa(value, 'meta.class')
    value = metaclass(value);
end

out = ~isempty(value) && ~isempty(value.EnumerationMemberList);


%--------------------------------------------------------------------------%
% isenum.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
