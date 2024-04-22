% this code was developed by Marius Pachitariu and Carsen Stringer as part of the software package Suite2p

function batchSize = getBatchSize(nPixels)

g = gpuDevice;

batchSize = 2^(floor(log2(8e9))-6)/2^ceil(log2(nPixels));
if any(strcmp(fields(g), 'AvailableMemory'))
  batchSize = 2^(floor(log2(g.AvailableMemory))-6)/2^ceil(log2(nPixels));
elseif any(strcmp(fields(g), 'FreeMemory'))
  batchSize = 2^(floor(log2(g.FreeMemory))-6)/2^ceil(log2(nPixels));
end

% The calculation was deducted from the following examples
% batchSize = 2^25/2^ceil(log2(nPixels)); % works well on GTX 970 (which has 4 GB memory)
% batchSize = 2^23/2^ceil(log2(nPixels)); % works well on GTX 560 Ti (which has 1 GB memory)


%--------------------------------------------------------------------------%
% getBatchSize.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
