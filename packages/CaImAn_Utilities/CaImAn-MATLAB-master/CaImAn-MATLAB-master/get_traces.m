function [Y_r,Df] = get_traces(Y,A,C,b,f,d1,d2,T,options)

Y = reshape(Y,d1,d2,T);
nA = full(sqrt(sum(A.^2))');
[K,~] = size(C);
A = A/spdiags(nA,0,K,K);    % normalize spatial components to unit energy
C = bsxfun(@times,C,nA(:)); %spdiags(nA,0,K,K)*C;

AY = mm_fun(A,Y);
Y_r = (AY- (A'*A)*C - full(A'*double(b))*f) + C;

[~,Df] = extract_DF_F(Y,A,C,[],options,AY);