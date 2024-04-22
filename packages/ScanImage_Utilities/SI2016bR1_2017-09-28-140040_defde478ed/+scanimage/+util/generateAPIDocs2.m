function generateAPIDocs2(free)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GENERATEAPIDOCS2 Generates the API documentation for scanimage
% Performs a recursive search for .m files through all the directories starting from the
% current Matlab directory.  Uses the function saveHtmlDoc to produce HTML
% files for the .m files.  Function processDir starts from the current root
% directory and descends through the directory tree to make the cell array
% mFileList which contains all m file names and thier locations.  This
% program requires jsoup.jar so that the function paserHtml will work.
% jsoup-1.8.3.jar is in a private folder that gets added more-or-less
% automatically to the java class path.  Hopefully, it doesn't conflict with
% anything.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if nargin < 1 || isempty(free)
        free = false;
    end
    
    checkJavaPath;

    %% get current root directory folder name
    %scriptPath1 = mfilename('fullpath');
    %scriptPath = fileparts(mfilename('fullpath'));
    %disp(scriptPath);
    %rootDir = fileparts(scriptPath);
    %rootDir = fileparts(rootDir);   %Contains the final root directory name
    rootDir = pwd;
    docDir =strcat(rootDir, '\', 'docs'); %Contains the directory name for the HTML documents to be stored
    % The resulting cell array mFileList contains all .m file names and
    % file locations
    mFileList = {};
    mFileList = processDir(rootDir, docDir, mFileList); 


    %% Generate html documents
    % All .m files are passed to saveHtmlDoc with thier location
    for i = 1:numel(mFileList)
        saveHtmlDoc(mFileList{i}.location, mFileList{i}.name);
    end
end

%This function recursively descends through the directory tree searching
%for .m files.
function mFileList=processDir(rootDir, docDir, mFileList)
dirList = dir(rootDir);%rootDir becomes child directory names as the descent happens
excludeInds = arrayfun(@(x)ismember(x.name,{'.git' '.' '..'}),dirList);
dirList(excludeInds) = [];
%This code section makes all the directories required for the documents directory
res = mkdir(docDir);
    if res == 0
        most.idioms.warn('Error creating documentation directory');
        return;
    end
%    
    for i = 1:numel(dirList)
         [pathstr, name, ext] = fileparts(dirList(i).name);
         %If there is a .m file record the name and the location directory
         if (strcmp(ext, '.m') == 1)
             mFile = struct('name', dirList(i).name, 'location', docDir);
             mFileList = [mFileList; mFile]; %#ok<AGROW>
         end
        %These if statement filters out unwanted directories.  When a good
        %subdirectory is found there is a recursive call to this function.
        if (dirList(i).isdir == 1 && strcmp(dirList(i).name, '.') == 0 && strcmp(dirList(i).name, '..') == 0 && strcmp(dirList(i).name, 'docs') == 0)
            if(strcmp(dirList(i).name, 'private') == 0 && strcmp(dirList(i).name, '+private') == 0)
                if(strcmp(dirList(i).name, '.git') == 0 && strcmp(dirList(i).name, 'guis') == 0)
                    subDir = strcat(rootDir, '\', dirList(i).name);
                    subDocDir = strcat(docDir, '\', dirList(i).name);
                    subDocDir = strrep(subDocDir, '+', '');
                    subDocDir = strrep(subDocDir, '@', '');
                    mFileList = processDir(subDir, subDocDir, mFileList);
                end
            end
        end
    end
end

function saveHtmlDoc(rootDir, docName)
%   saves the html file corresponding to the docs/help call on docNam
%   assumces the directory 'docs' exists within rootDir
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
    % Eventually most.util.doc.gendochtml calls some internal Matlab code
    % that ends up touching the source file that defines the class.  This
    % causes the class to reload invalidating the metaclass reference that
    % is being passed around.  Without the following block of code, there
    % is no other metaclass reference and so the reference being passed
    % around gets invalidated midstream.  By keeping a reference here,
    % we ensure the metaclass stays alive even after the class reload.
    %
    % Ok that was wrong.  There's something random about this.  It seems
    % like this happens for all the classes that inherit DAQmxClass or 
    % or PDEPPropDynamic something .
    % 
%{
    mc=[]; %#ok<NASGU>
    try % not all fullDocNames correspond to a class name
        c = eval(['?' fullDocName]); %#ok<NASGU> % don't know a better way to get metaclass from string name 
    catch 
    end
%}
    try
        try
            [~,html] = most.util.doc.gendochtml(fullDocName);%create HTML
        catch e 
            try
                disp(e);
                c = eval(fullDocName);
                [~,html] = most.util.doc.gendochtml(fullDocName);%create HTML
                disp('\tSecond time worked!');
            catch e 
                disp(e);
                mc = meta.class.fromName(fullDocName);
                [~,html] = most.util.doc.gendochtml(fullDocName);%create HTML
                disp('\tThird time worked!');
            end
        end
        htmlOut = parseHtml(html);%process links to remove links
        htmlOutChar = char(htmlOut);%convert back to character array because that is what fopen needs
        htmlName = strcat(docName, '.html');
        fid = fopen(fullfile(rootDir, htmlName), 'w');%open HTML files 
        fprintf(fid,'%s', htmlOutChar);%write file
        fclose(fid);%close file
    catch e
        disp(e)
    end
end

function htmlOut=parseHtml(htmlIn)
%This function removes hrefs and other links.  In the future it could
%convert the links to functional hrefs to work on confluence site.

objJsoup = org.jsoup.Jsoup.parse(htmlIn);%creates a Jsoup object to process HTML
removeHrefLinks = objJsoup.select('a').unwrap();%removes hrefs
firstTable = objJsoup.select('table[width=100%]').remove();%removes links to code and Matlab help
htmlOut = objJsoup.toString();
end

function checkJavaPath
    path=[fileparts(mfilename('fullpath')) filesep 'private' filesep 'jsoup-1.8.3.jar'];
    javaaddpath(path);
end

%--------------------------------------------------------------------------%
% generateAPIDocs2.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2015 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%


%--------------------------------------------------------------------------%
% generateAPIDocs2.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
