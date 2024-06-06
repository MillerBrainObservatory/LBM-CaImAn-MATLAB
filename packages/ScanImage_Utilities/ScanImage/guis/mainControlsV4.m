function varargout = mainControlsV4(varargin)
%MAINCONTROLSV4 M-file for mainControlsV4.fig
%      MAINCONTROLSV4, by itself, creates a new MAINCONTROLSV4 or raises the existing
%      singleton*.
%
%      H = MAINCONTROLSV4 returns the handle to a new MAINCONTROLSV4 or the handle to
%      the existing singleton*.
%
%      MAINCONTROLSV4('Property','Value',...) creates a new MAINCONTROLSV4 using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to mainControlsV4_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      MAINCONTROLSV4('CALLBACK') and MAINCONTROLSV4('CALLBACK',hObject,...) call the
%      local function named CALLBACK in MAINCONTROLSV4.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help mainControlsV4

% Last Modified by GUIDE v2.5 14-May-2016 12:57:06

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @mainControlsV4_OpeningFcn, ...
                   'gui_OutputFcn',  @mainControlsV4_OutputFcn, ...
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


% --- Executes just before mainControlsV4 is made visible.
function mainControlsV4_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for mainControlsV4
handles.output = hObject;

% Create PropControls
handles.pcZoom = most.gui.control.MultiDigitSpinner( ...
    [findobj(hObject,'Tag','zoomtensslider') findobj(hObject,'Tag','zoomonesslider') findobj(hObject,'Tag','zoomfracslider')], ...
[findobj(hObject,'Tag','zoomtens') findobj(hObject,'Tag','zoomones') findobj(hObject,'Tag','zoomfrac')], ...
    10,-1);        

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes mainControlsV4 wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = mainControlsV4_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in focusButton.
function focusButton_Callback(hObject, eventdata, handles)
% hObject    handle to focusButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.focusButton();


% --- Executes on button press in grabOneButton.
function grabOneButton_Callback(hObject, eventdata, handles)
% hObject    handle to grabOneButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.grabButton();


% --- Executes on button press in startLoopButton.
function startLoopButton_Callback(hObject, eventdata, handles)
% hObject    handle to startLoopButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.loopButton();


% --- Executes on button press in pbExternalTrig.
function pbExternalTrig_Callback(hObject, eventdata, handles)
% hObject    handle to pbExternalTrig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pbExternalTrig
handles.hController.showGUI('triggerControlsV5');


function etScanOffsetX_Callback(hObject, eventdata, handles)
% hObject    handle to etScanOffsetX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etScanOffsetX as text
%        str2double(get(hObject,'String')) returns contents of etScanOffsetX as a double


% --- Executes during object creation, after setting all properties.
function etScanOffsetX_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etScanOffsetX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etScanOffsetY_Callback(hObject, eventdata, handles)
% hObject    handle to etScanOffsetY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etScanOffsetY as text
%        str2double(get(hObject,'String')) returns contents of etScanOffsetY as a double


% --- Executes during object creation, after setting all properties.
function etScanOffsetY_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etScanOffsetY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function phaseSlider_Callback(hObject, eventdata, handles)
% hObject    handle to phaseSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function phaseSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to phaseSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in abortCurrentAcq.
function abortCurrentAcq_Callback(hObject, eventdata, handles)
% hObject    handle to abortCurrentAcq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%% File Saving Controls

function etFramesPerFile_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


function cbFramesPerFileLock_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in cbAutoSave.
function cbAutoSave_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


function etServoDelay_Callback(hObject, eventdata, handles)
% hObject    handle to etServoDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etServoDelay as text
%        str2double(get(hObject,'String')) returns contents of etServoDelay as a double


% --- Executes during object creation, after setting all properties.
function etServoDelay_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etServoDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbFinePhaseAdjust.
function cbFinePhaseAdjust_Callback(hObject, eventdata, handles)
% hObject    handle to cbFinePhaseAdjust (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbFinePhaseAdjust


% --- Executes on button press in pbDecServoDelay.
function pbDecServoDelay_Callback(hObject, eventdata, handles)
% hObject    handle to pbDecServoDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbIncServoDelay.
function pbIncServoDelay_Callback(hObject, eventdata, handles)
% hObject    handle to pbIncServoDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function etAccelerationTime_Callback(hObject, eventdata, handles)
% hObject    handle to etAccelerationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etAccelerationTime as text
%        str2double(get(hObject,'String')) returns contents of etAccelerationTime as a double


% --- Executes during object creation, after setting all properties.
function etAccelerationTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etAccelerationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbDecAccelerationTime.
function pbDecAccelerationTime_Callback(hObject, eventdata, handles)
% hObject    handle to pbDecAccelerationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbIncAccelerationTime.
function pbIncAccelerationTime_Callback(hObject, eventdata, handles)
% hObject    handle to pbIncAccelerationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbSaveConfig.
function pbSaveConfig_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveConfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in cbInfiniteFocus.
function cbInfiniteFocus_Callback(hObject, eventdata, handles)
% hObject    handle to cbInfiniteFocus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbInfiniteFocus



function shutterDelay_Callback(hObject, eventdata, handles)
% hObject    handle to shutterDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of shutterDelay as text
%        str2double(get(hObject,'String')) returns contents of shutterDelay as a double


% --- Executes during object creation, after setting all properties.
function shutterDelay_CreateFcn(hObject, eventdata, handles)
% hObject    handle to shutterDelay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function scanRotationSlider_Callback(hObject, eventdata, handles)
% hObject    handle to scanRotationSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
val = sign(get(hObject,'Value'));
set(hObject,'Value',0);
handles.hController.changeScanRotation(hObject,val);

function scanRotation_Callback(hObject, eventdata, handles)
% hObject    handle to scanRotation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of scanRotation as text
%        str2double(get(hObject,'String')) returns contents of scanRotation as a double
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes on button press in zeroRotate.
function zeroRotate_Callback(hObject, eventdata, handles)
% hObject    handle to zeroRotate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.zeroScanRotation(hObject);

% --- Executes on button press in left.
function left_Callback(hObject, eventdata, handles)
% hObject    handle to left (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.saStep(-1,0);


function fullfield_Callback(hObject, eventdata, handles)
handles.hModel.hRoiManager.scanZoomFactor = 1;


function scanShiftSlow_Callback(hObject, eventdata, handles)
% hObject    handle to scanShiftSlow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hints: get(hObject,'String') returns contents of scanShiftSlow as text
%        str2double(get(hObject,'String')) returns contents of scanShiftSlow as a double
handles.hController.updateModel(hObject,eventdata,handles);


function scanShiftFast_Callback(hObject, eventdata, handles)
% hObject    handle to scanShiftFast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hints: get(hObject,'String') returns contents of scanShiftFast as text
%        str2double(get(hObject,'String')) returns contents of scanShiftFast as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in right.
function right_Callback(hObject, eventdata, handles)
% hObject    handle to right (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.saStep(1,0);


% --- Executes on button press in down.
function down_Callback(hObject, eventdata, handles)
% hObject    handle to down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.saStep(0,1);


% --- Executes on button press in up.
function up_Callback(hObject, eventdata, handles)
% hObject    handle to up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.saStep(0,-1);


% --- Executes on button press in zero.
function zero_Callback(hObject, eventdata, handles)
% hObject    handle to zero (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.zeroScanAngle();


function ystep_Callback(hObject, eventdata, handles)
% hObject    handle to ystep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ystep as text
%        str2double(get(hObject,'String')) returns contents of ystep as a double


function xstep_Callback(hObject, eventdata, handles)
% hObject    handle to xstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xstep as text
%        str2double(get(hObject,'String')) returns contents of xstep as a double

% --- Executes on slider movement.
function zoomtensslider_Callback(hObject, eventdata, handles)
% hObject    handle to zoomtensslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles.hController.changeScanZoomFactor(hObject,10,str2double(get(handles.zoomtens,'String')), handles);


% --- Executes on slider movement.
function zoomonesslider_Callback(hObject, eventdata, handles)
% hObject    handle to zoomonesslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles.hController.changeScanZoomFactor(hObject,1,str2double(get(handles.zoomones,'String')), handles);


% --- Executes on button press in reset.
function reset_Callback(hObject, eventdata, handles)
% hObject    handle to reset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function zoomhundreds_Callback(hObject, eventdata, handles)
% hObject    handle to zoomhundreds (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zoomhundreds as text
%        str2double(get(hObject,'String')) returns contents of zoomhundreds as a double
handles.hController.changeScanZoomFactor(hObject,100,str2double(get(handles.zoomhundreds,'String')), handles);



function zoomtens_Callback(hObject, eventdata, handles)
% hObject    handle to zoomtens (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zoomtens as text
%        str2double(get(hObject,'String')) returns contents of zoomtens as a double
handles.hController.changeScanZoomFactorForEdit(hObject,10,handles);

function zoomones_Callback(hObject, eventdata, handles)
% hObject    handle to zoomones (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zoomones as text
%        str2double(get(hObject,'String')) returns contents of zoomones as a double
handles.hController.changeScanZoomFactorForEdit(hObject,1,handles);

% --- Executes on button press in selectLineScanAngle.
function selectLineScanAngle_Callback(hObject, eventdata, handles)
% hObject    handle to selectLineScanAngle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in centerOnSelection.
function centerOnSelection_Callback(hObject, eventdata, handles)
% hObject    handle to centerOnSelection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in tbPoint.
function tbPoint_Callback(hObject, eventdata, handles)
% hObject    handle to tbPoint (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tbPoint

%NOTE: In SI4, the 'align' button is re-purposed for point functionality
handles.hController.changedPointButton(hObject,eventdata);

% --- Executes on slider movement.
function zoomfracslider_Callback(hObject, eventdata, handles)
% hObject    handle to zoomfracslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
handles.hController.changeScanZoomFactor(hObject,0.1,str2double(get(handles.zoomfrac,'String')), handles);

function zoomfrac_Callback(hObject, eventdata, handles)
% hObject    handle to zoomfrac (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zoomfrac as text
%        str2double(get(hObject,'String')) returns contents of zoomfrac as a double
%handles.hController.updateModel(hObject,eventdata,handles);
handles.hController.changeScanZoomFactorForEdit(hObject,0.1,handles);

function etScanAngleMultiplierSlow_Callback(hObject, eventdata, handles)
% hObject    handle to etScanAngleMultiplierSlow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etScanAngleMultiplierSlow as text
%        str2double(get(hObject,'String')) returns contents of etScanAngleMultiplierSlow as a double
handles.hController.updateModel(hObject,eventdata,handles);

function etScanAngleMultiplierFast_Callback(hObject, eventdata, handles)
% hObject    handle to etScanAngleMultiplierFast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etScanAngleMultiplierFast as text
%        str2double(get(hObject,'String')) returns contents of etScanAngleMultiplierFast as a double
handles.hController.updateModel(hObject,eventdata,handles);

% --- Executes on button press in setReset.
function setReset_Callback(hObject, eventdata, handles)
% hObject    handle to setReset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function cycleName_Callback(hObject, eventdata, handles)
% hObject    handle to cycleName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cycleName as text
%        str2double(get(hObject,'String')) returns contents of cycleName as a double


% --- Executes during object creation, after setting all properties.
function cycleName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cycleName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function configName_Callback(hObject, eventdata, handles)
% hObject    handle to configName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etConfiguration as text
%        str2double(get(hObject,'String')) returns contents of etConfiguration as a double


% --- Executes during object creation, after setting all properties.
function etConfiguration_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etConfiguration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function cyclePosition_Callback(hObject, eventdata, handles)
% hObject    handle to cyclePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cyclePosition as text
%        str2double(get(hObject,'String')) returns contents of cyclePosition as a double


% --- Executes during object creation, after setting all properties.
function cyclePosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cyclePosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function repeatsDone_Callback(hObject, eventdata, handles)
% hObject    handle to repeatsDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etRepeatsDone as text
%        str2double(get(hObject,'String')) returns contents of etRepeatsDone as a double


% --- Executes during object creation, after setting all properties.
function etRepeatsDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etRepeatsDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function repeatsTotal_Callback(hObject, eventdata, handles)
% hObject    handle to repeatsTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumRepeats as text
%        str2double(get(hObject,'String')) returns contents of etNumRepeats as a double
handles.hController.updateModel(hObject,eventdata,handles);



function baseName_Callback(hObject, eventdata, handles)
% hObject    handle to baseName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of baseName as text
%        str2double(get(hObject,'String')) returns contents of baseName as a double
handles.hController.updateModel(hObject,eventdata,handles);


function fileCounter_Callback(hObject, eventdata, handles)
% hObject    handle to fileCounter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of fileCounter as text
%        str2double(get(hObject,'String')) returns contents of fileCounter as a double
handles.hController.updateModel(hObject,eventdata,handles);

function cbOverwriteWarn_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);
fileCounter_Callback(handles.fileCounter,eventdata, handles);

% --- Executes on slider movement.
function positionToExecuteSlider_Callback(hObject, eventdata, handles)
% hObject    handle to positionToExecuteSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function positionToExecuteSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to positionToExecuteSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function slicesDone_Callback(hObject, eventdata, handles)
% hObject    handle to slicesDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etSlicesDone as text
%        str2double(get(hObject,'String')) returns contents of etSlicesDone as a double


% --- Executes during object creation, after setting all properties.
function etSlicesDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etSlicesDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function framesTotal_Callback(hObject, eventdata, handles)
% hObject    handle to framesTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumFrames as text
%        str2double(get(hObject,'String')) returns contents of etNumFrames as a double
handles.hController.updateModel(hObject,eventdata,handles);



function slicesTotal_Callback(hObject, eventdata, handles)
% hObject    handle to slicesTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumSlices as text
%        str2double(get(hObject,'String')) returns contents of etNumSlices as a double
handles.hController.updateModel(hObject,eventdata,handles);


function etRepeatPeriod_Callback(hObject, eventdata, handles)
% hObject    handle to etRepeatPeriod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etRepeatPeriod as text
%        str2double(get(hObject,'String')) returns contents of etRepeatPeriod as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in showrotbox.
function showrotbox_Callback(hObject, eventdata, handles)
% hObject    handle to showrotbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in linescan.
function linescan_Callback(hObject, eventdata, handles)
% hObject    handle to linescan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of linescan


% --- Executes on button press in ROI.
function ROI_Callback(hObject, eventdata, handles)
% hObject    handle to ROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in addROI.
function addROI_Callback(hObject, eventdata, handles)
% hObject    handle to addROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in roiSaver.
function roiSaver_Callback(hObject, eventdata, handles)
% hObject    handle to roiSaver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns roiSaver contents as cell array
%        contents{get(hObject,'Value')} returns selected item from roiSaver


% --- Executes during object creation, after setting all properties.
function roiSaver_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roiSaver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in dropROI.
function dropROI_Callback(hObject, eventdata, handles)
% hObject    handle to dropROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in backROI.
function backROI_Callback(hObject, eventdata, handles)
% hObject    handle to backROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in nextROI.
function nextROI_Callback(hObject, eventdata, handles)
% hObject    handle to nextROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in undo.
function undo_Callback(hObject, eventdata, handles)
% hObject    handle to undo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function etSecondsCounter_Callback(hObject, eventdata, handles)
% hObject    handle to etSecondsCounter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etSecondsCounter as text
%        str2double(get(hObject,'String')) returns contents of etSecondsCounter as a double


% --- Executes during object creation, after setting all properties.
function etSecondsCounter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etSecondsCounter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pbBase_Callback(hObject, eventdata, handles)
handles.hModel.scanParamResetToBase();

function pbSetBase_Callback(hObject, eventdata, handles)
handles.hModel.scanParamSetBase();

% --- Executes on button press in cbLineScanEnable.
function cbLineScanEnable_Callback(hObject, eventdata, handles)
% hObject    handle to cbLineScanEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbLineScanEnable



function userSettingsName_Callback(hObject, eventdata, handles)
% hObject    handle to userSettingsName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etUserSettings as text
%        str2double(get(hObject,'String')) returns contents of etUserSettings as a double


% --- Executes during object creation, after setting all properties.
function etUserSettings_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etUserSettings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in tbCycleControls.
function tbCycleControls_Callback(hObject, eventdata, handles)
% hObject    handle to tbCycleControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tbCycleControls



function etIterationsTotal_Callback(hObject, eventdata, handles)
% hObject    handle to etIterationsTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etIterationsTotal as text
%        str2double(get(hObject,'String')) returns contents of etIterationsTotal as a double



function etIterationsDone_Callback(hObject, eventdata, handles)
% hObject    handle to etIterationsDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etIterationsDone as text
%        str2double(get(hObject,'String')) returns contents of etIterationsDone as a double

% --- Executes on button press in pbAddCurrent.
function pbAddCurrent_Callback(hObject, eventdata, handles)
% hObject    handle to pbAddCurrent (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbAddSquare.
function pbAddSquare_Callback(hObject, eventdata, handles)
% hObject    handle to pbAddSquare (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbAddLine.
function pbAddLine_Callback(hObject, eventdata, handles)
% hObject    handle to pbAddLine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbAddPoints.
function pbAddPoints_Callback(hObject, eventdata, handles)
% hObject    handle to pbAddPoints (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in tbToggleROI.
function tbToggleROI_Callback(hObject, eventdata, handles)
% hObject    handle to tbToggleROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tbToggleROI


% --- Executes on button press in pbAddPosition.
function pbAddPosition_Callback(hObject, eventdata, handles)
% hObject    handle to pbAddPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in pbLoadUsr.
function pbLoadUsr_Callback(hObject, eventdata, handles)
% hObject    handle to pbLoadUsr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.usrLoadUsr();

% --- Executes on button press in pbSaveUsr.
function pbSaveUsr_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveUsr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.usrSaveUsr();

% --- Executes on button press in pbLoadCfg.
function pbLoadCfg_Callback(hObject, eventdata, handles)
% hObject    handle to pbLoadCfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.cfgLoadConfig();

% --- Executes on button press in pbSaveCfg.
function pbSaveCfg_Callback(hObject, eventdata, handles)
% hObject    handle to pbSaveCfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hConfigurationSaver.cfgSaveConfig();

% --- Executes on button press in pbSetSaveDir.
function pbSetSaveDir_Callback(hObject, eventdata, handles)
% hObject    handle to pbSetSaveDir (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.setSavePath();

function etNumAvgFramesSave_Callback(hObject, eventdata, handles)
% hObject    handle to etNumAvgFramesSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumAvgFramesSave as text
%        str2double(get(hObject,'String')) returns contents of etNumAvgFramesSave as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in pbIncAcqNumber.
function pbIncAcqNumber_Callback(hObject, eventdata, handles)
% hObject    handle to pbIncAcqNumber (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hScan2D.logFileCounter = handles.hModel.hScan2D.logFileCounter + 1;

%% Fast Configurations Panel

function pbFastConfig1_Callback(hObject, eventdata, handles) %#ok<*INUSL,*DEFNU>
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(1);

function pbFastConfig2_Callback(hObject, eventdata, handles)
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(2);

function pbFastConfig3_Callback(hObject, eventdata, handles)
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(3);

function pbFastConfig4_Callback(hObject, eventdata, handles)
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(4);

function pbFastConfig5_Callback(hObject, eventdata, handles)
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(5);

function pbFastConfig6_Callback(hObject, eventdata, handles)
handles.hController.hModel.hConfigurationSaver.fastCfgLoadConfig(6);

function pbShowConfigGUI_Callback(hObject, eventdata, handles)
%TODO: Re-implement 'tethering'
handles.hController.showGUI('configControlsV4');

%% File menu
function mnu_File_LoadUserSettings_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.usrLoadUsr();

function mnu_File_SaveUserSettings_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.usrSaveUsr();

function mnu_File_SaveUserSettingsAs_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.usrSaveUsrAs();

function mnu_File_LoadConfiguration_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.cfgLoadConfig();

function mnu_File_SaveConfiguration_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.cfgSaveConfig();

function mnu_File_SaveConfigurationAs_Callback(hObject, eventdata, handles)
handles.hModel.hConfigurationSaver.cfgSaveConfigAs();

function mnu_File_FastConfigurations_Callback(hObject, eventdata, handles)
handles.hController.showGUI('fastConfigurationV4');

function mnu_File_SetSavePath_Callback(hObject, eventdata, handles)
handles.hController.setSavePath();

function mnu_File_ExitMatlab_Callback(hObject, eventdata, handles)
ans = questdlg('Are you sure you want to exit Matlab?','Exit Matlab Confirmation','Yes','No','No');

if strcmpi(ans,'No')
    return; %Abort this exit function
end
exit;

function mnu_File_ExitScanImage_Callback(hObject, eventdata, handles)
ans = questdlg('Are you sure you want to exit ScanImage?','Exit ScanImage Confirmation','Yes','No','No');

if strcmpi(ans,'No')
    return; %Abort this exit function
end
handles.hController.exit();

function mnu_File_LoadCycle_Callback(hObject, eventdata, handles)

function mnu_File_SaveCycle_Callback(hObject, eventdata, handles)

function mnu_File_SaveCycleAs_Callback(hObject, eventdata, handles)

%% Settings menu

function mnu_Settings_Beams_Callback(hObject, eventdata, handles)
handles.hController.showGUI('powerControlsV4');

function mnu_Settings_Channels_Callback(hObject, eventdata, handles)
handles.hController.showGUI('channelControlsV4');

function mnu_Settings_FastConfigurations_Callback(hObject, eventdata, handles)
handles.hController.showGUI('fastConfigurationV4');

function mnu_Settings_UserFunctions_Callback(hObject, eventdata, handles)
handles.hController.showGUI('userFunctionControlsV4');

function mnu_Settings_UserSettings_Callback(hObject, eventdata, handles)
handles.hController.showGUI('userSettingsV4');

function mnu_Settings_YokeWS_Callback(hObject, eventdata, handles)
if strcmp(get(hObject,'Checked'),'on')
	handles.hModel.hWSConnector.enable = false;
    set(hObject,'Checked','off'); 
else
	handles.hModel.hWSConnector.enable = true;
    set(hObject,'Checked','on');
end
%+++handles.hController.updateModel(hObject,eventdata,handles);

%% View menu
function mnu_View_RaiseAllWindows_Callback(hObject, eventdata, handles)
handles.hController.raiseAllGUIs();

function mnu_View_ShowAllWindows_Callback(hObject, eventdata, handles)
handles.hController.showAllGUIs();

function mnu_View_AcquisitionControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('acquisitionControlsV4');

function mnu_View_ImageControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('imageControlsV4');

function mnu_View_PowerControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('powerControlsV4');

function mnu_View_MotorControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('motorControlsV5');

function mnu_View_FastZControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('fastZControlsV4');

function mnu_View_TriggerControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('triggerControlsV5');

function mnu_View_PmtControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('pmtControlsV5');

function mnu_View_Channel1Display_Callback(hObject, eventdata, handles)
handles.hController.showChannelDisplay(1);

function mnu_View_Channel2Display_Callback(hObject, eventdata, handles)
handles.hController.showChannelDisplay(2);

function mnu_View_Channel3Display_Callback(hObject, eventdata, handles)
handles.hController.showChannelDisplay(3);

function mnu_View_Channel4Display_Callback(hObject, eventdata, handles)
handles.hController.showChannelDisplay(4);

function mnu_View_ChannelMergeDisplay_Callback(hObject, eventdata, handles)
handles.hController.showMergeDisplay(0);

function mnu_View_SlmControls_Callback(hObject, eventdata, handles)
handles.hController.showGUI('slmControls');

% --- Executes on button press in cbAutoSave.
function checkbox13_Callback(hObject, eventdata, handles)
% hObject    handle to cbAutoSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbAutoSave

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isempty(handles.hController) || ~isvalid(handles.hController)
    close(hObject);
    return
end

answer = questdlg('Are you sure you want to exit ScanImage?','Exit ScanImage Confirmation','Yes','No','No');
if strcmpi(answer,'No')
    return; %Abort this exit function
end
handles.hController.exit();

%% CREATE FCNS 

% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% --- Executes during object creation, after setting all properties.
function statusString_CreateFcn(hObject, eventdata, handles)
% hObject    handle to statusString (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% --- Executes during object creation, after setting all properties.
function pnlAcqSettings_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pnlAcqSettings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% --- Executes during object creation, after setting all properties.
function scanRotationSlider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanRotationSlider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function scanRotation_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanRotation (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function scanShiftSlow_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanShiftSlow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function scanShiftFast_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanShiftFast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function ystep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ystep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function xstep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function zoomhundredsslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomhundredsslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function zoomtensslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomtensslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes during object creation, after setting all properties.
function zoomonesslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomonesslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor',[.9 .9 .9]);
end
% --- Executes during object creation, after setting all properties.
function zoomhundreds_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomhundreds (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function zoomtens_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomtens (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function zoomones_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomones (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function zoomfracslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomfracslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor',[.9 .9 .9]);
end
% --- Executes during object creation, after setting all properties.
function zoomfrac_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zoomfrac (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function cbLineScanEnable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cbLineScanEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% --- Executes during object creation, after setting all properties.
function etScanAngleMultiplierFast_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etScanAngleMultiplierFast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etScanAngleMultiplierSlow_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etScanAngleMultiplierSlow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function configName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to configName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function repeatsDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to repeatsDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function repeatsTotal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to repeatsTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function baseName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to baseName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function fileCounter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to fileCounter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function slicesDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slicesDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function framesTotal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to framesTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function framesDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to framesDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function slicesTotal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slicesTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function userSettingsName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to userSettingsName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etIterationsTotal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etIterationsTotal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etIterationsDone_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etIterationsDone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etRepeatPeriod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etRepeatPeriod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function secondsCounter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to secondsCounter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etNumAvgFramesSave_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumAvgFramesSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etCurrentROIID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etCurrentROIID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end



% --- Executes during object creation, after setting all properties.
function left_CreateFcn(hObject, eventdata, handles)
% hObject    handle to left (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,180,[0 0 1]));


% --- Executes during object creation, after setting all properties.
function right_CreateFcn(hObject, eventdata, handles)
% hObject    handle to right (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,[],[0 0 1]));

% --- Executes during object creation, after setting all properties.
function down_CreateFcn(hObject, eventdata, handles)
% hObject    handle to down (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,90,[0 0 1]));

% --- Executes during object creation, after setting all properties.
function up_CreateFcn(hObject, eventdata, handles)
% hObject    handle to up (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'CData',most.gui.loadIcon('arrow.bmp',16,270,[0 0 1]));


% --- Executes on button press in tbToggleLinescan.
function tbToggleLinescan_Callback(hObject, eventdata, handles)
% hObject    handle to tbToggleLinescan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tbToggleLinescan
handles.hController.toggleLineScan(hObject,eventdata);


% --- Executes during object deletion, before destroying properties.
function statusString_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to statusString (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over statusString.
function statusString_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to statusString (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --------------------------------------------------------------------
function mnu_View_PhotostimControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_PhotostimControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('photostimControlsV5');

% --------------------------------------------------------------------
function mnu_View_PhotonCountingCtrls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_PhotostimControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('PhotonCountingCtrls');

% --- Executes on button press in cbEnableMroi.
function cbEnableMroi_Callback(hObject, eventdata, handles)
% hObject    handle to cbEnableMroi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbEnableMroi
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in pbEditRoiGroup.
function pbEditRoiGroup_Callback(hObject, eventdata, handles)
% hObject    handle to pbEditRoiGroup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.editImagingRoiGroup();


% --------------------------------------------------------------------
function mnu_View_AlignmentControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_AlignmentControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('AlignmentControls');


% --- Executes on button press in pbPhotostim.
function pbPhotostim_Callback(hObject, eventdata, handles)
% hObject    handle to pbPhotostim (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('photostimControlsV5');


% --- Executes on button press in fAbort.
function fAbort_Callback(hObject, eventdata, handles)
% hObject    handle to fAbort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.abortButton();


% --- Executes on button press in gAbort.
function gAbort_Callback(hObject, eventdata, handles)
% hObject    handle to gAbort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.abortButton();


% --- Executes on button press in lAbort.
function lAbort_Callback(hObject, eventdata, handles)
% hObject    handle to lAbort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.abortButton();


% --------------------------------------------------------------------
function mnu_File_GenerateReport_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_GenerateReport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
persistent processing
if isempty(processing)
    processing = false;
end
if processing
    return
else
    processing = true;
    try
        scanimage.util.generateSIReport(0);
    catch ME
        most.idioms.reportError(ME);
        processing = false;
    end
    processing = false;
end



% --------------------------------------------------------------------
function mnu_File_FactoryReset_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_FactoryReset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.resetScanImage();


% --------------------------------------------------------------------
function mnu_File_ResetDaqDevices_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_ResetDaqDevices (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.resetDaqDevices();


% --------------------------------------------------------------------
function mnu_View_CycleControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_CycleControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.hCycleManagerCtrl.raiseGUI();


% --- Executes on button press in cbExternalTrig.
function cbExternalTrig_Callback(hObject, eventdata, handles)
% hObject    handle to cbExternalTrig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pbExternalTrig.
function pbExternalTrig_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pbExternalTrig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object creation, after setting all properties.
function etFramesPerFile_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etFramesPerFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
set(hObject,'BackgroundColor','white');
end


% --- Executes on key press with focus on pbExternalTrig and none of its controls.
function pbExternalTrig_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to pbExternalTrig (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pbFastCfg.
function pbFastCfg_Callback(hObject, eventdata, handles)
% hObject    handle to pbFastCfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('fastConfigurationV4');


% --------------------------------------------------------------------
function mnu_View_IntegrationControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_IntegrationControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('integrationRoiOutputChannelControlsV5');


% --- Executes on button press in pbIntegration.
function pbIntegration_Callback(hObject, eventdata, handles)
% hObject    handle to pbIntegration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('integrationRoiOutputChannelControlsV5');


% --- Executes on button press in cbIntegration.
function cbIntegration_Callback(hObject, eventdata, handles)
% hObject    handle to cbIntegration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);



% --------------------------------------------------------------------
function mnu_View_StatusWindow_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_StatusWindow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('StatusWindow');


% --------------------------------------------------------------------
function mnu_View_MotionCorrectionControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_View_MotionCorrectionControls (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('MotionDisplay');


% --------------------------------------------------------------------
function mnu_File_Config_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_Config (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.openConfigEditor();


% --------------------------------------------------------------------
function mnu_View_WaveformControls_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_Config (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('waveformControls');


% --------------------------------------------------------------------
function mnu_View_LaserTriggerScope_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_Config (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('LaserTriggerScope');


% --------------------------------------------------------------------
function mnu_View_DataScope_Callback(hObject, eventdata, handles)
% hObject    handle to mnu_File_Config (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.showGUI('DataScope');


%--------------------------------------------------------------------------%
% mainControlsV4.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
