function make()   
    [majorVer,minorVer,updateVer] = getDAQmxVersion;
    switch computer('arch')
        case 'win32'
            archpath = 'win32';
        case 'win64'
            archpath = 'x64';
        otherwise
            assert('NI DAQmx: Unknown computer architecture: %s',computer('arch'));
    end
    fprintf('NI DAQmx: Detected DAQmx version %d.%d.%d on %s\n',majorVer,minorVer,updateVer,computer);
    
    versionpath = sprintf('NIDAQmx_%d_%d_x',majorVer,minorVer);
    
    binpath = fullfile(fileparts(mfilename('fullpath')),versionpath,archpath);
    if ~exist(binpath,'dir')
        mkdir(binpath);
    end
    
    disp('NI DAQmx: Checking Compiler setup...');
    checkCompilerSetup();

    disp('NI DAQmx: Creating header files...');
    headermodpath = makeModifiedDAQmxHeader(binpath);

    disp('NI DAQmx: Starting compilation...');
    build(binpath,headermodpath);
    disp('NI DAQmx: Compilation completed');
end

function build(binpath,headermodpath)
currentpath = pwd();

if ~isdir(binpath);mkdir(binpath);end
cd(binpath)

% suppress warnings
s = warning();
warning off MATLAB:loadlibrary:TypeNotFound
warning off MATLAB:loadlibrary:TypeNotFoundForStructure
try
    if libisloaded('nicaiu');unloadlibrary('nicaiu');end
    [~,~] = loadlibrary('nicaiu',headermodpath,'mfilename',fullfile(binpath,'NIDAQmx_proto.m'));
    unloadlibrary('nicaiu');
    delete('*.h','*.exp','*.lib','*.obj'); % clean up auxiliary files
catch ME
    cd(currentpath);
    warning(s);
    rethrow(ME);
end
cd(currentpath);
warning(s);
end

function checkCompilerSetup()
    myCCompiler = mex.getCompilerConfigurations('C','Selected');
    if isempty(myCCompiler) || isempty(myCCompiler.Name)
        error('NI DAQmx: No compiler configured in Matlab. Run ''mex -setup'' to choose a compiler.');        
    end
end

function headermodpath = makeModifiedDAQmxHeader(binpath)
copyfile(fullfile(getApiInstallationHeaderPath(),'NIDAQmx.h'),binpath,'f');

% the header needs some changes
% the line
%
%   typedef void*              TaskHandle;
%
% needs to be replaced by
%
%   #ifdef _WIN64
%   typedef uInt64             TaskHandle;
%   #else
%   typedef uInt32             TaskHandle;
%   #endif
%

headercontent = fileread(fullfile(binpath,'NIDAQmx.h'));
searchexpression = '^\s*typedef\s+void\*\s+TaskHandle;\s*$'; % 'typedef void*              TaskHandle;'
replacestring = '\r\n#ifdef _WIN64\r\ntypedef uInt64             TaskHandle;\r\n#else\r\ntypedef uInt32             TaskHandle;\r\n#endif\r\n';
headercontent_mod = regexprep(headercontent,searchexpression,replacestring,'once','lineanchors','dotexceptnewline');

% write the modified header to a new file
headermodpath = fullfile(binpath,'NIDAQmx_mod.h');
file = fopen(headermodpath,'w');
fwrite(file,headercontent_mod);
fclose(file);
end

function p = getApiInstallationHeaderPath()
pfx86 = fullfile(startPath(),'program files (x86)');
pf    = fullfile(startPath(),'program files');

if isdir(pfx86)
    pfPath = pfx86;
elseif isdir(pf)
    pfPath = pf;
else
    assert(false);    
end

p = fullfile(pfPath,'national instruments','ni-daq','daqmx ansi c dev','include');
end

function startPath = startPath()
%STARTPATH Gives path simply of drive on which Matlab is installed
%   This can be useful as input to uiputfile,uigetfile,uigetdir, rather than using the Matlab current directory

mlroot = matlabroot();
startPath = mlroot(1:3); %e.g. c:\

end


%--------------------------------------------------------------------------%
% make.m                                                                   %
% Copyright � 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
