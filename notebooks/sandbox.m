parent_path = fullfile("./sandbox/");
Y_in = matfile(fullfile(parent_path, "raw.mat")).data;
h5_path = fullfile(parent_path, 'test.h5');

%%
clc;
cl = class(Y_in);
nd = ndims(Y_in) - 1;
sizY = size(Y_in);

write_frames(h5_path,Y_in);
h5disp(h5_path)
write_frames(h5_path,Y_in);
h5disp(h5_path)