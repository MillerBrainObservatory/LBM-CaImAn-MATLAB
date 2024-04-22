function pts = xformPoints(pts,T,inverse)
% T is a 2D or 3D affine
% pts is [N x 2] or [N x 3] array of xy or xyz points
    
    if nargin<3 || isempty(inverse)
        inverse = false;
    end
    
    if size(T,1) == 3
        pts(:,3) = 1;
        
        if inverse
            pts = pts / T';
        else
            pts = pts * T';
        end
            
        
        if ~isequal(T(3,:),[0 0 1])
            pts(:,1) = pts(:,1) ./ pts(:,3);
            pts(:,2) = pts(:,2) ./ pts(:,3);
        end
        
        pts(:,3) = [];
    else
        pts(:,4) = 1;
        
        if inverse
            pts = pts / T';
        else
            pts = pts * T';
        end
        
        if ~isequal(T(4,:),[0 0 0 1])
            pts(:,1) = pts(:,1) ./ pts(:,4);
            pts(:,2) = pts(:,2) ./ pts(:,4);
            pts(:,3) = pts(:,3) ./ pts(:,4);
        end
        
        pts(:,4) = [];
    end
end


%--------------------------------------------------------------------------%
% xformPoints.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
