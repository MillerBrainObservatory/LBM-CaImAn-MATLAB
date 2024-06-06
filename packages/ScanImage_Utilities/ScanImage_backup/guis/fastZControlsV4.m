function varargout = fastZControlsV4(varargin)
% FASTZCONTROLSV4 MATLAB code for fastZControlsV4.fig
%      FASTZCONTROLSV4, by itself, creates a new FASTZCONTROLSV4 or raises the existing
%      singleton*.
%
%      H = FASTZCONTROLSV4 returns the handle to a new FASTZCONTROLSV4 or the handle to
%      the existing singleton*.
%
%      FASTZCONTROLSV4('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in FASTZCONTROLSV4.M with the given input arguments.
%
%      FASTZCONTROLSV4('Property','Value',...) creates a new FASTZCONTROLSV4 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before fastZControlsV4_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to fastZControlsV4_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help fastZControlsV4

% Last Modified by GUIDE v2.5 05-Feb-2016 12:41:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @fastZControlsV4_OpeningFcn, ...
                   'gui_OutputFcn',  @fastZControlsV4_OutputFcn, ...
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


% --- Executes just before fastZControlsV4 is made visible.
function fastZControlsV4_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to fastZControlsV4 (see VARARGIN)

% Choose default command line output for fastZControlsV4
handles.output = hObject;

%Initialize PropControls
handles.pcFramePeriodAdjust = most.gui.control.Spinner(...
                                findobj(hObject,'Tag','sldrFramePeriodAdjust'),...
                                findobj(hObject,'Tag','etFramePeriodAdjust'));

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes fastZControlsV4 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = fastZControlsV4_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


%% Acquisition Control Panel

function cbReturnHome_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function cbCenteredStack_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function etZStepPerSlice_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function etNumZSlices_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function etVolumeRate_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function cbEnable_Callback(hObject, eventdata, handles)
updateModel(handles.hController,hObject,eventdata,handles);

function etNumVolumes_Callback(hObject, eventdata, handles)
updateModel(handles.hController,hObject,eventdata,handles);

%% Fast Z Configuration

function etFlybackTime_Callback(hObject, eventdata, handles)
updateModel(handles.hController,hObject,eventdata,handles);

function pmScanType_Callback(hObject, eventdata, handles)
handles.hController.changeWaveformType(get(hObject,'Value'));

function cbDiscardFlybackFrames_Callback(hObject, eventdata, handles)
updateModel(handles.hController,hObject,eventdata,handles);


function sldrFramePeriodAdjust_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


function etFramePeriodAdjust_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function etNumDiscardFrames_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function pbMeasureFramePeriod_Callback(hObject, eventdata, handles)
handles.hModel.hScan2D.measureScannerFrequency();


%% CREATE FCNS

% --- Executes during object creation, after setting all properties.
function etFramePeriod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etFramePeriod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function etZStepPerSlice_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etZStepPerSlice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function etNumZSlices_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumZSlices (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etVolumesDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etVolumesDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etNumVolumes_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumVolumes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function etFlybackTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etFlybackTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function pmScanType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmScanType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function sldrFramePeriodAdjust_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sldrFramePeriodAdjust (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



% --- Executes during object creation, after setting all properties.
function etFramePeriodAdjust_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etFramePeriodAdjust (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etNumDiscardFrames_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumDiscardFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etVolumeRate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etVolumeRate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbSpecifyZs.
function cbSpecifyZs_Callback(hObject, eventdata, handles)
% hObject    handle to cbSpecifyZs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hFastZ.useArbitraryZs = get(hObject,'Value');



function etUserZs_Callback(hObject, eventdata, handles)
% hObject    handle to etUserZs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etUserZs_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etUserZs (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbTunePiezo.
function pbTunePiezo_Callback(hObject, eventdata, handles)
% hObject    handle to pbTunePiezo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.tuneActuator();


% --- Executes on button press in cbCurvatureCorrection.
function cbCurvatureCorrection_Callback(hObject, eventdata, handles)
% hObject    handle to cbCurvatureCorrection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);



function etActuatorLag_Callback(hObject, eventdata, handles)
% hObject    handle to etActuatorLag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etActuatorLag_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etActuatorLag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%--------------------------------------------------------------------------%
% fastZControlsV4.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
