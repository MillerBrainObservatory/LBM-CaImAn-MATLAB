function out = className(className,type)
%className - returns the name / related paths of a class
%
% SYNTAX
%     s = className(className)
%     s = className(className,type)
%     
% ARGUMENTS
%     className: object or string specifying a class
%     type:      <optional> one of {'classNameShort','classPrivatePath','packagePrivatePath','classPath'}
%                   if omitted function defaults to 'classNameShort' 
%
% RETURNS
%     out - a string containing the appropriate class name / path

if nargin < 2 || isempty(type)
    type = 'classNameShort';
end

if isobject(className)
    className = class(className);
end

switch type
    case 'classNameShort'
        classNameParts = textscan(className,'%s','Delimiter','.');
        out = classNameParts{1}{end};
    case 'classPrivatePath'
        out = fullfile(fileparts(which(className)),'private');
    case 'packagePrivatePath'
        mc = meta.class.fromName(className);
        containingpack = mc.ContainingPackage;
        if isempty(containingpack)
            out = [];
        else
            p = fileparts(fileparts(which(className)));
            out = fullfile(p,'private');
        end
    case 'classPath'
        out = fileparts(which(className));
    otherwise
        error('most.util.className: Not a valid option: %s',type);
end
end


%--------------------------------------------------------------------------%
% className.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
