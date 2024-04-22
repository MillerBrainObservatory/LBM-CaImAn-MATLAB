function varargout = photostimControlsV5(varargin)
% PHOTOSTIMCONTROLSV5 MATLAB code for photostimControlsV5.fig
%      PHOTOSTIMCONTROLSV5, by itself, creates a new PHOTOSTIMCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = PHOTOSTIMCONTROLSV5 returns the handle to a new PHOTOSTIMCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      PHOTOSTIMCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PHOTOSTIMCONTROLSV5.M with the given input arguments.
%
%      PHOTOSTIMCONTROLSV5('Property','Value',...) creates a new PHOTOSTIMCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before photostimControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to photostimControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help photostimControlsV5

% Last Modified by GUIDE v2.5 29-Jan-2016 09:59:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @photostimControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @photostimControlsV5_OutputFcn, ...
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


% --- Executes just before photostimControlsV5 is made visible.
function photostimControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to photostimControlsV5 (see VARARGIN)

% Choose default command line output for photostimControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes photostimControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = photostimControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pbStart.
function pbStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.hController.hModel.hPhotostim.active
    handles.hController.hModel.hPhotostim.abort();
else
    handles.hController.hModel.hPhotostim.start();
end



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1


% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbSoftTrig.
function pbSoftTrig_Callback(hObject, eventdata, handles)
% hObject    handle to pbSoftTrig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.hModel.hPhotostim.triggerStim();




% --- Executes on button press in pbSync.
function pbSync_Callback(hObject, eventdata, handles)
% hObject    handle to pbSync (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.hModel.hPhotostim.triggerSync();


% --- Executes on selection change in lbStimGroups.
function lbStimGroups_Callback(hObject, eventdata, handles)
% hObject    handle to lbStimGroups (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns lbStimGroups contents as cell array
%        contents{get(hObject,'Value')} returns selected item from lbStimGroups
persistent lastClickTic
v = get(hObject,'Value');
if ~isempty(v) && strcmp(get(handles.figure1,'SelectionType'), 'open')
    if isempty(lastClickTic) || toc(lastClickTic) > 0.5
        lastClickTic = tic();
        handles.hController.dblClickStimGroup(v);
    end
end


% --- Executes during object creation, after setting all properties.
function lbStimGroups_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lbStimGroups (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pbMode.
function pbMode_Callback(hObject, eventdata, handles)
% hObject    handle to pbMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pbMode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pbMode
handles.hController.changePhotostimMode(get(hObject, 'value'));


% --- Executes during object creation, after setting all properties.
function pbMode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pbMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etSequence_Callback(hObject, eventdata, handles)
% hObject    handle to etSequence (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etSequence as text
%        str2double(get(hObject,'String')) returns contents of etSequence as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etSequence_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etSequence (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etNumSequences_Callback(hObject, eventdata, handles)
% hObject    handle to etNumSequences (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumSequences as text
%        str2double(get(hObject,'String')) returns contents of etNumSequences as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etNumSequences_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumSequences (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbNew.
function pbNew_Callback(hObject, eventdata, handles)
% hObject    handle to pbNew (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.addStimGroup();

% --- Executes on button press in pbDelete.
function pbDelete_Callback(hObject, eventdata, handles)
% hObject    handle to pbDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.remStimGroup();

% --- Executes on button press in pbEdit.
function pbEdit_Callback(hObject, eventdata, handles)
% hObject    handle to pbEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.editStimGroup();

% --- Executes on button press in cbStimImmediately.
function cbStimImmediately_Callback(hObject, eventdata, handles)
% hObject    handle to cbStimImmediately (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbStimImmediately
handles.hController.updateModel(hObject,eventdata,handles);



function etTrigTerm_Callback(hObject, eventdata, handles)
% hObject    handle to etTrigTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etTrigTerm as text
%        str2double(get(hObject,'String')) returns contents of etTrigTerm as a double
handles.hController.changePhotostimTrigger();


% --- Executes during object creation, after setting all properties.
function etTrigTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etTrigTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etSyncTerm_Callback(hObject, eventdata, handles)
% hObject    handle to etSyncTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etSyncTerm as text
%        str2double(get(hObject,'String')) returns contents of etSyncTerm as a double
handles.hController.changePhotostimSync();


% --- Executes during object creation, after setting all properties.
function etSyncTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etSyncTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function etStatus_Callback(hObject, eventdata, handles)
% hObject    handle to etStatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etStatus as text
%        str2double(get(hObject,'String')) returns contents of etStatus as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etStatus_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbAllowMult.
function cbAllowMult_Callback(hObject, eventdata, handles)
% hObject    handle to cbAllowMult (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbAllowMult
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in cbEnableHotkeys.
function cbEnableHotkeys_Callback(hObject, eventdata, handles)
% hObject    handle to cbEnableHotkeys (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbEnableHotkeys
handles.hController.enablePhotostimHotkeys = get(hObject,'Value');


% --- Executes on button press in pbDown.
function pbDown_Callback(hObject, eventdata, handles)
% hObject    handle to pbDown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.moveStimGroup(1);


% --- Executes on button press in pbCopy.
function pbCopy_Callback(hObject, eventdata, handles)
% hObject    handle to pbCopy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.copyStimGroup();


% --- Executes on button press in pbUp.
function pbUp_Callback(hObject, eventdata, handles)
% hObject    handle to pbUp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.moveStimGroup(-1);


function etExtStimSelTriggerTerm_Callback(hObject, eventdata, handles)
% hObject    handle to etExtStimSelTriggerTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etExtStimSelTriggerTerm as text
%        str2double(get(hObject,'String')) returns contents of etExtStimSelTriggerTerm as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etExtStimSelTriggerTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etExtStimSelTriggerTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etExtStimSelTerms_Callback(hObject, eventdata, handles)
% hObject    handle to etExtStimSelTerms (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etExtStimSelTerms as text
%        str2double(get(hObject,'String')) returns contents of etExtStimSelTerms as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etExtStimSelTerms_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etExtStimSelTerms (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etExtStimSelAssignments_Callback(hObject, eventdata, handles)
% hObject    handle to etExtStimSelAssignments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etExtStimSelAssignments as text
%        str2double(get(hObject,'String')) returns contents of etExtStimSelAssignments as a double
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etExtStimSelAssignments_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etExtStimSelAssignments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbLogging.
function cbLogging_Callback(hObject, eventdata, handles)
handles.hController.setPhotostimLogging(hObject.Value);

% --- Executes on button press in cbShowMonitor.
function cbShowMonitor_Callback(hObject, eventdata, handles)
handles.hController.setPhotostimMonitor(hObject.Value);


% --- Executes on button press in pbCalibrateMonitorAndOffset.
function pbCalibrateMonitorAndOffset_Callback(hObject, eventdata, handles)
% hObject    handle to pbCalibrateMonitorAndOffset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.calibratePhotostimMonitor();


% --- Executes on selection change in pmTrigSource.
function pmTrigSource_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigSource (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePhotostimTrigger();
% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigSource contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigSource


% --- Executes during object creation, after setting all properties.
function pmTrigSource_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigSource (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmSyncSource.
function pmSyncSource_Callback(hObject, eventdata, handles)
% hObject    handle to pmSyncSource (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePhotostimSync();


% --- Executes during object creation, after setting all properties.
function pmSyncSource_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmSyncSource (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%--------------------------------------------------------------------------%
% photostimControlsV5.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
