function data = loadjsonobj(fname,varargin)
data = most.json.loadjson(fname,varargin{:});

data = fieldToObj(data);
end

function data = fieldToObj(data,currentfieldnames)
    if nargin < 2 || isempty(currentfieldnames)
        currentfieldnames = {};
        s = data;
    else
        s = getfield(data,currentfieldnames{:});
    end
    
    if isa(s,'struct')
        if isfield(s,'classname')
            obj = eval([s.classname '.loadobj(s)']);
            if isempty(currentfieldnames)
                data = obj;
            else
                data = setfield(data,currentfieldnames{:},obj);
            end                
        else
            fnames = fieldnames(s);
            for idx = 1:length(fnames)
                data = fieldToObj(data,[currentfieldnames fnames{idx}]);
            end
        end
    elseif isa(s,'cell')
        for idx = 1:length(s)
            s{idx} = fieldToObj(s{idx});
            data = setfield(data,currentfieldnames{:},s);
        end
    end
end

%--------------------------------------------------------------------------%
% loadjsonobj.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
