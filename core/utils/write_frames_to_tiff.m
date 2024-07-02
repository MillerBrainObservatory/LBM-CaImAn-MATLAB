function write_frames_to_tiff(varargin)
% Write image to TIFF file with specified datatype.
%
% Parameters
% ----------
% imgdata : numeric array
%     Image data to be exported. It must be a numeric array.
% imfile : char
%     Name of the output TIFF file.
% datatype : char
%     Data type for the export. Supported data types include 'uint16' and 'int16'.
% hTiff : Tiff object
%     Tiff object containing metadata tags.
%
% Notes
% -----
% To avoid errors such as '??? Error using ==> tifflib The value for
% MaxSampleValue must be ...', override the tag MaxSampleValue with MATLAB
% supported values or simply remove the tag from the header.
%
% Overwriting of the existing image files is not checked. Be cautious
% with the export image file name.
%
% Examples
% --------
% imgdata = imread('ngc6543a.jpg');
% header  = imfinfo('ngc6543a.jpg');
% write_frames_to_tiff(imgdata,header,'new_zplane_1.tif','uint16');
%
% imgdata = imread('mri.tif');
% write_frames_to_tiff(imgdata,[],'new_mri.tif','int32','Copyright','MRI',
% 'Compression',1);
%
% More information can be found by searching for 'Exporting Image Data
% and Metadata to TIFF Files' in MATLAB Help.

% Parse input arguments
p = inputParser;
addRequired(p, 'data');
addRequired(p, 'filename');
addRequired(p, 'datatype');
addRequired(p, 'tiff_object');

parse(p, varargin{:});

data = p.Results.data;
filename = p.Results.filename;
datatype = p.Results.datatype;
tiff_object = p.Results.tiff_object;

% check errors
if ~isnumeric(data)
     error('The first input argument (image data) must be a numeric array.');
end
if ~ischar(filename)
    error('The third input argument (output tif file name) must be string.');
end
switch lower(datatype)
    case 'uint16'
        data = uint16(data);
    case 'int16'
        data = int16(data);
    otherwise
        error('Invalid output data type.');
end

% creat a Tiff object
t = Tiff(filename,'w');

tagnamelist = Tiff.getTagNames();
tagnamelist_delete = {...
    'TileByteCounts';...
    'TileOffsets';...
    'MaxSampleValue';...
    'MinSampleValue';...
    'ResolutionUnit'};

for ii=1:length(tagnamelist_delete)    % remove read only tag names
    tagnamelist(strcmpi(tagnamelist_delete{ii},tagnamelist)) = [];
end
tagstruct = struct();
tagstruct.BitsPerSample = 16;
tagstruct.RowsPerStrip = size(data, 2);
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.SamplesPerPixel = tiff_object.getTag("SamplesPerPixel");
tagstruct.SampleFormat = Tiff.SampleFormat.Int;

tagstruct.ImageLength = size(data, 2);
tagstruct.ImageWidth = size(data, 1);

% tagstruct.ImageDescription = fiji_desc;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

tic;
for frame = 1:size(data,3)
    t.setTag(tagstruct)
    t.write(data(:,:,frame));
    t.writeDirectory();
end
toc
t.close()
