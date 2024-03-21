function loadHtml2Confluence()

docDir = pwd;
disp('Processing ScanImage docs.....');
processSIDocs(docDir);
disp('Processing most docs.....');
processMostDocs(docDir);
disp('Processing dabs docs.....');
processDabsDocs(docDir);




end

function processSIDocs(docDir)
siDocDir = strcat(docDir, '\scaniamge\components');
treeInfo = {};
fileId = fopen('C:\bitbucket\ScanImage\+scanimage\+util\ScanImageAPITreeStructure.csv');
treeInfo = textscan(fileId, '%s %s %s %s','Delimiter', ',');
%celldisp(treeInfo);
fclose(fileId);

[nrows, ncols] = size(treeInfo{1});
[status, cmdOut] = dos('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "ScanImage Application Model (hSI)" --parent "ScanImage API" --replace', '-echo');
refPageIds = {};
refPageIds{1} = 'Line1';
refPageIds{2} = findPageId(cmdOut);
    for n=3:nrows
        if (strcmp(treeInfo{3}{n}, '') == 1 || strcmp(treeInfo{4}{n}, '') == 1)
            dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "', treeInfo{1}{n}, '" --parent "', treeInfo{2}{n}, '" --replace'); 
        else
            dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "', treeInfo{1}{n}, '" --parent "', treeInfo{2}{n}, '" --file "', treeInfo{3}{n}, '\', treeInfo{4}{n}, '" --content "{html}" --content2 "{html}" --replace'); 
        end
        [status, cmdOut] = dos(dosCmd, '-echo');  
        refPageIds{n} = findPageId(cmdOut);
    end
locSIHtml = strcat(treeInfo{3}{2}, '\', treeInfo{4}{2});
inputHtml = java.io.File(locSIHtml);
objJsoup = org.jsoup.Jsoup.parse(inputHtml, 'UTF-8', '');
    for m = 3:nrows
        [path, name, ext] = fileparts(treeInfo{4}{m});
        if(strcmp(name, '') == 0 && strcmp(name, 'Roi') == 0)
            name = strcat('h', name);
            elementName = strcat('td:contains(', name, ')');
            hAlignmentTd = objJsoup.select(elementName);
            hAlignmentTd.empty();
            hRef = strcat('<a href="http://scanimage.vidriotechnologies.com/pages/viewpage.action?pageId=', refPageIds{m}, '">', name);
            hAlignmentTd.prepend(hRef);
            hAlignmentTd.after('</a>');
        end
    end

strHtml = objJsoup.toString();
revisedHtml = char(strHtml);
fid = fopen(locSIHtml, 'w');
fprintf(fid,'%s', revisedHtml);
fclose(fid);    
dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "ScanImage Application Model (hSI)" --parent "ScanImage API" --file "', locSIHtml, '" --content "{html}" --content2 "{html}" --replace');
[status, cmdOut] = dos(dosCmd, '-echo');

locROIManagerHtml = strcat(treeInfo{3}{15}, '\', treeInfo{4}{15});
inputHtml2 = java.io.File(locROIManagerHtml);
objJsoup2 = org.jsoup.Jsoup.parse(inputHtml2, 'UTF-8', '');
elementName = 'td:contains(currentRoiGroup)';
hAlignmentTd = objJsoup2.select(elementName);
hAlignmentTd.empty();
hRef = strcat('<a href="http://scanimage.vidriotechnologies.com/pages/viewpage.action?pageId=', refPageIds{16}, '">currentRoiGroup');
hAlignmentTd.prepend(hRef);
hAlignmentTd.after('</a>');
elementName = 'td:contains(roiGroupMroi)';

% ElementTransformer(element) -> element
    function e = IdentityElementTransformer(element)
        e=element;
    end
    function e = FirstElementTransformer(element)
        e=element.first;
    end

    function proc(elemname,elementTransformerFunc)
        locROIManagerHtml = strcat(treeInfo{3}{15}, '\', treeInfo{4}{15});
        inputHtml2 = java.io.File(locROIManagerHtml);
        objJsoup2 = org.jsoup.Jsoup.parse(inputHtml2, 'UTF-8', '');
        elementName = 'td:contains(currentRoiGroup)';
        hAlignmentTd = elementTransformerFunc( objJsoup2.select(elemname) );
        hAlignmentTd.empty();
        hRef = strcat('<a href="http://scanimage.vidriotechnologies.com/pages/viewpage.action?pageId=', refPageIds{16}, '">currentRoiGroup');
        hAlignmentTd.prepend(hRef);
        hAlignmentTd.after('</a>');
    end

% using  it
proc(elementName,@IdentityElementTransformer);
proc(elementName,@FirstElementTransformer);

%before
hAlignmentTd = objJsoup2.select(elementName).first();

%after
hAlignmentTd = ElementTransformer( objJsoup2.select(elementName) );



hAlignmentTd.empty();
hRef = strcat('<a href="http://scanimage.vidriotechnologies.com/pages/viewpage.action?pageId=', refPageIds{16}, '">roiGroupMroi');
hAlignmentTd.prepend(hRef);
hAlignmentTd.after('</a>');

strHtml2 = objJsoup2.toString();
revisedHtml2 = char(strHtml2);
fid = fopen(locROIManagerHtml, 'w');
fprintf(fid,'%s', revisedHtml2);
fclose(fid);    
dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "ROI Manager (hSI.hRoiManager)" --parent "ScanImage Application Model (hSI)" --file "', locROIManagerHtml, '" --content "{html}" --content2 "{html}" --replace');
[status, cmdOut] = dos(dosCmd, '-echo');

locCycleManagerHtml = strcat(treeInfo{3}{7}, '\', treeInfo{4}{7});
inputHtml3 = java.io.File(locCycleManagerHtml);
objJsoup3 = org.jsoup.Jsoup.parse(inputHtml3, 'UTF-8', '');
elementName = 'td:contains(cycleDataGroup)';
hAlignmentTd = objJsoup3.select(elementName);
hAlignmentTd.empty();
hRef = strcat('<a href="http://scanimage.vidriotechnologies.com/pages/viewpage.action?pageId=', refPageIds{9}, '">cycleDataGroup');
hAlignmentTd.prepend(hRef);
hAlignmentTd.after('</a>');

strHtml3 = objJsoup3.toString();
revisedHtml3 = char(strHtml3);
fid = fopen(locCycleManagerHtml, 'w');
fprintf(fid,'%s', revisedHtml3);
fclose(fid);    
dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action addPage --space "API" --title "Cycle Manager (hSI.hCycleManager)" --parent "ScanImage Application Model (hSI)" --file "', locCycleManagerHtml, '" --content "{html}" --content2 "{html}" --replace');
[status, cmdOut] = dos(dosCmd, '-echo');

end

function processMostDocs(docDir)
locMostHtml = strcat(docDir, '\docs\most');
dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action loadFiles --space "API" --title "Most" --parent "ScanImage API" --file "', locMostHtml, '" --replace');
[status, cmdOut] = dos(dosCmd, '-echo');
end

function processDabsDocs(docDir)
locDabsHtml = strcat(docDir, '\docs\dabs');
dosCmd = strcat('C:\atlassian-cli-5.0.0-distribution\atlassian-cli-5.0.0\atlassian confluence --action loadFiles --space "API" --title "Dabs" --parent "ScanImage API" --file "', locDabsHtml, '" --replace');
[status, cmdOut] = dos(dosCmd, '-echo');
end

function pageID=findPageId(cmdOut)
pageID = cmdOut((strfind(cmdOut, 'id: ')+4):numel(cmdOut));
end


%--------------------------------------------------------------------------%
% loadHtml2Confluencev2.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
