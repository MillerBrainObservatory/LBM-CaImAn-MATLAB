function varargout = triggerControlsV5(varargin)
% TRIGGERCONTROLSV5 MATLAB code for triggerControlsV5.fig
%      TRIGGERCONTROLSV5, by itself, creates a new TRIGGERCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = TRIGGERCONTROLSV5 returns the handle to a new TRIGGERCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      TRIGGERCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TRIGGERCONTROLSV5.M with the given input arguments.
%
%      TRIGGERCONTROLSV5('Property','Value',...) creates a new TRIGGERCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before triggerControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to triggerControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help triggerControlsV5

% Last Modified by GUIDE v2.5 15-Aug-2014 11:55:52

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @triggerControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @triggerControlsV5_OutputFcn, ...
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


% --- Executes just before triggerControlsV5 is made visible.
function triggerControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to triggerControlsV5 (see VARARGIN)

% Choose default command line output for triggerControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes triggerControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = triggerControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pbAcqStart.
function pbAcqStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbAcqStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hScan2D.trigIssueSoftwareAcq();


% --- Executes on button press in pbAcqStop.
function pbAcqStop_Callback(hObject, eventdata, handles)
% hObject    handle to pbAcqStop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hScan2D.trigIssueSoftwareStop();

% --- Executes on button press in pbNextFileMarker.
function pbNextFileMarker_Callback(hObject, eventdata, handles)
% hObject    handle to pbNextFileMarker (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hScan2D.trigIssueSoftwareNext();



% --- Executes on button press in cbTrigNextStopEnable.
function cbTrigNextStopEnable_Callback(hObject, eventdata, handles)
% hObject    handle to cbTrigNextStopEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Hint: get(hObject,'Value') returns toggle state of cbTrigNextStopEnable
handles.hController.updateModel(hObject,eventdata,handles);



% --- Executes on selection change in pmTrigAcqInTerm.
function pmTrigAcqInTerm_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigAcqInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigAcqInTerm contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigAcqInTerm
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigAcqInTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigAcqInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmTrigNextInTerm.
function pmTrigNextInTerm_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigNextInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigNextInTerm contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigNextInTerm
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigNextInTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigNextInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmTrigStopInTerm.
function pmTrigStopInTerm_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigStopInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigStopInTerm contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigStopInTerm
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigStopInTerm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigStopInTerm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmTrigAcqEdge.
function pmTrigAcqEdge_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigAcqEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigAcqEdge contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigAcqEdge
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigAcqEdge_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigAcqEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmTrigStopEdge.
function pmTrigStopEdge_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigStopEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigStopEdge contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigStopEdge
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigStopEdge_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigStopEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pmTrigNextEdge.
function pmTrigNextEdge_Callback(hObject, eventdata, handles)
% hObject    handle to pmTrigNextEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmTrigNextEdge contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmTrigNextEdge
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes during object creation, after setting all properties.
function pmTrigNextEdge_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmTrigNextEdge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%--------------------------------------------------------------------------%
% triggerControlsV5.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
