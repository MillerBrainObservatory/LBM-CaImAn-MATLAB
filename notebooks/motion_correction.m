%% Motion Correction Grid Search
clear
%% POINT THIS PATH TO YOUR DESIRED PLANE, ASSEMBLED FILES, AND REGISTERED FILES
plane = 26;

assembled_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\assembled');
motion_corrected_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\motion_corrected');

%%

raw_filename = fullfile(assembled_path, sprintf("assembled_plane_%d.h5", plane));
metadata = read_h5_metadata(raw_filename, '/Y');

%%
data_size = metadata.data_size;
% data_size = h5info(filename, '/Y').ChunkSize(1:2); % you can get size from h5 as well

% Put any variables you want to search inside [], separated by a comma
shifts_um = [5, 20, 40];
grid_sizes = [64, 128];

for i=1:numel(shifts_um)
    max_shift = shifts_um(i);
    for j=1:numel(grid_sizes)
        grid_size = grid_sizes(j);

        % use variables to save the file
        grid_search_savepath = sprintf( ...
                "%s/plane_%d_max_shift_%d_grid_size_%dx%d", ...
                plane,assembled_path,max_shift,grid_size(1), grid_size(1) ...
        );

        options = NoRMCorreSetParms(...
            'd1', data_size(1),...
            'd2', data_size(2),...
            'grid_size', grid_size, ...
            'bin_width', 100,... % number of frames to avg when updating template
            'max_shift', max_shift,...
            'correct_bidir', false... % defaults to true, this was already done in step 1
        );
        
        motionCorrectPlane( ...
            assembled_path, ... % we used this to save extracted data
            'save_path', grid_search_savepath, ... % save registered data here
            'ds', '/Y', ... % where we saved the last step in h5
            'debug_flag', 0, ...
            'overwrite', 1, ...
            'num_cores', 23, ...
            'start_plane', plane, ...
            'end_plane', plane,  ...
            'options', options ...
        );
    end
end

%% Play registration movie alongside raw movie

motion_corrected_filename = fullfile(motion_corrected_path, sprintf("motion_corrected_plane_%d.h5", plane));
raw_movie = h5read(raw_filename, '/Y');
motion_corrected_data = h5read(raw_filename, '/Y');

play_movie({raw_movie, motion_corrected_data})

%% Save registration movie alongside raw movie

write_frames_to_mp4(raw_movie, motion_corrected_path, metadata.frame_rate);
write_frames_to_avi(raw_movie, motion_corrected_path, metadata.frame_rate);
write_frames_to_gif(raw_movie, motion_corrected_path, metadata.frame_rate);