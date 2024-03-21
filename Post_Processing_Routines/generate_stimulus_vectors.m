%% Select file, read in

clear
% close all
clc

% path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_2mm_FOV_50_550um_depth_250mW_som_stimuli_9min_00001\';

choice = menu('Select NAS:','v-data1','v-data2','v-data3');

addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\CaImAn_Utilities\motion_correction\'));

switch choice
    case 1
        path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\';
    case 2
        path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\';
    case 3
        disp('Drive is not configured for use yet.')
end

path = uigetdir(path);
path = [path '\'];

files = dir([path '*.txt']);
v = zeros(1,size(files,1));
for ijk = 1:size(files,1)
    if size(strfind(files(ijk).name,'experiment'),1) > 0 
        v(ijk) = 1;
    end 
end
fid =  fopen([path files(v==1).name]);
data = textscan(fid,'%f %f %f');
fclose(fid);

files = dir([path '*.mat']);
load([path files(end).name]);
duration = P.duration_trial_secs;
FrameRate = P.fps;

stimulus_condition = menu('Stimulus:','Whisker only','Visual only','Dual stimuli','Dual stimuli (old)','None');

%% Prepare vectors from txt and mat files

stream_time = data{1,1}.*1e-6;
treadmill_position = data{1,3};
bit_stream = data{1,2};

keep = false(1,numel(stream_time));
keep1 = keep;
keep1(stream_time<duration) = true;
keep2 = keep;
keep2(diff(stream_time)>0) = true;
keep = keep1&keep2;

stream_time = stream_time(keep);
treadmill_position = treadmill_position(keep);
bit_stream = bit_stream(keep);

case_stream = round(log10(bit_stream));

blink_times = stream_time(case_stream==0);
stream_time = stream_time-blink_times(1);

blink_times = stream_time(case_stream==0);
velocity_times = stream_time(case_stream==4);
whisker_times = stream_time(case_stream==2 | case_stream==3);

dt = 1./FrameRate;

frame_clock = 0:dt:duration;
T = numel(frame_clock);

velocity_events = zeros(1,T-1);
% whisker_events = velocity_events;
blink_events = velocity_events;

for j = 1:(T-1)
    blink_events(j) = size(blink_times(blink_times>=frame_clock(j) & blink_times<frame_clock(j+1)),1);
    velocity_events(j) = size(velocity_times(velocity_times>=frame_clock(j) & velocity_times<frame_clock(j+1)),1);
%     whisker_events(j) = size(whisker_times(whisker_times>=frame_clock(j) & whisker_times<frame_clock(j+1)),1);
end

frame_clock = frame_clock(1:end-1);
T = numel(frame_clock);

nv = ceil(P.fps*P.duration_visual_secs);
nw = ceil(P.fps*P.duration_whisker_secs);

visual_events = do_table(:,4).*circshift(do_table(:,4),-nv);
whisker_events = do_table(:,2).*circshift(do_table(:,2),-nw);

tk = frame_clock - frame_clock(ceil(numel(frame_clock)/2));

tau = 0.55/log(2);
kernel = exp(tk./0.2);
kernel(tk>=0) = exp(-tk(tk>=0)./tau);

swsk = conv(whisker_events,kernel,'same')';
svis = conv(visual_events,kernel,'same')';
svel = conv(velocity_events,kernel,'same');

if numel(svel)<numel(swsk)
    pad = zeros(1,numel(swsk)-numel(svel));
    svel = [svel pad];
elseif numel(svel)>numel(swsk)
    svel = svel(1:numel(swsk));
end

%% DeepLabCut
if exist([path '\output\paw_tracking.mat'],'file')>0
    load([path '\output\paw_tracking.mat'])
    spaw = spaw';
    
    if numel(spaw)>numel(swsk)
        spaw = spaw(1:numel(swsk));
    elseif numel(spaw)<numel(swsk)
        pad = zeros(1,numel(swsk)-numel(spaw));
        spaw = [spaw pad];
    end
    
    istracking = 1;
else
    spaw = zeros(1,numel(swsk));
    istracking = 0;
end

%% Load the relevant traces

files = dir([path '\output\*.mat']);
v = zeros(1,size(files,1));
for j = 1:size(files,1)
    if strfind(files(j).name,'collated')>0
        v(j) = 1;
    end
end

v = find(v);

d = load([path 'output\' files(v(1)).name],'C_all','T_all');
T_all = d.T_all;

T = size(T_all,2);

if numel(swsk)>T
    swsk = swsk(1:T);
    svis = svis(1:T);
    svel = svel(1:T);
    spaw = spaw(1:T);
    
elseif numel(swsk)<T
    pad = zeros(1,T-numel(swsk));
    swsk = [swsk pad];
    svis = [svis pad];
    svel = [svel pad];
    spaw = [spaw pad];
    
end

%% Make distributions

switch stimulus_condition
    case 1
        nst = floor((duration - P.duration_baseline_secs)./P.period_whisker_secs);
        Tanb = T_all;
        swsknb = swsk;
        svisnb = svis;
        
    case 2
        nst = floor((duration - P.duration_baseline_secs)./P.period_visual_secs);
        Tanb = T_all;
        swsknb = swsk;
        svisnb = svis;
        
    case 3
        nst = floor(1./3.*(duration - P.duration_baseline_secs)./P.period_whisker_secs);
        Tanb = T_all;
        
        vec = do_table(:,2).*do_table(:,4); % occurrences of both stimuli simultaneously occurring
        vecc = conv(vec,kernel,'same');
        vecc = vecc./max(vecc);
        thresh = 0.01;
        
        bothvec = zeros(size(vecc));
        bothvec(vecc>thresh) = 1;
        bothvec = bothvec(1:size(T_all,2));
        startpt = round(P.duration_baseline_secs*P.fps);
        bothvec(1:startpt) = 1;
        
        Tanb = Tanb(:,~bothvec);
        swsknb = swsk(:,~bothvec);
        svisnb = svis(:,~bothvec);
        
    case 4 
        nst = floor((duration - P.duration_baseline_secs)./P.period_whisker_secs);
        Tanb = T_all;
        
        bothvec = zeros(1,size(T_all,2));
        startpt = round(P.duration_baseline_secs*P.fps);
        bothvec(1:startpt) = 1;
        
        Tanb = Tanb(:,~bothvec);
        swsknb = swsk(:,~bothvec);
        svisnb = svis(:,~bothvec);
        
        P.whisker_interval = round(P.period_whisker_secs*P.fps/2);
        P.visual_interval = round(P.period_visual_secs*P.fps/2);

    case 5
        nst = 0;
end

Tnb = size(Tanb,2);

% Whisker stimuli
if stimulus_condition == 1 || stimulus_condition == 3 || stimulus_condition == 4
    disp('Calculating random distribution for whisker stimuli...')
    
    % Determine thresholds
    muswsk = zeros(1,251);
    sigmaswsk = zeros(1,251);
    parfor ijk = 1:251
        stimvec = zeros(1,Tnb);
        stimvec(randi(Tnb,1,nst)) = 1;
        stimvec = conv(stimvec,kernel,'same');
        rr = corr(stimvec',Tanb');
        p = fitdist(rr','Normal');
        muswsk(ijk) = p.mu;
        sigmaswsk(ijk) = p.sigma;
    end
    
    muwsk = median(muswsk);
    sigmawsk = median(sigmaswsk);
    threshwsk = muwsk + 3*sigmawsk;
    
    % Create aesthetic distribution
    murwsk = 1;
    while abs(murwsk) > 0.002
        rst = zeros(1,Tnb); 
        rst(randi(Tnb,1,nst)) = 1;
        rst = conv(rst,kernel,'same');
        Rrwsk = corr(rst',Tanb');
        pd = fitdist(Rrwsk','Normal');
        murwsk = pd.mu;
    end
    
    disp('Calculating preferred lag for top 100 whisker-correlated neurons...')
    Rwsk = corr(swsknb',Tanb');
    [~,inds] = sort(Rwsk,'descend');
    r = zeros(1,100); l = zeros(1,100);
    parfor j = 1:100
        [rs,ls] = xcorr(swsknb',Tanb(inds(j),:)',ceil(P.whisker_interval/2));
        [r(j),in] = max(rs);
        l(j) = ls(in);
    end
    lag = round(median(l));
    swsk = circshift(swsk,-lag,2);
    swsknb = circshift(swsknb,-lag,2);
    Rwsk = corr(swsknb',Tanb');
    nwsk = logical(Rwsk > threshwsk);

    figure;
    histogram(Rwsk,-0.5:0.005:1);
    hold on
    histogram(Rrwsk,-0.5:0.005:1);
    xlim([-0.2 0.4])
    
else
    muwsk = 0;
    sigmawsk = 0;
    threshwsk = 0;
    Rwsk = 0;
    Rrwsk = 0;
    nwsk = 0;
    
end

% Visual stimuli
if stimulus_condition == 2 || stimulus_condition == 3 || stimulus_condition == 4
    
    if stimulus_condition == 2
        
        % Determine thresholds
        musvis = zeros(1,251);
        sigmasvis = zeros(1,251);
        parfor ijk = 1:251
            stimvec = zeros(1,Tnb);
            stimvec(randi(Tnb,1,nst)) = 1;
            stimvec = conv(stimvec,kernel,'same');
            rr = corr(stimvec',Tanb');
            p = fitdist(rr','Normal');
            musvis(ijk) = p.mu;
            sigmasvis(ijk) = p.sigma;
        end

        muvis = median(musvis);
        sigmavis = median(sigmasvis);
        threshvis = muvis + 3*sigmavis;

        % Create aesthetic distribution
        display('Calculating random distribution for visual stimuli...')
        murvis = 1;
        while abs(murvis) > 0.002
            rst = zeros(1,Tnb); 
            rst(randi(Tnb,1,nst)) = 1;
            rst = conv(rst,kernel,'same');
            Rrvis = corr(rst',Tanb');
            pd = fitdist(Rrvis','Normal');
            murvis = pd.mu;
        end

    else
        Rrvis = Rrwsk;
        muvis = muwsk;
        sigmavis = sigmawsk;
        threshvis = threshwsk;
    end
    
    disp('Calculating preferred lag for top 100 visual-correlated neurons...')
    Rvis = corr(svisnb',Tanb');
    [~,inds] = sort(Rvis,'descend');
    r = zeros(1,100); l = zeros(1,100);
    for j = 1:100
        [rs,ls] = xcorr(svisnb',Tanb(inds(j),:)',ceil(P.visual_interval/2));
        [r(j),in] = max(rs);
        l(j) = ls(in);
    end
    lag = round(median(l));
    svis = circshift(svis,-lag,2);
    svisnb = circshift(svisnb,-lag,2);
    Rvis = corr(svisnb',Tanb');
    nvis = logical(Rvis > threshvis);

    figure;
    histogram(Rvis,-0.5:0.005:1);
    hold on
    histogram(Rrvis,-0.5:0.005:1);
    xlim([-0.2 0.4])
    
else
    murvis = 0;
    sigmavis = 0;
    threshvis = 0;
    Rvis = 0;
    Rrvis = 0;
    nvis = 0;
    
end

% Velocity stimuli
display('Calculating random distribution for velocity stimuli...')
murvel = 1;
while abs(murvel) > 0.002
    Tr = zeros(size(T_all));
    for k = 1:size(Tr,1)
        Tr(k,:) = circshift(T_all(k,:),randi(T),2);
    end
    Rrvel = corr(svel',Tr');
    pd = fitdist(Rrvel','Normal');
    murvel = pd.mu;
end
sigmavel = pd.sigma;
threshvel = murvel + 3*sigmavel;

disp('Calculating preferred lag for top 100 velocity-correlated neurons...')
Rvel = corr(svel',T_all');
[~,inds] = sort(Rvel,'descend');
r = zeros(1,100); l = zeros(1,100);
for j = 1:100
    [rs,ls] = xcorr(svel',T_all(inds(j),:)',ceil(2*P.fps));
    [r(j),in] = max(rs);
    l(j) = ls(in);
end
lag = round(median(l));
svel = circshift(svel,-lag,2);
Rvel = corr(svel',T_all');
nvel = logical(Rvel > threshvel);

figure;
histogram(Rvel,-0.5:0.005:1);
hold on
histogram(Rrvel,-0.5:0.005:1);
xlim([-0.3 0.6])

% Behavior stimuli
if istracking
    display('Calculating random distribution for behavior stimuli...')
    murpaw = 1;
    while abs(murpaw) > 0.002
        Tr = zeros(size(T_all));
        for k = 1:size(Tr,1)
            Tr(k,:) = circshift(T_all(k,:),randi(T),2);
        end
        Rrpaw = corr(spaw',Tr');
        pd = fitdist(Rrpaw','Normal');
        murpaw = pd.mu;
    end
    sigmapaw = pd.sigma;
    threshpaw = murpaw + 3*sigmapaw;

    disp('Calculating preferred lag for top 100 behavior-correlated neurons...')
    Rpaw = corr(spaw',T_all');
    [~,inds] = sort(Rpaw,'descend');
    r = zeros(1,100); l = zeros(1,100);
    for j = 1:100
        [rs,ls] = xcorr(spaw',T_all(inds(j),:)',ceil(2*P.fps));
        [r(j),in] = max(rs);
        l(j) = ls(in);
    end
    lag = round(median(l));
    spaw = circshift(spaw,-lag,2);
    Rpaw = corr(spaw',T_all');
    npaw = logical(Rpaw > threshpaw);

    figure;
    histogram(Rpaw,-0.5:0.005:1);
    hold on
    histogram(Rrpaw,-0.5:0.005:1);
    xlim([-0.3 0.6])

else
    murpaw = 0;
    sigmapaw = 0;
    threshpaw = 0;
    Rpaw = 0;
    Rrpaw = 0;
    npaw = 0;
end

disp(['Whisker tuned neurons: ' num2str(sum(nwsk))])
disp(['Visual tuned neurons: ' num2str(sum(nvis))])

clear T_all C_all Tr Tanb
save([path 'output\stimulus_vectors_and_correlated_populations.mat'])