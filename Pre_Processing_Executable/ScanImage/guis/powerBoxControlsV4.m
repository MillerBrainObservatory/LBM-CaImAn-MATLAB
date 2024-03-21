function varargout = powerBoxControlsV4(varargin)
% POWERBOXCONTROLSV4 MATLAB code for powerBoxControlsV4.fig
%      POWERBOXCONTROLSV4, by itself, creates a new POWERBOXCONTROLSV4 or raises the existing
%      singleton*.
%
%      H = POWERBOXCONTROLSV4 returns the handle to a new POWERBOXCONTROLSV4 or the handle to
%      the existing singleton*.
%
%      POWERBOXCONTROLSV4('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in POWERBOXCONTROLSV4.M with the given input arguments.
%
%      POWERBOXCONTROLSV4('Property','Value',...) creates a new POWERBOXCONTROLSV4 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before powerBoxControlsV4_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to powerBoxControlsV4_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help powerBoxControlsV4

% Last Modified by GUIDE v2.5 04-Sep-2015 15:05:55

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @powerBoxControlsV4_OpeningFcn, ...
                   'gui_OutputFcn',  @powerBoxControlsV4_OutputFcn, ...
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


% --- Executes just before powerBoxControlsV4 is made visible.
function powerBoxControlsV4_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to powerBoxControlsV4 (see VARARGIN)

% Choose default command line output for powerBoxControlsV4
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes powerBoxControlsV4 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = powerBoxControlsV4_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function etPowers_Callback(hObject, eventdata, handles)
% hObject    handle to etPowers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePowerBoxPowers();


% --- Executes during object creation, after setting all properties.
function etPowers_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPowers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etStartFrame_Callback(hObject, eventdata, handles)
% hObject    handle to etStartFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etStartFrame_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etStartFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etEndFrame_Callback(hObject, eventdata, handles)
% hObject    handle to etEndFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function etEndFrame_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etEndFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbCopy1.
function pbCopy1_Callback(hObject, eventdata, handles)
% hObject    handle to pbCopy1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.powerBoxGuiCopyChannel(1);


% --- Executes on button press in pbCopy2.
function pbCopy2_Callback(hObject, eventdata, handles)
% hObject    handle to pbCopy2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.powerBoxGuiCopyChannel(2);


% --- Executes on button press in pbCopy3.
function pbCopy3_Callback(hObject, eventdata, handles)
% hObject    handle to pbCopy3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.powerBoxGuiCopyChannel(3);


% --- Executes on button press in pbCopy4.
function pbCopy4_Callback(hObject, eventdata, handles)
% hObject    handle to pbCopy4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.powerBoxGuiCopyChannel(4);



function etLeft_Callback(hObject, eventdata, handles)
% hObject    handle to etLeft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePowerBoxRect();


% --- Executes during object creation, after setting all properties.
function etLeft_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etLeft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etTop_Callback(hObject, eventdata, handles)
% hObject    handle to etTop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePowerBoxRect();


% --- Executes during object creation, after setting all properties.
function etTop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etTop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etWidth_Callback(hObject, eventdata, handles)
% hObject    handle to etWidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePowerBoxRect();


% --- Executes during object creation, after setting all properties.
function etWidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etWidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etPosition_Callback(hObject, eventdata, handles)
% hObject    handle to etPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changePowerBoxRect();


% --- Executes during object creation, after setting all properties.
function etPosition_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosition (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when selected object is changed in unitPanel.
function unitPanel_SelectionChangeFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in unitPanel 
% eventdata  structure with the following fields (see UIBUTTONGROUP)
%	EventName: string 'SelectionChanged' (read only)
%	OldValue: handle of the previously selected object or empty if none was selected
%	NewValue: handle of the currently selected object
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedPowerBoxes();


% --- Executes on selection change in pmPbSel.
function pmPbSel_Callback(hObject, eventdata, handles)
% hObject    handle to pmPbSel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmPbSel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmPbSel
handles.hController.selectPowerBox();

% --- Executes during object creation, after setting all properties.
function pmPbSel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmPbSel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbDelete.
function pbDelete_Callback(hObject, eventdata, handles)
% hObject    handle to pbDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.deletePowerBox();


%--------------------------------------------------------------------------%
% powerBoxControlsV4.m                                                     %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
