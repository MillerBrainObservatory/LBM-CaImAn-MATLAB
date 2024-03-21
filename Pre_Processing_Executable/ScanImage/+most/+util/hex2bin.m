function bin = hex2bin(hex, bits, format)
    map = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'a', 'b', 'c', 'd', 'e', 'f'};
    assert(ischar(hex), 'Input must be of type char!');
    
    for i = 1:length(hex)
        assert(~isempty(find([map{:}] == hex(i),1)), 'Input is not a valid hexidecimal value!');
    end
    
    if nargin < 2
        bits = 1;
        
    end
    
    if nargin < 3
       format = 'str';
    end
    
    assert(~isempty(format) && (strcmp(format, 'str') || strcmp(format, 'cell')), 'Format must either be str or cell!');
    
    temp = {};
    
    for i = 1:length(hex)
        
        switch hex(i)
            case '0'

                temp{i} = '0';

            case '1'

                temp{i} = '1';

            case '2'

                temp{i} = '10';

            case '3'

                temp{i} = '11';

            case '4'

                temp{i} = '100';

            case '5'

                temp{i} = '101';

            case '6'

                temp{i} = '110';

            case '7'

                temp{i} = '111';

            case '8'

                temp{i} = '1000';

            case '9'

                temp{i} = '1001';

            case {'A' 'a'}

                temp{i} = '1010';

            case {'B' 'b'}

                temp{i} = '1011';

            case {'C' 'c'}

                temp{i} = '1100';

            case {'D' 'd'}

                temp{i} = '1101';

            case {'E' 'e'}

                temp{i} = '1110';

            case {'F' 'f'}

                temp{i} = '1111';


            otherwise

        end
    end
    
    %% Remove Extraneous Leading Zeros
    zeroMap = temp;
    for i = 1:length(temp)
        if temp{i} == '0'
            zeroMap{i} = true;
        else
            zeroMap{i} = false;
        end
    end
    
    msb = find([zeroMap{:}] == false,1);
    count = 0;
    
    while count < (msb - 1)
       temp(1) = [];
       count = count + 1;
    end
    
    %% Makes sure Minimum bits satisfied.
    % Each unique hex value is 4 bits. If you have multiple hex values they
    % need to be 4 bit offset from eachother. I.e. 2 in hex converts to 2
    % in bin in the same way 2 dec does -> the 10. The minimum number of
    % bits to address this is 2. 22 in hex converts to bin by converting each
    % hex value to bin first and then concatenating them. If you just use
    % basic conversion min bits you wind up with 10 and 10 which would
    % result in a final concatenated value of 1010. This is WRONG! When
    % there are multiple hex values the min # of bits needed is 4 per hex
    % value (excluding final leading 0's). Thus we need to fill bits. This
    % way the conversion yields 10 and 0010. Which concatenates to 100010.
    % This is a correct conversion of 0x22 to binary. 
    hexVals = length(temp);
    if hexVals > 1
        minBits = (hexVals*4) - (4-length(temp{1}));% - length(find(temp{1} == '0'));
        for i = hexVals:-1:2
           fill = '';
           if length(temp{i}) ~= 4
               fillBits = 4 - length(temp{i});
               for j=1:fillBits
                   fill(end+1) = '0';
               end
               temp{i} = [fill temp{i}];
           end
        end
    else
        minBits = length(temp{1});
    end
    
    %% Pad Extra Bits
    % In case you want an output with specific number of bits. Can not be
    % less than the min number of bits required. 
    temp = cellstr(cell2mat(temp));
    temp = temp{1};
    padBits = bits - minBits;
    pad = '';
     if bits <= minBits
         temp2 = temp;
     else
         for i = 1:padBits
             pad(end+1) = '0';
         end
         temp2 = [pad temp];
     end  
     
     if strcmp(format, 'str')
         bin = temp2;
     elseif strcmp(format, 'cell')
         temp3 = {};
         buf = '';
         count = 0;
         for i = length(temp2):-1:1
             if mod(count, 4) == 0
                 temp3{end+1} = fliplr(buf);
                 buf = '';
             end
             buf(end+1) = temp2(i);
             count = count + 1;
         end
         temp3{end+1} = fliplr(buf);
         temp3 = fliplr(temp3);
         bin = temp3(1:end-1);
     end
     
end

%--------------------------------------------------------------------------%
% hex2bin.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
