function planeToTiff(varargin)
% PLANETOTIFF Write image to tif file with specified datatype.
%   PLANETOTIFF(IMGDATA,HEADER,IMFILE,DATATYPE) exports IMGDATA with HEADER
%   to TIF file named IMFILE. HEADER is usally obtained by IMFINFO from 
%   original image file, and it can also be left empty. String DATATYPE 
%   specifies data type for the export. Supported data types include 
%   logical, uint8, int8, uint16, int16, uint32, int32, uint64, int64, 
%   single and double.
%
%   PLANETOTIFF(IMGDATA,HEADER,IMFILE,DATATYPE,TAG NAME1,TAG VALUE1,TAG NAME2,
%   TAG VALUE2,...) writes with specified Matlab supported TIF tag values.
%   These new tag values overide those already defined in HEADER.
%
%   Note 1: 
%       to avoid errors such as '??? Error using ==> tifflib The value for
%       MaxSampleValue must be ...', overide tag MaxSampleValue by Matlab
%       supported values. Or simply remove the tag from HEADER.
%
%   Note 2:
%       Overwriting of the existing image files is not checked. Be cautious
%       with the export image file name.
%
%   Example 1:
%       imgdata = imread('ngc6543a.jpg');
%       header  = imfinfo('ngc6543a.jpg');
%       imwrite2tif(imgdata,header,'new_ngc6543a.tif','uint8');
%
%   Example 2:
%       imgdata = imread('mri.tif');
%       imwrite2tif(imgdata,[],'new_mri.tif','int32','Copyright','MRI',
%       'Compression',1);
%
%   More information can be found by searching for 'Exporting Image Data 
%   and Metadata to TIFF Files' in Matlab Help.
%   Zhang Jiang 
%   $Revision: 1.0 $  $Date: 2011/02/23 $

% Parse input arguments
p = inputParser;
addRequired(p, 'imgdata');
addRequired(p, 'imfile');
addRequired(p, 'datatype');
addRequired(p, 'hTiff');

parse(p, varargin{:});

imgdata = p.Results.imgdata;
imfile = p.Results.imfile;
datatype = p.Results.datatype;
hTiff = p.Results.hTiff;
tagstruct = getTagStructFromTiff(hTiff);

% check errors
if ~isnumeric(imgdata)
     error('The first input argument (image data) must be a numeric array.');
end
if ~ischar(imfile)
    error('The third input argument (output tif file name) must be string.');
end
switch lower(datatype)   
    case 'uint16'   
        imgdata = uint16(imgdata);           
    case 'int16'
        imgdata = int16(imgdata);
    otherwise
        error('Invalid output data type.');
end

% creat a Tiff object
t = Tiff(imfile,'w');

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
tagstruct.RowsPerStrip = size(imgdata, 2);
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.SamplesPerPixel = hTiff.getTag("SamplesPerPixel");    
tagstruct.SampleFormat = Tiff.SampleFormat.Int;

tagstruct.ImageLength = size(imgdata, 2);
tagstruct.ImageWidth = size(imgdata, 1);

% tagstruct.ImageDescription = fiji_desc;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

tic;
for frame = 1:size(imgdata,3)
    t.setTag(tagstruct)
    t.write(imgdata(:,:,frame));
    t.writeDirectory();
end
toc
t.close() 
