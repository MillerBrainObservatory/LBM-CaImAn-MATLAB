function twos = bin2Twos(bin)
    theOnes = find(bin == '1');
    theZeros = find(bin == '0');
    
    bin(theOnes) = '0';
    bin(theZeros) = '1';
    
    decTemp = bin2dec(bin) + 1;
    
    twos = dec2bin(decTemp);
end

%--------------------------------------------------------------------------%
% bin2Twos.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
