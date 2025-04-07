clear
close all
clc

load('neuron_coordinates_and_traces.mat')

%% Create stimulus and do single correlations

Ssa = Ss - Sv; Ssa(Ssa<0) = 0;
Sva = Sv - Ss; Sva(Sva<0) = 0;

Sbbin = ones(size(Sb));
Sbbin(Sb>0.01) = NaN;

T_all_no_both = T_all.*(ones(K,1)*Sbbin);
T_all_no_both = reshape(T_all_no_both(~isnan(T_all_no_both)),K,[]);
Tnb = size(T_all_no_both,2);

Rsa = corr(Ssa(~isnan(Sbbin))',(T_all_no_both)');
Rva = corr(Sva(~isnan(Sbbin))',(T_all_no_both)');

nts = sum(logical(Ssa>0.99));
ntv = sum(logical(Sva>0.99));

disp('Calculating random distributions...')

tau = 0.55/log(2);
tt = t-t(dsearchn(t',2));
tt = tt(1:Tnb);
kernel = exp(tt./0.2);
kernel(tt>=0) = exp(-tt(tt>=0)./tau);

muss = zeros(1,1000);
sigmass = zeros(1,1000);

% Whisker
parfor aa = 1:1000
    % Make stim vector
    stim_vec = zeros(1,Tnb);
    stim_vec(randi(Tnb,1,nts)) = 1;
    stim_vec = conv(stim_vec,kernel,'full');
    stim_vec = stim_vec(1:Tnb);

    Rrsc = corr(stim_vec',T_all_no_both');

    pds = fitdist(Rrsc','Normal');
    muss(aa) = pds.mu; 
    sigmass(aa) = pds.sigma;

end

disp('Whisker done, computing visual...')

muvs = zeros(1,1000);
sigmavs = zeros(1,1000);

% Visual
parfor bb = 1:1000
    % Make stim vector
    stim_vec = zeros(1,Tnb);
    stim_vec(randi(Tnb,1,ntv)) = 1;
    stim_vec = conv(stim_vec,kernel,'full');
    stim_vec = stim_vec(1:Tnb);

    Rrvc = corr(stim_vec',T_all_no_both');

    pdv = fitdist(Rrvc','Normal');
    muvs(bb) = pdv.mu; 
    sigmavs(bb) = pdv.sigma;
  
end

disp('Visual done, computing motion...')

mum = 1;
mums = zeros(1,1000);
sigmams = zeros(1,1000);

% Motion
parfor cc = 1:1000
    T_all_shuffled = zeros(size(T_all));
    
    for abc = 1:K
        T_all_shuffled(abc,:) = circshift(T_all(abc,:),randi(T,1),2);
    end
    
    Rrmc = corr(Sm',T_all_shuffled');
    
    pdm = fitdist(Rrmc','Normal');
    mums(cc) = pdm.mu; 
    sigmams(cc) = pdm.sigma;
    
end

figure;
histogram(sigmass)

figure;
histogram(sigmavs)

figure;
histogram(sigmams)

mus = median(muss);
sigmas = median(sigmass);

muv = median(muvs);
sigmav = median(sigmavs);

mum = median(mums);
sigmam = median(sigmams);

disp('Distributions all calculated.')

mu = 1;
while abs(mu)>0.002
    stim_vec = zeros(1,Tnb);
    stim_vec(randi(Tnb,1,nts)) = 1;
    stim_vec = conv(stim_vec,kernel,'full');
    stim_vec = stim_vec(1:Tnb);
    Rrsa = corr(stim_vec',T_all_no_both');
    pd = fitdist(Rrsa','Normal');
    mu = pd.mu;
end

mu = 1;
while abs(mu)>0.002
    stim_vec = zeros(1,Tnb);
    stim_vec(randi(Tnb,1,ntv)) = 1;
    stim_vec = conv(stim_vec,kernel,'full');
    stim_vec = stim_vec(1:Tnb);
    Rrva = corr(stim_vec',T_all_no_both');
    pd = fitdist(Rrva','Normal');
    mu = pd.mu;
end

mu = 1;
while abs(mu)>0.002
    T_all_shuffled = zeros(size(T_all));
    for abc = 1:K
        T_all_shuffled(abc,:) = circshift(T_all(abc,:),randi(T,1),2);
    end
    Rrm = corr(Sm',T_all_shuffled');
    pd = fitdist(Rrm','Normal');
    mu = pd.mu;
end

%% Whisker stimulus

figure;
histogram(Rrsa,-1:0.005:1);
hold on
histogram(Rsa,-1:0.005:1)
xlim([-0.3 0.5])
xlabel('Correlation')
ylabel('Neurons')
title('Whisker')
legend('Shuffled','Stimulus')

FPR = zeros(1,10);
FDR = FPR;

for ns = 1:10;
    thr = mus+ns*sigmas;
    num_false_positive = sum(logical(Rrsa>thr));
    num_significant = sum(logical(Rsa>thr));
    FPR(ns) = num_false_positive./K;
    FDR(ns) = num_false_positive./num_significant;
end

figure(101);
semilogy(1:10,FPR.*100,'-bo','MarkerSize',10)
xlabel('Number of sigma')
ylabel('False positive rate (%)')
title('False positive rate')
hold on

figure(102);
semilogy(1:10,FDR.*100,'-bo','MarkerSize',10)
xlabel('Number of sigma')
ylabel('False discovery rate (%)')
title('False discovery rate')
hold on

%% Visual stimulus

figure;
histogram(Rrva,-1:0.005:1);
hold on
histogram(Rva,-1:0.005:1)
xlim([-0.3 0.5])
xlabel('Correlation')
ylabel('Neurons')
title('Visual')
legend('Shuffled','Stimulus')

FPR = zeros(1,10);
FDR = FPR;

for ns = 1:10;
    thr = muv+ns*sigmav;
    num_false_positive = sum(logical(Rrva>thr));
    num_significant = sum(logical(Rva>thr));
    FPR(ns) = num_false_positive./K;
    FDR(ns) = num_false_positive./num_significant;
end

figure(101);
semilogy(1:10,FPR.*100,'-bsquare','MarkerSize',10,'Color',[0 0.5 0])

figure(102);
semilogy(1:10,FDR.*100,'-bsquare','MarkerSize',10,'Color',[0 0.5 0])

%% Motion stimulus

figure;
histogram(Rrm,-1:0.005:1);
hold on
histogram(Rm,-1:0.005:1)
xlim([-0.3 0.6])
xlabel('Correlation')
ylabel('Neurons')
title('Motion')
legend('Shuffled','Stimulus')

FPR = zeros(1,10);
FDR = FPR;

for ns = 1:10;
    thr = mum+ns*sigmam;
    num_false_positive = sum(logical(Rrm>thr));
    num_significant = sum(logical(Rm>thr));
    FPR(ns) = num_false_positive/K;
    FDR(ns) = num_false_positive./num_significant;
end

figure(101);
semilogy(1:10,FPR.*100,'-rdiamond','MarkerSize',10)

figure(102);
semilogy(1:10,FDR.*100,'-rdiamond','MarkerSize',10)

%%
clc

nst = 3;

thrs = mus + nst.*sigmas;
thrv = muv + nst.*sigmav;
thrm = mum + nst.*sigmam;

[~,ins] = min(abs(Rsa-thrs));
[~,inv] = min(abs(Rva-thrv));

Ssbin = zeros(size(Ssa));
Ssbin(Ss>0.1) = 1;

Ssbin = ones(5,1)*Ssbin;
Ssbin = repmat(Ssbin,[1 1 3]);
Ssbin(:,:,2:3) = 0;

figure;
h = imagesc(t,-2:2,Ssbin);
h.AlphaData = 0.3.*Ssbin(:,:,1);
hold on
plot(t,movmean(T_all(ins,:),5,2))
set(gca,'yDir','normal')
ylim([-0.25 1.25])

num_whisker = sum(logical(Rsa>thrs));
disp(['Number of whisker tuned neurons for ' num2str(nst) ' sigma = ' num2str(num_whisker)])

Svbin = zeros(size(Sva));
Svbin(Sva>0.1) = 1;

Svbin = ones(5,1)*Svbin;
Svbin = 0.5.*repmat(Svbin,[1 1 3]);
Svbin(:,:,[1 3]) = 0;

figure;
h = imagesc(t,-2:2,Svbin);
h.AlphaData = 0.3.*Svbin(:,:,2);
hold on
plot(t,movmean(T_all(inv,:),5,2))
set(gca,'yDir','normal')
ylim([-0.25 1.25])

num_visual = sum(logical(Rva>thrv));
disp(['Number of visual tuned neurons for ' num2str(nst) ' sigma = ' num2str(num_visual)])

num_motion = sum(logical(Rm>thrm));
disp(['Number of motion tuned neurons for ' num2str(nst) ' sigma = ' num2str(num_motion)])


%% Setting thresholds:

thr_num_sig = 3;

thrs = mus + nst.*sigmas;
thrv = muv + nst.*sigmav;
thrm = mum + nst.*sigmam;

soi = logical(Rsa>thrs);
voi = logical(Rva>thrv);
moi = logical(Rm>thrm);
uoi = logical(abs(Rm) < thrm/3 & abs(Rsa) < thrs/3 & abs(Rva) < thrv/3);

ks = sum(soi);
kv = sum(voi);
km = sum(moi);
ku = sum(uoi);

save('thresholds.mat','thrs','thrv','thrm','thr_num_sig','soi','voi','moi','uoi','ks','kv','km','ku','Rsa','Rva','Rrsa','Rrva','Rm','Rrm','Ssa','Sva','Sb','Sm')