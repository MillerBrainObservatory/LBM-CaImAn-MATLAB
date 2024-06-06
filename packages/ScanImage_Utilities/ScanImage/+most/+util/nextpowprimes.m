function [P,A] = nextpowprimes(A,primes,direction)
    % like nextpow2, but allows to specify the prime factors
    if nargin<3 || isempty(direction)
        direction = 1;
    end
    
    validateattributes(A,{'numeric'},{'positive','integer','real'},'Input A needs to be a positive integer');
    validateattributes(primes,{'numeric'},{'>=',2,'integer','increasing','vector','real'},'primes input vector needs to be sorted prime numbers');
    assert(all(isprime(primes)),'primes input vector needs to be prime');
    validateattributes(direction,{'numeric','logical'},{'scalar','nonnan','real'},'Direction needs to be -1 OR 1 OR true OR false');
    
    P = zeros(size(primes),'like',primes);
    if A == 1
        return;
    end
    
    if direction > 0
        increment = 1;
    else
        increment = -1;
    end
    
    while true
        factors = factor(A);
        undesired_factors = setdiff(factors,primes);
        if isempty(undesired_factors)
            break % found a match
        else
            A = A+increment;
        end
    end
    
    for idx = 1:numel(primes)
        P(idx) = sum(factors == primes(idx));
    end
end

%--------------------------------------------------------------------------%
% nextpowprimes.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
