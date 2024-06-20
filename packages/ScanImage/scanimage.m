function [hSI_,hSICtl_] = scanimage(varargin)
% SCANIMAGE     starts ScanImage application and its GUI(s)
%
%   It places two variables in the base workspace.
%   hSI is a scanimage.SI object that gives access to the operation and
%   configuration of the microscope.  hSICtl gives access to the user
%   interface elements.  There is implicit synchronization between the
%   microscope configuration and the user interface, so most of the time,
%   hSICtl can be safely ignored.
%
%   See also scanimage.SI and scanimage.SIController

if nargout > 0
    hSI_ = [];
    hSICtl_ = [];
end

mdf = '';
usr = '';
hidegui = false;

scanimage.util.checkSystemRequirements();

if nargin > 0 && ischar(varargin{1})
    mdf = varargin{1};
    assert(logical(exist(mdf,'file')), 'Specified machine data file not found.');
end

if nargin > 1 && ischar(varargin{2})
    usr = varargin{2};
    if ~isempty(usr)
        assert(logical(exist(usr,'file')), 'Specified usr file not found.');
    end
end

if nargin > 2
    for i = 3:nargin
        if ischar(varargin{i}) && strcmp(varargin{i}, '-hidegui')
            hidegui = true;
        end
    end
end

hSI = [];
if evalin('base','exist(''hSI'')')
    hSI = evalin('base','hSI');
end

hSICtl = [];
if evalin('base','exist(''hSICtl'')')
    hSICtl = evalin('base','hSICtl');
end

if isempty(hSI)    
    hCE = scanimage.guis.ConfigurationEditor([],false,true); %ConfigurationEditor(mdfPath,initNow,persist)
    
    if isempty(mdf) && isempty(usr)
        [mdf,usr,runSI] = scanimage.guis.StartupConfig.doModalConfigPrompt(mdf,usr,hCE);
        if ~runSI
            most.idioms.safeDeleteObj(hCE);
            return;
        end
    end
    
    try
        hSI = scanimage.SI(mdf,hCE);
        hSIBasename = 'hSI';
        assignin('base',hSIBasename,hSI); % assign object in base as soon as it is constructed
        hSI.initialize();
        
        hSICtl = scanimage.SIController(hSI);
        hSICtl.hConfigEditor = hCE;
        assignin('base','hSICtl',hSI.hController{1}); % assign object in base as soon as it is constructed
        hSICtl.initialize(usr,hidegui);
        hSICtl.attachPropBindingsToToolTipStrings(['Command line: ' hSIBasename '.']);
        
    catch ME
        if exist('hSI', 'var')
            most.idioms.safeDeleteObj(hSI);
        end
        
        most.idioms.safeDeleteObj(hCE);
        evalin('base','clear hSI hSICtl MachineDataFile');
        
        if strcmp(ME.message, 'MachineDateFile: Operation canceled.')
            most.idioms.warn(ME.message);
        else
            ME.rethrow;
        end
    end
elseif isempty(hSICtl)
    try
        hSICtl = scanimage.SIController(hSI);
        assignin('base','hSICtl',hSICtl);
        hSICtl.initialize(usr,hidegui);
        hSICtl.attachPropBindingsToToolTipStrings('Command line: hSI.');
    catch ME
        evalin('base','clear hSICtl');
        ME.rethrow;
    end
else
    most.idioms.warn('ScanImage is already running.');
    evalin('base','hSICtl.raiseAllGUIs')
end

if nargout > 0
    hSI_ = hSI;
    hSICtl_ = hSICtl;
end

end


%--------------------------------------------------------------------------%
% scanimage.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
