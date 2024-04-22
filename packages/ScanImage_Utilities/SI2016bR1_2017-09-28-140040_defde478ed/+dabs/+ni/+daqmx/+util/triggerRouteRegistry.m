classdef triggerRouteRegistry < handle
    % Helper class to manage DAQmx trigger routes
    % This class is used to track routes that are connected via an objects
    % lifetime - on deletion of this object all registered routes are
    % disconnected
    properties
        verbose = false;
    end
    
    properties (SetAccess = private)
        routes = cell.empty(0,2);
    end
    
    properties (Access = private)
        daqSys;
    end
    
    %% Lifecycle
    methods
        function obj = triggerRouteRegistry()
            obj.daqSys = dabs.ni.daqmx.System();
        end
        
        function delete(obj)
            if most.idioms.isValidObj(obj.daqSys)
                obj.clearRoutes();
            end
        end
    end
    
    %% User methods
    methods
        function connectTerms(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.daqSys.connectTerms(src,dest);
                obj.addRoute(src,dest);
            end
        end
        
        function disconnectTerms(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.physicallyDisconnectTerms(src,dest);
                obj.removeRoute(src,dest);
            end
        end
        
        function reinitRoutes(obj)
            routes_ = obj.routes;
            for idx = 1:size(routes_,1)
                try
                    src = routes_{idx,1};
                    dest = routes_{idx,2};
                    obj.connectTerms(src,dest);
                catch ME
                    most.idioms.reportError(ME);
                end
            end            
        end
        
        function deinitRoutes(obj)
            routes_ = obj.routes;
            for idx = 1:size(routes_,1)
                try
                    src = routes_{idx,1};
                    dest = routes_{idx,2};
                    obj.physicallyDisconnectTerms(src,dest);
                catch ME
                    most.idioms.reportError(ME);
                end
            end            
        end
        
        function clearRoutes(obj)
            for idx = 1:size(obj.routes,1)
                src = obj.routes{idx,1};
                dest = obj.routes{idx,2};
                obj.physicallyDisconnectTerms(src,dest);
            end
            
            obj.routes = cell.empty(0,2);
        end
    end
    
    %% Private methods
    methods (Access = private)        
        function idx = findRouteIdx(obj,src,dest)
            if isempty(obj.routes)
                idx = 0;
                return
            end
            
            src = lower(src);
            dest = lower(dest);
            routes_ = lower(obj.routes);            
            
            [~,srcidxs] = ismember(src,routes_(:,1));
            if srcidxs > 0
                [~,destidxs] = ismember(dest,routes_(srcidxs,2));
            end
            
            if srcidxs < 1 || destidxs < 1
                idx = 0;
            else
                idx = srcidxs(destidxs);
            end
        end
        
        function addRoute(obj,src,dest)
            if ~strcmpi(src,dest)
                if obj.findRouteIdx(src,dest)==0
                    obj.routes(end+1,:) =  {src,dest};
                end
            end
        end
        
        function removeRoute(obj,src,dest)
            if ~strcmpi(src,dest)
                idx = obj.findRouteIdx(src,dest);
                if idx~=0
                    obj.routes(idx,:) =  [];
                end
            end
        end
        
        function physicallyConnectTerms(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.daqSys.connectTerms(src,dest);
                obj.fprintf('Connecting terminals: %s -> %s\n',src,dest);
            end
        end
        
        function physicallyDisconnectTerms(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.daqSys.disconnectTerms(src,dest);
                obj.fprintf('Disonnecting terminals: %s -> %s',src,dest);
                
                if strfind(dest,'PFI')
                    obj.daqSys.tristateOutputTerm(dest);
                    obj.fprintf(' and tristating terminal %s',dest);
                end
                obj.fprintf('\n');
            end
        end
        
        function fprintf(obj,varargin)
            if obj.verbose
                fprintf(varargin{:});
            end
        end
    end
end
    


%--------------------------------------------------------------------------%
% triggerRouteRegistry.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
