function varargout = pmtControlsV5(varargin)
% PMTCONTROLSV5 MATLAB code for pmtControlsV5.fig
%      PMTCONTROLSV5, by itself, creates a new PMTCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = PMTCONTROLSV5 returns the handle to a new PMTCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      PMTCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PMTCONTROLSV5.M with the given input arguments.
%
%      PMTCONTROLSV5('Property','Value',...) creates a new PMTCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before pmtControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to pmtControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help pmtControlsV5

% Last Modified by GUIDE v2.5 25-May-2016 18:39:34

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pmtControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @pmtControlsV5_OutputFcn, ...
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


% --- Executes just before pmtControlsV5 is made visible.
function pmtControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to pmtControlsV5 (see VARARGIN)

% Choose default command line output for pmtControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes pmtControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = pmtControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function etPmt1Gain_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt1Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsGains(1,val);

function etPmt2Gain_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt2Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsGains(2,val);

function etPmt3Gain_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt3Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsGains(3,val);

function etPmt4Gain_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt4Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsGains(4,val);


% --- Executes on button press in pbPmtsAllOn.
function pbPmtsAllOn_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmtsAllOn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn([],true);

% --- Executes on button press in pbPmtsAllOff.
function pbPmtsAllOff_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmtsAllOff (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn([],false);

% --- Executes on button press in pbPmt1Power.
function pbPmt1Power_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmt1Power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn(1);

% --- Executes on button press in pbPmt2Power.
function pbPmt2Power_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmt2Power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn(2);

% --- Executes on button press in pbPmt2Power.
function pbPmt3Power_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmt2Power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn(3);

% --- Executes on button press in pbPmt4Power.
function pbPmt4Power_Callback(hObject, eventdata, handles)
% hObject    handle to pbPmt4Power (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(hObject,'Value',0);
handles.hController.changePmtsPowersOn(4);

% --- Executes on button press in pbResetPmt1.
function pbResetPmt1_Callback(hObject, eventdata, handles)
% hObject    handle to pbResetPmt1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.pmtsResetTripped(1);

% --- Executes on button press in pbResetPmt2.
function pbResetPmt2_Callback(hObject, eventdata, handles)
% hObject    handle to pbResetPmt2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.pmtsResetTripped(2);

% --- Executes on button press in pbResetPmt3.
function pbResetPmt3_Callback(hObject, eventdata, handles)
% hObject    handle to pbResetPmt3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.pmtsResetTripped(3);

% --- Executes on button press in pbResetPmt4.
function pbResetPmt4_Callback(hObject, eventdata, handles)
% hObject    handle to pbResetPmt4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.pmtsResetTripped(4);

% --- Executes during object creation, after setting all properties.
function etPmt1Gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt1Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etPmt2Gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt2Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etPmt3Gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt3Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function etPmt4Gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt4Gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt1Status_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt1Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etPmt1Status as text
%        str2double(get(hObject,'String')) returns contents of etPmt1Status as a double


% --- Executes during object creation, after setting all properties.
function etPmt1Status_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt1Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt2Status_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt2Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etPmt2Status as text
%        str2double(get(hObject,'String')) returns contents of etPmt2Status as a double


% --- Executes during object creation, after setting all properties.
function etPmt2Status_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt2Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt3Status_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt3Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etPmt3Status as text
%        str2double(get(hObject,'String')) returns contents of etPmt3Status as a double


% --- Executes during object creation, after setting all properties.
function etPmt3Status_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt3Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt4Status_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt4Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etPmt4Status as text
%        str2double(get(hObject,'String')) returns contents of etPmt4Status as a double


% --- Executes during object creation, after setting all properties.
function etPmt4Status_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt4Status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt1Offset_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt1Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsOffsets(1,val);


% --- Executes during object creation, after setting all properties.
function etPmt1Offset_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt1Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt2Offset_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt2Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsOffsets(2,val);


% --- Executes during object creation, after setting all properties.
function etPmt2Offset_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt2Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt3Offset_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt3Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsOffsets(3,val);


% --- Executes during object creation, after setting all properties.
function etPmt3Offset_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt3Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt4Offset_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt4Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsOffsets(4,val);


% --- Executes during object creation, after setting all properties.
function etPmt4Offset_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt4Offset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt1Bandwidth_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt1Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsBandwidths(1,val);


% --- Executes during object creation, after setting all properties.
function etPmt1Bandwidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt1Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt2Bandwidth_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt2Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsBandwidths(2,val);


% --- Executes during object creation, after setting all properties.
function etPmt2Bandwidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt2Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt3Bandwidth_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt3Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsBandwidths(3,val);


% --- Executes during object creation, after setting all properties.
function etPmt3Bandwidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt3Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPmt4Bandwidth_Callback(hObject, eventdata, handles)
% hObject    handle to etPmt4Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
val = str2double(get(hObject,'String'));
handles.hController.changePmtsBandwidths(4,val);


% --- Executes during object creation, after setting all properties.
function etPmt4Bandwidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPmt4Bandwidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cbPmt1AutoPwr.
function cbPmt1AutoPwr_Callback(hObject, eventdata, handles)
% hObject    handle to cbPmt1AutoPwr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.setPmtAutoPwr(1,hObject.Value);


% --- Executes on button press in cbPmt2AutoPwr.
function cbPmt2AutoPwr_Callback(hObject, eventdata, handles)
% hObject    handle to cbPmt2AutoPwr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.setPmtAutoPwr(2,hObject.Value);


% --- Executes on button press in cbPmt3AutoPwr.
function cbPmt3AutoPwr_Callback(hObject, eventdata, handles)
% hObject    handle to cbPmt3AutoPwr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.setPmtAutoPwr(3,hObject.Value);


% --- Executes on button press in cbPmt4AutoPwr.
function cbPmt4AutoPwr_Callback(hObject, eventdata, handles)
% hObject    handle to cbPmt4AutoPwr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.setPmtAutoPwr(4,hObject.Value);


%--------------------------------------------------------------------------%
% pmtControlsV5.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
