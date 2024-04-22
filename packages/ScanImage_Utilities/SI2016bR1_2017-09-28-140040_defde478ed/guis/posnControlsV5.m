function varargout = posnControlsV5(varargin)
% POSNCONTROLSV5 MATLAB code for posnControlsV5.fig
%      POSNCONTROLSV5, by itself, creates a new POSNCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = POSNCONTROLSV5 returns the handle to a new POSNCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      POSNCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in POSNCONTROLSV5.M with the given input arguments.
%
%      POSNCONTROLSV5('Property','Value',...) creates a new POSNCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before posnControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to posnControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help posnControlsV5

% Last Modified by GUIDE v2.5 16-Sep-2015 15:06:59

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @posnControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @posnControlsV5_OutputFcn, ...
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


% --- Executes just before posnControlsV5 is made visible.
function posnControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to posnControlsV5 (see VARARGIN)

% Choose default command line output for posnControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes posnControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = posnControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in lbPosns.
function lbPosns_Callback(hObject, eventdata, handles)
% hObject    handle to lbPosns (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if strcmp(get(handles.figure1,'SelectionType'), 'open')
    handles.hController.dblClickPosn();
else
    handles.hController.changedSelectedPosn();
end



% --- Executes during object creation, after setting all properties.
function lbPosns_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lbPosns (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbUp.
function pbUp_Callback(hObject, eventdata, handles)
% hObject    handle to pbUp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.movePosnUp();


% --- Executes on button press in pbDown.
function pbDown_Callback(hObject, eventdata, handles)
% hObject    handle to pbDown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.movePosnDown();


% --- Executes on button press in pbDelete.
function pbDelete_Callback(hObject, eventdata, handles)
% hObject    handle to pbDelete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.removePosn();


% --- Executes on button press in cbX.
function cbX_Callback(hObject, eventdata, handles)
% hObject    handle to cbX (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedDimCbs();


% --- Executes on button press in cbY.
function cbY_Callback(hObject, eventdata, handles)
% hObject    handle to cbY (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedDimCbs();


% --- Executes on button press in cbZ.
function cbZ_Callback(hObject, eventdata, handles)
% hObject    handle to cbZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedDimCbs();


% --- Executes on button press in cbZZ.
function cbZZ_Callback(hObject, eventdata, handles)
% hObject    handle to cbZZ (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedDimCbs();


% --- Executes on button press in pbAdd.
function pbAdd_Callback(hObject, eventdata, handles)
% hObject    handle to pbAdd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.addPosn();


% --- Executes on button press in pbRead.
function pbRead_Callback(hObject, eventdata, handles)
% hObject    handle to pbRead (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.readPosn();



function etPosn_Callback(hObject, eventdata, handles)
% hObject    handle to etPosn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changedPosnEt();


% --- Executes during object creation, after setting all properties.
function etPosn_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPosn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etName_Callback(hObject, eventdata, handles)
% hObject    handle to etName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etName as text
%        str2double(get(hObject,'String')) returns contents of etName as a double


% --- Executes during object creation, after setting all properties.
function etName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%--------------------------------------------------------------------------%
% posnControlsV5.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
