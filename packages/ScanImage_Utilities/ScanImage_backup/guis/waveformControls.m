function varargout = waveformControls(varargin)
% WAVEFORMCONTROLS MATLAB code for waveformControls.fig
%      WAVEFORMCONTROLS, by itself, creates a new WAVEFORMCONTROLS or raises the existing
%      singleton*.
%
%      H = WAVEFORMCONTROLS returns the handle to a new WAVEFORMCONTROLS or the handle to
%      the existing singleton*.
%
%      WAVEFORMCONTROLS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WAVEFORMCONTROLS.M with the given input arguments.
%
%      WAVEFORMCONTROLS('Property','Value',...) creates a new WAVEFORMCONTROLS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before waveformControls_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to waveformControls_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help waveformControls

% Last Modified by GUIDE v2.5 04-Oct-2016 10:57:57

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @waveformControls_OpeningFcn, ...
                   'gui_OutputFcn',  @waveformControls_OutputFcn, ...
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


% --- Executes just before waveformControls is made visible.
function waveformControls_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to waveformControls (see VARARGIN)

% Choose default command line output for waveformControls
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes waveformControls wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = waveformControls_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes when entered data in editable cell(s) in tbWaveformControls.
function tbWaveformControls_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tbWaveformControls (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)


% --- Executes when selected cell(s) is changed in tbWaveformControls.
function tbWaveformControls_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to tbWaveformControls (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
handles.hController.tbWaveformControlsCellSelected(eventdata);


% --- Executes on button press in pbUpdateWaveforms.
function pbUpdateWaveforms_Callback(hObject, eventdata, handles)
% hObject    handle to pbUpdateWaveforms (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hModel.hWaveformManager.updateWaveforms();


%--------------------------------------------------------------------------%
% waveformControls.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
