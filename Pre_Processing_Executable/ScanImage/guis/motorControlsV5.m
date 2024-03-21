function varargout = motorControlsV5(varargin)
%MOTORCONTROLSV5 M-file for motorControlsV5.fig

% Edit the above text to modify the response to help motorControlsV5

% Last Modified by GUIDE v2.5 09-Dec-2016 13:30:41

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @motorControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @motorControlsV5_OutputFcn, ...
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

function motorControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;
guidata(hObject, handles);

function varargout = motorControlsV5_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;

%% Main Subpanel - Position controls
function pbReadPos_Callback(hObject, eventdata, handles) %#ok<*INUSL,*DEFNU>
handles.hController.changedMotorPosition;

function etPosX_Callback(hObject, eventdata, handles)
handles.hController.changeMotorPosition(hObject,1);

function etPosY_Callback(hObject, eventdata, handles)
handles.hController.changeMotorPosition(hObject,2);

function etPosZ_Callback(hObject, eventdata, handles)
handles.hController.changeMotorPosition(hObject,3);

function etPosZZ_Callback(hObject, eventdata, handles)
handles.hController.changeMotorPosition(hObject,4);

function pbZeroXYZ_Callback(hObject, eventdata, handles)
handles.hController.motorZeroAction('motorZeroXYZ');

function pbZeroZ_Callback(hObject, eventdata, handles)
handles.hController.motorZeroAction('motorZeroZ');

function pbZeroXY_Callback(hObject, eventdata, handles)
handles.hController.motorZeroAction('motorZeroXY');

function pbAltZeroXY_Callback(hObject, eventdata, handles)
handles.hController.motorZeroAction('motorZeroXY');

function pbAltZeroZ_Callback(hObject, eventdata, handles)
handles.hController.motorZeroAction('motorZeroZ');

function pbClearZero_Callback(hObject, eventdata, handles)
handles.hController.motorClearZero();

function cbSecZ_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

%% Main Subpanel - Arrow controls

function pbStepXInc_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(1,1);

function pbStepYInc_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(1,2);

function pbStepZInc_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(1,3);

function pbStepXDec_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(-1,1);

function pbStepYDec_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(-1,2);

function pbStepZDec_Callback(hObject, eventdata, handles)
handles.hController.motorStepPosition(-1,3);

function etStepSizeX_Callback(hObject, eventdata, handles)
handles.hController.motorStepSize(1) = str2double(get(hObject,'String'));

function etStepSizeY_Callback(hObject, eventdata, handles)
handles.hController.motorStepSize(2) = str2double(get(hObject,'String'));

function etStepSizeZ_Callback(hObject, eventdata, handles)
handles.hController.motorStepSize(3) = str2double(get(hObject,'String'));

function etStepSizeZZ_Callback(hObject, eventdata, handles)
handles.hController.motorStepSize(4) = str2double(get(hObject,'String'));

function pbPosn_Callback(hObject, eventdata, handles)
handles.hController.showGUI('posnControlsV5');
handles.hController.raiseGUI('posnControlsV5');

%% Stack subpanel
function pbSetStart_Callback(hObject, eventdata, handles)
handles.hController.stackSetStackStart();

function pbSetEnd_Callback(hObject, eventdata, handles)
handles.hController.stackSetStackEnd();

function pbClearStartEnd_Callback(hObject, eventdata, handles)
handles.hController.stackClearStartEnd();

function pbClearEnd_Callback(hObject, eventdata, handles)
handles.hController.stackClearEnd();

function cbUseStartPower_Callback(hObject,eventdata,handles)
tfUseStartPower = get(hObject,'Value');
if ~tfUseStartPower
    % Using overrideLz without stackUseStartPower is very rare. The SI4
    % API permits this with a warning, but here in UI we help the user out.
    handles.hController.hModel.hBeams.stackUserOverrideLz = false;
end
handles.hController.hModel.hBeams.stackUseStartPower = tfUseStartPower;

function cbOverrideLz_Callback(hObject, eventdata, handles)
tfOverrideLz = get(hObject,'Value');
if tfOverrideLz
    % Using overrideLz without stackUseStartPower is very rare. The SI4
    % API permits this with a warning, but here in the UI we help the user out.
    handles.hController.hModel.hBeams.stackUseStartPower = true;
end
handles.hController.hModel.hBeams.stackUserOverrideLz = tfOverrideLz;

function etNumberOfZSlices_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function etZStepPerSlice_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function cbReturnHome_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

function cbCenteredStack_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);

%% The yellow button
function pbRecover_Callback(hObject,eventdata,handles)
handles.hController.motorRecover();

%% CREATE FCNS 

% --- Executes during object creation, after setting all properties.
function etPosnID1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosnID1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etStepSizeX_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStepSizeX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etStepSizeY_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStepSizeY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etStepSizeZ_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStepSizeZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etNumberOfZSlices_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumberOfZSlices (see GCBO)
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
function etStepSizeZZ_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStepSizeZZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etPosY_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etPosZ_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etPosX_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etPosR_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etStackEnd_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStackEnd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etEndPower_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etEndPower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etStackStart_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStackStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function etStartPower_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStartPower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etPosZZ_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosZZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);

%% CREATE FCNS


% --- Executes during object creation, after setting all properties.
function pbStepXDec_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepXDec (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,180,[0 0 1]));


% --- Executes during object creation, after setting all properties.
function pbStepXInc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepXInc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,[],[0 0 1]));


% --- Executes during object creation, after setting all properties.
function pbStepYDec_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepYDec (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,90,[0 0 1]));


% --- Executes during object creation, after setting all properties.
function pbStepYInc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepYInc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,270,[0 0 1]));


% --- Executes during object creation, after setting all properties.
function pbStepZDec_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepZDec (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,90,[0 0 1]));


% --- Executes during object creation, after setting all properties.
function pbStepZInc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbStepZInc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,270,[0 0 1]));


% --- Executes on button press in pbOverrideLz.
function pbOverrideLz_Callback(hObject, eventdata, handles)
% hObject    handle to pbOverrideLz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hBeams.lengthConstants = handles.hModel.hBeams.beamComputeOverrideLzs();


% --- Executes during object creation, after setting all properties.
function etPosnID2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosnID2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etPosnID1_Callback(hObject, eventdata, handles)
handles.hController.changedPosnID(hObject, handles.pbGo1)


function etPosnID2_Callback(hObject, eventdata, handles)
handles.hController.changedPosnID(hObject, handles.pbGo2)


function etPosnID3_Callback(hObject, eventdata, handles)
handles.hController.changedPosnID(hObject, handles.pbGo3)

% --- Executes during object creation, after setting all properties.
function etPosnID3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosnID3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pbGo1_Callback(hObject, eventdata, handles)
handles.hModel.hMotors.gotoUserDefinedPosition(str2double(get(handles.etPosnID1,'String')));

function pbGo2_Callback(hObject, eventdata, handles)
handles.hModel.hMotors.gotoUserDefinedPosition(str2double(get(handles.etPosnID2,'String')));

function pbGo3_Callback(hObject, eventdata, handles)
handles.hModel.hMotors.gotoUserDefinedPosition(str2double(get(handles.etPosnID3,'String')));


% --- Executes on button press in pbStepZZDec.
function pbStepZZDec_Callback(hObject, eventdata, handles)
% hObject    handle to pbStepZZDec (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.motorStepPosition(-1,4);

% --- Executes on button press in pbStepZZInc.
function pbStepZZInc_Callback(hObject, eventdata, handles)
% hObject    handle to pbStepZZInc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.motorStepPosition(1,4);


% --- Executes on button press in pbMotorAlignment.
function pbMotorAlignment_Callback(hObject, eventdata, handles)
% hObject    handle to pbMotorAlignment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('motorsAlignmentControls');



function etStepLimit_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etStepLimit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStepLimit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbLSCInit.
function pbLSCInit_Callback(hObject, eventdata, handles)
handles.hController.changeLSCInitted();



function edit_elevation_Callback(hObject, eventdata, handles)
% hObject    handle to edit_elevation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_elevation as text
%        str2double(get(hObject,'String')) returns contents of edit_elevation as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function edit_elevation_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_elevation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_azimuth_Callback(hObject, eventdata, handles)
% hObject    handle to edit_azimuth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_azimuth as text
%        str2double(get(hObject,'String')) returns contents of edit_azimuth as a double
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes during object creation, after setting all properties.
function edit_azimuth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_azimuth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbEnableObjectiveAngles.
function pbEnableObjectiveAngles_Callback(hObject, eventdata, handles)
% hObject    handle to pbEnableObjectiveAngles (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.toggleShowObjectiveAngles();


%--------------------------------------------------------------------------%
% motorControlsV5.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
