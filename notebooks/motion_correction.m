%% Motion Correction Grid Search

%% POINT THIS PATH TO YOUR ASSEMBLED TIFF FILES

save_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\assembled');
mc_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\motion_corrected');

filename = fullfile(save_path, "assembled_plane_26.h5");

%%
metadata = read_h5_metadata(filename, '/Y');

% data_size = metadata.data_size;
data_size = h5info(filename, '/Y');
data_size = data_size.ChunkSize(1:2);

% Put any variables you want to search inside [], separated by a comma
shifts_um = [5, 20, 40];
grid_sizes = [64, 128];

%%
for i=1:numel(shifts_um)
    disp(i);
    disp(size(shifts_um))
    max_shift = shifts_um(i);
    for j=1:numel(grid_sizes)
        grid_size = grid_sizes(j);

        % use variables to save the file
        grid_search_savepath = sprintf("%s/max_shift_%d_grid_size_%dx%d",save_path,max_shift,grid_size(1), grid_size(1));

        options = NoRMCorreSetParms(...
            'd1', data_size(1),...
            'd2', data_size(2),...
            'grid_size', grid_size, ...
            'bin_width', 100,... % number of frames to avg when updating template
            'max_shift', max_shift,...
            'correct_bidir', false... % defaults to true, this was already done in step 1
        );
        
        motionCorrectPlane( ...
            save_path, ... % we used this to save extracted data
            'save_path', grid_search_savepath, ... % save registered data here
            'ds', '/Y', ... % where we saved the last step in h5
            'debug_flag', 0, ...
            'overwrite', 1, ...
            'num_cores', 23, ...
            'start_plane', 26, ...
            'end_plane', 26,  ...
            'options', options ...
        );
    end
end
