classdef MotionManager < scanimage.interfaces.Component & most.HasClassDataFile
    % MotionManager
    % contains functionality to define motion estimators and a motion
    % corrector
    
    %ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'MotionManager';       % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};       % Cell array of strings specifying properties that can be set while focusing
        PROP_TRUE_LIVE_UPDATE = {'motionHistoryLength' 'correctionBoundsXY','correctionBoundsZ','correctionEnableXY','correctionEnableZ','estimatorClassName','resetCorrectionAfterAcq'}; % Cell array of strings specifying properties that can be set while the component is active
        DENY_PROP_LIVE_UPDATE = {'correctionDeviceXY' 'correctionDeviceZ'}; % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};          % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};    % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};          % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    % ABSTRACT PROPERTY REALIZATIONS (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'hMotionEstimators','motionHistory','hMotionCorrector','motionCorrectionVector','plotPerformance'};
    end
    
    %% Motion Manager Specific
    properties (SetObservable)
        enable = false;                 % logical, enables/disables motion detection
        estimatorClassName = 'scanimage.components.motionEstimators.SimpleMotionEstimator'; % Classname of the default estimator class
        motionHistoryLength = 100;      % length of motion history
        
        correctionEnableXY = false;     % true/false enables/disables lateral motion correction
        correctionEnableZ  = false;     % true/false enables/disables axial motion correction
        correctionDeviceXY = 'galvos';  % defines the device used to correct lateral motion valid values are {'galvos' 'motor'}
        correctionDeviceZ  = 'fastz';   % defines the device used to correct axial motion valid values are {'fastz' 'motor'}
        correctionBoundsXY = [-5 5];    % 1x2 double ar6ray of allowed correction range in x (reference space, units of scan angle)
        correctionBoundsZ = [-50 50];   % 1x2 double array of allowed correction range in z (um)
        
        motionMarkersXY = [];           % Nx2 double array of [x,y] points to be shown in Motion Correction Display (visualization only)
        
        zStackAlignmentFcn = @scanimage.components.motionEstimators.util.alignZRoiData;
        resetCorrectionAfterAcq = true;
    end
    
    properties (SetObservable, Dependent)
        correctorClassName;     % Classname of the motion corrector
    end
    
    properties (SetObservable, Dependent)
        plotPerformance;        % shows or hides a performance plot to benchmark the motion estimators
    end
    
    properties (SetObservable, SetAccess = private, Transient)
        hMotionEstimators = []; % Array of estimator class objects
        motionHistory = [];     % struct array of frameNumberAcq,frameTimestamp,hRoi,z,dr,refTransform,q,userData,userDataStr
        motionCorrectionVector = zeros(1,3); % Currently applied absolute motion correction (in reference space coordinates)
    end
    
    properties (SetObservable, Transient)
        hMotionCorrector = [];  % Motion Corrector object
    end
    
    properties (SetAccess = private, Hidden)
        resultQueue = [];       % Array of estimator result objects
        hLogFile;               % handle to log file
        hCorrectNowListener;    % listener to motion corrector event 'correctNow'
        scannerOffsets = [];    % struct specifying the offsets for correction devices
        hMotionEstimatorListeners = []; % array of listeners for motion estimators
        performanceCache;      % caches performance relevant settings
        hPerformancePlot;       % handle to most.util.PerformancePlot object
        classDataFileName;      % path to class data file
    end
    
    properties (Constant, Hidden)
        ESTIMATOR_FILE_EXT = 'me';  % file extension for saved motion estimators
    end
    
    events
        newMotionEstimateAvailable
        motionEstimatorsChanged
    end
    
    %% LIFE CYCLE METHODS
    methods
        % Constructor
        function obj = MotionManager(hSI)
            obj@scanimage.interfaces.Component(hSI);
            obj.correctorClassName = 'scanimage.components.motionCorrectors.SimpleMotionCorrector'; % initiate hMotionCorrector
            
            % Determine CDF name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            obj.loadClassData();
            
            obj.hPerformancePlot = most.util.PerformancePlot('Motion Manager Performance',false);
        end
        
        % Destructor
        function delete(obj)
            obj.saveClassData();
            most.idioms.safeDeleteObj(obj.hMotionEstimatorListeners);
            most.idioms.safeDeleteObj(obj.resultQueue);
            most.idioms.safeDeleteObj(obj.hMotionEstimators);
            most.idioms.safeDeleteObj(obj.hMotionCorrector)
            most.idioms.safeDeleteObj(obj.hPerformancePlot);
        end
    end
    
    %% USER FUNCTIONS
    methods        
        %% addEstimator(obj,data,className)
        %
        % Add a new estimator for processing
        % if data is a scanimage.mroi.roiData object, a new estimator is
        % automatically created. The class will be of type className, or if
        % className is omitted, the type will be hMotionManager.estimatorClassName
        % if data is a motion estimator object, the object will be added as-is
        %
        function newEstimator = addEstimator(obj, val, className)
            if nargin < 3 || isempty(className)
                className = obj.estimatorClassName;
            end
            
            assert(isscalar(val),'Input to addEstimator must be scalar');
            validateattributes(className,{'char'},{'row'});
            assert(logical(exist(className,'class')),'Classname %s cannot be found on path.',className);
            checkEstimatorSystemRequirements(className);
            
            if isa(val,'scanimage.mroi.RoiData')
                % construct from estimatorClassName
                classConstructorFcn = str2func(className);
                roiName = val.hRoi.name;
                
                waitbartext = sprintf('Constructing motion estimator for ROI %s\n( %s )',roiName,className);
                hWb = waitbar(0.1,waitbartext,'WindowStyle','modal');
                try
                    newEstimator = classConstructorFcn(val);
                catch ME
                    most.idioms.safeDeleteObj(hWb);
                    rethrow(ME);
                end
                most.idioms.safeDeleteObj(hWb);
            else
                newEstimator = val;
            end
            
            checkEstimatorSystemRequirements(newEstimator);
            assert(isvalid(newEstimator),'Estimator was not constructed successfully');
            
            if ~isempty(obj.hMotionEstimators)
                assert(~any([obj.hMotionEstimators.uuiduint64]==newEstimator.uuiduint64),'Cannot add the same motion estimator instance multiple times');
            end
            
            obj.hMotionEstimators = [obj.hMotionEstimators newEstimator];
        end
        
        %% clearEstimators(obj)
        %
        % clears all motion estimators from hMotionManager
        %
        function clearEstimators(obj)
            obj.hMotionEstimators = [];
        end
        
        %% clearAndDeleteEstimators(obj)
        %
        % clears and deletes all motion estimators from hMotionManager
        %
        function clearAndDeleteEstimators(obj)
            hMEs = obj.hMotionEstimators;
            obj.clearEstimators();
            most.idioms.safeDeleteObj(hMEs);
        end
        
        %% removeEstimator(obj, id)
        %
        % the id can be
        %   - the index of the estimator in hMotionManager.hMotionEstimators
        %   - the (char) uuid of the roi
        %   - the (uint64) uuiduint64 of the roi
        %
        function removeEstimator(obj,id)
            idxs = matchMotionEstimators(obj.hMotionEstimators,id);
            idxs(idxs == 0) = [];
            obj.hMotionEstimators(idxs) = [];
        end
        
        %% selectEstimatorClass(obj)
        %
        % opens a file dialog to select a new default estimator class
        %
        function selectEstimatorClass(obj)
            path = which(obj.estimatorClassName);
            filterspec = {'*.m;*.p'};
            [filename,pathname] = uigetfile(filterspec,'Select a motion estimator class',path);
            if isequal(filename,0)
                % user cancelled
                return
            end
            
            [~,filename,~] = fileparts(filename); % remove extension
            path = fullfile(pathname,filename);
            
            path = regexp(path,'(\\\+[^(\\|(\\\+))]*){0,}\\[^\\]*$','match','once');
            path = regexprep(path,'(\\\+)|(\\)','.');
            path(1) = []; % remove leading '.'
            
            classChanged = ~strcmp(obj.estimatorClassName,path);
            obj.estimatorClassName = path;
            
            if ~isempty(obj.hMotionEstimators) && classChanged
                button = questdlg('Do you want to convert all existing motion estimators to the new default class?');
                if strcmpi(button,'yes')
                    obj.convertEstimatorsToDefaultClass();
                end
            end
        end
        
        %% changeEstimatorsToDefaultClass
        %
        % converts all estimators to the default class
        %
        function convertEstimatorsToDefaultClass(obj)
            if isempty(obj.hMotionEstimators)
                return % Nothing to do here
            end
            
            hMEs = obj.hMotionEstimators;
            obj.clearEstimators();
            
            for idx = 1:length(hMEs)
                hME = hMEs(idx);
                if isa(hME,obj.estimatorClassName)
                    obj.addEstimator(hME); % no conversion required, just add estimator back as-is
                else
                    if hME.outOfDate
                        hME.enable = false;
                        obj.addEstimator(hME);
                        most.idioms.warn('Cannot convert motion estimator for ROI ''%s'' to default class because the ROI geometry changed', hME.roiData.hRoi.name);
                    else
                        hME_new = obj.addEstimator(hME.roiData); % create new estimator from 
                        hME_new.enable = hME.enable;
                    end
                end
            end
        end
        
        %% reprocessEstimatorsAndCorrector(obj)
        %
        % clears the estimator/corrector and recreates all estimators/corrector. Execute this
        % function when the estimator/corrector class changes to reprocess the
        % reference volumes
        %        
        function reprocessEstimatorsAndCorrector(obj)
            if isempty(obj.hMotionEstimators)
                return % Nothing to do here
            end
            
            hMEsOld = obj.hMotionEstimators;
            
            for idx = 1:length(hMEsOld)
                try
                    hMEOld = hMEsOld(idx);
                    [s,hRoi] = hMEOld.saveobj();
                    hMENew = scanimage.interfaces.IMotionEstimator.loadobj(s,hRoi);
                    obj.removeEstimator(hMEOld);
                    obj.addEstimator(hMENew);
                    most.idioms.safeDeleteObj(hMEOld);
                catch MatlabException
                    most.idioms.reportError(MatlabException);
                end
            end
            
            hMCOld = obj.hMotionCorrector();
            s = hMCOld.saveobj();
            hMCnew = scanimage.interfaces.IMotionCorrector.loadobj(s);
            obj.hMotionCorrector = hMCnew;
            most.idioms.safeDeleteObj(hMCOld);
        end
        
        %% selectCorrectorClass(obj)
        %
        % opens a file dialog to select a new corrector class
        %
        function selectCorrectorClass(obj)
            path = which(obj.correctorClassName);
            filterspec = {'*.m;*.p'};
            [filename,pathname] = uigetfile(filterspec,'Select a motion corrector class',path);
            if isequal(filename,0)
                % user cancelled
                return
            end
            
            [~,filename,~] = fileparts(filename); % remove extension
            path = fullfile(pathname,filename);
            
            path = regexp(path,'(\\\+[^(\\|(\\\+))]*){0,}\\[^\\]*$','match','once');
            path = regexprep(path,'(\\\+)|(\\)','.');
            path(1) = []; % remove leading '.'
            
            obj.correctorClassName = path;
        end
        
        %% selectCorrectorClass(obj)
        %
        % opens a file dialog to select a new corrector class
        %
        function roiDataAligned = alignZStack(obj,roiData)
            validateattributes(roiData,{'scanimage.mroi.RoiData'},{'vector'});
            assert(~isempty(obj.zStackAlignmentFcn),'The zStackAlignmentFcn is not defined');
            roiDataAligned = obj.zStackAlignmentFcn(roiData);
        end
        
        %% activateMotionCorrectionSimple(obj,channel)
        %
        % grabs the current volume from the channel display window as a
        % reference, create the default estimator, and activates motion correction
        %
        function activateMotionCorrectionSimple(obj,channel)
            if ~isempty(obj.hMotionEstimators)
                answer = questdlg(sprintf('This will clear all motion estimators.\nDo you want to continue?'),'Confirm deletion');
                if ~strcmpi(answer,'Yes')
                    return
                end
            end
            
            stripeData = obj.hSI.hDisplay.lastStripeData;
            assert(~isempty(stripeData),'No image data in buffer. Take an image first and retry');
            
            roiData = stripeData.roiData{1};
            if nargin < 2 || isempty(channel)
                channels = roiData.channels;
            
                if isempty(channels)
                    msg = 'Cannot activate motion correction if no channels are selected for display.';
                    warndlg(msg,'ScanImage');
                    error(msg);            
                elseif isscalar(channels)
                    channel = channels(1);
                else
                    answer = inputdlg(sprintf('Which channel do you want to use for motion correction?\nAvailable channels:  %s',mat2str(channels)),...
                        'Select channel for motion correction',1,{num2str(channels(1))});

                    if isempty(answer)
                        return
                    end
                    
                    channel = str2double(answer{1});
                end
            end
            
            if isempty(channel) || ~ismember(channel,roiData.channels)
                msg = 'Invalid input.';
                warndlg(msg,'ScanImage');
                error(msg);
            end
            
            z = roiData.zs(1);  % use the first available z
            
            roiData.onlyKeepZs(z);
            roiData.onlyKeepChannels(channel);
            
            obj.clearEstimators();
            obj.addEstimator(roiData);
            
            hSICtl = obj.hSI.hController{1};
            hGUI = hSICtl.hGuiClasses.MotionDisplay;
            
            hSICtl.showGUI('MotionDisplay');
            hSICtl.raiseGUI('MotionDisplay');
            hGUI.currentZ = z;
            hGUI.selectedEstimator = obj.hMotionEstimators(1);
            
            obj.enable = true;
        end
        
        %% saveManagedEstimators(obj,channel)
        %
        % saves motion estimators managed by MotionManager in file given by
        % filePath
        %
        function saveManagedEstimators(obj,filePath)
            if nargin<2 || isempty(filePath)
                filePath = [];
            end
            
            if ~isempty(obj.hMotionEstimators)
                obj.saveEstimators(obj.hMotionEstimators,filePath);
            end
        end
        
        %% saveEstimators(obj,hMEs,channel)
        %
        % saves motion estimators managed by MotionManager in file given by
        % filePath
        %
        function saveEstimators(obj,hMEs,filePath)
            if isempty(hMEs)
                return
            end

            validateattributes(hMEs,{'scanimage.interfaces.IMotionEstimator'},{'vector'});
            
            if nargin<3 || isempty(filePath)
                [file,path] = uiputfile(sprintf('*.%s',obj.ESTIMATOR_FILE_EXT),...
                    'Select path for saving motion estimator','MotionEstimator.me');
                if file == 0
                    return % user cancelled
                end
                
                filePath = fullfile(path,file);
            end
            
            validateattributes(filePath,{'char'},{'row'});
            
            c = arrayfun(@(me)me.saveobj(),hMEs,'UniformOutput',false);
            save(filePath,'c','-mat');
        end
        
        %% resetMotionCorrection(obj,moveAxes)
        %
        % resets motion correction to dr = [0 0 0]
        %
        % inputs:
        %   moveAxes: true (default) moves Axes to dr = [0 0 0] (only while scanning)
        %             false, reset dr without moving axes
        %
        
        function resetMotionCorrection(obj,moveAxes)
            if nargin < 2 || isempty(moveAxes)
                moveAxes = true;
            end
            
            obj.scannerOffsets = [];
            
            if moveAxes && obj.active && obj.enable
                obj.moveAxesAbsolute(zeros(1,3));
            else
                obj.motionCorrectionVector = zeros(1,3);
            end
        end
        
        %% saveEstimators(obj,hMEs,channel)
        %
        % saves motion estimators managed by MotionManager in file given by
        % filePath
        %
        function loadEstimators(obj,filePaths)
            if nargin<2 || isempty(filePaths)
                [files,path] = uigetfile(sprintf('*.%s',obj.ESTIMATOR_FILE_EXT),...
                    'Select a motion estimator','MultiSelect','on');
                if isnumeric(files) && files == 0
                    return % user cancelled
                end
                
                if ischar(files)
                    files = {files};
                end
                filePaths = cellfun(@(f)fullfile(path,f),files,'UniformOutput',false);
            end
            
            if ischar(filePaths)
                filePaths = {filePaths};
            end
            
            if iscellstr(filePaths)
                cellfun(@(fp)assert(logical(exist(fp,'file')),'File %s does not exist.',fp),filePaths);
                cellfun(@(fp)loadEstimator(fp),filePaths);
            elseif isstruct(filePaths)
                loadEstimator(filePaths);
            else
                error('''filePaths'' needs to be a character array or a cellstring or a struct array');
            end
            
            function loadEstimator(filepath)
                if ischar(filepath)
                    c = load(filepath,'-mat');
                    c = c.c;
                elseif isstruct(filepath)
                    c = mat2cell(filepath(:),ones(1,numel(filepath)),1);
                end
                
                assert(iscell(c));
                
                for idx = 1:length(c)
                    s = c{idx};
                    hME = scanimage.interfaces.IMotionEstimator.loadobj(s);
                    hRoi = hME.roiData.hRoi;
                    isDefaultImagingRoi = strcmpi(hME.roiData.hRoi.name,obj.hSI.hRoiManager.DEFAULT_NAME_ROI);
                    
                    if isDefaultImagingRoi
                        scanSettings = hME.roiData.hRoi.UserData;
                        obj.hSI.hRoiManager.applyScanSettings(scanSettings);
                        try
                            hME.swapRoi(obj.hSI.hRoiManager.roiGroupDefault.rois(1));
                        catch ME
                            fprintf('Failed to relink motion estimator to default imaging roi');
                            most.idioms.reportError(ME);
                        end
                    else
                        [matchedTf,hRoi_matched] = obj.hSI.hRoiManager.matchRoi(hRoi);
                        if matchedTf
                            hME.swapRoi(hRoi_matched);
                        else
                            obj.hSI.hRoiManager.roiGroupMroi.add(hRoi);
                        end
                    end
                    
                    obj.addEstimator(hME);
                end
            end
        end
        
        %% manualCorrect(obj,dr)
        %
        % triggers a manual correction of XYZ axes
        % inputs: dr (optional): [x y z] relative correction vector in units [angle angle um]
        %           if dr is empty, the motion corrector is queried for a
        %           correction vector
        %           
        function manualCorrect(obj,dr)
            if nargin<2 || isempty(dr)
                dr = [];
            end
            
            assert(obj.active,'Acquisition is not active.');
            assert(obj.enable,'Motion Estimation/Correction is not enabled.');
            
            [correctionXYPossible,correctionZPossible] = obj.correctionPossible();
            assert(correctionXYPossible, 'XY Correction is not possible with the currently selected actuator');
            assert(correctionZPossible,  'Z Correction is not possible with the currently selected actuator');
            
            forceXY = true;
            forceZ  = true;
            obj.correctMotion(dr,forceXY,forceZ);
        end
        
        %% manualCorrectXY(obj,dr)
        %
        % triggers a manual correction of XY axes
        % inputs: dr (optional): [x y] relative correction vector in units [angle angle]
        %           if dr is empty, the motion corrector is queried for a
        %           correction vector
        %        
        function manualCorrectXY(obj,dr)
            if nargin<2 || isempty(dr)
                assert(most.idioms.isValidObj(obj.hMotionCorrector),'hMotionCorrector is invalid');
                dr = obj.hMotionCorrector.getCorrection();
            else
                validateattributes(dr,{'numeric'},{'vector','numel',2});
            end
            
            dr(3) = NaN;
            
            assert(obj.active,'Acquisition is not active.');
            assert(obj.enable,'Motion Estimation/Correction is not enabled.');
            
            [correctionXYPossible,~] = obj.correctionPossible();
            assert(correctionXYPossible, 'XY Correction is not possible with the currently selected actuator. Check motor registration.');
            
            forceXY = true;
            forceZ  = false;
            obj.correctMotion(dr,forceXY,forceZ);
        end
        
        %% manualCorrectZ(obj,dr)
        %
        % triggers a manual correction of Z axes
        % inputs: dr (optional): z relative correction value in units [um]
        %           if dr is empty, the motion corrector is queried for a
        %           correction value
        %           
        function manualCorrectZ(obj,dr)
            if nargin<2 || isempty(dr)
                assert(most.idioms.isValidObj(obj.hMotionCorrector),'hMotionCorrector is invalid');
                dr = obj.hMotionCorrector.getCorrection();
                dr(1:2) = NaN;
            else
                validateattributes(dr,{'numeric'},{'scalar'});
                dr = [NaN NaN dr];
            end
            
            assert(obj.active,'Acquisition is not active.');
            assert(obj.enable,'Motion Estimation/Correction is not enabled.');
            
            [~,correctionZPossible] = obj.correctionPossible();
            assert(correctionZPossible,  'Z Correction is not possible with the currently selected actuator');
            
            forceXY = false;
            forceZ  = true;
            obj.correctMotion(dr,forceXY,forceZ);
        end
        
        %% loadTiffOrMotionEstimatorFromFile(obj)
        %
        % loads tiff file or motion estimator from file
        % inputs: filePaths: absolute path to file(s). char array for
        %                    single file OR cell array for multiple file names
        
        function loadTiffOrMotionEstimatorFromFile(obj, filePaths)
            if nargin<2 || isempty(filenames)
                [filenames,pathname] = uigetfile('*.tif;*.tiff;*.me',...
                    'Select a tif file or motion estimator','MultiSelect','on');
                
                if isnumeric(filenames) && isequal(filenames,0)
                    return %file dialog cancelled by user
                end
                
                if ischar(filenames)
                    filenames = {filenames};
                end
                
                filePaths = cellfun(@(fn)fullfile(pathname,fn),filenames,'UniformOutput',false);
            else
                if ischar(filePaths)
                    filePaths = {filePaths};
                end
            end
            
            assert(all(cellfun(@(f)exist(f,'file'),filePaths)),'File does not exist');

            [~,~,extensions] = cellfun(@(fp)fileparts(fp),filePaths,'UniformOutput',false);
            ext = unique(lower(extensions));
            assert(numel(ext) == 1,'Cannot open files with different extensions at the same time');
            ext = ext{1};
            
            switch ext
                case {'.tif','.tiff'}
                    assert(numel(filePaths)==1,'Cannot open multiple TIFF files at once');
                    obj.loadReferenceFromFile(filePaths{1});
                case '.me'
                    obj.loadEstimators(filePaths);
                otherwise
                    error('Something bad happended')
            end
        end

        % What happens if not an SI tiff? No ROI data structure.
        function loadReferenceFromFile(obj, tifPath)
           % Load the file
            if nargin < 2 || isempty(tifPath)
                [filename,pathname] = uigetfile('*.tif','Select a tif file for the reference image');%,obj.getClassDataVar('lastFile'));
                if isequal(filename,0)
                    return %file dialog cancelled by user
                end
                tifPath = fullfile(pathname,filename);
%                 obj.setClassDataVar('lastFile',tifPath);
            end
            
            try
                % Try to pull data using getMRoiDataFromTiff
                try
                    warning('off');
                    [roiDataSimple, roiGroup, hdr, imageData, imgInfo] = scanimage.util.getMroiDataFromTiff(tifPath);
                    warning('on');
                catch
                    warning('on');
                    hdr = [];
                end
                
                % Check to see if this was an SI Tiff
                SI_Tiff = ~isempty(hdr) && isfield(hdr, 'SI');
                
                if ~SI_Tiff
                    msgStr = 'The selected file has been detected as a non-SI tiff file. This means it was either generated outside of ScanImage or was modified in post processing. Due to loss of information support for non-SI tif files is limited and requires manual data entry.';
                    uiwait(msgbox(msgStr, 'Non SI Tif File', 'warn'));
                    RoiData_ = processNonSITiff(tifPath);
                    % Dialog Cancelled
                    if isempty(RoiData_);return;end
                    obj.addEstimator(RoiData_);
                else
                    % Check to see if tiff was saved in mROI mode
                    isMROI = hdr.SI.hRoiManager.mroiEnable;
                    
                    % Converts RoiDataSimple to RoiData, Matches ROI Data, 
                    % discards/disables unmatched, returns summary
                    [roiDataInfo, roiData] = checkROIs(obj, roiDataSimple, isMROI);
                    
                    % Dialog Cancelled.
                    if isempty(roiDataInfo)||isempty(roiData);return;end
                    
                    % Parses out the ImageData and returns modified RoiData
                    % Object with new ImageData. 
                    roiDataModified = parseRoiData(roiData, roiDataInfo);
                    
                    % Dialog Cancelled
                    if isempty(roiDataModified);return;end
                    
                    % Instantiates Estimator object for each modified
                    % RoiData object.
                    for roi = 1:numel(roiDataModified)
                        obj.addEstimator(roiDataModified{roi});
                    end
                end
            catch ME
                most.idioms.reportError(ME);
            end
            
            % Converts ROI Simple to ROI, matches file ROI to current ROI,
            % Option to add unmatched File ROI to SI, option to discards
            % unmatched file ROI, option to disable SI ROI.
            % Provides data summary - so you don't have to re-analyze
            function [roiDataInfo, roiData] = checkROIs(obj, roiDataSimple, file_mROI)
                
                % Convert RoiDataSimple to RoiData 
                RoiData = cell(1,numel(roiDataSimple));
                for r = 1:numel(RoiData)
                   RoiData{r} = scanimage.mroi.RoiData();
                   RoiData{r}.hRoi = roiDataSimple{r}.hRoi;
                   RoiData{r}.zs = roiDataSimple{r}.zs;
                   RoiData{r}.channels = roiDataSimple{r}.channels;
                   RoiData{r}.imageData = roiDataSimple{r}.imageData;
                end
                
                % This situation should not occur.
                if isempty(obj.hSI.hRoiManager.currentRoiGroup.rois) && ~obj.hSI.hRoiManager.mroiEnable
                    error('mROI mode is not active but the default ROI is not present.');
                end
                
                % This situation is more likely.
                if file_mROI && ~obj.hSI.hRoiManager.mroiEnable
                    resp = questdlg('The file contains multiple ROI but currently ScanImage is not in mROI mode. Turn mROI mode on?', 'mROI', 'Yes', 'No', 'Yes');
                    switch resp
                        case 'Yes'
                            obj.hSI.hRoiManager.mroiEnable = 1;
                        otherwise
                            roiDataInfo = [];
                            roiData = [];
                            return;
                    end
                elseif ~file_mROI && obj.hSI.hRoiManager.mroiEnable
                    resp = questdlg('The file was imaged at the default ROI but currently ScanImage is in mROI mode. Turn mROI mode off?', 'mROI', 'Yes', 'No', 'Yes');
                    switch resp
                        case 'Yes'
                            obj.hSI.hRoiManager.mroiEnable = 0;
                        otherwise
                            roiDataInfo = [];
                            roiData = [];
                            return;
                    end
                end
                
                
                % Match Roi to mRois
                % This will return a logical array for all File ROI that
                % were matched to an SI ROI and all SI ROI that have not
                % been associated with a File ROI.
                [fileRoiFoundTF, SI_RoiFoundTF] = matchROI(obj, RoiData);
                
                if ~file_mROI && ~obj.hSI.hRoiManager.mroiEnable && all(fileRoiFoundTF(:) == 0)
                    % Both the file and SI should be using the default ROI
                    % but they are different.Force SI to conform to File ROI
                    resp = questdlg('Both the file ROI and the active ROI in SI are the Default ROI, however they have different settings. Overwrite SI settings to meet file ROI settings?',...
                        'Default ROI Differs', 'Yes', 'No', 'Yes');
                    switch resp
                        case 'Yes'
                            obj.hSI.hRoiManager.linesPerFrame = hdr.SI.hRoiManager.linesPerFrame;
                            obj.hSI.hRoiManager.pixelsPerLine = hdr.SI.hRoiManager.pixelsPerLine;
                            obj.hSI.hRoiManager.scanAngleMultiplierFast = hdr.SI.hRoiManager.scanAngleMultiplierFast;
                            obj.hSI.hRoiManager.scanAngleMultiplierSlow = hdr.SI.hRoiManager.scanAngleMultiplierSlow;
                            obj.hSI.hRoiManager.scanAngleShiftFast = hdr.SI.hRoiManager.scanAngleShiftFast;
                            obj.hSI.hRoiManager.scanAngleShiftSlow = hdr.SI.hRoiManager.scanAngleShiftSlow;
                            obj.hSI.hRoiManager.scanZoomFactor = hdr.SI.hRoiManager.scanZoomFactor;
                            [fileRoiFoundTF, SI_RoiFoundTF] = matchROI(obj, RoiData);
                        otherwise
                            roiDataInfo = [];
                            roiData = [];
                            return;
                    end
                    
                end
                
                % Some or all of the file ROI were not matched.
                if ~all(fileRoiFoundTF(:) == 1)
                    % Descision dialog: Discard the unmatched file ROI or
                    % create them in SI. 
                    [descision, disable] = roiMitigationDialog(fileRoiFoundTF,SI_RoiFoundTF);
                    if isempty(descision)
                        roiDataInfo = [];
                        roiData = [];
                        return;
                    end
                    switch descision
                        case 'discard'
                            RoiData(find(fileRoiFoundTF(:) == 0)') = [];
                        case 'create'
                            for create = find(fileRoiFoundTF(:) == 0)'
                               obj.hSI.hRoiManager.currentRoiGroup.add(RoiData{create}.hRoi); 
                            end
                    end
                    % There may still be ROI in SI that are not matched to 
                    % an ROI in the file. You can choose to disable them.
                    if disable
                       for d = find(SI_RoiFoundTF == 0)
                          obj.hSI.hRoiManager.currentRoiGroup.rois(d).enable = 0;
                       end
                    end
                % All of the File ROI were matched but there are stil some
                % ROI in SI that are not matched to a File ROI. You can
                % choose to disable them. 
                elseif all(fileRoiFoundTF(:) == 1) && numel(obj.hSI.hRoiManager.currentRoiGroup.rois) > numel(RoiData)
                    resp = questdlg('All File ROI have been matched to ROI in SI, but there are still umatched ROI in SI. Do you wish to disable them?',...
                        'Disable Extra SI ROI?', 'Yes', 'No', 'Yes');
                    
                    switch resp
                        case 'Yes'
                            for d = find(SI_RoiFoundTF == 0)
                                obj.hSI.hRoiManager.currentRoiGroup.rois(d).enable = 0;
                            end
                        otherwise
                            
                    end
                end               
                
                % Make a structure to pull and organize basic information
                % Probably not necessary but useful for a basic summary and
                % prevents you from having to parse through roiData
                % structure later for necessary information - simplifies
                % logic
                numROI = numel(RoiData);
                for i = 1:numROI
                    roiSummary = struct();
                    roiSummary.uuid64 = RoiData{i}.hRoi.uuiduint64;
                    roiSummary.name = RoiData{i}.hRoi.name;
                    roiSummary.chanList = RoiData{1}.channels;
                    roiSummary.numChans = numel(RoiData{i}.imageData);
                    roiSummary.numVolumes = numel(RoiData{i}.imageData{1});
                    roiSummary.numSlices = numel(RoiData{i}.imageData{1}{1});
                    roiSummary.numFrames = numel(RoiData{i}.imageData{1}{1}{1});
                    roiDataInfo(i) = roiSummary;
                end
                roiData = RoiData; % unneccessary?
                
            end
            
            % Parses data to pull out only desired ROI, Z plane, frames,
            % etc. Averages desired frames. 
            function roiDataModified = parseRoiData(roiData, roiDataInfo)
                % Create new Roi Data to hold averaged image data
                newRoiData = cell(1,numel(roiData));
                for r = 1:numel(roiData)
                   newRoiData{r} = scanimage.mroi.RoiData();
                   newRoiData{r}.hRoi = roiData{r}.hRoi;
                   newRoiData{r}.zs = roiData{r}.zs;
                   newRoiData{r}.channels = roiData{r}.channels;
                end
                
                % Determine your desired ROI(s)
                numRoi = numel(roiDataInfo);
                numSlices = [roiDataInfo.numSlices];
                numFrames = [roiDataInfo.numFrames];
                chanList = roiDataInfo(1).chanList;
                
                % Channel select - single channel only for now.
                chanPrompt = sprintf('ROI imageData is defined for channels: %s.\nWhich would you like to use?', num2str(chanList));
                chanSelectIdx = listdlg('Name', 'Chan Select', 'PromptString', {chanPrompt,'',''}, 'ListString', arrayfun(@(x) {num2str(x)}, chanList),'SelectionMode', 'single', 'ffs', 28);
                if isempty(chanSelectIdx)
                    % User canceled dialog
                    roiDataModified = [];
                    return;
                end
                
                % Fix ROI Data channels to selected channel
                for i = 1:numRoi
                    newRoiData{i}.channels = chanList(chanSelectIdx);
                end
                roiPrompt = sprintf('The file contains %d ROI. Which would you like to use?', numRoi);
                roiList = {roiDataInfo.name};
                [roiIdxs, tf] = listdlg('Name', 'ROI Select','PromptString', {roiPrompt, ''}, 'ListString', roiList, 'ffs', 24);
                if ~tf
                   % User canceled the dialog
                   roiDataModified = [];
                   return;
                end                
                
                % Check to make sure that one of these ROI does not have
                % more or fewer frames than others - this should never
                % happen as the only aspect that should vary are the Z
                % planes
                assert(all(numFrames(:) == numFrames(1)), 'Frame count is not unifrom between ROI. This should not happen');
                numFrames = numFrames(1); 
                
                % Which frames do you want to use? 
                frameIdxs  = eval(sprintf('[%s]',cell2mat(inputdlg(sprintf('Each slice contains %d Frames. Which would you like to use?\nEntering multiple frames, i.e. 1:5, will average them.', numFrames),'Select Frames'))));
                if isempty(frameIdxs)
                    roiDataModified = [];
                    return;
                end
                
                % Parse out the desired frames and then average them
                % together... 
                % For each selected ROI
                for i = roiIdxs
                    % Go through every plane... 
                    volDataSubset = {};
                    for j = 1:numSlices(i)
                        % Pull selected frames in to new plane. 
                        volDataSubset{j} = roiData{i}.imageData{chanSelectIdx}{1}{j}(frameIdxs);
                        avgData = [];
                        for k = 1:numel(volDataSubset{j})
                            imData = volDataSubset{j}{k};
                            imData = imData./numel(volDataSubset{j});
                            if isempty(avgData) || numel(volDataSubset{j})==1
                                avgData = imData;
                            else
                                avgData = avgData+imData;
                            end
                        end
                        volDataSubset{j} = avgData';
                    end
                    newRoiData{i}.imageData{1} = volDataSubset;
                end
                    
                
                roiDataModified = newRoiData(roiIdxs);
            end
            
            % Matches ROI in RoiData object to ROI in ScanImage. Returns
            % boolean array of File ROI that have been matched to ROI in SI
            % and SI ROI that have been matched to File ROI. 
            function [matchedFileROI, SI_RoiMatched] = matchROI(obj, RoiData)
                % Create boolean to track which ROI were found
                fileRoiFoundTF = zeros(1, numel(RoiData));
                SI_RoiMatched = zeros(1, numel(obj.hSI.hRoiManager.currentRoiGroup.rois));
                % For each ROI in the file...
                for i = 1:numel(RoiData)
                    % for each ROI in ScanImage....
                    for j=1:numel(obj.hSI.hRoiManager.currentRoiGroup.rois)
                        % Check if the file ROI matches the current SI
                        % ROI...
                        if RoiData{i}.hRoi.isequalish(obj.hSI.hRoiManager.currentRoiGroup.rois(j))
                           % if it matches, assign SI ROI data and set flag
                           % to true
                           RoiData{i}.hRoi = obj.hSI.hRoiManager.currentRoiGroup.rois(j);
                           fileRoiFoundTF(i) = true;
                           SI_RoiMatched(j) = true;
                        end
                    end
                end
                matchedFileROI = fileRoiFoundTF;
                
            end
            
            % Custom dialog to decide whether to create or discard
            % umatched ROI and disable check box to determine whether to
            % disable ROI that exist in SI but don't match any file ROI. 
            function [descision, disable] = roiMitigationDialog(roiFileLogic, roiSILogic)
                totalFile = numel(roiFileLogic);
                badFile = sum(roiFileLogic == 0);
                totalSI = numel(roiSILogic);
                badSI = sum(roiSILogic == 0);
                mainTextStr = sprintf('%d/%d ROI in the file have NOT been matched to an ROI in SI.', badFile, totalFile);
                d = dialog('Position',[300 300 300 140],'Name','ROI Mismatch', 'CloseRequestFcn', @close_callback);
                maintext = uicontrol('Parent',d,...
                       'Style','text',...
                       'Position',[0 80 300 50],...
                       'String',mainTextStr);

                discardbtn = uicontrol('Parent',d,...
                       'Position',[20 70 100 25],...
                       'String','Discard extra ROI',...
                       'Callback',@discard_callback);

               createbtn = uicontrol('Parent',d,...
                       'Position',[125 70 90 25],...
                       'String','Create ROI in SI',...
                       'Callback',@create_callback);

               closebtn = uicontrol('Parent',d,...
                       'Position',[220 70 70 25],...
                       'String','Cancel',...
                       'Callback',@close_callback);
               disableStr = sprintf('%d/%d ROI in SI are unmatched. Disable them?', badSI, totalSI);
               cb_disable = uicontrol('Parent',d,...
                   'Style','checkbox',...
                   'Position',[20 30 250 25],...
                   'String',{disableStr, ''});

                uiwait(d);
                function discard_callback(discardbtn,event)
                    descision = 'discard';
                    disable = cb_disable.Value;
                    delete(gcf);
                end

                function create_callback(createbtn, event)
                    descision = 'create';
                    disable = cb_disable.Value;
                    delete(gcf);
                end

                function close_callback(closebtn, event)
                    descision = [];
                    disable = [];
                    delete(gcf);
                end
            end
            
            % Special Logic to handle non-SI Tif files. Limited support due
            % to lack of information from losing hdr data. 
            function RoiData = processNonSITiff(tifPath)
                try
                    warning('off');
                    hTif = Tiff(tifPath, 'r');

                    % Can only connect to 1 ROI. Why? In mROI mode with
                    % multiple ROI when opened in Tiff mode the image data from
                    % all ROI are concatened together. We would need XxY
                    % resolution of images, scanfield flyto time and line
                    % period. No access to that in non-SI tiff. Plus we know
                    % nothing of the order of ROI. No way to associate data
                    % without just guessing. 

                    % Get total frames in the file
                    totalFrames = 1;
                    while ~hTif.lastDirectory()
                        hTif.nextDirectory();
                        totalFrames = totalFrames + 1;
                    end
                    hTif.setDirectory(1);
                    % Done
                    warning('on');
                catch
                    
                end
                
                % Can only match to 1 ROI for now
                uiwait(warndlg('Non-SI tiff data can only be associated with a single ROI due to lack of information. If this tiff contains data from multiple ROI this will fail!', 'ROI Warn'));
                
                % Query for general information
                params = num2cell(str2double(inputdlg({'How many slices? Enter 1 if not a volume.:', 'How many frames per slice?:', 'Which channel?:'}, 'Tiff Data', [1 50], {'1', '1', '1'})));
                if isempty(params)
                    RoiData = [];
                    return;
                end
                [numSlices, framesPerSlice, chan] = params{:};
                assert(~isempty(numSlices) && isnumeric(numSlices) && ~isinf(numSlices) && ~isnan(numSlices), 'Invalid val:numSlices');
                assert(~isempty(framesPerSlice) && isnumeric(framesPerSlice) && ~isinf(framesPerSlice) && ~isnan(framesPerSlice), 'Invalid val:framesPerSlice');
                assert(~isempty(chan) && isnumeric(chan) && ~isinf(chan) && ~isnan(chan), 'Invalid val:Channel');
                
                % If this is a fastZ volume it will likely contain flyback
                % frames. Could also just use the first volume and ignore
                % this....
                if numSlices > 1
                    fstZ = questdlg('Number of slices was > 1. Was this a FastZ volume?', 'FastZ?', 'Yes', 'No', 'Yes');
                    switch fstZ
                        case 'Yes'
                            isFastZ = 1;
                            params = num2cell(str2double(inputdlg({'How many volumes?:', 'How many, if any, flyback frames?:'}, 'FastZ Data', [1 50], {'1', '0'})));
                            if isempty(params)
                                RoiData = [];
                                return;
                            end
                            [numVolumes, numFlyback] = params{:};
                            assert(~isempty(numVolumes) && isnumeric(numVolumes) && ~isinf(numVolumes) && ~isnan(numVolumes), 'Invalid val:numVolumes');
                            assert(~isempty(numFlyback) && isnumeric(numFlyback) && ~isinf(numFlyback) && ~isnan(numFlyback), 'Invalid val:numFlyback');
                            
                            if numVolumes > 1
                                str = sprintf('You have indicated that the file contains %d volumes, select which one to use:', numVolumes);
                                volSelect = str2double(inputdlg(str, 'Vol Select', [1 50], {'1'}));
                                if isempty(volSelect)
                                    RoiData = [];
                                    return
                                end
                                assert(isnumeric(volSelect) && ~isinf(volSelect) && ~isnan(volSelect), 'Invalid val:volSelect');
                            end
                        case 'No'
                            isFastZ = 0;
                            numVolumes = 1;
                            numFlyback = 0;
                            volSelect = 1;
                        otherwise
                            %Empty, dialog cancelled. 
                            RoiData = [];
                            return;
                    end
                    
                    % Pick Z's
                    zsStep = questdlg('Choose how to enter z positions?', 'Z Positions', 'Step Size', 'Discrete Zs', 'Cancel', 'Step Size');
                    
                    switch zsStep
                        case 'Step Size'
                            stepSize = (cell2mat(inputdlg('Enter step size per slice:', 'Step Size', [1, 50], {'1'})));
                            if isempty(stepSize)
                                RoiData = [];
                                return;
                            end
                            stepSize = str2num(stepSize);
                            if numel(stepSize) > 1
                               error('Step size must be a discrete value');
                            end
                            assert(~isempty(stepSize) && isnumeric(stepSize) && ~isinf(stepSize) && ~isnan(stepSize), 'Invalid val:stepSize');
                            zs = 0:stepSize:(numSlices-1)*stepSize;
                        case 'Discrete Zs'
                            zs = (cell2mat(inputdlg('Enter z positions:', 'Z Positions', [1, 50], {'1'})));
                            if isempty(zs)
                                RoiData = [];
                                return;
                            end
                            zs = str2num(zs);
                            assert(~isempty(zs) && isnumeric(zs) && ~any(isinf(zs)) && ~any(isnan(zs)), 'Invalid val:zs');
                            if numel(zs) ~= numSlices
                                error('Number of Z planes does not match number of slices.');
                            end
                        otherwise
                            %Empty, dialog cancelled. 
                            RoiData = [];
                            return;
                    end
                else
                    isFastZ = 0;
                    numVolumes = 1;
                    numFlyback = 0;
                    volSelect = 1;
                    zs = 0;
                end
                
                % Check that entered data meshes with detected number
                % of frames
                userComputed = (numSlices*framesPerSlice*numVolumes)+(numVolumes*numFlyback);
                if userComputed ~= totalFrames
                    error('User entered data indicates %d frames total but actual number of frames in file is %d.', userComputed, totalFrames);
                end
                
                % Okay so ow we have the basic information, which ROI now. 
                
                numRoi = numel(obj.hSI.hRoiManager.currentRoiGroup.rois);
                roiPrompt = sprintf('There %d ROI in the current ROI group. Select which to associate image data with:', numRoi);
                roiList = {obj.hSI.hRoiManager.currentRoiGroup.rois.name};
                [roiIdxs, tf] = listdlg('Name', 'ROI Select','PromptString', {roiPrompt, ''}, 'ListString', roiList, 'ffs', 24, 'SelectionMode', 'Single');
                if ~tf
                   % User canceled the dialog
                   RoiData = [];
                   return;
                end
                
                thisROI = obj.hSI.hRoiManager.currentRoiGroup.rois(roiIdxs);
                
                % PParse Image data and contrsuct RoiData obj
                imData = {};
                % FastZ file can contain multiple (repeated) volume
                % acquisitions as well as inter-volume flyback (garbage)
                % frames. Want to select the correct volume and not use
                % garbage frames as M.C. reference images.
                if isFastZ
                    % Make sure you start at the right Vol offset. 
                    volStartIdx = ((volSelect-1)*(numSlices+numFlyback))+1;
                    hTif.setDirectory(volStartIdx);
                    %FastZ contains 1 frame per slice always so just
                    %iterate through the slices.
                    for i = 1:numSlices
                        imData{1}{i}{1} = hTif.read()';
                        % If you reach the last directory/last frame/end of
                        % file make sure that this is the last slice.
                        % Should only hit end of file if last volume is
                        % selected and there are no flyback frames 
                        if hTif.lastDirectory && i~=numSlices && numFlyback == 0
                            error('Premature end of file.');
                        else
                            hTif.nextDirectory();
                        end
                    end
                else
                   % For each slice
                   for i = 1:numSlices
                       % For all the frames that should be on that slice
                       for k = 1:framesPerSlice
                           % Read that data in 1 frame at a time....
                           imData{1}{i}{k} = hTif.read()';
                           % ...make sure this isnt the last directory(i.e.
                           % last frame in file/end of file)...
                           if hTif.lastDirectory
                               % If it is the last directory make sure is
                               % is appropriate; should only hit end of
                               % file on the last frame of the last slice
                               if k ~= framesPerSlice && i ~= numSlices
                                   % If that isn't true then this is a
                                   % premature end of file. The user likely
                                   % entered incorrect information about
                                   % the file we made a mistake in sofware.
                                  error('Premature end of file.'); 
                               end
                           % Otherwise if this is not the last directory
                           % (end of file) move to the next directory
                           % (should contain the next frame)
                           else
                               hTif.nextDirectory();
                           end
                       end
                   end
                end
                
                % Easier to do this last after parsing out the images from
                % Tiff directories
                if ~isFastZ % Dont avg in FastZ b/c 1 frame per slice
                    frameIdxs  = eval(sprintf('[%s]',cell2mat(inputdlg(sprintf('Each slice contains %d Frames. Which would you like to use?\nEntering multiple frames(i.e 5:8) will average them.', framesPerSlice),'Select Frames'))));
                    if isempty(frameIdxs)
                        RoiData = [];
                        return;
                    end
                    for i = 1:numSlices
                        imageSubset = imData{1}{i}(frameIdxs);
                        avgData = [];
                        for j = 1:numel(imageSubset)
                            im = imageSubset{j};
                            im = im./numel(imageSubset);
                            if isempty(avgData) || numel(imageSubset) == 1
                                avgData = im;
                            else
                                avgData = avgData+im;
                            end
                        end
                        imData{1}{i} = {avgData};
                    end
                end
               
               RoiData = scanimage.mroi.RoiData();
               RoiData.hRoi = thisROI;
               RoiData.zs = zs;
               RoiData.channels = chan;
               RoiData.imageData = imData;
            end
        end
    end
    
    %% PROPERTY GET/SET FUNCTIONS
    methods
        function val = get.hMotionEstimators(obj)
            if ~isempty(obj.hMotionEstimators)
                validMask = isvalid(obj.hMotionEstimators);
                if ~all(validMask)
                    obj.hMotionEstimators = obj.hMotionEstimators(validMask);
                end
            end
            
            val = obj.hMotionEstimators;
        end
        
        function set.plotPerformance(obj,val)
            oldVal = obj.hPerformancePlot.visible;
            obj.hPerformancePlot.visible = val;
            
            if oldVal ~= val && val
                obj.hPerformancePlot.reset;
            end
        end
        
        function val = get.plotPerformance(obj)
            val = obj.hPerformancePlot.visible;
        end
        
        function set.zStackAlignmentFcn(obj,val)
            validateattributes(val,{'function_handle'},{'scalar'});
            obj.zStackAlignmentFcn = val;
        end
        
        function set.hMotionEstimators(obj,val)
            obj.hMotionEstimators = val;
            obj.attachMotionEstimatorListeners();
            obj.notifyMotionEstimatorsChanged();
        end
        
        function set.correctionEnableXY(obj,val)
            val = obj.validatePropArg('correctionEnableXY',val);
            
            if obj.componentUpdateProperty('correctionEnableXY',val)
                obj.correctionEnableXY = logical(val);
                obj.checkCorrectionEnableAxes();
            end
        end
        
        function set.correctionEnableZ(obj,val)
            val = obj.validatePropArg('correctionEnableZ',val);
            
            if obj.componentUpdateProperty('correctionEnableZ',val)
                obj.correctionEnableZ = logical(val);
                obj.checkCorrectionEnableAxes();
            end
        end
        
        function set.correctionDeviceXY(obj,val)
            val = lower(val);
            validentries = {'galvos','motor'};
            assert(ismember(val,validentries),'Incorrect correctionDeviceXY: %s. Valid entries are: {''%s''}',val,strjoin(validentries,''', '''));
            
            if obj.componentUpdateProperty('correctionDeviceXY',val)
                obj.correctionDeviceXY = val;
                obj.resetMotionCorrection();
            end
        end
        
        function set.correctionDeviceZ(obj,val)
            val = lower(val);
            validentries = {'fastz','motor'};
            assert(ismember(val,validentries),'Incorrect correctionDeviceZ: %s. Valid entries are: {''%s''}',val,strjoin(validentries,''', '''));
            
            if obj.componentUpdateProperty('correctionDeviceZ',val)
                obj.correctionDeviceZ = val;
                obj.resetMotionCorrection();
            end
        end
        
        function set.estimatorClassName(obj, val)
            val = checkEstimatorSystemRequirements(val);
            
            if obj.componentUpdateProperty('estimatorClassName',val)
                if isobject(val)
                    mc = metaclass(val);
                    val = mc.Name;
                end
                obj.estimatorClassName = val;
            end
        end
        
        function set.correctorClassName(obj,val)
            assert(most.idioms.isa(val,'scanimage.interfaces.IMotionCorrector'),'Not a valid scanimage.interfaces.IMotionCorrector class');
            if strcmp(val,obj.correctorClassName)
                return % Nothing to do
            end
            
            if obj.componentUpdateProperty('correctorClassName',val)
                constructorFcn = str2func(val);
                hMC = constructorFcn();
                if most.idioms.isValidObj(hMC)
                    oldMC = obj.hMotionCorrector;
                    obj.hMotionCorrector = hMC;
                    most.idioms.safeDeleteObj(oldMC);
                end
            end
        end
        
        function val = get.correctorClassName(obj)
            if isempty(obj.hMotionCorrector) || ~most.idioms.isValidObj(obj.hMotionCorrector)
                val = '';
            else
                val = class(obj.hMotionCorrector);
            end
        end
        
        function set.hMotionCorrector(obj,val)
            assert(isa(val,'scanimage.interfaces.IMotionCorrector'));
            if isequal(obj.hMotionCorrector,val)
                return % Nothing to do here
            end
            
            if obj.componentUpdateProperty('hMotionCorrector',val)
                most.idioms.safeDeleteObj(obj.hCorrectNowListener);
                obj.hCorrectNowListener = addlistener(val,'correctNow',@(varargin)obj.correctMotion());
                obj.hMotionCorrector = val;
            end
        end
        
        function set.enable(obj, val)
            val = obj.validatePropArg('enable',val);
            if obj.componentUpdateProperty('enable',val)
                obj.enable = logical(val);
            end
        end
        
        function set.motionHistoryLength(obj,val)
            val = obj.validatePropArg('motionHistoryLength',val);
            if obj.componentUpdateProperty('motionHistoryLength',val)
                obj.motionHistoryLength = val;
            end
        end
        
        function set.correctionBoundsXY(obj,val)
            if isscalar(val)
                val = [-val val];
            end
            val = obj.validatePropArg('correctionBoundsXY',val);
            val = sort(val);
            
            assert(val(1)<=0 && val(2)>=0,'Correction bounds must be a vector containing a negative and a positive number');
            
            if obj.componentUpdateProperty('correctionBoundsXY',val)
                obj.correctionBoundsXY = val;
            end
        end
        
        function set.correctionBoundsZ(obj,val)
            if isscalar(val)
                val = [-val val];
            end
            val = obj.validatePropArg('correctionBoundsZ',val);
            val = sort(val);
            
            assert(val(1)<=0 && val(2)>=0,'Correction bounds must be a vector containing a negative and a positive number');
            
            if obj.componentUpdateProperty('correctionBoundsZ',val)
                obj.correctionBoundsZ = val;
            end
        end
        
        function set.motionMarkersXY(obj,val)
            if isempty(val)
                val = zeros(0,2);
            end
            validateattributes(val,{'numeric'},{'ncols',2});
            
            obj.motionMarkersXY = val;
        end
        
        function set.resetCorrectionAfterAcq(obj,val)
            val = obj.validatePropArg('resetCorrectionAfterAcq',val);
            
            if obj.componentUpdateProperty('resetCorrectionAfterAcq',val)
                oldVal = obj.resetCorrectionAfterAcq;
                obj.resetCorrectionAfterAcq = val;
                
                if ~obj.resetCorrectionAfterAcq && oldVal && ~obj.active
                    obj.resetMotionCorrection();
                end
            end
        end
    end
    
    %% INTERNAL MEHTODS
    methods (Hidden)
        % Pipe live data to the estimators
        function stripeData = estimateMotion(obj, stripeData)
            if ~obj.active || ~obj.enable || isempty(obj.hMotionEstimators)
                return
            end
            
            if ~stripeData.startOfFrame || ~stripeData.endOfFrame
                most.idioms.warn('Motion correction cannot be activated when striping display is used.');
                obj.enable = false;
                return
            end
            
            obj.hPerformancePlot.tic();
            
            roiDatas = stripeData.roiData;
            for roiDataIdx = 1:length(roiDatas)
                roiData = roiDatas{roiDataIdx};
                estimatorMask = ismembc([obj.hMotionEstimators.roiUuiduint64],roiData.hRoi.uuiduint64);
                hMotionEstimators_ = obj.hMotionEstimators(estimatorMask);
                for idx = 1:length(hMotionEstimators_)
                    try
                        if hMotionEstimators_(idx).enable
                            if ~hMotionEstimators_(idx).started
                                % if new estimators were added since componentStart, we have to start them now
                                hMotionEstimators_(idx).start();
                            end
                            result = hMotionEstimators_(idx).estimateMotion(roiData);
                            obj.appendResultQueue(result);
                        else
                            if hMotionEstimators_(idx).started
                                hMotionEstimators_(idx).abort();
                            end
                        end
                    catch ME
                        % something went wrong in the motion estimator
                        most.idioms.reportError(ME);
                    end
                end
            end
            
            obj.pollResults();
            
            stripeData = obj.calculateRoiDataMotionOffset(stripeData);
            
            obj.hPerformancePlot.toc();
        end
        
        function appendResultQueue(obj, result)
            if ~isempty(result)
                assert(isa(result,'scanimage.interfaces.IMotionEstimatorResult'),'Class ''%s'' is not a valid scanimage.interfaces.IMotionEstimatorResult',class(result));
                result.callback = @obj.pollResults;
                obj.resultQueue = horzcat(obj.resultQueue,result);
            end
        end
        
        function pollResults(obj,varargin)
            if ~obj.active || ~obj.enable
                return
            end
            
            resultAvailableMask = false(1,length(obj.resultQueue));
            
            for idx = 1:length(obj.resultQueue)
                % poll oldest results first
                timeout_s = 0;
                resultAvailableMask(idx) = obj.resultQueue(idx).wait(timeout_s);
                if ~resultAvailableMask(idx)
                    break % this ensures in-order evaluation of results
                end
            end
            
            % remove the completed results from queue
            resultQueue_ = obj.resultQueue(resultAvailableMask);
            obj.resultQueue(resultAvailableMask) = [];
            
            % fetch the results
            newResultAvailable = false;
            for idx = 1:numel(resultQueue_)
                try
                    result = resultQueue_(idx);
                    drPixel = result.fetch();
                    if ~isempty(drPixel)
                        hMotionEstimator = result.hMotionEstimator;
                        roiData = result.roiData;
                        confidence = result.confidence;
                        correlation = result.correlation;
                        userData = result.userData;
                        userDataStr = result.userData2Str();
                        obj.updateMotionHistory(hMotionEstimator,roiData,drPixel,confidence,correlation,userData,userDataStr);
                        newResultAvailable = true;
                    end
                catch ME
                    most.idioms.reportError(ME);
                end
            end
            
            if newResultAvailable
                obj.notify('newMotionEstimateAvailable');
                obj.updateMotionCorrector();
            end
        end
        
        function flushResultQueue(obj)
            obj.resultQueue = []; % do not delete result objects, just let them go out of scope
        end
                
        function updateMotionHistory(obj,hMotionEstimator,roiData,drPixel,confidence,correlation,userData,userDataStr)
            [T] = drToRefTransform(roiData,drPixel);
            
            historyEntry = struct();
            historyEntry.hMotionEstimator = hMotionEstimator;
            historyEntry.hMotionEstimatorUuiduint64 = hMotionEstimator.uuiduint64;
            historyEntry.hRoi = roiData.hRoi;
            historyEntry.roiData = roiData;
            historyEntry.acqNumber = roiData.acqNumber;
            historyEntry.frameNumberAcq = roiData.frameNumberAcq;
            historyEntry.frameNumberAcqMode = roiData.frameNumberAcqMode;
            historyEntry.frameTimestamp = roiData.frameTimestamp;
            historyEntry.z = roiData.zs;
            historyEntry.zs = hMotionEstimator.zs;
            historyEntry.drPixel = drPixel;
            historyEntry.drRef = T(1:3,4)';
            historyEntry.refTransform = T;
            historyEntry.confidence = confidence;
            historyEntry.correlation = correlation;
            historyEntry.userData = userData;
            historyEntry.userDataStr = userDataStr;
            
            appendMotionHistory(historyEntry);
            obj.logResult(historyEntry);
            
            %%% local functions
            function T = drToRefTransform(roiData,dr)
                dx = dr(1);
                dy = dr(2);
                dz = dr(3);
                
                z = roiData.zs;
                scanfield = roiData.hRoi.get(z);
                
                % convert pixel offset into a reference space transformation
                pixSfT = eye(3);
                pixSfT(1,3) = dr(1);
                pixSfT(2,3) = dr(2);
                
                scanfieldPixelToRefTransform = scanfield.pixelToRefTransform;
                T = scanfieldPixelToRefTransform * pixSfT / scanfieldPixelToRefTransform;
                T = scanimage.mroi.util.affine2Dto3D(T);
                T(15) = dz;
            end
            
            function appendMotionHistory(historyEntry)
                if isempty(obj.motionHistory)
                    historyEntry.historyIdx = 1;
                    obj.motionHistory = historyEntry;
                elseif length(obj.motionHistory) < obj.motionHistoryLength
                    historyEntry.historyIdx = obj.motionHistory(end).historyIdx+1;
                    obj.motionHistory(end+1) = historyEntry;
                else
                    historyEntry.historyIdx = obj.motionHistory(end).historyIdx+1;
                    obj.motionHistory = circshift(obj.motionHistory,-1,2);
                    obj.motionHistory(end) = historyEntry;
                end
            end
        end
        
        function resetmotionHistory(obj)
            obj.motionHistory = [];
        end
        
        function openLogFile(obj)
            if obj.hSI.hChannels.loggingEnable
                logFileName = fullfile(obj.hSI.hScan2D.logFilePath,[obj.hSI.hScan2D.logFileStem '_Motion_' sprintf('%05d', obj.hSI.hScan2D.logFileCounter) '.csv']);
                [hLogFile_,errmsg] = fopen(logFileName,'W'); % permission 'w' flushes output buffer after each call to fwrite. 'W' disables this behavior
                
                if hLogFile_ > -1
                    obj.hLogFile = hLogFile_;
                    fields = {'timestamp' 'frameNumber' 'roiName' 'z' 'drPixel' 'drRef' 'confidence' 'userData'};
                    delimiter = ', ';
                    fprintf(obj.hLogFile,'%s\r\n',strjoin(fields,delimiter));
                else
                    obj.hLogFile = [];
                    error('%s',errmsg);
                end
            end
        end
        
        function logResult(obj,historyEntry)
            if ~isempty(obj.hLogFile) 
                if ischar(historyEntry.userData)
                    userDataStr = historyEntry.userDataStr;
                else
                    userDataStr = '';
                end
                
                % {formatstring, data}
                format = {...
                    '%f' historyEntry.frameTimestamp    ;...
                    '%d' historyEntry.frameNumberAcqMode;...
                    '%s' historyEntry.hRoi.name         ;...
                    '%f' historyEntry.z                 ;...
                    '%s' mat2str(historyEntry.drPixel)  ;...
                    '%s' mat2str(historyEntry.drRef)    ;...
                    '%s' mat2str(historyEntry.confidence);...
                    '%s' userDataStr                     ...
                    };
                
                delimiter = ', ';
                fprintf(obj.hLogFile,[strjoin(format(:,1),delimiter) '\r\n'],format{:,2});
            end
        end
        
        function closeLogFile(obj)
            if ~isempty(obj.hLogFile)
                fclose(obj.hLogFile);
                obj.hLogFile = [];
            end
        end
        
        function stripeData = calculateRoiDataMotionOffset(obj,stripeData)
            if isempty(obj.motionHistory)
                return
            end
            
            drRef = [];
            for idx = length(obj.motionHistory):-1:1
                % find newest estimate
                drRef_ = obj.motionHistory(idx).drRef;
                if all(~isnan(drRef_(1:2)))
                    drRef = drRef_;
                    break
                end
            end
            
            if isempty(drRef)
                return
            end
            
            roiDatas = stripeData.roiData;
            for idx = 1:length(roiDatas)
                roiData = roiDatas{idx};
                hRoi = roiData.hRoi;
                sf = hRoi.get(roiData.zs);
                pixelToRefTransform = sf.pixelToRefTransform;
                
                dOriginPixels = scanimage.mroi.util.xformPoints([0,0],pixelToRefTransform,true);
                dRPixels = scanimage.mroi.util.xformPoints(drRef(1:2),pixelToRefTransform,true);
                roiData.motionOffset = dRPixels - dOriginPixels;
            end
            
            motionMatrix = eye(4);
            motionMatrix(13:14) = -drRef(1:2);
            stripeData.motionMatrix = motionMatrix;
        end
        
        function updateMotionCorrector(obj)
            if ~isempty(obj.hMotionCorrector) && most.idioms.isValidObj(obj.hMotionCorrector)
                obj.hMotionCorrector.updateMotionHistory(obj.motionHistory);
            end
        end
        
        function correctMotion(obj,dr,forceXY,forceZ)
            if ~obj.active || ~obj.enable
                return
            end
            
            if nargin<2 || isempty(dr)
                assert(most.idioms.isValidObj(obj.hMotionCorrector),'hMotionCorrector is invalid');
                dr = obj.hMotionCorrector.getCorrection();
            end
            
            if nargin<3 || isempty(forceXY)
                forceXY = false;
            end
            
            if nargin<4 || isempty(forceZ)
                forceZ = false;
            end
            
            validateattributes(dr,{'numeric'},{'vector','numel',3});
            
            dAbsOld = obj.motionCorrectionVector;
            for axIdx = 1:3
                dAbsNew(axIdx) = coerceCorrectionAxis(axIdx,dAbsOld(axIdx),dr(axIdx)); %#ok<AGROW>
            end
            
            if ~isequal(dAbsOld,dAbsNew)
                obj.moveAxesAbsolute(dAbsNew);
            end

            %%% local function
            function dAbsNew = coerceCorrectionAxis(axis_number,dAbsOld,d)
                correctionEnableAxes = [obj.correctionEnableXY obj.correctionEnableXY obj.correctionEnableZ];
                force = [forceXY forceXY forceZ];
                useAxis = correctionEnableAxes(axis_number) || force(axis_number);
                
                valid = useAxis && ~isnan(d) && isreal(d) && ~isinf(d);
                if valid
                    axisName = {'XY' 'XY' 'Z'};
                    bounds = obj.(['correctionBounds' axisName{axis_number}]);
                    dAbsNew = dAbsOld+d;
                    dAbsNew = max(min(bounds(2),dAbsNew),bounds(1)); % coerce to allowed range
                else
                    dAbsNew = dAbsOld;
                end
            end
        end
    end
    
    methods (Access = private)
        function ensureClassDataFileProps(obj)
            try
                obj.ensureClassDataFile(struct('motionHistoryLength', obj.motionHistoryLength), obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionEnableXY',  obj.correctionEnableXY),  obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionEnableZ',   obj.correctionEnableZ),   obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionDeviceXY',  obj.correctionDeviceXY),  obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionDeviceZ',   obj.correctionDeviceZ),   obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionBoundsXY',  obj.correctionBoundsXY),  obj.classDataFileName);
                obj.ensureClassDataFile(struct('correctionBoundsZ',   obj.correctionBoundsZ),   obj.classDataFileName);
                obj.ensureClassDataFile(struct('resetCorrectionAfterAcq', obj.resetCorrectionAfterAcq), obj.classDataFileName);
                
                obj.ensureClassDataFile(struct('motionCorrectorStruct',[]), obj.classDataFileName);
                obj.ensureClassDataFile(struct('estimatorClassName',[]),    obj.classDataFileName);
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function loadClassData(obj)
            try
                obj.ensureClassDataFileProps();

                safeSetProp('motionHistoryLength');
                safeSetProp('correctionEnableXY');
                safeSetProp('correctionEnableZ');
                safeSetProp('correctionDeviceXY');
                safeSetProp('correctionDeviceZ');
                safeSetProp('correctionBoundsXY');
                safeSetProp('correctionBoundsZ');
                safeSetProp('resetCorrectionAfterAcq');
                
                motionCorrectorStruct = obj.getClassDataVar('motionCorrectorStruct',obj.classDataFileName);
                if ~isempty(motionCorrectorStruct)
                    hMC = scanimage.interfaces.IMotionCorrector.loadobj(motionCorrectorStruct);
                    hMCOld = obj.hMotionCorrector;
                    obj.hMotionCorrector = hMC;
                    most.idioms.safeDeleteObj(hMCOld);
                end
                
                estimatorClassName_ = obj.getClassDataVar('estimatorClassName',obj.classDataFileName);
                if ~isempty(estimatorClassName_)
                    obj.estimatorClassName = estimatorClassName_;
                end
            catch ME
                most.idioms.reportError(ME);
            end
            
            function safeSetProp(propName)
                try
                    obj.(propName) = obj.getClassDataVar(propName,obj.classDataFileName);
                catch ME_
                    most.idioms.warn('MotionManager: Could not restore property %s',propName);
                end
            end
        end
        
        function saveClassData(obj)
            try
                obj.ensureClassDataFileProps();
                
                obj.setClassDataVar('motionHistoryLength', obj.motionHistoryLength, obj.classDataFileName);
                obj.setClassDataVar('correctionEnableXY',  obj.correctionEnableXY,  obj.classDataFileName);
                obj.setClassDataVar('correctionEnableZ',   obj.correctionEnableZ,   obj.classDataFileName);
                obj.setClassDataVar('correctionDeviceXY',  obj.correctionDeviceXY,  obj.classDataFileName);
                obj.setClassDataVar('correctionDeviceZ',   obj.correctionDeviceZ,   obj.classDataFileName);
                obj.setClassDataVar('correctionBoundsXY',  obj.correctionBoundsXY,  obj.classDataFileName);
                obj.setClassDataVar('correctionBoundsZ',   obj.correctionBoundsZ,   obj.classDataFileName);
                obj.setClassDataVar('resetCorrectionAfterAcq', obj.resetCorrectionAfterAcq, obj.classDataFileName);
                
                if most.idioms.isValidObj(obj.hMotionCorrector)
                    motionCorrectorStruct = obj.hMotionCorrector.saveobj();
                    obj.setClassDataVar('motionCorrectorStruct',motionCorrectorStruct,obj.classDataFileName);
                end
                
                if ~isempty(obj.estimatorClassName)
                    obj.setClassDataVar('estimatorClassName',obj.estimatorClassName,obj.classDataFileName);
                end
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function moveAxesAbsolute(obj,newMotionCorrectionVector)
            if ~obj.active || ~obj.enable
                return
            end
            
            validateattributes(newMotionCorrectionVector,{'numeric'},{'numel',3,'nonnan','finite'});
            dr = newMotionCorrectionVector-obj.motionCorrectionVector;
            
            if ~any(dr)
                return % nothing to do
            end
            
            % buffer key parameters for local functions
            if isempty(obj.performanceCache.scannerset)
                ss = obj.hSI.hScan2D.scannerset;
                [correctionXYPossible,correctionZPossible] = obj.correctionPossible();
            else
                ss = obj.performanceCache.scannerset;
                correctionXYPossible = obj.performanceCache.correctionXYPossible;
                correctionZPossible  = obj.performanceCache.correctionZPossible;
            end
            isSlowZ = obj.hSI.hStackManager.isSlowZ;
            isFastZ = obj.hSI.hStackManager.isFastZ;
            
            % get corrections
            [moveMotor,motor_d] = getMotorCorrection();
            [moveGalvos,galvo_volt_offset] = getGalvoVoltCorrectionXY();
            [moveFastZ,fastZ_volt_offset] = getFastZVoltCorrection();
            
            %%% update scannerOffsets
            if moveFastZ
                obj.scannerOffsets.ao_volts.Z = fastZ_volt_offset;
            end
            
            if moveGalvos
                obj.scannerOffsets.ao_volts.G = galvo_volt_offset;
            end

            %%% execute devices movements
            if moveMotor
                obj.hSI.hMotors.motorPosition(1:3) = obj.hSI.hMotors.motorPosition(1:3) + motor_d;
            end
            
            % logic for updating live values
            % currently the offset is applied in get.scannerAO in
            % WaveformManager
            
            forceLiveUpdateScan2D = false;
            if moveFastZ
                if obj.hSI.hFastZ.sharingScannerDaq
                    forceLiveUpdateScan2D = true;
                else
                    obj.hSI.hFastZ.liveUpdate();
                end
            end

            if moveGalvos || forceLiveUpdateScan2D
                obj.hSI.hScan2D.updateLiveValues(false);
            end
            
            if ~isequal(obj.motionCorrectionVector,newMotionCorrectionVector)
                obj.motionCorrectionVector = newMotionCorrectionVector;
                obj.hMotionCorrector.correctedMotion(dr,newMotionCorrectionVector);
                obj.hSI.hUserFunctions.notify('motionCorrected');
            end
            
            %%% local functions
            function [moveMotor,motor_d] = getMotorCorrection()
                moveMotor = false;
                motor_d = [0 0 0];                
                
                useMotorXY = any(dr(1:2)) && strcmpi(obj.correctionDeviceXY,'motor');
                if correctionXYPossible && useMotorXY && ~isSlowZ % don't update motor position in slow Z stack acquisition
                    assert(obj.hSI.hMotors.motorToRefTransformValid);
                    motorToRefT = obj.hSI.hMotors.motorToRefTransform; % this is a 3x3 matrix

                    origin_motor = scanimage.mroi.util.xformPoints([0 0],motorToRefT,true);
                    dr_motor = scanimage.mroi.util.xformPoints(dr(1:2),motorToRefT,true);
                    motor_d(1:2) = dr_motor-origin_motor; % motion vector
                    moveMotor = true;
                end
                
                useMotorZ = dr(3) && strcmpi(obj.correctionDeviceZ,'motor');
                if correctionZPossible && useMotorZ && ~isSlowZ % don't update motor position in slow Z stack acquisition
                    motor_d(3) = dr(3);
                    moveMotor = true;
                end                
            end
            
            function [moveGalvos,galvo_volt_offset] = getGalvoVoltCorrectionXY()
                moveGalvos = false;
                galvo_volt_offset = [0 0];
                
                useGalvos = any(dr(1:2)) && strcmpi(obj.correctionDeviceXY,'galvos');
                if correctionXYPossible && useGalvos
                    % transform around scanner origin
                    scannerOriginRef = scanimage.mroi.util.xformPoints([0,0],ss.scannerToRefTransform);
                    correctedOriginRef = scannerOriginRef+newMotionCorrectionVector(1:2);
                    d_galvo_deg = scanimage.mroi.util.xformPoints(correctedOriginRef,ss.scannerToRefTransform,true);
                    
                    if isa(ss,'scanimage.mroi.scannerset.GalvoGalvo')
                        x_gscanner = ss.scanners{1};
                        y_gscanner = ss.scanners{2};
                    elseif isa(ss,'scanimage.mroi.scannerset.ResonantGalvoGalvo')
                        x_gscanner = ss.scanners{2};
                        y_gscanner = ss.scanners{3};
                    end
                    
                    %%% coerce galvos into allowed voltage range                    
                    x_ao_max_deg = sort(x_gscanner.volts2Position(obj.performanceCache.ao_GX_max_volts));
                    y_ao_max_deg = sort(y_gscanner.volts2Position(obj.performanceCache.ao_GY_max_volts));
                    
                    x_allowed_d = x_gscanner.travelRange-x_ao_max_deg;
                    y_allowed_d = y_gscanner.travelRange-y_ao_max_deg;
                    
                    d_galvo_deg(1) = min(max(d_galvo_deg(1),x_allowed_d(1)),x_allowed_d(2));
                    d_galvo_deg(2) = min(max(d_galvo_deg(2),y_allowed_d(1)),y_allowed_d(2));
                    d_galvo_ref = scanimage.mroi.util.xformPoints(d_galvo_deg,ss.scannerToRefTransform);

                    newMotionCorrectionVector(1:2) = d_galvo_ref - scannerOriginRef;
                    dr(1:2) = newMotionCorrectionVector(1:2)-obj.motionCorrectionVector(1:2);
                    %%% 
                    
                    if ~isequal(newMotionCorrectionVector(1:2),obj.motionCorrectionVector(1:2))
                        galvo_volt_offset(1) = x_gscanner.position2Volts(d_galvo_deg(1))-x_gscanner.position2Volts(0);
                        galvo_volt_offset(2) = y_gscanner.position2Volts(d_galvo_deg(2))-y_gscanner.position2Volts(0);
                        moveGalvos = true;
                    end
                end
            end
            
            function [moveFastZ,fastZ_volt_offset] = getFastZVoltCorrection()
                moveFastZ = 0;
                fastZ_volt_offset = 0;
                
                useFastZ = dr(3)~=0 && strcmpi(obj.correctionDeviceZ,'fastz');
                if correctionZPossible && useFastZ && (isFastZ || obj.hSI.hFastZ.enableFieldCurveCorr)
                    hFastZ = ss.fastz;
                    dz = newMotionCorrectionVector(3);
                    
                    %%% coerce fastZ to allowed actuator voltage range
                    aoz_max_ref = hFastZ.volts2RefPosition(obj.performanceCache.ao_Z_max_volts);
                    z_lims_ref = hFastZ.volts2RefPosition(hFastZ.position2Volts(hFastZ.travelRange));
                    
                    aoz_max_ref = sort(aoz_max_ref(:)');
                    z_lims_ref = sort(z_lims_ref(:)');
                    allowedCorrectionRange = z_lims_ref - aoz_max_ref;
                    
                    dz = max(min(dz,allowedCorrectionRange(2)),allowedCorrectionRange(1)); % coerce correction range
                    newMotionCorrectionVector(3) = dz;
                    dr(3) = newMotionCorrectionVector(3)-obj.motionCorrectionVector(3);
                    %%% end coerce
                    
                    if ~isequal(newMotionCorrectionVector(3),obj.motionCorrectionVector(3))
                        fastZ_volt_offset = hFastZ.refPosition2Volts(dz)-hFastZ.refPosition2Volts(0);
                        moveFastZ = true;
                    end                        
                end
            end
        end
        
        function [correctionXYPossible,correctionZPossible] = correctionPossible(obj)
            [lateralDevs,axialDevs] = obj.getAvailableMotionCorrectionDevices();
            correctionXYPossible = ~isempty(lateralDevs) && any(strcmpi(obj.correctionDeviceXY,lateralDevs));
            correctionZPossible  = ~isempty(axialDevs)   && any(strcmpi(obj.correctionDeviceZ,axialDevs));
        end
        
        function checkCorrectionEnableAxes(obj)
            if ~obj.mdlInitialized
                return % obj.correctionPossible will fail since hScan2D is not available yet
            end
            
            motionCorrectorValid = most.idioms.isValidObj(obj.hMotionCorrector);
            if ~motionCorrectorValid && (obj.correctionEnableXY || obj.correctionEnableZ)
                obj.correctionEnableXY = false;
                obj.correctionEnableZ  = false;
                most.idioms.warn('Motion correction cannot be enabled because no valid motion corrector is selected.');
                return
            end
            
            [correctionXYPossible,correctionZPossible] = obj.correctionPossible();
            
            if obj.correctionEnableXY && ~correctionXYPossible
                obj.correctionEnableXY = false;
                most.idioms.warn('Lateral motion correction cannot be enabled because the device selected for correction is not available.');
            end
            
            if obj.correctionEnableZ && ~correctionZPossible
                obj.correctionEnableZ = false;
                most.idioms.warn(...
                    sprintf( ['Axial motion correction cannot be enabled because the device selected for correction is not available.\n',...
                    'If using the Fast-Z actuatur, make sure to enable Fast-Z']));
            end
        end
        
        function [lateralDevs,axialDevs] = getAvailableMotionCorrectionDevices(obj)
            ss = obj.hSI.hScan2D.scannerset;
            
            isGG = isa(ss,'scanimage.mroi.scannerset.GalvoGalvo');
            isRGG = isa(ss,'scanimage.mroi.scannerset.ResonantGalvoGalvo');
            isMotorRefCalibrated = obj.hSI.hMotors.motorToRefTransformValid;
            xGalvoAvailable = isGG || (isRGG && ~isempty(ss.scanners{2}));
            yGalvoAvailable = isGG || (isRGG && ~isempty(ss.scanners{3}));
            
            isSlowZwithMotor = obj.hSI.hStackManager.isSlowZ && ~obj.hSI.hStackManager.slowStackWithFastZ;
            
            xMotorAvailable = isMotorRefCalibrated && obj.hSI.hMotors.motorDimMappingMtr(1)~=0 && ~isSlowZwithMotor;
            yMotorAvailable = isMotorRefCalibrated && obj.hSI.hMotors.motorDimMappingMtr(2)~=0 && ~isSlowZwithMotor;
            zMotorAvailable = obj.hSI.hMotors.motorDimMappingMtr(3)~=0 && ~isSlowZwithMotor;
            fastZAvailable  = ss.hasFastZ && obj.hSI.hStackManager.isFastZ;
            
            lateralDevs = {};
            if xGalvoAvailable && yGalvoAvailable; lateralDevs{end+1} = 'galvos'; end
            if xMotorAvailable && yMotorAvailable; lateralDevs{end+1} = 'motor';  end
            
            axialDevs = {};
            if fastZAvailable;   axialDevs{end+1} = 'fastz'; end
            if zMotorAvailable ; axialDevs{end+1} = 'motor'; end
        end
        
        function attachMotionEstimatorListeners(obj)
            most.idioms.safeDeleteObj(obj.hMotionEstimatorListeners);
            obj.hMotionEstimatorListeners = [];
            for idx = 1:length(obj.hMotionEstimators)
                hMotionEstimator = obj.hMotionEstimators(idx);
                obj.hMotionEstimatorListeners = [obj.hMotionEstimatorListeners addlistener(hMotionEstimator,'changed',@(src,evt)obj.notifyMotionEstimatorsChanged(src,evt))];
            end
        end
        
        function notifyMotionEstimatorsChanged(obj,src,evt)
            obj.notify('motionEstimatorsChanged');
        end
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (scanimage.interfaces.Component)
    methods(Hidden, Access = protected)
        function componentStart(obj)
            obj.hPerformancePlot.reset();

            obj.performanceCache = struct();
            obj.performanceCache.scannerset = obj.hSI.hScan2D.scannerset;
            [correctionXYPossible,correctionZPossible] = correctionPossible(obj);
            obj.performanceCache.correctionXYPossible  = correctionXYPossible;
            obj.performanceCache.correctionZPossible   = correctionZPossible;
            
            if obj.enable
                assert(strcmpi(obj.hSI.hRoiManager.scanType,'frame'),'Motion Correction does not support scan type ''%s''',obj.hSI.hRoiManager.scanType);
                if isprop(obj.hSI.hScan2D,'stripingEnable') && obj.hSI.hScan2D.stripingEnable
                    most.idioms.warn('Motion Correction cannot be enabled when striping display is used. Disabling striping display.');
                    obj.hSI.hScan2D.stripingEnable = false; % this is okay to do here since hScan2D.start occurs after hMotinManager.start and hScan2D.arm does not reference stripingEnable
                end
                
                obj.checkCorrectionEnableAxes();
                obj.resetmotionHistory();
                
                imagingRois = obj.hSI.hRoiManager.currentRoiGroup.rois;
                imagingRois = imagingRois([imagingRois.enable]);
                
                for idx = 1:length(obj.hMotionEstimators)
                    hMotionEstimator = obj.hMotionEstimators(idx);
                    if ~any(hMotionEstimator.roiUuiduint64==[imagingRois.uuiduint64])
                        % estimator is not imaged disable it
                        hMotionEstimator.enable = false;
                        most.idioms.warn('Motion Estimator for Roi %s is not imaged and was disabled.',hMotionEstimator.roiName);
                    end
                    
                    if hMotionEstimator.enable
                        assert(~hMotionEstimator.outOfDate,'Motion Estimator for ROI ''%s'' cannot be enabled because the ROI geometry changed.',hMotionEstimator.roiData.hRoi.name);
                    end
                    obj.hMotionEstimators(idx).start(); % start motion estimator anyway, it can be enabled during the acquisition
                end
                
                if ~isempty(obj.hMotionCorrector) && most.idioms.isValidObj(obj.hMotionCorrector)
                    obj.hMotionCorrector.start();
                end
                
                obj.openLogFile();
                
                obj.performanceCache = bufferScannerAOMinMax(obj.performanceCache);
            end
                        
            function s = bufferScannerAOMinMax(s)
                [ao_G_valid, ao_G] = getScannerAO('G');
                [ao_Z_valid, ao_Z] = getScannerAO('Z');
                
                if ao_G_valid
                    s.ao_GX_max_volts = [min(ao_G(:,1)) max(ao_G(:,1))];
                    s.ao_GY_max_volts = [min(ao_G(:,2)) max(ao_G(:,2))];
                end
                
                if ao_Z_valid
                    s.ao_Z_max_volts = [min(ao_Z(:)) max(ao_Z(:))];
                end
            end
            
            function [valid,ao] = getScannerAO(scanner)
                valid = false;
                ao = [];
                scannerAO = obj.hSI.hWaveformManager.scannerAO;
                if isfield(scannerAO,'ao_volts_beforeMotionCorrection') && ...
                   isfield(scannerAO.ao_volts_beforeMotionCorrection,scanner)
                    valid = true;
                    ao = scannerAO.ao_volts_beforeMotionCorrection.(scanner);
                elseif isfield(scannerAO,'ao_volts') && ...
                       isfield(scannerAO.ao_volts,scanner)
                    valid = true;
                    ao = scannerAO.ao_volts.(scanner);
                end
            end
        end
        
        function componentAbort(obj)
            obj.performanceCache = [];
            
            try
                if ~isempty(obj.hMotionCorrector) && most.idioms.isValidObj(obj.hMotionCorrector)
                    obj.hMotionCorrector.abort();
                end
            catch ME
                most.idioms.reportError(ME);
            end
            
            for idx = 1:length(obj.hMotionEstimators)
                try
                    obj.hMotionEstimators(idx).abort();
                catch ME
                    most.idioms.reportError(ME);
                end
            end
            
            obj.flushResultQueue();
            obj.closeLogFile();
            if obj.resetCorrectionAfterAcq
                moveAxes = false;
                obj.resetMotionCorrection(moveAxes);
            end
        end
    end
end

%% LOCAL FUNCTIONS
function s = ziniInitPropAttributes()
    s.enable = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.motionHistoryLength = struct('Classes','numeric','Attributes',{{'scalar','positive','integer','>=',2}});
    s.correctionEnableXY = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.correctionEnableZ = struct('Classes','binaryflex','Attributes',{{'scalar'}});
    s.correctionBoundsXY = struct('Classes','numeric','Attributes',{{'nonnan','vector','numel',2}});
    s.correctionBoundsZ = struct('Classes','numeric','Attributes',{{'nonnan','vector','numel',2}});
    s.resetCorrectionAfterAcq = struct('Classes','binaryflex','Attributes',{{'scalar'}});
end

function classname = checkEstimatorSystemRequirements(classname)
    superClass = 'scanimage.interfaces.IMotionEstimator';
    assert(most.idioms.isa(classname,'scanimage.interfaces.IMotionEstimator'),'''%s'' is not a valid %s',classname,superClass);
    if isobject(classname)
        mc = metaclass(classname);
        classname = mc.Name;
    end
    
    % call static function checkSystemRequirements without instantiating
    % class
    ceckSystemRequirementsFun = str2func([classname '.checkSystemRequirements']);
    ceckSystemRequirementsFun();
end

function idxs = matchMotionEstimators(motionEstimators,id)
    if isa(id,'scanimage.interfaces.IMotionEstimator')
        id = id.uuiduint64;
        [~,idxs] = ismember(id,[motionEstimators.uuiduint64]);
        
    elseif isa(id,'scanimage.mroi.RoiData')
        uuiduint64 = id.hRoi.uuiduint64;
        [~,idxs] = ismember(uuiduint64,[motionEstimators.roiUuiduint64]);
        
    else
        % use id as index into motionEstimators
        if ~isempty(id)
            validateattributes(id,{'numeric'},{'vector','integer','positive','<=',numel(motionEstimators)});
        end
        idxs = id;
    end
end

%--------------------------------------------------------------------------%
% MotionManager.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
