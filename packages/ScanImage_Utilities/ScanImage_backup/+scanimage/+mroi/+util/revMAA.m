function T = revMAA(p1, v1, p2, v2, vlim, alim)
    
    D = p2-p1;

    if abs(v1-v2)<1e-10
        % satisfy acceleration limit
        T = [roots([alim 4*v1 -4*D]); roots([-alim 4*v1 -4*D])];
        T = T(imag(T)==0);
        T = max(T(T>0));
        
        % satisfy velocity limit
        T = 2*D./([vlim -vlim]+v1);
        Tv = min(T(T>0));
        
        % take most conservative solution
        T = max([T Tv]);
    else
        %constants used in equation
        vd = v2 - v1;
        vs = v2 + v1;
        
        % satisfy acceleration limit
        k1 = vd^2/alim - 2*D;
        k1sq = k1^2;
        
        k2 = 2*vs*vd - 4*v2^2;
        c1a = vs^2 + k2;
        c1b = vs^2 - k2;
        
        k3 = 8*v2*D - 4*vd*D;
        c2a = 2*k1*vs + k3;
        c2b = 2*k1*vs - k3;
        
        k4 = 4*D^2;
        c3a = k1sq - k4;
        c3b = k1sq + k4;
        
        T = [roots([c1a c2a c3a]); roots([c1b c2b c3b]);];
        T = T((imag(T)==0) & (T>0));
        t1 = T./2 - 0.5*vd/alim;
        
        inds = (t1 > 0) & (T > t1);
        T = T(inds);
        t1 = t1(inds);
        
        [T,i] = min(T);
        t1 = t1(i);
        
        if isempty(t1) || t1 < 0 || t1 > T(1)
            % the other solution is the correct one
            k1 = -vd^2/alim - 2*D;
            k1sq = k1^2;
            
            c2a = 2*k1*vs + k3;
            c2b = 2*k1*vs - k3;
            
            c3a = k1sq - k4;
            c3b = k1sq + k4;
            
            T = [roots([c1a c2a c3a]); roots([c1b c2b c3b]);];
            T = T((imag(T)==0) & (T>0));
            t1 = T./2 + 0.5*vd/alim;
            
            inds = (t1 > 0) & (T > t1);
            T = min(T(inds));
            
            a = alim;
        else
            a = -alim;
        end
        
        % satisfy average velocity limit
        try
        T = max([T abs(D)/vlim]);
        catch
            keyboard
        end
    end
end


%--------------------------------------------------------------------------%
% revMAA.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
