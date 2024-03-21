classdef ParallelPool < handle
    properties (SetAccess = private,Hidden)
        keepPoolAliveTimer;
        pool;
        JavaQueueObj;
    end
    
    properties
        maxQueueSize = 20;
    end
    
    properties (Dependent)
        isConnected
    end
    
    %% Lifecycle
    methods
        function obj = ParallelPool()
            obj.checkSystemRequirements();
            
            [obj,newInstance] = Singleton(obj); % get singleton obj
            
            if newInstance
                obj.initPool();
            end
            
            obj.checkPoolConnected();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.keepPoolAliveTimer);
            most.idioms.safeDeleteObj(obj.pool);
        end
    end
    
    %% User Methods
    methods
        function numQueuedFutures = getQueueSize(obj)
            obj.checkPoolConnected();
            
            %%% This is the proper way to do it, but it's slow
            %numQueuedFutures = numel(obj.pool.FevalQueue.QueuedFutures);
            
            %%%% Hack: Copied from parallel.FevalQueue
            % Get a list of outstanding tasks - we are handed new
            % duplicates.
            javaTaskList = obj.JavaQueueObj.getOutstandingTasks();
            disposer     = onCleanup(@() iDisposeList(javaTaskList));

            numTasks = double(javaTaskList.size());
            numQueuedFutures = numTasks;
            %%%%
        end
        
        function varargout = parfeval(obj,varargin)
            obj.checkPoolConnected();
            varargout = cell(1,nargout);
            varargout{:} =  parfeval(obj.pool,varargin{:});
        end
        
        function checkPoolConnected(obj)
            assert(obj.isConnected,'Pool got disconnected.');
        end
    end
    
    %% Internal Methods
    methods (Access = private)
        function initPool(obj)
            most.idioms.safeDeleteObj(obj.keepPoolAliveTimer);
            
            obj.pool = gcp('nocreate'); % get handle to current pool
            
            if isempty(obj.pool)
                cpuinfo = most.idioms.cpuinfo;
                numprocessors = cpuinfo.NumProcessors;
                numWorkers = max(1,numprocessors-2); % leave 2 processors for ScanImage and OS
                
                waitbartext = sprintf('Starting pool with %d workers.\nThis can take some time...',numWorkers);
                hWb = waitbar(0.1,waitbartext,'WindowStyle','modal');
                try
                    obj.pool = parpool('local',numWorkers);
                catch ME
                    delete(hWb);
                    rethrow(ME);
                end
                delete(hWb);
            end
            
            %%% Hack: get private property FevalQueue
            warnStruct = warning('off','MATLAB:structOnObject');
            fevalQueueStruct = struct(obj.pool.FevalQueue);
            obj.JavaQueueObj = fevalQueueStruct.JavaQueueObj;
            warning(warnStruct);
            %%%
            
            obj.initKeepPoolAliveTimer();
        end
        
        function initKeepPoolAliveTimer(obj)
            most.idioms.safeDeleteObj(obj.keepPoolAliveTimer);

            obj.keepPoolAliveTimer = timer('Name','Parallel Pool keep alive timer');
            obj.keepPoolAliveTimer.Period = obj.pool.IdleTimeout*60 / 4;
            obj.keepPoolAliveTimer.ExecutionMode = 'fixedRate';
            obj.keepPoolAliveTimer.StartFcn = @obj.keepPoolAliveTimerFcn;
            obj.keepPoolAliveTimer.TimerFcn = @obj.keepPoolAliveTimerFcn;
            
            start(obj.keepPoolAliveTimer);
        end
        
        function keepPoolAliveTimerFcn(obj,varargin)
            poolTimeout_s = obj.pool.IdleTimeout*60;
            if most.idioms.parPoolTimeToIdleTimeout(obj.pool) < poolTimeout_s/2
                parfeval(obj.pool,@()1,1); % send dummy job to pool to keep alive
            end
        end
    end
    
    methods
        function set.maxQueueSize(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','real'});
            assert(isinf(val) || most.idioms.isIntegerValued(val),'Queue Size needs to be either INF or an integer value');
            obj.maxQueueSize = val;
        end
        
        function val = get.isConnected(obj)
            val = ~isempty(obj.pool) && isvalid(obj.pool) && obj.pool.Connected;
        end
    end
    
    methods (Static)
        function [tf,msg] = checkSystemRequirements()
            tf = most.util.parallelComputingToolboxAvailable();
            msg = [];
            
            if ~tf
                msg = sprintf('''%s'' requires the Matlab Parallel Computing Toolbox. This toolbox is not installed/licensed on this computer.',mfilename('class'));
            end
            
            if ~tf && nargout <= 0
                error(msg);
            end
        end
    end
end

%% Local functions
function [obj,newInstance] = Singleton(newObj)
    persistent localObj
    
    if isempty(localObj) || ~isvalid(localObj) || ~localObj.isConnected
        localObj = newObj;
        newInstance = true;
    else
        delete(newObj);
        newInstance = false;
    end
    
    obj = localObj;
end

%%% Copied from parallel.FevalQueue
% Dispose of a java array of wrappers
function iDisposeList(javaTaskList)
    for ii = 0:(double(javaTaskList.size())-1)
        try
            javaTaskList.get(ii).dispose();
        catch E %#ok<NASGU>
        end
    end
end

%--------------------------------------------------------------------------%
% ParallelPool.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
