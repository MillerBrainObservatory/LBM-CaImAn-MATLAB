function generateAPIDocs2(dir2Doc, noHref)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GENERATEAPIDOCS2 Generates the API documentation for scanimage
% Performs a recursive search for .m files through all the directories starting from the
% current Matlab directory.  Uses the function saveHtmlDoc to produce HTML
% files for the .m files.  Function processDir starts from the current root
% directory and descends through the directory tree to make the cell array
% mFileList which contains all m file names and thier locations.  This
% program requires jsoup.jar so that the function parserHtml will work.
% jsoup-1.11.3.jar is in a private folder that gets added more-or-less
% automatically to the java class path.  Hopefully, it doesn't conflict with
% anything.
% generateAPIDocs2 depends on scanimage\+scanimage\+util\+doc\DocGenExcludedDIRS.txt
% which contains the list of directories to exclude in the document
% generation process.
%
%
% You may need to change the following in order to get things to work:
%
% In dabs.ni.daqmx.private.DAQmxClass.m (line 1).  Change:
%
%       classdef DAQmxClass < most.APIWrapper & most.PDEPPropDynamic
%
% to
%
%       classdef DAQmxClass < handle
%
% run the documentation generator and then change things back.  The above
% solution provided a clue about the origin of the problem.  When the HTML
% documentation for AIChann.m is being produced, the handle to the
% instantiation of the class is lost.  The handle is lost because a which
% statement appears to alter the class and reset the handles.  It was noted
% that if the class was instantiated on the matlab command line before
% running generateAPIDocs2.m then the error does not happen.  By
% instantiating the AIChan class at the beginning of this program in the
% base space, the error can also be prevented.
% Perhaps Mathworks will automagically do it for us one day.
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin < 1 || isempty(dir2Doc)
    dir2Doc = fileparts(which('scanimage'));
    noHref = true;
    
    if(isempty(dir2Doc))
        error('Change directories to the ScanImage directory or specify the directory you want to document on the command line.');
    end
end

if isempty(noHref)
    noHref = true;
end
% Sets the path to Jsoup for the HTML parsing functions
path = fullfile(fileparts(mfilename('fullpath')), 'private', 'jsoup-1.11.3.jar');
javaaddpath(path);
% Instantiates the AIChan class so an error is prevented in the document
% generation process.  See comments above for more details.
evalin('base','hChan = dabs.ni.daqmx.AIChan;');

%Read in directories to eliminate from document generation
filestem = fileparts(which('scanimage'));
docloc = fullfile(filestem, '+scanimage', '+util', '+doc');
excludeloc = fullfile(docloc, 'DocGenExcludedDIRS.txt');

if 2 == exist(excludeloc, 'file')
    fileId = fopen(excludeloc);
    excludedDirs = textscan(fileId, '%s');
    excludedDirs = excludedDirs{1};
    fclose(fileId);
else
    error('The exclusion file DocGenExcludedDIRS.txt does not exist in directory `%s`', docloc);
end

% Get current root directory folder name.  Must start program in the
% directory where you want to generate docs
rootDir = dir2Doc;
docDir = fullfile(rootDir ,'docs'); %Contains the directory name for the HTML documents to be stored

% The resulting cell array mFileList contains all .m file names and
% file locations

mFileList = processDir(rootDir, docDir, [], excludedDirs);
if isempty(mFileList)
    error('There seems to be no .m files in the directory that you selected for document generation');
end

%% Generate html documents
% All .m files are passed to saveHtmlDoc with thier location
for i = 1:numel(mFileList)
    saveHtmlDoc(mFileList(i).location, mFileList(i).name, noHref);
end
evalin('base','clear hChan');
end

% This function recursively descends through the directory tree searching
% for .m files.
function mFileList=processDir(rootDir, docDir, mFileList, excludedDirs)
children = dir(rootDir);%rootDir becomes child directory names as the descent happens

% These statements remove unwanted directories from the dirList.  The file
% +scanimage\+util\+doc\DocGenExcludedDIRS.txt
% contains the list of directories to exclude.
childNames = {children.name};
excludeInds = false(size(childNames));
for i=1:length(childNames)
    excludeInds(i) = any(strcmp(excludedDirs, childNames{i}));
end
children = children(~excludeInds);
childNames = childNames(~excludeInds);
iChildDirs = logical([children.isdir]);
iChildMFiles = false(size(childNames));

%find all child files that end in '.m'
childFileNames = childNames(~iChildDirs);
iChildFiles = false(1, sum(~iChildDirs));
for i=1:length(childFileNames)
    [~, ~, ext] = fileparts(childFileNames{i});
    iChildFiles(i) = strcmp(ext, '.m');
end

iChildMFiles(~iChildDirs) = iChildFiles;

% This code section makes all the directories required for the documents directory
res = mkdir(docDir);
if res == 0
    most.idioms.warn('Error creating documentation directory');
    return;
end
%
%for .m files record the name and the location directory
if any(iChildMFiles)
    mFiles = children(iChildMFiles);
    for i=1:length(mFiles)
        mFiles(i).location = docDir;
    end
    mFileList = [mFileList; mFiles];
end

if any(iChildDirs)
    childDirNames = childNames(iChildDirs);
    subDirs = strcat(rootDir, '\', childDirNames);
    subDocDirs = strcat(docDir, '\', childDirNames);
    subDocDirs = strrep(subDocDirs, '+', '');
    subDocDirs = strrep(subDocDirs, '@', '');
    for i=1:length(childDirNames)
        mFileList = processDir(subDirs{i}, subDocDirs{i}, mFileList, excludedDirs);
    end
end
end

function saveHtmlDoc(rootDir, docName, noHref)
%   saves the html file corresponding to the docs/help call on docNam
%   assumes the directory 'docs' exists within rootDir.  All document
%   directories are made in the processDir function.
%
slashPosition = strfind(rootDir, '\');%Find the postions of the directory delimiters
dirNames = {};
pathFlag = false; %this flag is set to 1 when the docs directory name is found in the dirNames list
docClassPath = '';
for p = 1:numel(slashPosition)
    if (p == numel(slashPosition))%If we are on the last delimiter then add to the end of the string
        dirNames = [dirNames; rootDir((slashPosition(p)+1):numel(rootDir))];
    else
        dirNames = [dirNames; rootDir((slashPosition(p)+1):(slashPosition(p+1)-1))];%include characters between delimiters
    end
    if (pathFlag == 1)
        docClassPath = strcat(docClassPath, dirNames{p}, '.');%concatenate names back together with .
    end
    if (strcmp(dirNames{p}, 'docs') == 1)%When docs directory is discovered set flag
        pathFlag = true;
    end
end
docName = strrep(docName, '.m', '');
fullDocName = strcat(docClassPath, docName);
fullDocName = strrep(fullDocName, '+', '');
htmlCreateMsg = strcat('Creating--', fullDocName, '...');
disp(htmlCreateMsg);

% HAX (ngc)
% Need to keep an extra reference to the metaclass (when applicable).
% Eventually most.idioms.gendochtml calls some internal Matlab code
% that ends up touching the source file that defines the class.  This
% causes the class to reload invalidating the metaclass reference that
% is being passed around.  Without the following block of code, there
% is no other metaclass reference and so the reference being passed
% around gets invalidated midstream.  By keeping a reference here,
% we ensure the metaclass stays alive even after the class reload.
mc=[]; %#ok<NASGU>
% may not need this section because of evalin near the top of the code.
try % not all fullDocNames correspond to a class name
    mc = eval(['?' fullDocName]); %#ok<NASGU> % don't know a better way to get metaclass from string name
catch
end

[~,html] = most.util.doc.gendochtml(fullDocName);%create HTML
if (noHref)
    htmlOut = parseHtml(html);%process HTML to remove links if noHref is true
    html = char(htmlOut);%convert back to character array because that is what fopen needs
end

htmlName = strcat(docName, '.html');
fid = fopen(fullfile(rootDir, htmlName), 'w');%open HTML files
fprintf(fid,'%s', html);%write file
fclose(fid);%close file
end

function htmlOut=parseHtml(htmlIn)
%This function removes hrefs and other links.
objJsoup = org.jsoup.Jsoup.parse(htmlIn);%creates a Jsoup object to process HTML
objJsoup.select('a').unwrap();%removes hrefs
firstTable = objJsoup.select('table[width=100%]').remove();%removes links to code and Matlab help
htmlOut = objJsoup.toString();
end

%--------------------------------------------------------------------------%
% generateAPIDocs2.m                                                        %
% Copyright © 2018 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2018 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%


%--------------------------------------------------------------------------%
% generateAPIDocs2.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
