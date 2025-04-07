clear
close all

file = 'mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001DLC_resnet50_maximumJan21shuffle1_60000_labeled_highres.avi';

numFrames = 51934;

v = VideoReader(file);

frames = read(v,[numFrames-100 numFrames]);

figure; imagesc(uint8(mean(frames(:,:,:,1:10),4)))

light = reshape(mean(mean(mean(frames(179:184,327:335,:,:),3),2),1),[],1);

figure; plot(light)