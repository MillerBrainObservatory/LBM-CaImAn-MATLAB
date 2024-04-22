function mask = fastRoiHitZ(rois,z)
    % returns tf array indicating if each roi is involved in the imaging of plane z
    mask = false(1,length(rois));
    if numel(rois)
        rois_discretePlanes_ = {rois.discretePlaneMode};
        rois_zs_ = {rois.zs};
        for i = 1:length(rois)
            if(isempty(rois_zs_{i})),   mask(i) = false; continue; end
            if rois_discretePlanes_{i}, mask(i) = any(rois_zs_{i} == z); continue; end
            if(length(rois_zs_{i})==1), mask(i) = true;  continue; end
            mask(i) = min(rois_zs_{i}(:))<=z && z<=max(rois_zs_{i}(:));
        end
    end
end



%--------------------------------------------------------------------------%
% fastRoiHitZ.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
