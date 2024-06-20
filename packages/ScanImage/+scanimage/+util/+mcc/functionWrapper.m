function varargout = functionWrapper(fWrapper_fstruct, varargin)
persistent PARSED_PERSISTENT_VARS;
if isempty(PARSED_PERSISTENT_VARS)
    PARSED_PERSISTENT_VARS = containers.Map;
end

%init if dne
if ~isKey(PARSED_PERSISTENT_VARS, fWrapper_fstruct.name)
    PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = struct();
end

pvarfnames = fieldnames(PARSED_PERSISTENT_VARS(fWrapper_fstruct.name));
pnames = fWrapper_fstruct.persistnames;
newnames = setxor(pvarfnames, pnames);
oldnames = intersect(pvarfnames, pnames);
%pvars have changed, add new pvars
if ~isempty(newnames)
    oldpstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
    pstruct = struct();
    for i=1:numel(oldnames)
        pstruct.(oldnames{i}) = oldpstruct.(oldnames{i});
    end
    for i=1:numel(newnames)
        pstruct.(newnames{i}) = [];
    end
    PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = pstruct;
end

%unpack persistent vars
pstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
for i=1:numel(pnames)
    eval([pnames{i} ' = pstruct.' pnames{i} ';']);
end

%unpack fcn arguments
for i=1:length(fWrapper_fstruct.argnames)
    if strcmp(fWrapper_fstruct.argnames{i}, 'varargin')
        varargin = varargin(i:end);
        break;
    end
    if strcmp(fWrapper_fstruct.argnames{i}, '~')
        continue;
    end
    eval([fWrapper_fstruct.argnames{i} ' = varargin{i};']);
end

eval(fWrapper_fstruct.fcn);

%repack persistent vars
fWrapper_pstruct = PARSED_PERSISTENT_VARS(fWrapper_fstruct.name);
fWrapper_pfields = fieldnames(fWrapper_pstruct);
for i=1:length(fWrapper_pfields)
    fWrapper_pstruct.(fWrapper_pfields{i}) = eval(fWrapper_pfields{i});
end
PARSED_PERSISTENT_VARS(fWrapper_fstruct.name) = fWrapper_pstruct;
%varargout is set automatically by eval so don't pack output args
if ~any(strcmp(fWrapper_fstruct.outnames, 'varargout'))
    for i=1:length(fWrapper_fstruct.outnames)
        outnm = fWrapper_fstruct.outnames{i};
        varargout{i} = eval(fWrapper_fstruct.outnames{i});
    end
end
end

%--------------------------------------------------------------------------%
% functionWrapper.m                                                        %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
