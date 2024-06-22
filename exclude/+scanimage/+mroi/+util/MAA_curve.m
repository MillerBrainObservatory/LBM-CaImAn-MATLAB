function Y = MAA_curve (d1,d2,v1,v2,T, res)
%A curve Y with Minimum Absolute Acceleration joining an initial position
%(d1) and velocity (v1) with a final position (d2) and velocity (v2), in a
%fixed time T
%res is the resolution of the returned curve, 
    %i.e. we return res+1 points spanning [0 T]

% Author: Kaspar Podgorski
% GJ: improve performance by eliminating supersampling

if T==0 || res==0
    assert(T==0 && res==0);    
    Y = [];
    return
end

validateattributes(d1,{'numeric'},{'scalar','finite','nonnan'});
validateattributes(d2,{'numeric'},{'scalar','finite','nonnan'});
validateattributes(v1,{'numeric'},{'scalar','finite','nonnan'});
validateattributes(v2,{'numeric'},{'scalar','finite','nonnan'});
validateattributes(T,{'numeric'},{'positive','scalar','finite','nonnan'});
validateattributes(res,{'numeric'},{'positive','scalar','integer'});

if abs(v1-v2)<1e-10
    t = T/2;
    a = (2*d2-2*d1-t*v1+T*v1-2*T*v1+t*v2-T*v2)/(t*T);
else
    D = d2-d1;

    c1 = (v1-v2);
    c2 = 2*(v2*T - D);
    c3 = T*D - 0.5*v1*(T.^2) -0.5*v2*(T.^2);
    
    t1 = (-c2 + sqrt(c2.^2 - 4*c1*c3))/(2*c1);
    t2 = (-c2 - sqrt(c2.^2 - 4*c1*c3))/(2*c1);
    
    if t1<0 || t1>T
        t = t2;
    else
        t = t1;
    end
    
    a = (v1-v2)/(T-2*t);
end

tt = linspace(0,T,res+1);
tt1 = tt(tt<=t);
tt2 = tt(tt>t);

tt1 = d1 + v1*tt1 + a/2*tt1.^2;
tt2 = d2 - v2*(T-tt2) - a/2*(T-tt2).^2;

Y = horzcat(tt1,tt2);
end

%--------------------------------------------------------------------------%
% MAA_curve.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
