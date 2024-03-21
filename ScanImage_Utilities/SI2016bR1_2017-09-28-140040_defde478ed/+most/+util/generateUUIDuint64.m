function [uuid_uint64,uuid_char] = generateUUIDuint64
    % generates a universally unique identifier
    % example: 0af56da1-0232-440c-b79d-ba88849d3af9 ( ?dB€Í•C±ÿﬁ]?“√ )
    
    uuid_uint64 = typecast([randi(intmax('uint32'),'uint32');randi(intmax('uint32'),'uint32')],'uint64');
    uuid_char = sprintf('%X',uuid_uint64);
end

%--------------------------------------------------------------------------%
% generateUUIDuint64.m                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
