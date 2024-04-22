function result = xcorr2(A, B)
%   IMPORTANT: Currently only real inputs are supported
%
    result = xcorr2_matlab(single(A),single(B));
end

function res = xcorr2_matlab(A,B)
%   NOTE: Removing conj, since its unnecessary for our current use-case
    [M, N] = size(A);
    [P, Q] = size(B);
    %conjB = conj(B);
    resultXElements = M + N - 1;
    resultYElements = M + N - 1;
    res = zeros(resultXElements, resultYElements);
    for l = -(Q - 1):(N - 1)
        for k = -(P - 1):(M - 1)
            val = 0;
            for m = 1:M
                for n = 1:N
                    indexX = m - k;
                    indexY = n - l;
                    if (indexX > 0) && (indexY > 0) && (indexX <= P) && (indexY <= Q)
                        %val = val + A(m,n) * conjB(indexX, indexY);
                        val = val + A(m,n) * B(indexX, indexY);
                    end
                end
            end
            res(P + k,Q + l) = val;
        end
    end
end


%--------------------------------------------------------------------------%
% xcorr2.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
