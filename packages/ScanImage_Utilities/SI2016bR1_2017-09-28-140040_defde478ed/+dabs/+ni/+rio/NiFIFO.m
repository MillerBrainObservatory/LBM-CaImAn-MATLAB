classdef NiFIFO < handle
    % Implementation of a National Instruments FPGA FIFO

    properties (SetAccess = immutable)
        fifoNumber;
        fifoName;
        fifoDirection;
        fifoDatatype;
        fifoMatlabDatatype;
        fifoAccessMethod = [];
    end
    
    properties (SetAccess = immutable, Hidden)
        hFpga;
    end
    
    properties (SetAccess = private)
        fifoDepth = [];
    end
    
    properties (Constant,Hidden)
        stdtimeout = 10000; %standardtimeout in ms
        fiforeadmethodmap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64'},...
            {'NiFpga_ReadFifoBool', 'NiFpga_ReadFifoU8', 'NiFpga_ReadFifoU16', 'NiFpga_ReadFifoU32', 'NiFpga_ReadFifoU64',...
            'NiFpga_ReadFifoI8', 'NiFpga_ReadFifoI16', 'NiFpga_ReadFifoI32', 'NiFpga_ReadFifoI64'});
        fifowritemethodmap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64'},...
            {'NiFpga_WriteFifoBool', 'NiFpga_WriteFifoU8', 'NiFpga_WriteFifoU16', 'NiFpga_WriteFifoU32', 'NiFpga_WriteFifoU64',...
            'NiFpga_WriteFifoI8', 'NiFpga_WriteFifoI16', 'NiFpga_WriteFifoI32', 'NiFpga_WriteFifoI64'});
    end
    
    %% Lifecycle
    
    methods (Access = ?dabs.ni.rio.NiFPGA)
        function obj = NiFIFO(hFpga,fifoName,fifoDirection,fifoNumber,fifoDatatype,fifoMatlabDatatype)
            narginchk(6,6);
            assert(isa(hFpga,'dabs.ni.rio.NiFPGA'));
            
            obj.hFpga = hFpga;
            obj.fifoName = fifoName;
            obj.fifoDirection = fifoDirection;
            obj.fifoNumber = uint32(fifoNumber);
            obj.fifoDatatype = fifoDatatype;
            obj.fifoMatlabDatatype = fifoMatlabDatatype;
            
            if strcmp(obj.fifoDirection,'TargetToHost')
                obj.fifoAccessMethod = obj.fiforeadmethodmap(fifoDatatype);
            elseif strcmp(obj.fifoDirection,'HostToTarget')
                obj.fifoAccessMethod = obj.fifowritemethodmap(fifoDatatype);
            end
        end
        
        function delete(~)
            % Nothing to do here
        end
    end
    
    
    methods        
        function actualFifoDepth = configure(obj,requestedDepth)
           % requestedDepth
           assert(obj.hFpga.session ~= 0,'No active session');
           validateattributes(requestedDepth,{'numeric'},{'scalar','positive','nonnan','finite'});
           
           %NiFpga_Status NiFpga_ConfigureFifo2(NiFpga_Session session, uint32_t fifo, size_t requestedDepth, size_t* actualDepth) 
           actualFifoDepth = obj.hFpga.nifpgaCall('NiFpga_ConfigureFifo2',obj.hFpga.session,obj.fifoNumber,requestedDepth,0);
           obj.fifoDepth = actualFifoDepth;
        end
        
        function start(obj)
            assert(obj.hFpga.session ~= 0,'No active session');
            %NiFpga_Status NiFpga_StartFifo(NiFpga_Session session, uint32_t fifo)
            obj.hFpga.nifpgaCall('NiFpga_StartFifo',obj.hFpga.session,obj.fifoNumber); 
        end
        
        function stop(obj)
            assert(obj.hFpga.session ~= 0,'No active session');
            %NiFpga_Status NiFpga_StopFifo(NiFpga_Session session, uint32_t fifo)
            obj.hFpga.nifpgaCall('NiFpga_StopFifo',obj.hFpga.session,obj.fifoNumber);
        end
        
        function emptyelementsremaining = write(obj,data,timeout)
            % data:    numeric scalar or vector to be written to the FIFO
            % timeout: time in milliseconds to wait for the data to be
            %          written to the FIFO
            %           0: timeout immediately if data cannot be written to FIFO
            %         inf: wait infinitely (attention: this function is blocking!)
            % return values:
            %        emptyelementsremaining: number of empty elements in FIFO
            
            assert(strcmp(obj.fifoDirection,'HostToTarget'),'Cannot write to read only FIFO %s',obj.fifoName);
            assert(obj.hFpga.session ~= 0,'No active session');
            
            if nargin < 2 || isempty(data)
               error('Cannot write empty array to FIFO %s', obj.fifoName) 
            end
            
            if nargin < 3 || isempty(timeout)
                timeout = obj.stdtimeout;
            end

            validateattributes(data,{'numeric'},{'vector'})
            validateattributes(timeout,{'numeric'},{'scalar','nonnegative','nonnan'});
            if isinf(timeout)
               timeout = 2^32-1;
            end
            
            castdata = cast(data,obj.fifoMatlabDatatype);
            if ~strcmp(class(data),obj.fifoMatlabDatatype) && ~isequal(data,castdata)
               warning('Data written to FIFO %s cast to %s. Precision loss occured',obj.fifoName,obj.fifoMatlabDatatype);
            end
            
            [~,emptyelementsremaining] = obj.hFpga.nifpgaCall(obj.fifoAccessMethod,obj.hFpga.session,obj.fifoNumber,castdata,length(castdata),timeout,0);
        end
        
        function [data, elementsremaining] = read(obj,numofelements,timeout)
            % numofelements: numeric scalar specifying the amount of elements to be read from the FIFO
            % timeout: time in milliseconds to wait for the data to be
            %          read from the FIFO
            %              0: timeout immediately if data cannot be written to FIFO
            %            inf: wait infinitely (attention: this function is blocking!)
            %
            % return values:
            %    data: numeric array containing the read data
            %    elementsremaining: unread number of elements in FIFO
            
            assert(strcmp(obj.fifoDirection,'TargetToHost'),'Cannot read from write only FIFO %s',obj.fifoName);
            assert(obj.hFpga.session ~= 0,'No active session');
            
            if nargin < 2 || isempty(numofelements)
                numofelements = 1;
            end
            
            if nargin < 3 || isempty(timeout)
                timeout = obj.stdtimeout;
            end
            
            validateattributes(numofelements,{'numeric'},{'scalar','nonnegative','finite','nonnan'});
            validateattributes(timeout,{'numeric'},{'scalar','nonnegative','nonnan'});
            if isinf(timeout)
               timeout = 2^32-1; 
            end
            
            data = zeros(numofelements,1,obj.fifoMatlabDatatype); %Preallocate data
            
            %NiFpga_Status NiFpga_ReadFifoI16(NiFpga_Session session, uint32_t fifo, int16_t* data, size_t numberOfElements, uint32_t timeout, size_t* elementsRemaining)
            [data,elementsremaining] = obj.hFpga.nifpgaCall(obj.fifoAccessMethod,obj.hFpga.session,obj.fifoNumber,data,numofelements,timeout,0);
        end
        
        function data = readAll(obj,maxN)
            
            if nargin < 2 || isempty(maxN)
                maxN = inf;
            elseif maxN == 0
                data = [];
                return;
            else
                assert(maxN > 0, 'Max number of elements must be positive.');
            end
            
            try
                [data, N] = obj.read(1,0);
            catch
                data = [];
                return;
            end
            
            N = min(N,maxN-1);
            
            if N > 0
                try
                    appData = obj.read(N,0);
                catch ME
                    fprintf(2,'Error reading remaining FIFO elements. There may be another reader. Error message:\n');
                    ME.rethrow;
                end

                data = [data; appData];
            end
        end
    end
end


%--------------------------------------------------------------------------%
% NiFIFO.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
