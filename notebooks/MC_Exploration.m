addpath(genpath('C:\Users\RBO\Documents\MATLAB\caiman_pipeline'));
load(fullfile("../Pre_Processing_Executable/temp.mat"));

%% 
clc
[t_shifts, t_peaks, t_ex_lim] = rigid_mcorr(Y,'template', template_good, 'max_shift', 20, 'subtract_median', false, 'upsampling', 20);

%%
t_shifts_r = squeeze(cat(3,t_shifts));
t_shifts_v = movvar(t_shifts_r,24,1);

translated_frames = zeros(size(Y), 'like', Y);
for k = 1:size(Y,3)
    current_frame = Y(:,:,k);
    translation_vector = t_shifts_r(k,:);  % extract shifts for frame k
    translated_frame = imtranslate(current_frame, translation_vector, 'FillValues', 0);
    translated_frames(:,:,k) = translated_frame;
end

%% 

slicex = 1:144;
slicey = 150:300;
frame1 = 20;
frame2 = 21;

figure;
subplot(2,2,1);
imshow(translated_frames(slicey, slicex,frame1), []);
axis image; colormap 'gray';
title('Translated Frame 2');
subplot(2,2,2);  
imshow(translated_frames(slicey, slicex,frame2), []);
axis image; colormap 'gray';
title('Translated Frame 3'); 
subplot(2,2,3);
imshow(Y(slicey, slicex,frame1), []);
axis image; colormap 'gray';
title('Original Frame 2');
subplot(2,2,4);  
imshow(Y(slicey, slicex,frame2), []);
axis image; colormap 'gray';
title('Original Frame 3');