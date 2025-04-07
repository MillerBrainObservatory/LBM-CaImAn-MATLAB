
file = 'mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001DLC_resnet50_maximumJan21shuffle1_60000_labeled_highres.mp4';
% file = 'mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001DeepCut_resnet50_maximumJan21shuffle1_20000_labeled';

spath = 'Z:\jeff_demas\MAxiMuM_data\Paper_Videos\S6\';

numFrames = 51934;

v = VideoReader(file);

startFrame = 1731;
endFrame = 3461;

frames = read(v,[startFrame endFrame]);

frames_trunc = frames(108:347,170:489,:,:);

filename = [spath 'mouseVideo5.avi'];

fr = 28.85;

writerObj = VideoWriter(filename,'Uncompressed AVI');
% writerObj.FrameRate = fr;
% writerObj.Quality = 100;
open(writerObj);

ds = 1;

for k = 1:ds:size(frames_trunc,4)
   frame = frames_trunc(:,:,:,k);
   writeVideo(writerObj,frame)
end

close(writerObj);