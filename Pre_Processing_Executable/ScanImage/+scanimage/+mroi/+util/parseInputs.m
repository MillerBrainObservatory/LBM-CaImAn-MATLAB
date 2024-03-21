function inputstruct = parseInputs(inputs)
% takes an input of form {'argument1',value1,'argument2',value2, ...}
% and creates a struct of the form
%   inputstruct.argument1 = value1
%   inputstruct.argument2 = value2
%       ...

assert(mod(length(inputs),2)==0,...
    'Error parsing inputs: inputs must be ''argument'',value pairs.');

inputs = reshape(inputs,2,[]);
%assert(all(cellfun(@(a)isa(a,'char'),inputs(1,:))));

inputstruct = struct();
for iter = 1:size(inputs,2)
    inputstruct.(inputs{1,iter}) = inputs{2,iter};
end
end


%--------------------------------------------------------------------------%
% parseInputs.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
