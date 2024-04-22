function varargout = userFunctionControlsV4(varargin)
% USERFUNCTIONCONTROLSV4 MATLAB code for userFunctionControlsV4.fig
%      USERFUNCTIONCONTROLSV4, by itself, creates a new USERFUNCTIONCONTROLSV4 or raises the existing
%      singleton*.
%
%      H = USERFUNCTIONCONTROLSV4 returns the handle to a new USERFUNCTIONCONTROLSV4 or the handle to
%      the existing singleton*.
%
%      USERFUNCTIONCONTROLSV4('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in USERFUNCTIONCONTROLSV4.M with the given input arguments.
%
%      USERFUNCTIONCONTROLSV4('Property','Value',...) creates a new USERFUNCTIONCONTROLSV4 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before userFunctionControlsV4_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to userFunctionControlsV4_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help userFunctionControlsV4

% Last Modified by GUIDE v2.5 15-Jun-2011 19:27:26

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @userFunctionControlsV4_OpeningFcn, ...
    'gui_OutputFcn',  @userFunctionControlsV4_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

function userFunctionControlsV4_OpeningFcn(hObject,~,handles,varargin)
handles.output = hObject;

hModel = varargin{1};
hController = varargin{2};

% Construct userFunctionsTable
recordFieldInfo = struct(...
    'EventName',struct('Column',2,'EncodeFcn',[],'DecodeFcn',[]),...
    'UserFcnName',struct('Column',3,'EncodeFcn',[],'DecodeFcn',[]),...
    'Arguments',struct('Column',4,'EncodeFcn',@most.util.toString,'DecodeFcn',@(x)eval(x)),...
    'Enable',struct('Column',5,'EncodeFcn',@logical,'DecodeFcn',[]));
firstUserFcn = hModel.hUserFunctions.userFunctionsEvents{1};
defaultNewRecord = struct('EventName',firstUserFcn,'UserFcnName','','Arguments',{{}},'Enable',false);
handles.uft = scanimage.components.userfcns.UserFunctionsTable(hModel.hUserFunctions,handles.tblUserFunctions,...
    recordFieldInfo,'EventName',@()hController.userFunctionsCurrentEvents,@()hController.userFunctionsCurrentProp,...
    defaultNewRecord);

% Construct userFunctionsTable for override fcns
recordFieldInfo = struct(...
    'Function',struct('Column',2,'EncodeFcn',[],'DecodeFcn',[]),...
    'UserFcnName',struct('Column',3,'EncodeFcn',[],'DecodeFcn',[]),...
    'Enable',struct('Column',4,'EncodeFcn',@logical,'DecodeFcn',[]));
firstOverrideFcn = hModel.hUserFunctions.userFunctionsOverrideFunctions{1};
overrideDefaultNewRecord = struct('Function',firstOverrideFcn,'UserFcnName','','Enable',false);
handles.uftOverride = scanimage.components.userfcns.UserFunctionsTable(hModel.hUserFunctions,handles.tblOverrideFcns,...
    recordFieldInfo,'Function',@()hModel.hUserFunctions.userFunctionsOverrideFunctions,@()'userFunctionsOverride',...
    overrideDefaultNewRecord);

most.gui.AdvancedPanelToggler.init(hObject,handles.tbShowAdvanced,11.4);

guidata(hObject, handles);

% Set buttongroup selectionChangeFcn (for some reason not accessible in GUIDE Property Inspector)
set(handles.bgView,'SelectionChangeFcn',@zcbkBgViewSelectionChanged);

% Set initial userFunctions view to be CFG
set(handles.tbCfg,'Value',1);

% SI4Controller initializes tables

function varargout = userFunctionControlsV4_OutputFcn(~,~,handles)
varargout{1} = handles.output;

function zcbkBgViewSelectionChanged(src,~)
handles = guidata(src);
handles.uft.refresh();

function pbAdd_Callback(~,~,handles)
handles.uft.add();

function pbDel_Callback(hObject,eventdata,handles) %#ok<*DEFNU,INUSL>
handles.uft.del();

function cbAffectAll_Callback(hObject,~,handles)
val = get(hObject,'Value');
switch handles.hController.userFunctionsViewType
    case 'none'
    case 'CFG'
        if ~isempty(handles.hModel.hUserFunctions.userFunctionsCfg)
            [handles.hModel.hUserFunctions.userFunctionsCfg.Enable] = deal(val);
        end
    case 'USR'
        if ~isempty([handles.hModel.hUserFunctions.userFunctionsUsr.Enable])
            [handles.hModel.hUserFunctions.userFunctionsUsr.Enable] = deal(val);
        end 
end

function tbShowAdvanced_Callback(hObject,~,~)
hFig = ancestor(hObject,'figure');
most.gui.AdvancedPanelToggler.toggle(hFig);

function pbAddOverride_Callback(~,~,handles)
handles.uftOverride.add();

function pbDelOverride_Callback(~,~,handles)
handles.uftOverride.del();

function pbSave_Callback(~,~,handles)
switch handles.hController.userFunctionsViewType
    case 'none'
    case 'CFG'
        handles.hModel.hConfigurationSaver.cfgSaveConfig;
    case 'USR'
        handles.hModel.hConfigurationSaver.usrSaveUsr;
end

function pbSaveOverrides_Callback(hObject, eventdata, handles)
handles.hModel.cfgSaveConfig;


%--------------------------------------------------------------------------%
% userFunctionControlsV4.m                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
