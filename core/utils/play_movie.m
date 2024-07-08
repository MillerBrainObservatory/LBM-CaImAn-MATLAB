function play_movie(movie_cell_array,labels_cell_array,min_mov,max_mov)
% Play a movie or list of movies with labels, press any key to stop  the movie from playing.
%
% Parameters
% ----------
% movie_cell_array : cell array
%     Cell array of movies. Each movie is a 3D array (height x width x frames).
% labels_cell_array : cell array, optional
%     Cell array of titles for the movies. If not provided, empty labels will be used.
% min_mov : numeric, optional
%     Minimum value for setting the color limits on the movies. If not provided, will be computed from the first movie.
% max_mov : numeric, optional
%     Maximum value for setting the color limits on the movies. If not provided, will be computed from the first movie.
%
% Examples
% --------
% play_movie({movie1, movie2}, {'Movie 1', 'Movie 2'}, 0, 255)
% play_movie(movie, 'Sample Movie')
if ~iscell(movie_cell_array)
    movie_cell_array = {movie_cell_array};
end
if ~exist('labels','var')
    labels_cell_array = cell(size(movie_cell_array));
end
if ~exist('min_mov','var') || ~exist('max_mov','var')
    nml = min(1e7,numel(movie_cell_array{1}));
    min_mov = quantile(movie_cell_array{1}(1:nml),0.001);
    max_mov = quantile(movie_cell_array{1}(1:nml),1-0.001);
end

dialogBox = uicontrol('Style', 'PushButton', 'String', 'stop','Callback', 'delete(gcbf)');

num_movs = numel(movie_cell_array);
len_movs = size(movie_cell_array{1},3);

t = 0;
while (ishandle(dialogBox)) && t<len_movs
    t = t+1;    
    for idx_mov = 1:num_movs
        subplot(1,num_movs,idx_mov); imagesc(movie_cell_array{idx_mov}(:,:,t),[min_mov,max_mov]); 
        axis square; 
        axis off; 
        colormap('gray');
        title([labels_cell_array{idx_mov}, ', frame ',num2str(t)]);
    end        
    if t == 1
        set(gcf,'Position',[100,100,1.2*length(movie_cell_array)*size(movie_cell_array{1},2),1.2*size(movie_cell_array{1},1)]);
    end
    pause(0.001);
end
close()