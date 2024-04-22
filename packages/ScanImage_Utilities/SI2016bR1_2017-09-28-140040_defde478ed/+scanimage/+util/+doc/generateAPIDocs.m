function generateAPIDocs(free)
%GENERATEAPIDOCS Generates the API documentation for scanimage

    if nargin < 1 || isempty(free)
        free = false;
    end

    %% get folder names
    scriptPath = fileparts(mfilename('fullpath'));
    rootDir = fileparts(scriptPath);
    rootDir = fileparts(rootDir);


    % Create the documentation directory, res returns 1 when the directory already exists
    res = mkdir(rootDir,'docs');
    if res == 0
        most.idioms.warn('Error creating documentation directory');
        return;
    end

    componentsCell = {  
                        'scanimage.components.Channels'
                        'scanimage.components.ConfigurationSaver'
                        'scanimage.components.CycleManager'
                        'scanimage.components.Display'
                        'scanimage.components.FastZ'
                        'scanimage.components.Motors'
                        'scanimage.components.RoiManager'
                        'scanimage.components.Scan2D'
                        'scanimage.components.Shutters'
                        'scanimage.components.StackManager'
                        'scanimage.components.UserFunctions'
                        };
                        %'scanimage.components.Beams'           % Needs PowerBox documentation
                        %'scanimage.components.Pmts'            % Needs more documentation
                        %'scanimage.components.WSConnector'     % Barely any useful API calls

    %if ~free
    %componentsCell{numel(componentsCell) + 1, 1}  = 'scanimage.components.Alignment';  % Needs more documentation
    %componentsCell{numel(componentsCell) + 1, 1}  = 'scanimage.components.Photostim';  % Needs more documentation
    %componentsCell{numel(componentsCell) + 1, 1}  = 'scanimage.mroi.Roi';              
    %componentsCell{numel(componentsCell) + 1, 1}  = 'scanimage.mroi.RoiData';
    %componentsCell{numel(componentsCell) + 1, 1}  = 'scanimage.mroi.RoiGroup';
    %end

    %% Generate html documents

    % Main SI model documentation
    saveHtmlDoc(rootDir, 'scanimage.SI');

    % Components
    for i = 1:numel(componentsCell)
        saveHtmlDoc(rootDir, componentsCell{i,1});
    end

    % Other docs
    %saveHtmlDoc(rootDir, 'scanimage.util.opentif');
    %saveHtmlDoc(rootDir, 'scanimage.util.generateSIReport');
    %if ~free
        %saveHtmlDoc(rootDir, 'scanimage.util.getMroiDataFromTiff');
    %end
end

function saveHtmlDoc(rootDir, docName)
%   saves the html file corresponding to the docs/help call on docNam
%   assumces the directory 'docs' exists within rootDir
%   
    [~,html] = most.idioms.gendochtml(docName); 
    htmlName = [strrep(docName, '.', '_') '.html'];
    fid = fopen(fullfile(rootDir, 'docs', htmlName), 'w');
    fprintf(fid,'%s', html);
    fclose(fid);
end


%--------------------------------------------------------------------------%
% generateAPIDocs.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
