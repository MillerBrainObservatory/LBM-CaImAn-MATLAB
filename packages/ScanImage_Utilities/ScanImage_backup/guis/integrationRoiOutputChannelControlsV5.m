function varargout = integrationRoiOutputChannelControlsV5(varargin)
% INTEGRATIONROIOUTPUTCHANNELCONTROLSV5 MATLAB code for integrationRoiOutputChannelControlsV5.fig
%      INTEGRATIONROIOUTPUTCHANNELCONTROLSV5, by itself, creates a new INTEGRATIONROIOUTPUTCHANNELCONTROLSV5 or raises the existing
%      singleton*.
%
%      H = INTEGRATIONROIOUTPUTCHANNELCONTROLSV5 returns the handle to a new INTEGRATIONROIOUTPUTCHANNELCONTROLSV5 or the handle to
%      the existing singleton*.
%
%      INTEGRATIONROIOUTPUTCHANNELCONTROLSV5('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INTEGRATIONROIOUTPUTCHANNELCONTROLSV5.M with the given input arguments.
%
%      INTEGRATIONROIOUTPUTCHANNELCONTROLSV5('Property','Value',...) creates a new INTEGRATIONROIOUTPUTCHANNELCONTROLSV5 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before integrationRoiOutputChannelControlsV5_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to integrationRoiOutputChannelControlsV5_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help integrationRoiOutputChannelControlsV5

% Last Modified by GUIDE v2.5 08-Jun-2016 09:26:36

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @integrationRoiOutputChannelControlsV5_OpeningFcn, ...
                   'gui_OutputFcn',  @integrationRoiOutputChannelControlsV5_OutputFcn, ...
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


% --- Executes just before integrationRoiOutputChannelControlsV5 is made visible.
function integrationRoiOutputChannelControlsV5_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to integrationRoiOutputChannelControlsV5 (see VARARGIN)

% Choose default command line output for integrationRoiOutputChannelControlsV5
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes integrationRoiOutputChannelControlsV5 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = integrationRoiOutputChannelControlsV5_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in pmOutputChannel.
function pmOutputChannel_Callback(hObject, eventdata, handles)
% hObject    handle to pmOutputChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmOutputChannel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmOutputChannel
handles.hController.changedIntegrationRoiOutputChannel();


% --- Executes during object creation, after setting all properties.
function pmOutputChannel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmOutputChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function etOutputFunction_Callback(hObject, eventdata, handles)
% hObject    handle to etOutputFunction (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of etOutputFunction as text
%        str2double(get(hObject,'String')) returns contents of etOutputFunction as a double


% --- Executes during object creation, after setting all properties.
function etOutputFunction_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etOutputFunction (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbEditOutputFunction.
function pbEditOutputFunction_Callback(hObject, eventdata, handles)
% hObject    handle to pbEditOutputFunction (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.hController.editIntegrationRoiOutputChannelFunction();


% --- Executes on button press in cbEnableOutput.
function cbEnableOutput_Callback(hObject, eventdata, handles)
% hObject    handle to cbEnableOutput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of cbEnableOutput
handles.hController.changeIntegraionRoiOutputChannelEnable();


% --- Executes when entered data in editable cell(s) in tbRoiSelection.
function tbRoiSelection_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tbRoiSelection (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
handles.hController.changeIntegrationRoiOutputChannelRoiSelection();


% --- Executes on button press in pbEditIntegrationFields.
function pbEditIntegrationFields_Callback(hObject, eventdata, handles)
handles.hController.editIntegrationFieldGroup();


% --- Executes on button press in pbShowIntegrationDisplay.
function pbShowIntegrationDisplay_Callback(hObject, eventdata, handles)
handles.hController.showGUI('roiIntegratorDisplay');
handles.hController.raiseGUI('roiIntegratorDisplay');


% --- Executes on button press in cbEnableIntegration.
function cbEnableIntegration_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


% --- Executes on button press in cbEnableDisplay.
function cbEnableDisplay_Callback(hObject, eventdata, handles)
handles.hController.updateModel(hObject,eventdata,handles);


%--------------------------------------------------------------------------%
% integrationRoiOutputChannelControlsV5.m                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
