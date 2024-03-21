function varargout = motorsAlignmentControls(varargin)
% MOTORSALIGNMENTCONTROLS MATLAB code for motorsAlignmentControls.fig
%      MOTORSALIGNMENTCONTROLS, by itself, creates a new MOTORSALIGNMENTCONTROLS or raises the existing
%      singleton*.
%
%      H = MOTORSALIGNMENTCONTROLS returns the handle to a new MOTORSALIGNMENTCONTROLS or the handle to
%      the existing singleton*.
%
%      MOTORSALIGNMENTCONTROLS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MOTORSALIGNMENTCONTROLS.M with the given input arguments.
%
%      MOTORSALIGNMENTCONTROLS('Property','Value',...) creates a new MOTORSALIGNMENTCONTROLS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before motorsAlignmentControls_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to motorsAlignmentControls_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help motorsAlignmentControls

% Last Modified by GUIDE v2.5 03-Jun-2016 08:27:26

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @motorsAlignmentControls_OpeningFcn, ...
                   'gui_OutputFcn',  @motorsAlignmentControls_OutputFcn, ...
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


% --- Executes just before motorsAlignmentControls is made visible.
function motorsAlignmentControls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to motorsAlignmentControls (see VARARGIN)

% Choose default command line output for motorsAlignmentControls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes motorsAlignmentControls wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = motorsAlignmentControls_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pbAddCalibrationPoint.
function pbAddCalibrationPoint_Callback(hObject, eventdata, handles)
handles.hController.addMotorCalibrationPoints();



function etXStagePosition_Callback(hObject, eventdata, handles)
% hObject    handle to etXStagePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etXStagePosition as text
%        str2double(get(hObject,'String')) returns contents of etXStagePosition as a double


% --- Executes during object creation, after setting all properties.
function etXStagePosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etXStagePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etYStagePosition_Callback(hObject, eventdata, handles)
% hObject    handle to etYStagePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etYStagePosition as text
%        str2double(get(hObject,'String')) returns contents of etYStagePosition as a double


% --- Executes during object creation, after setting all properties.
function etYStagePosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etYStagePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbStagePositionAutoRead.
function cbStagePositionAutoRead_Callback(hObject, eventdata, handles)
tf = get(hObject,'Value');
if tf
    set([handles.etXStagePosition,handles.etYStagePosition],'Enable','off','String','');
else
    set([handles.etXStagePosition,handles.etYStagePosition],'Enable','on','String','0');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbResetCalibrationPoints.
function pbResetCalibrationPoints_Callback(hObject, eventdata, handles)
handles.hController.hModel.hMotors.abortCalibration();


% --- Executes on button press in pbGenerateAlignment.
function pbGenerateAlignment_Callback(hObject, eventdata, handles)
handles.hController.hModel.hMotors.createCalibrationMatrix();


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double


% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit7_Callback(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit7 as text
%        str2double(get(hObject,'String')) returns contents of edit7 as a double


% --- Executes during object creation, after setting all properties.
function edit7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etNumberCalibrationPoints_Callback(hObject, eventdata, handles)
% hObject    handle to etNumberCalibrationPoints (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumberCalibrationPoints as text
%        str2double(get(hObject,'String')) returns contents of etNumberCalibrationPoints as a double


% --- Executes during object creation, after setting all properties.
function etNumberCalibrationPoints_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumberCalibrationPoints (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbCorrectAspectRatio.
function pbCorrectAspectRatio_Callback(hObject, eventdata, handles)
handles.hController.hModel.hRoiManager.normalizeScannerAspectRatio(handles.hController.hModel.hMotors);

function etStageAspectRatio_Callback(hObject, eventdata, handles)
% hObject    handle to etStageAspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etStageAspectRatio as text
%        str2double(get(hObject,'String')) returns contents of etStageAspectRatio as a double


% --- Executes during object creation, after setting all properties.
function etStageAspectRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStageAspectRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etStageRotation_Callback(hObject, eventdata, handles)
% hObject    handle to etStageRotation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etStageRotation as text
%        str2double(get(hObject,'String')) returns contents of etStageRotation as a double


% --- Executes during object creation, after setting all properties.
function etStageRotation_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStageRotation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etStageShear_Callback(hObject, eventdata, handles)
% hObject    handle to etStageShear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etStageShear as text
%        str2double(get(hObject,'String')) returns contents of etStageShear as a double


% --- Executes during object creation, after setting all properties.
function etStageShear_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStageShear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbResetMatrix.
function pbResetMatrix_Callback(hObject, eventdata, handles)
% hObject    handle to pbResetMatrix (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hMotors.resetCalibrationMatrix();


% --- Executes on button press in pbActivateMotionCorrection.
function pbActivateMotionCorrection_Callback(hObject, eventdata, handles)
% hObject    handle to pbActivateMotionCorrection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.activateMotionCorrectionSimple;


%--------------------------------------------------------------------------%
% motorsAlignmentControls.m                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
