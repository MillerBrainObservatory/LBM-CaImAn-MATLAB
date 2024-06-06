function varargout = motionCorrectionControls(varargin)
% MOTIONCORRECTIONCONTROLS MATLAB code for motionCorrectionControls.fig
%      MOTIONCORRECTIONCONTROLS, by itself, creates a new MOTIONCORRECTIONCONTROLS or raises the existing
%      singleton*.
%
%      H = MOTIONCORRECTIONCONTROLS returns the handle to a new MOTIONCORRECTIONCONTROLS or the handle to
%      the existing singleton*.
%
%      MOTIONCORRECTIONCONTROLS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MOTIONCORRECTIONCONTROLS.M with the given input arguments.
%
%      MOTIONCORRECTIONCONTROLS('Property','Value',...) creates a new MOTIONCORRECTIONCONTROLS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before motionCorrectionControls_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to motionCorrectionControls_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help motionCorrectionControls

% Last Modified by GUIDE v2.5 06-May-2016 14:06:08

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @motionCorrectionControls_OpeningFcn, ...
                   'gui_OutputFcn',  @motionCorrectionControls_OutputFcn, ...
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


% --- Executes just before motionCorrectionControls is made visible.
function motionCorrectionControls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to motionCorrectionControls (see VARARGIN)

% Choose default command line output for motionCorrectionControls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes motionCorrectionControls wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = motionCorrectionControls_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in cbEnableMotionCorrection.
function cbEnableMotionCorrection_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in cbGpuAcceleration.
function cbGpuAcceleration_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);



function etPreProcessFcn_Callback(hObject, eventdata, handles)
% hObject    handle to etPreProcessFcn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etPreProcessFcn as text
%        str2double(get(hObject,'String')) returns contents of etPreProcessFcn as a double
handles.hController.changeReferenceImagePreprocessFcn(hObject.String);


% --- Executes during object creation, after setting all properties.
function etPreProcessFcn_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etPreProcessFcn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function etMotionDetectionFcn_Callback(hObject, eventdata, handles)
handles.hController.changeDetectMotionFcn(hObject.String);

% --- Executes during object creation, after setting all properties.
function etMotionDetectionFcn_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etMotionDetectionFcn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbSelectPreProcessFcn.
function pbSelectPreProcessFcn_Callback(hObject, eventdata, handles)
handles.hController.changeReferenceImagePreprocessFcn();


% --- Executes on button press in pbSelectMotionDetectionFcn.
function pbSelectMotionDetectionFcn_Callback(hObject, eventdata, handles)
handles.hController.changeDetectMotionFcn();


% --- Executes on button press in pbLoadReferenceImage.
function pbLoadReferenceImage_Callback(hObject, eventdata, handles)
handles.hController.loadMotionReferenceImage();


% --- Executes on button press in cbShowMotionDisplay.
function cbShowMotionDisplay_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


%--------------------------------------------------------------------------%
% motionCorrectionControls.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
