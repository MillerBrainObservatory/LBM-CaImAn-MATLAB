function tf = parallelComputingToolboxAvailable()
v = ver();
toolboxinstalled = any(strcmpi('Parallel Computing Toolbox',{v.Name}));
toolboxlicensed = license('test','Distrib_Computing_Toolbox');

tf = toolboxinstalled && toolboxlicensed ;    
end


%--------------------------------------------------------------------------%
% parallelComputingToolboxAvailable.m                                      %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
