
fpath = fullfile("../benchmarks/high_resolution");
files = dir(fullfile(fpath, '*.mat'));
fileNames = {files.name};
relevantFiles = contains(fileNames, 'plane');
relevantFileNames = fileNames(relevantFiles);
numFiles = length(relevantFileNames);

for abc = 1:numFiles
  
    planeIdentifier = sprintf('plane_%d.mat', abc);
    
    % Find the filename that contains this specific plane identifier
    fileNameMatch = relevantFileNames(contains(relevantFileNames, planeIdentifier));
    if length(fileNameMatch) > 1
        error("too many filenames in the directory contain plane_%d.mat in the filename. \n Remove files that are not 3D time-series motion-corrected videos.", abc)
    end
   
    % load data
    d = load(fullfile(fpath, fileNameMatch{1}));   
    filepath = fullfile("C:\Users\RBO\Documents\MATLAB\benchmarks\LBM_sample_data\");
    planeName = sprintf('high_res_plane_%d.tiff', abc);
    fullFileName = fullfile(filepath, planeName);
    t = Tiff(fullFileName, 'w');
   
     thisSlice = d.Y(:, :, 20);
    
    % Set necessary TIFF tags for the slice
    t.setTag('ImageLength', size(thisSlice, 1));
    t.setTag('ImageWidth', size(thisSlice, 2));
    t.setTag('Photometric', Tiff.Photometric.MinIsBlack);
    t.setTag('SampleFormat', Tiff.SampleFormat.IEEEFP);
    t.setTag('BitsPerSample', 32);
    t.setTag('SamplesPerPixel', 1);
    t.setTag('RowsPerStrip', size(thisSlice, 1));
    t.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
    t.setTag('Compression', Tiff.Compression.None);
    
    % Write the slice/frame to the file
    t.write(thisSlice);
    
    % If not the last frame, create a new directory for the next slice
    if curr_frame ~= frames
        t.writeDirectory();
    end
end
% Close the Tiff object
t.close();

