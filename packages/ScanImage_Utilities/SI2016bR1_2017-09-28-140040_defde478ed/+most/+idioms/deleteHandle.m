function deleteHandle(h)
  %deleteSmart Delete function for handle objects, which checks if handle is valid before deleting
  %   
  % h: Handle object, or array of such
  %
  % NOTES
  %  This idiom used to avoid delete() method error: 'Invalid or deleted object'
  %
  
  delete(h(ishandle(h)));
  
end



%--------------------------------------------------------------------------%
% deleteHandle.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
