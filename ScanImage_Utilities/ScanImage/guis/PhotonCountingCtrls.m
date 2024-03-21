function varargout = PhotonCountingCtrls(varargin)
%PHOTONCOUNTINGCTRLS MATLAB code file for PhotonCountingCtrls.fig
%      PHOTONCOUNTINGCTRLS, by itself, creates a new PHOTONCOUNTINGCTRLS or raises the existing
%      singleton*.
%
%      H = PHOTONCOUNTINGCTRLS returns the handle to a new PHOTONCOUNTINGCTRLS or the handle to
%      the existing singleton*.
%
%      PHOTONCOUNTINGCTRLS('Property','Value',...) creates a new PHOTONCOUNTINGCTRLS using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to PhotonCountingCtrls_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      PHOTONCOUNTINGCTRLS('CALLBACK') and PHOTONCOUNTINGCTRLS('CALLBACK',hObject,...) call the
%      local function named CALLBACK in PHOTONCOUNTINGCTRLS.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help PhotonCountingCtrls

% Last Modified by GUIDE v2.5 04-May-2018 14:20:00

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @PhotonCountingCtrls_OpeningFcn, ...
                   'gui_OutputFcn',  @PhotonCountingCtrls_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
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


% --- Executes just before PhotonCountingCtrls is made visible.
function PhotonCountingCtrls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for PhotonCountingCtrls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes PhotonCountingCtrls wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = PhotonCountingCtrls_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes during object creation, after setting all properties.
function pmPhysicalChannelSelector_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmPhysicalChannelSelector (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function pmPhtCtgEnable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmPhtCtgEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etIntThresh_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etIntThresh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function etPhotonSelectionMask_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPhotonSelectionMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbDifferentiate.
function cbDifferentiate_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on button press in cbAbsoluteValue.
function cbAbsoluteValue_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

function etIntThresh_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on button press in cbEnableIntegrationThreshold.
function cbEnableIntegrationThreshold_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on selection change in pmPhtCtgEnable.
function pmPhtCtgEnable_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on selection change in pmPhtCtgEnable.
function tbChannelOverview_Callback(hObject, eventdata, handles)
handles.hController.changedPhotonCountingCtrls();

% --- Executes on button press in cbUniformSampling.
function cbUniformSampling_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on selection change in pmPhysicalChannelSelector.
function pmPhysicalChannelSelector_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on button press in pbConfigurePhotonDiscriminator.
function pbConfigurePhotonDiscriminator_Callback(hObject, eventdata, handles)
handles.hController.configurePhotonDiscriminator();

% --- Executes on button press in cbDisableMaskAveraging.
function cbDisableMaskAveraging_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

function etPhotonSelectionMask_Callback(hObject, eventdata, handles)
handles.hController.changePhotonCountingCtrls();

% --- Executes on button press in pbShowPhotonHistogram.
function pbShowPhotonHistogram_Callback(hObject, eventdata, handles)
handles.hController.showPhotonHistogram();

%--------------------------------------------------------------------------%
% PhotonCountingCtrls.m                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
