classdef AppConfiguration < handle
    
    properties (Abstract,Constant)
        configurationSchema;
        cfgExtension;
    end
    
    properties (Hidden)
        appConfigFile;
        appConfigFileCachePath;
        appCfgPropSet;
        cfgLoading = false;
    end
    
    
    methods
        function cfgLoadingComplete(~)
            % overide if desired
        end
        
        function appCfgPropSet = saveAppConfiguration(obj)
            appCfgPropSet = obj.buildAppPropSet(obj.configurationSchema);
            
            if ~nargout
                if isempty(obj.appConfigFile)
                    [filename,pathname] = uiputfile(obj.cfgExtension,'Choose Location to Save Configuration File...',pwd);
                    assert(ischar(filename), 'No configuration file selected.');
                    obj.appConfigFile = fullfile(pathname,filename);
                end
                
                most.json.savejson([],appCfgPropSet,obj.appConfigFile);
            end
        end
        
        function appCfgPropSet = loadAppConfiguration(obj)
            if isempty(obj.appConfigFile) || ~exist(obj.appConfigFile,'file')
                % look for text file that contains config location
                if ~isempty(obj.appConfigFileCachePath)
                    f = fopen(obj.appConfigFileCachePath, 'r');
                    if f > 0
                        obj.appConfigFile = fgetl(f);
                        fclose(f);
                    end
                end
                
                if isempty(obj.appConfigFile) || ~exist(obj.appConfigFile,'file')
                    % location cache not found. prompt
                    [filename,pathname] = uigetfile(obj.cfgExtension,'Select NorthernLights Configuration File...',pwd);
                    assert(ischar(filename), 'No configuration file selected.');
                    obj.appConfigFile = fullfile(pathname,filename);
                    
                    if ~isempty(obj.appConfigFileCachePath)
                        % save this for future launch
                        f = fopen(obj.appConfigFileCachePath,'w+');
                        if f > 0
                            fprintf(f,'%s',obj.appConfigFile);
                            fclose(f);
                        end
                    end
                end
            end
            
            appCfgPropSet = most.json.loadjson(obj.appConfigFile);
            
            if ~nargout
                obj.applyPropSet(appCfgPropSet,obj.configurationSchema);
            end
        end
        
        function applyPropSet(obj, propSet, schema)
            try
                obj.appCfgPropSet = propSet;
                obj.cfgLoading = true;
                obj.applyPropSetRC(propSet, schema, '');
                obj.cfgLoading = false;
                obj.cfgLoadingComplete();
            catch ME
                obj.cfgLoading = false;
                obj.cfgLoadingComplete();
                ME.rethrow();
            end
        end
        
        function applyPropSetRC(obj, propSet, schema, propSetHier)
            fields = fieldnames(schema);
            
            if nargin < 4 || isempty(propSetHier)
                propSetHier = '';
                propSetHierTxt = '';
            else
                propSetHierTxt = sprintf('''%s'' section of ', propSetHier);
            end
            
            for i = 1:numel(fields);
                f = fields{i};
                item = schema.(f);
                
                if iscell(item)
                    % this is a property to be read
                    if isempty(propSet)
                        % function was called without a prop set. applying
                        % default value from the schema
                        try
                            obj.(item{2}) = item{3};
                        catch ME
                            most.idioms.warn('Error applying default value to %s (%s). Message:\n  %s', item{1},item{2},ME.message);
                        end
                    elseif isfield(propSet,f)
                        try
                            obj.(item{2}) = propSet.(f);
                        catch ME
                            most.idioms.warn('Error applying %s (%s) from configuration. Message:\n  %s', item{1},item{2},ME.message);
                        end
                    else
                        try
                            obj.(item{2}) = item{3};
                            most.idioms.warn('%s (%s) field missing from %sconfiguration. Using default value.',item{1},item{2},propSetHierTxt);
                        catch ME
                            most.idioms.warn('%s (%s) field missing from %sconfiguration. Error applying default value. Message:\n  %s',item{1},item{2},propSetHierTxt,ME.message);
                        end
                    end
                elseif isstruct(item)
                    % this is a sub prop set
                    if isempty(propSetHier)
                        subnm = f;
                    else
                        subnm = [propSetHier '.' f];
                    end
                    
                    if isempty(propSet)
                        % function was called without a prop set. applying
                        % default value from the schema
                        ps = [];
                    elseif isfield(propSet,f)
                        ps = propSet.(f);
                    else
                        most.idioms.warn('%s (''%s'' section) missing from configuration. Using default values.',item.propSetName,subnm);
                        ps = [];
                    end
                    obj.applyPropSetRC(ps, item, subnm);
                end
            end
        end
        
        function propSet = buildAppPropSet(obj, schema)
            propSet = buildPropSetInt(obj, schema, false);
        end
    end
    
    methods (Static)
        function saveDefaultAppConfigFile(className,path)
            schema = eval([className '.configurationSchema']);
            ext = eval([className '.cfgExtension']);
            ps = buildPropSetInt([], schema, true);
            
            if nargin < 2 || isempty(path)
                [filename,pathname] = uiputfile(ext,'Choose Location to Save Configuration File...',pwd);
                assert(ischar(filename), 'No configuration file selected.');
                path = fullfile(pathname,filename);
            end
            
            most.json.savejson([],ps,path);
        end
    end
end
        
function propSet = buildPropSetInt(obj, schema, defaults)
    if nargin < 3
        defaults = false;
    end

    fields = fieldnames(schema);

    for i = 1:numel(fields);
        f = fields{i};
        item = schema.(f);

        if iscell(item)
            % this is a property
            if defaults
                v = item{3};
            else
                v = obj.(item{2});
            end
            propSet.(f) = v;
        elseif isstruct(item)
            % this is a sub prop set
            propSet.(f) = buildPropSetInt(obj, item, defaults);
        end
    end
end


%--------------------------------------------------------------------------%
% AppConfiguration.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
