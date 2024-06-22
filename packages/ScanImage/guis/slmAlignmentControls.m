function varargout = slmAlignmentControls(varargin)
% SLMALIGNMENTCONTROLS MATLAB code for slmAlignmentControls.fig
%      SLMALIGNMENTCONTROLS, by itself, creates a new SLMALIGNMENTCONTROLS or raises the existing
%      singleton*.
%
%      H = SLMALIGNMENTCONTROLS returns the handle to a new SLMALIGNMENTCONTROLS or the handle to
%      the existing singleton*.
%
%      SLMALIGNMENTCONTROLS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SLMALIGNMENTCONTROLS.M with the given input arguments.
%
%      SLMALIGNMENTCONTROLS('Property','Value',...) creates a new SLMALIGNMENTCONTROLS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before slmAlignmentControls_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to slmAlignmentControls_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help slmAlignmentControls

% Last Modified by GUIDE v2.5 15-Mar-2018 18:19:05

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @slmAlignmentControls_OpeningFcn, ...
                   'gui_OutputFcn',  @slmAlignmentControls_OutputFcn, ...
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


% --- Executes just before slmAlignmentControls is made visible.
function slmAlignmentControls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to slmAlignmentControls (see VARARGIN)

% Choose default command line output for slmAlignmentControls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes slmAlignmentControls wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = slmAlignmentControls_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in pbSetMotionCorrection.
function pbSetMotionCorrection_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.setAlignmentReference();


% --- Executes on button press in pbAddAlignmentPoint.
function pbAddAlignmentPoint_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.addAlignmentPoint();


% --- Executes on button press in pbResetPoints.
function pbResetPoints_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.abortAlignment();

% --- Executes on button press in pbGenerateAlignment.
function pbGenerateAlignment_Callback(hObject, eventdata, handles)
handles.hModel.hSlmScan.createAlignmentMatrix();


function etNumAlignmentPts_Callback(hObject, eventdata, handles)
% hObject    handle to etNumAlignmentPts (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etNumAlignmentPts as text
%        str2double(get(hObject,'String')) returns contents of etNumAlignmentPts as a double


% --- Executes during object creation, after setting all properties.
function etNumAlignmentPts_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etNumAlignmentPts (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbShowZAlignment.
function pbShowZAlignment_Callback(hObject, eventdata, handles)
slmZAlignmentControls_ = handles.hController.hGuiClasses.ZAlignmentControls;
slmZAlignmentControls_.Visible = true;
handles.hController.raiseGUI('ZAlignmentControls');
zAlignmentControls = handles.hController.hGuiClasses.ZAlignmentControls;
zAlignmentControls.scanner = 'SLM';


%--------------------------------------------------------------------------%
% slmAlignmentControls.m                                                   %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
