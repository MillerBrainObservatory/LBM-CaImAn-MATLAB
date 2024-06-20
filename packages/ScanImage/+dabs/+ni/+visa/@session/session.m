classdef session < handle
    %Implementation of NI VISA
    
    %% User properties
    properties (SetAccess = immutable)
        address = '';
    end
    
    %% Internal properties
    properties (Hidden, SetAccess = private)
        defaultRM = [];
        sessionId = [];
        
        asyncOpPending = false;
        asyncOpQueue = {};
        hAsyncOpTimer;
    end
    
    %% Lifecycle
    methods
        function obj = session(addr)
            assert(ischar(addr), 'Addess must be a string');
            obj.defaultRM = obj.getDefaultRM();
            assert(isa(obj.defaultRM, 'uint32'), 'Failed to connect to VISA resource manager. Status: %d', obj.defaultRM);
            
            try
                obj.sessionId = obj.open(addr,0,990);
                obj.address = addr;
            catch
                error('Failed to open VISA session for device ''%s''.', addr);
            end
            
            obj.hAsyncOpTimer = timer('Name','NI Visa Session Async Op Timer');
            obj.hAsyncOpTimer.ExecutionMode = 'singleShot';
            obj.hAsyncOpTimer.StartDelay = 2;
            obj.hAsyncOpTimer.TimerFcn = @(varargin)obj.opTimeout();
        end
        
        function delete(obj)
            obj.asyncOpQueue = {};
            t = tic;
            while obj.asyncOpPending
                pause(0.001);
                assert(toc(t) < 1, 'Timed out waiting for last VISA operation to complete.');
            end
            
            if most.idioms.isValidObj(obj.hAsyncOpTimer)
                stop(obj.hAsyncOpTimer);
                delete(obj.hAsyncOpTimer);
            end
            
            if ~isempty(obj.sessionId)
                obj.close();
            end
        end
    end
    
    %% User methods
    methods
        function answer = stdQuerry(obj,bytesToRead)
            if nargin < 2 || isempty(bytesToRead)
                bytesToRead = 500;
            end
            
            answer = obj.writeWithReply('*IDN?', bytesToRead);
        end
        
        function err = writeAsync(obj, buf, callback)
            % callback = @(writeStatus)
            
            if nargin < 3
                callback = [];
            end
            
            err = obj.asyncOp(buf, @cb, 0);
            
            function cb(readBuffer, writeStatus, readStatus)
                if isa(callback, 'function_handle')
                    assert(isempty(readBuffer) && (readStatus == -1337), 'Unexpected mex returns.');
                    callback(writeStatus);
                end
            end
        end
        
        function err = readAsync(obj, callback, bytesToRead)
            % callback = @(readBuffer, readStatus)
            
            assert(isa(callback, 'function_handle'), 'Expected a function handle for callback.');
            
            if nargin < 3 || isempty(bytesToRead);
                bytesToRead = 500;
            end
            
            err = obj.asyncOp('', @cb, bytesToRead);
            
            function cb(readBuffer, writeStatus, readStatus)
                assert(writeStatus == -1336, 'Unexpected mex returns.');
                callback(readBuffer, readStatus);
            end
        end
        
        function err = writeWithReplyAsync(obj, buf, callback, bytesToRead)
            % callback = @(readBuffer, writeStatus, readStatus)
            
            assert(isa(callback, 'function_handle'), 'Expected a function handle for callback.');
            
            if nargin < 4 || isempty(bytesToRead);
                bytesToRead = 500;
            end
            
            err = obj.asyncOp(buf, callback, bytesToRead);
        end
        
        function writeStatus = write(obj, buf, timeout)
            
            if nargin < 3 || isempty(timeout)
                timeout = 10;
            end
            
            done = false;
            err = obj.writeAsync(buf, @cb);
            
            t = tic;
            while ~done
                assert(toc(t) < timeout, 'Write timed out.');
                pause(0.001);
            end
            
            function cb(wStatus)
                writeStatus = wStatus;
                done = true;
            end
        end
        
        function [readBuffer, readStatus] = read(obj, bytesToRead, timeout)
            
            if nargin < 2 || isempty(bytesToRead);
                bytesToRead = 500;
            end
            
            if nargin < 3 || isempty(timeout)
                timeout = 10;
            end
            
            done = false;
            err = obj.readAsync(@cb, bytesToRead);
            
            t = tic;
            while ~done
                assert(toc(t) < timeout, 'Read timed out.');
                pause(0.001);
            end
            
            function cb(buf, rStatus)
                readBuffer = buf;
                readStatus = rStatus;
                done = true;
            end
        end
        
        function [readBuffer, writeStatus, readStatus] = writeWithReply(obj, buf, bytesToRead, timeout)
            
            if nargin < 3 || isempty(bytesToRead)
                bytesToRead = 500;
            end
            
            if nargin < 4 || isempty(timeout)
                timeout = 10;
            end
            
            done = false;
            err = obj.writeWithReplyAsync(buf, @cb, bytesToRead);
            
            t = tic;
            while ~done
                assert(toc(t) < timeout, 'Write/Read timed out.');
                pause(0.001);
            end
            
            function cb(buf, wStatus, rStatus)
                readBuffer = buf;
                writeStatus = wStatus;
                readStatus = rStatus;
                done = true;
            end
        end
    end
    
    %% Internal methods
    methods (Access = private)
        sessionId = open(obj,addr,accessMode,timeoutMs);
        status = close(obj);
        status = writeReadAsync(obj, buf, callback, readCount);  % need more documentation
        
        function e = asyncOp(obj, varargin)
            if obj.asyncOpPending || numel(obj.asyncOpQueue)
                obj.asyncOpQueue{end+1} = varargin;
                e = 0;
            else
                e = obj.executeOp(varargin);
            end
        end
            
        function e = executeOp(obj,args)
            obj.asyncOpPending = true;
            
            e = obj.writeReadAsync(args{1}, @(varargin)obj.opCb(args{2},varargin), args{3});
            
            assert(e ~= -1337, 'Async op was left pending. This should never happen.');
            assert(e == 0, 'Failed to invoke an async operation!');
            
%             start(obj.hAsyncOpTimer);
        end
        
        function opCb(obj,extCb,args)
            stop(obj.hAsyncOpTimer);
            extCb(args{:});
            
            obj.asyncOpPending = false;
            
            if numel(obj.asyncOpQueue)
                obj.runNextOp();
            end
        end
        
        function opTimeout(obj)
            stop(obj.hAsyncOpTimer);
            most.idioms.warn('VISA async timeout ooccured for device ''%s''.', obj.address);
            obj.asyncOpPending = false;
            
            if numel(obj.asyncOpQueue)
                obj.runNextOp();
            end
        end
        
        function runNextOp(obj)
            assert(~obj.asyncOpPending, 'Async operation is already pending. This should never happen.');
            
            if numel(obj.asyncOpQueue)
                op = obj.asyncOpQueue{1};
                obj.asyncOpQueue(1) = [];
                obj.executeOp(op);
            end
        end
    end
    
    methods (Static, Hidden)
        sessionId = getDefaultRM();
    end
end



%--------------------------------------------------------------------------%
% session.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
