function X = intersectLinePlane(ptLn,vLn,ptPn,vPn)
outputSize = size(ptLn);
ptLn = validateVector(ptLn); % point on line
vLn  = validateVector(vLn);  % line vector
ptPn = validateVector(ptPn); % point on plane
vPn  = validateVector(vPn);  % plane normal vector

dot_vLn_vPn = dot(vLn,vPn);

if dot_vLn_vPn == 0
    X = nan(size(ptLn));
    return
end

% dot( vPn, (X-ptPn) ) = 0; % plane equation
% pTLn + U*vLn = X;    % parametric equation for line; U is scalar parameter
%
% dot( vPn, (ptLn-ptPn + U*vLn) ) = 0; % substitute X into plane equation
% dot( vPn, (ptLn-ptPn) ) + U * dot( vPn , vLn ) = 0;
% U = dot( vPn , (ptPn-ptLn) ) / dot( vPn, vLn );

% substitute U into line equation
X = ptLn + vLn * dot( vPn, (ptPn-ptLn) ) / dot_vLn_vPn;
X = reshape(X,outputSize);
end

function v = validateVector(v)
    assert(numel(v)==3);
    v = v(:);
end

%--------------------------------------------------------------------------%
% intersectLinePlane.m                                                     %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
