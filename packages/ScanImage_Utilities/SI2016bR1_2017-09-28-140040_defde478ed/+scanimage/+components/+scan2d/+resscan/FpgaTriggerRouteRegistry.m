classdef FpgaTriggerRouteRegistry < handle
    % Helper class to manage FPGA trigger routes
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
        hFpga;
    end
    
    %% Lifecycle
    methods
        function obj = FpgaTriggerRouteRegistry(hFpga)
            assert(isa(hFpga,'dabs.ni.rio.NiFPGA'));
            obj.hFpga = hFpga;
        end
        
        function delete(obj)
            if most.idioms.isValidObj(obj.hFpga)
                obj.clearRoutes();
            end
        end
    end
    
    %% User methods
    methods
        function connectTerms(obj,src,dest)
            if isempty(dest)
                obj.disconnectTerms(src);
                return
            end
            
            if ~strcmpi(src,dest)
                obj.physicallyConnectTerms(src,dest);
                obj.addRoute(src,dest);
            end
        end
        
        function disconnectTerms(obj,src)
            obj.physicallyDisconnectTerms(src);
            obj.removeRoute(src);
        end
        
        function reinitRoutes(obj)
            routes_ = obj.routes;
            for idx = 1:size(routes_,1)
                try
                    src = routes_{idx,1};
                    dest = routes_{idx,2};
                    obj.physicallyConnectTerms(src,dest);
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
                    obj.physicallyDisconnectTerms(src);
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
        
        function clearRoutes(obj)
            for idx = 1:size(obj.routes,1)
                src = obj.routes{idx,1};
                dest = obj.routes{idx,2};
                obj.physicallyDisconnectTerms(src);
            end
            
            obj.routes = cell.empty(0,2);
        end
    end
    
    %% Private methods
    methods (Access = private)        
        function idx = findRouteIdx(obj,src)
            if isempty(obj.routes)
                idx = 0;
                return
            end
            
            src = lower(src);
            routes_ = lower(obj.routes);            
            
            [~,idx] = ismember(src,routes_(:,1));
        end
        
        function addRoute(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.removeRoute(src); % just to double check
                obj.routes(end+1,:) = {src,dest};
            end
        end
        
        function removeRoute(obj,src)
            idx = obj.findRouteIdx(src);
            if idx~=0
                obj.routes(idx,:) = [];
            end
        end
        
        function physicallyConnectTerms(obj,src,dest)
            if ~strcmpi(src,dest)
                obj.hFpga.(src) = dest;
                obj.fprintf('Connecting terminals: %s -> %s\n',src,dest);
            end
        end
        
        function physicallyDisconnectTerms(obj,src)
            obj.hFpga.(src) = '';
            obj.fprintf('Disonnecting terminal: %s\n',src);
        end
        
        function fprintf(obj,varargin)
            if obj.verbose
                fprintf(varargin{:});
            end
        end
    end
end
    


%--------------------------------------------------------------------------%
% FpgaTriggerRouteRegistry.m                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
