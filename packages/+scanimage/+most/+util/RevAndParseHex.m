function processedHex = RevAndParseHex(hex)
        for i = 1:2:length(hex)-1
            positionHexReversed(length(hex)-i) = hex(i);
            positionHexReversed(length(hex)-i+1) = hex(i+1);
        end
        k = 1;
        for i = 1:2:length(positionHexReversed)-1
            parseHex{k} = positionHexReversed(i:i+1);
            k = k+1;
        end
        processedHex = parseHex;
end

%--------------------------------------------------------------------------%
% RevAndParseHex.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
