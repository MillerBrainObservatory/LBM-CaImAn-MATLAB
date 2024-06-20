%% Why was this written?
% A very good question. The simple answer is because the native function
% only outputs the hex form as minimum bit, rather than minimum byte. 
% 
% A more detailed explanation: Lets assume you read some bytes from a
% serial device. Say 9, 35, 46, 4. So 4 bytes. But these values are in
% decimal. In order to get the correct information these bytes represent
% you need to the decimal version of the ENTIRE number they make up. I.e.
% you need to convert them bytewise to hex, then concatenate them, then
% convert that whole hex value to decimal. This would be 09 23 2E 04 or in
% total 9232E04 which yields 153300484 decimal. The problem arises that
% when you use the native dec2hex the leading 0's are truncated from the
% binary representation and thus the hex output is only minimum bit! meaning what
% you get is 9 23 2E 4. If you concatenate this you wind up with 9232E4
% which yields 9581284 in decimal! 153300484 != 9581284
%
% Now you could just look at the individual bytes after conversion and
% determine whether they need to have their extra bits but that is messy
% to do in your  application. It should be handled in the function doing
% the conversion. Therein lies the reasoning for this function. Hopefully
% it works perfectly 100% of the time. Feel free to edit and improve but
% make sure you don't break the point! Minimum byte representation!
%
% Also works with works with negative numbers via 2's complement
function hex = dec2hex(dec,padBits)
    if nargin < 2 || isempty(padBits)
       padBits = false; 
    end
    % minBits = 8;
    if dec < 0
        if (log(dec)/log(2)) > 8 && (log(dec)/log(2)) < 16
            binDec = dec2bin(typecast(int16(dec),'uint16'));
        elseif (log(dec)/log(2)) > 16 && (log(dec)/log(2)) < 32
            binDec = dec2bin(typecast(int32(dec),'uint32'));
        elseif (log(dec)/log(2)) > 32
            binDec = dec2bin(typecast(int64(dec),'uint64'));
        elseif (log(dec)/log(2)) < 8 
            binDec = dec2bin(typecast(int8(dec),'uint8'));
        else
            error('This number is too large!');
        end
    else
        binDec = dec2bin(dec);
    end
    
    if length(binDec) < 8 || mod(length(binDec), 4) ~= 0
       % Need to pad 0 bits. 
       pad = '0';
       if length(binDec) < 8
           while length(binDec) ~= 8
               binDec = [pad binDec];
           end
       elseif mod(length(binDec), 4) ~= 0
           while mod(length(binDec), 4) ~= 0
               binDec = [pad binDec];
           end
       end
       
    end
    
    % Parse out into 4 bit sections
    k = 1;
    parsedBinDec = {};
    for i = 1:4:length(binDec)
       parsedBinDec{k} = [binDec(i) binDec(i+1) binDec(i+2) binDec(i+3)];
       k = k+1;
    end
    
    parsedHex = {};
    for i=1:length(parsedBinDec)
       switch parsedBinDec{i}
           
           case '0000'
               parsedHex{i} = '0';
           case '0001'
               parsedHex{i} = '1';
           case '0010'
               parsedHex{i} = '2';
           case '0011'
               parsedHex{i} = '3';
           case '0100'
               parsedHex{i} = '4';
           case '0101'
               parsedHex{i} = '5';
           case '0110'
               parsedHex{i} = '6';
           case '0111'
               parsedHex{i} = '7';
           case '1000'
               parsedHex{i} = '8';
           case '1001'
               parsedHex{i} = '9';
           case '1010'
               parsedHex{i} = 'A';
           case '1011'
               parsedHex{i} = 'B';
           case '1100'
               parsedHex{i} = 'C';
           case '1101'
               parsedHex{i} = 'D';
           case '1110'
               parsedHex{i} = 'E';
           case '1111'
               parsedHex{i} = 'F';
           otherwise
               error('Invalid value!\n');
       end
    end
    
    unpaddedHex = cell2mat(parsedHex);
    paddedHex = unpaddedHex;
    if mod(length(paddedHex),4) ~= 0
        pad = '0';
        while mod(length(paddedHex), 4) ~= 0
            paddedHex = [pad paddedHex];
        end
    end
    
    if padBits == true
    	hex = paddedHex;
    else
        hex = unpaddedHex;
    end
end

%--------------------------------------------------------------------------%
% dec2hex.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
