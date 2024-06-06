classdef RoiGroup < scanimage.mroi.RoiTree    
    %% Properties    
    properties(SetAccess = private)
        rois = scanimage.mroi.Roi.empty(1,0);
    end
    
    properties(SetAccess = private,Dependent)
        activeRois;   % subset of rois, where roi.enable  == true
        displayRois;  % subset of rois, where roi.display == true
        zs;           % array containing Z's of Rois in RoiGroup
    end
    
    %% Private properties
    properties (Hidden, SetAccess = private)
        roiStatusIds;
        roiUuiduint64s;
        roiUuiduint64sSorted;
        roiUuiduint64sSortIndx;
    end
    
    properties(Access = private)       
        roisListenerMap;
    end
    
    %% Lifecycle
    methods
        function obj=RoiGroup(nm)
            %% Makes an empty RoiGroup
            obj = obj@scanimage.mroi.RoiTree();
            
            obj.roisListenerMap = containers.Map('KeyType',class(obj.uuiduint64),'ValueType','any');
            obj.roiStatusIds = cast([],'like',obj.statusId);
            obj.roiUuiduint64s = cast([],'like',obj.uuiduint64);
            if nargin > 0 && ~isempty(nm)
                obj.name = nm;
            end
        end
        
        function delete(obj)
            obj.roisListenerMap; % Matlab 2016a workaround to prevent obj.scanFieldsListenerMap from becoming invalid
            cellfun(@(lh)delete(lh),obj.roisListenerMap.values); % delete all roi listener handles;
        end
        
        function s=saveobj(obj)
            s = saveobj@scanimage.mroi.RoiTree(obj);
            s.rois = arrayfun(@(r) saveobj(r),obj.rois);
        end
        
        function copyobj(obj,other)
            copyobj@scanimage.mroi.RoiTree(obj,other);
            obj.clear();
            arrayfun(@(roi)obj.add(roi),other.rois,'UniformOutput',false);
        end
    end
    
    methods(Access = protected)
        % Override copyElement method:
        function cpObj = copyElement(obj)
            %cpObj = copyElement@matlab.mixin.Copyable(obj);
            cpObj = scanimage.mroi.RoiGroup();
            copyElement@scanimage.mroi.RoiTree(obj,cpObj);
            arrayfun(@(roi)cpObj.add(roi.copy()),obj.rois,'UniformOutput',false);
        end
    end
    
    %% Public methods for AO generation
    methods        
        % public
        function [ao_volts,samplesPerTrigger,sliceScanTime,path_FOV] = scanStackAO(obj,scannerset,zPowerReference,zs,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ)
            if nargin < 7 || isempty(zActuator)
                zActuator = 'fast';
            end
            if nargin < 8 || isempty(sliceScanTime)
                sliceScanTime = [];
            end
            if nargin < 9 || isempty(tuneZ)
                tuneZ = true;
            end
            
            [path_FOV,samplesPerTrigger,sliceScanTime] = obj.scanStackFOV(scannerset,zPowerReference,zs,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ);
            ao_volts = arrayfun(@(fov)scannerset.pathFovToAo(fov),path_FOV);
        end
        
        % private
        function [path_FOV,samplesPerTrigger,sliceScanTime] = scanStackFOV(obj,scannerset,zPowerReference,zs,zWaveform,flybackFrames,zActuator,sliceScanTime,tuneZ,maxPtsPerSf,applyConstraints)
            if nargin < 7 || isempty(zActuator)
                zActuator = 'fast';
            end
            if nargin < 8
                sliceScanTime = [];
            end
            if nargin < 9
                tuneZ = true;
            end
            if nargin < 10 || isempty(maxPtsPerSf)
                maxPtsPerSf = inf;
            end
            if nargin < 11 || isempty(applyConstraints)
                applyConstraints = true;
            end
            
            if applyConstraints
                scannerset.satisfyConstraintsRoiGroup(obj);
            end
            
            if isempty(sliceScanTime)
                for idx = numel(zs) : -1 : 1
                    scanTimesPerSlice(idx) = obj.sliceTime(scannerset,zs(idx));
                end
                sliceScanTime = max(scanTimesPerSlice);
            end
            
            if numel(zs) > 1 && strcmp(zWaveform, 'sawtooth')
                dz = (zs(end)-zs(1))/(numel(zs)-1);
                dzdt = dz/sliceScanTime;
            else
                dzdt = 0;
            end
            
            flybackTime = scannerset.frameFlybackTime;
            frameTime = sliceScanTime - flybackTime;
            
            for idx = numel(zs) : -1 : 1
                [outputData{idx}, slcEmpty(idx)] = obj.scanSliceFOV(scannerset,zPowerReference,zs(idx),dzdt,zActuator,frameTime,flybackTime,zWaveform,maxPtsPerSf);
            end
            
            outputData(numel(zs)+1:numel(zs)+flybackFrames) = obj.zFlybackFrames(scannerset,flybackFrames,frameTime,flybackTime,zWaveform);

            samplesPerTrigger = scannerset.samplesPerTriggerForAO(outputData);
            
            if strcmp(zWaveform, 'slow')
                assert(~any(slcEmpty),'Some slices did not contain any ROIs to scan.');
                path_FOV = cellfun(@(x)scannerset.interpolateTransits(x,tuneZ,zWaveform),outputData);
            else
                dataPoints = most.util.vertcatfields([outputData{:}]);
                path_FOV = scannerset.interpolateTransits(dataPoints,tuneZ,zWaveform);
            end
        end

        % private
        % (used by scanStackFOV and scanStackAO)
        function [path_FOV, slcEmpty] = scanSliceFOV(obj,scannerset,zPowerReference,z,dzdt,zActuator,frameTime,flybackTime,zWaveformType,maxPtsPerSf)
            %% ao_volts = scan(obj,scannerset,z,dzdt,frameTime,flybackTime)
            %
            %  Generates the full ao for scanning plane z using the 
            %  specified scannerset
              
            if nargin < 10 || isempty(maxPtsPerSf)
                maxPtsPerSf = inf;
            end
            
            % We only need to call this dependent property once within this method
            activeRois_ = obj.activeRois;
            mask = scanimage.mroi.util.fastRoiHitZ(activeRois_,z);
            scanRois = activeRois_(mask);
            slcEmpty = true;
            paths = {};
            tfStim = false;
            
            if numel(scanRois) > 0
                allf = [scanRois(:).scanfields];
                tfStim = isa(allf(1), 'scanimage.mroi.scanfield.fields.StimulusField');
                if tfStim
                    sfs = arrayfun(@(r)r.scanfields(1),scanRois,'UniformOutput',false);
                else
                    sfs = arrayfun(@(r) r.get(z),scanRois,'UniformOutput',false);
                end
                slcEmpty = isempty(sfs);
                
                actz = z;
                
                for i = 1:numel(scanRois)
                    [paths{end+1}, dt] = scanRois(i).scanPathFOV(scannerset,zPowerReference,z,actz,dzdt,zActuator,tfStim,maxPtsPerSf);
                    
                    if ~tfStim
                        if i == numel(scanRois)
                            %end of frame transit
                            [paths{end+1}, ~] = scannerset.transitNaN(sfs{i},NaN);
                        else
                            %transit to next roi
                            [paths{end+1}, dtt] = scannerset.transitNaN(sfs{i},sfs{i+1});
                            
                            %update starting actual z position for next scanfield
                            actz = actz + dzdt * (dt + dtt);
                        end
                    end
                end
            else
                [paths{end+1}, ~] = scannerset.transitNaN(NaN,NaN);
            end

            path_FOV = most.util.vertcatfields([paths{:}]);
            
            % Padding: 
            if ~tfStim && (frameTime + flybackTime) > 0
                path_FOV = scannerset.padFrameAO(path_FOV,frameTime,flybackTime,zWaveformType);
            end
        end
        
        function data = zFlybackFrames(~,ss,flybackFrames,frameTime,flybackTime,zWaveformType)
            data = [];
            for i = flybackFrames:-1:1
                path_FOV = ss.zFlybackFrame(frameTime);
                data{i} = ss.padFrameAO(path_FOV,frameTime,flybackTime,zWaveformType);
            end
        end
        
        % public (but should look at why)
        function scanTime = scanTimes(obj,scannerset,z)
            % Returns array of seconds with scanTime for each scanfield
            % at a particular z
            scanTime=0;
            if ~isa(scannerset,'scanimage.mroi.scannerset.ScannerSet')
                return;                
            end
                
            scanfields  = obj.scanFieldsAtZ(z);
            scanTime    = cellfun(@(scanfield)scannerset.scanTime(scanfield),scanfields);
        end

        % public (but should look at why)
        function [seconds,flybackseconds] = transitTimes(obj,scannerset,z)
            % Returns array of seconds with transitionTime for each scanfield
            % at a particular z
            % seconds includes the transition from park to the first scanfield of the RoiGroup
            % flybackseconds is the flyback transition from last scanfield to park

            seconds=0;
            flybackseconds=0;            
            if ~isa(scannerset,'scanimage.mroi.scannerset.ScannerSet')
                return;                
            end
            
            scanfields = obj.scanFieldsAtZ(z);
            if isempty(scanfields)
                seconds = [];
                flybackseconds = 0;
            else
                scanfields = [{NaN} scanfields {NaN}]; % pre- and ap- pend "park" to the scan field sequence
                
                tp = scanimage.mroi.util.chain(scanfields); % form pair of scanfields for transition
                seconds = cellfun(@(pair) scannerset.transitTime(pair{1},pair{2}),tp);
                
                flybackseconds = seconds(end); % save flybackseconds separately
                seconds(end) = [];
            end
        end
        
        % public
        function seconds = sliceTime(obj,scannerset,z)
            %% Returns the minimum time [seconds] to scan plane z (does not include any padding)
            scantimes = obj.scanTimes(scannerset,z);
            [transitTimes,flybackTime] = obj.transitTimes(scannerset,z);
            seconds = sum(scantimes) + sum(transitTimes) + flybackTime;
        end
        
        function seconds = pathTime(obj,scannerset)
            r = obj.activeRois;
            if isempty(r)
                seconds = nan;
            else
                allf = [r(:).scanfields];
                seconds = sum(arrayfun(@(sf)scannerset.scanTime(sf),allf));
            end
        end

        % public
        function [scanfields,zrois] = scanFieldsAtZ(obj,z,activeSfsOnly)
            % Queries the roigroup for intersection with the specified z plane
            % Returns
            %   scanfields: a cell array of scanimage.mroi.scanfield.ScanField objects
            %   zrois     : a cell array of the corresponding hit rois
            if nargin < 3 || isempty(activeSfsOnly)
                activeSfsOnly = true;
            end
            
            if activeSfsOnly
                rois_ = obj.activeRois;
            else
                rois_ = obj.rois;
            end
            
            %% Returns cell array of scanfields at a particular z
            mask = arrayfun(@(roi) roi.hit(z),rois_);
            zrois = rois_(mask);
            scanfields = arrayfun(@(roi)roi.get(z),zrois,'UniformOutput',false);
            maskEmptyFields = cellfun(@(scanfield)isempty(scanfield),scanfields);
            scanfields(maskEmptyFields) = []; % remove empty entries
            zrois(maskEmptyFields) = [];
            zrois = num2cell(zrois);
        end

    end

    %% Public methods for operating on the roi list -- mostly for UI
    methods
        function clear(obj)
            v = obj.roisListenerMap.values;
            delete([v{:}]);                 % delete all roi listener handles
            obj.roisListenerMap.remove(obj.roisListenerMap.keys); % clear roisListenerMap
            obj.roiStatusIds = cast([],'like',obj.statusId);
            obj.roiUuiduint64s = cast([],'like',obj.uuiduint64);
            obj.rois = scanimage.mroi.Roi.empty(1,0);
        end
        
        function roi = getRoiById(obj,id)
            i = obj.idToIndex(id,true);
            roi = obj.rois(i);
        end

        function idxs = idToIndex(obj,ids,throwError)
            % returns the index of the array obj.rois for roi ids
            % ids: cellstr of uuids OR vector of uuidint64 OR numeric vector
            % throwError: false (standard): does not throw error
            %             true: issues error if one or more rois with given id are
            %                           not found
            % returns idxs: indices of rois in obj.rois; for unknown rois 0
            %               is returned
            
            if nargin < 3 || isempty(throwError)
                throwError = false;
            end
            
            
            if isa(ids,class(obj.uuiduint64))
                % assume id is a uuiduint64
                idxs = ismembc2(ids,obj.roiUuiduint64sSorted); % performance optimization
                idxs(idxs>0) = obj.roiUuiduint64sSortIndx(idxs(idxs>0)); % resort
            elseif isnumeric(ids)
                idxs = ids;
                idxs(idxs<1) = 0;
                idxs(idxs>length(obj.rois)) = 0;
            elseif ischar(ids) || iscellstr(ids)
                % this is relatively slow. better: use uuiduint64
                [~,idxs] = ismember(ids,{obj.rois.uuid});
            else
                error('Unknown id format: %s',class(ids));
            end
            
            if throwError && any(idxs==0)
                if isa(ids,'char')
                    zeroIds = ['''' ids ''''];
                elseif iscellstr(ids)
                    zeroIds = strjoin(ids(idxs==0));
                else
                    zeroIds = mat2str(ids(idxs==0));
                end
                
                error('SI:mroi:StimSeriesIndexNotFound Could not find rois with id(s) %s',zeroIds);
            end
        end
        
        function obj = add(obj,roi)
            if(~isa(roi,'scanimage.mroi.Roi'))
                error('MROI:TypeError','Expected an object of type scanimage.mroi.Roi');
            end
            
            obj.roiStatusIds(end+1) = roi.statusId;
            obj.roiUuiduint64s(end+1) = roi.uuiduint64;
            obj.rois = [obj.rois roi];
            
            % add listeners to roi
            if ~obj.roisListenerMap.isKey(roi.uuiduint64)
                lh = addlistener(roi,'changed',@obj.roiChanged);
                obj.roisListenerMap(roi.uuiduint64) = lh;
            end
        end
        
        function mc=scanfieldMetaclass(obj)
            if(isempty(obj.rois) || isempty(obj.rois(1).scanfields)),
                mc=meta.class.fromName(''); % empty class if no scanfields/not determined
            else
                mc=metaclass(obj.rois(1).scanfields(1));
            end
        end

        function obj=filterByScanfield(obj,f)
            % Disables some scanfields according to f.
            %
            % f must be a function mapping a scanfield to a boolean
            %   if f returns false, then the entire roi will be disabled.            
            for r=obj.rois
                tf=arrayfun(f,r.scanfields);
                if any(~tf)
                    r.enable=false;
                end
            end

        end
        
        function newIdxs = insertAfterId(obj,id,rois)
            i=obj.idToIndex(id,true);
            if nargin < 3 || isempty(rois)
                rois=scanimage.mroi.Roi();
            else
                assert(isa(rois,'scanimage.mroi.Roi'),'Roi must be of type scanimage.mroi.Roi');
            end
            rois = rois(:)'; % assert row vector
            numRois = length(rois);
            newIdxs = (1:numRois) + i;
            
            % add listeners to rois
            for roi = rois
                if ~obj.roisListenerMap.isKey(roi.uuiduint64)
                    lh = addlistener(roi,'changed',@obj.roiChanged);
                    obj.roisListenerMap(roi.uuiduint64) = lh;
                end
            end
            
            obj.roiStatusIds = [obj.roiStatusIds(1:i) rois.statusId obj.roiStatusIds(i+1:end)];
            obj.roiUuiduint64s = [obj.roiUuiduint64s(1:i) rois.uuiduint64 obj.roiUuiduint64s(i+1:end)];
            obj.rois=[obj.rois(1:i) rois obj.rois(i+1:end)];
        end

        function rois_ = removeById(obj,id)
            i=obj.idToIndex(id,true);
            rois_ = obj.rois(i);
            
            for roi = rois_
                if ~any(ismember(roi.uuiduint64,[obj.rois.uuiduint64]))
                    lh = obj.roisListenerMap(roi.uuiduint64);
                    delete(lh);
                    obj.roisListenerMap.remove(roi.uuiduint64);
                end
            end
            
            obj.roiUuiduint64s(i) = [];
            obj.roiStatusIds(i) = [];
            obj.rois(i) = [];
        end

        function newIdx = moveById(obj,id,step)
            % changed index of roi from i to i+step
            i=obj.idToIndex(id,true);
            
            if step == 0
                newIdx = i;
                return
            elseif i+step < 1
                idxs = [i, 1:i-1, i+1:length(obj.rois)];
                newIdx = 1;
            elseif i+step > length(obj.rois)
                idxs = [1:i-1, i+1:length(obj.rois), i];
                newIdx = length(obj.rois);
            else
                idxs = 1:length(obj.rois);
                idxs([i,i+step]) = flip(idxs([i,i+step]));
                newIdx = i+step;
            end
            
            obj.roiStatusIds=obj.roiStatusIds(idxs);
            obj.roiUuiduint64s=obj.roiUuiduint64s(idxs);
            obj.rois=obj.rois(idxs);
        end
        
        function newIdx = moveToFrontById(obj,id)
            newIdx = obj.moveById(id,-inf);
        end

        function newIdx = moveToBackById(obj,id)
            newIdx = obj.moveById(id,inf);
        end
    end % end public methods
    
    methods (Hidden)
        function roiChanged(obj,src,evt)
            idx = obj.idToIndex(src.uuiduint64);
            obj.roiStatusIds(idx) = src.statusId;
            obj.fireChangedEvent();
        end
    end
    
    %% Property access methods
    methods
        function val = get.activeRois(obj)
            if ~isempty(obj.rois)
                val = obj.rois([obj.rois.enable]);
            else
                val = [];
            end
        end
        
        function val = get.displayRois(obj)
            if ~isempty(obj.rois)
                val = obj.rois([obj.rois.enable] & [obj.rois.display]);
            else
                val = [];
            end
        end
        
        function val = get.zs(obj)
            zs = [];
            for roi = obj.rois();
                zs = horzcat(zs,roi.zs(:)'); %#ok<AGROW>
            end
            val = sort(unique(zs));
        end
        
        function set.rois(obj,val)
            if isempty(val)
                val = scanimage.mroi.Roi.empty(1,0);
            end
            obj.rois = val;
            obj.fireChangedEvent();
        end
        
        function set.roiUuiduint64s(obj,val)
            if isempty(val)
                val = cast([],'like',obj.uuiduint64);
            end
            
            obj.roiUuiduint64s = val;
            [obj.roiUuiduint64sSorted,obj.roiUuiduint64sSortIndx] = sort(val);
        end
        
        function saveToFile(obj,f)
            %roigroup = obj;
            %save(f,'roigroup','-mat');
            most.json.savejson('',obj,f);
        end
    end
    
    %% Static methods
    methods(Static)
        function obj=loadobj(s)
            obj=scanimage.mroi.RoiGroup();
            loadobj@scanimage.mroi.RoiTree(obj,s);
            if iscell(s.rois)
                s.rois = [s.rois{:}];
            end
            arrayfun(@(r) obj.add(scanimage.mroi.Roi.loadobj(r)),s.rois,'UniformOutput',false);
        end
        
        function obj=loadFromFile(f)
            try
                obj = most.json.loadjsonobj(f);
            catch ME
                % support for old binary roigroup file format
                try
                    data = load(f,'-mat','roigroup');
                    obj = data.roigroup;
                catch
                    rethrow(ME);
                end
            end
        end
    end
end


%--------------------------------------------------------------------------%
% RoiGroup.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
