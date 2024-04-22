function [uuid_humanreadable,uuid_bytes] = generateUUID
    % generates a universally unique identifier
    % example: 0af56da1-0232-440c-b79d-ba88849d3af9 ( ?dB€Í•C±ÿﬁ]?“√ )
    
    error(javachk('jvm'));
    uuid = java.util.UUID.randomUUID;
    uuid_humanreadable = char(uuid);
    uuid_bytes = horzcat(typecast(uuid.getMostSignificantBits,'uint8'),typecast(uuid.getLeastSignificantBits,'uint8'));
    uuid_bytes = char(uuid_bytes);
end

%--------------------------------------------------------------------------%
% generateUUID.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
