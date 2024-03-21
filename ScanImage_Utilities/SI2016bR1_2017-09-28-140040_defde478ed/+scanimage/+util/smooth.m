% Source: http://stackoverflow.com/questions/12987905/how-to-make-a-curve-smoothing-in-matlab

function yy = smooth(y, span)
    yy = y;
    l = length(y);

    for i = 1 : l
        if i < span
            d = i;
        else
            d = span;
        end

        w = d - 1;
        p2 = floor(w / 2);

        if i > (l - p2)
           p2 = l - i; 
        end

        p1 = w - p2;

        yy(i) = sum(y(i - p1 : i + p2)) / d;
    end
end


%--------------------------------------------------------------------------%
% smooth.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
