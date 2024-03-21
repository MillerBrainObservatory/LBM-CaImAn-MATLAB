classdef NiFPGA < dynamicprops
    %   A class to communicate with a National Instruments FPGA via the
    %   NI FPGA Interface C API. This class parses the .lvbtix file
    %   directly without the need of a headerfile.
    %   
    %   Implemented so far:
    %       - Read and Write Boolean and Integer Registers
    %       - Read and Write Enums, both as strings and integer values
    %         (see property returnEnumsAsStrings)
    %       - Read and Write FIFOs
    %       - Read and Write Arrays
    %   Clusters and Fixed Point not supported by C-API
    %
    %   The registers are added as dynamic properties during
    %   the construction of the object.
    %   Reading the property polls the register on the FPGA.
    %   Writing a property sets the register on the FPGA.
    
    properties (SetAccess = private)
        rioDeviceID = '';
        session = 0;
        bitFileName;
        bitFileSignature;        
    end
   
    %% HIDDEN PROPS
    properties (Hidden, SetAccess=private)
        registerMap;
    end
    
    properties (Hidden)
        returnEnumsAsStrings = true; % if true, properties of datatype Enum are returned as their string description. if false, their integer value is returned
    end
    
    properties (Constant,Access = private)
        dllRelPath = 'private';
        dllName = 'NiFpgaWrapper';
        headerName = 'NiFpgaWrapper.h';
        
        % Clusters and fixed point data types are not supported yet        
        matlabDataTypeMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64', 'ArrayBoolean', 'ArrayU8', 'ArrayU16', 'ArrayU32', 'ArrayU64','ArrayI8', 'ArrayI16', 'ArrayI32', 'ArrayI64', 'Array'},...
            {'uint8', 'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64', 'uint8', 'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64', 'PLACEHOLDER'});
        fpgaWriteMethodMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64', 'ArrayBoolean', 'ArrayU8', 'ArrayU16', 'ArrayU32', 'ArrayU64','ArrayI8', 'ArrayI16', 'ArrayI32', 'ArrayI64'},...
            {'NiFpga_WriteBool', 'NiFpga_WriteU8', 'NiFpga_WriteU16', 'NiFpga_WriteU32', 'NiFpga_WriteU64', 'NiFpga_WriteI8', 'NiFpga_WriteI16', 'NiFpga_WriteI32', 'NiFpga_WriteI64', 'NiFpga_WriteU8', 'NiFpga_WriteU16', 'NiFpga_WriteU32', 'NiFpga_WriteU64', 'NiFpga_WriteArrayBool', 'NiFpga_WriteArrayU8', 'NiFpga_WriteArrayU16', 'NiFpga_WriteArrayU32', 'NiFpga_WriteArrayU64', 'NiFpga_WriteArrayI8', 'NiFpga_WriteArrayI16', 'NiFpga_WriteArrayI32', 'NiFpga_WriteArrayI64'});
        fpgaReadMethodMap = containers.Map(...
            {'Boolean', 'U8', 'U16', 'U32', 'U64', 'I8', 'I16', 'I32', 'I64', 'EnumU8', 'EnumU16', 'EnumU32', 'EnumU64', 'ArrayBoolean', 'ArrayU8', 'ArrayU16', 'ArrayU32', 'ArrayU64','ArrayI8', 'ArrayI16', 'ArrayI32', 'ArrayI64'},...
            {'NiFpga_ReadBool', 'NiFpga_ReadU8', 'NiFpga_ReadU16', 'NiFpga_ReadU32', 'NiFpga_ReadU64', 'NiFpga_ReadI8', 'NiFpga_ReadI16', 'NiFpga_ReadI32', 'NiFpga_ReadI64', 'NiFpga_ReadU8', 'NiFpga_ReadU16', 'NiFpga_ReadU32', 'NiFpga_ReadU64', 'NiFpga_ReadArrayBool', 'NiFpga_ReadArrayU8', 'NiFpga_ReadArrayU16', 'NiFpga_ReadArrayU32', 'NiFpga_ReadArrayU64', 'NiFpga_ReadArrayI8', 'NiFpga_ReadArrayI16', 'NiFpga_ReadArrayI32', 'NiFpga_ReadArrayI64'});
    end
    
    %% Lifecycle
    methods
        function obj = NiFPGA(bitFileName,simulated)
            if nargin < 2 || isempty(simulated)
                simulated = false;
            end
            validateattributes(bitFileName,{'char'},{'nonempty'});
            
            % is bitfile on Matlab's search path?
            if ~isempty(which(bitFileName))
                bitFileName = which(bitFileName);
            end
            
            assert(exist(bitFileName, 'file')==2,'File %s does not exist',bitFileName);
            
            classpath = fileparts(mfilename('fullpath'));
            
            if ~libisloaded(obj.dllName)
                binarypath = fullfile(classpath,obj.dllRelPath);
                dllpath = fullfile(binarypath,[obj.dllName '.dll']);
                %headerpath = fullfile(binarypath,obj.headerName);
                
                try
                    s = warning();
                    warning('off'); % suppress warnings
                    loadlibrary(dllpath,str2func(obj.dllName));
                    warning(s);                
                catch ME
                    ME.rethrow();
                end                                                    
                    
                obj.nifpgaCall('NiFpga_Initialize');
            end
            
            obj.bitFileName = bitFileName;
            obj.parseBitFile();
        end
        
       function delete(obj)           
            if libisloaded(obj.dllName)
                if obj.session ~= 0
                   obj.closeSession();
                end
                
                %better not unload the library here, since other objects might still use it
                %obj.nifpgaCall('NiFpga_Finalize');
                %unloadlibrary(obj.dllName);
            end
        end  
    end
    
    %% Public Methods
    methods      
        function openSession(obj,rioDeviceID)
            if nargin < 2 || isempty(rioDeviceID)
                rioDeviceID = 'RIO0';
            end
            
            validateattributes(rioDeviceID,{'char'},{'vector','nonempty'});
           
            [~,~,~,obj.session] = obj.nifpgaCall('NiFpga_Open',obj.bitFileName,...
                    obj.bitFileSignature,rioDeviceID,uint32(0),0);
            
            obj.rioDeviceID = rioDeviceID;
        end
        
        function closeSession(obj,noResetIfLastSession)
           if nargin < 2 || isempty(noResetIfLastSession)
               noResetIfLastSession = false;
           else
               validateattributes(noResetIfLastSession,{'logical'},{});
           end

           if obj.session == 0
              warning('No active session');
           else
               %NiFpga_Status NiFpga_Close(NiFpga_Session session, uint32_t attribute)
               obj.nifpgaCall('NiFpga_Close',obj.session,uint32(noResetIfLastSession));
               obj.session = 0;
           end
        end
        
        function run(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Run(NiFpga_Session session, uint32_t attribute)
                obj.nifpgaCall('NiFpga_Run',obj.session,0);
            end  
        end
        
        function abort(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Abort(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Abort',obj.session);
            end  
        end

        function reset(obj)
            if obj.session == 0
                warning('No active session');
            else    
                %NiFpga_Status NiFpga_Reset(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Reset',obj.session);
            end  
        end
        
        function download(obj)
            if obj.session == 0
                warning('No active session');
            else
                %NiFpga_Status NiFpga_Download(NiFpga_Session session)
                obj.nifpgaCall('NiFpga_Download',obj.session);
            end  
        end
    end
    
    %% Hidden Methods
    methods (Hidden)   
        
        
        function parseBitFile(obj)
            xDoc = xmlread(obj.bitFileName);
            
            % get bitfile signature
            xSignature = xDoc.getElementsByTagName('SignatureRegister');
            xSignature = xSignature.item(0);
            obj.bitFileSignature = char(xSignature.getFirstChild.getData);
            
            
            %get fifos
            xDmaChAllocList = xDoc.getElementsByTagName('DmaChannelAllocationList');
            xDmaChAllocList = xDmaChAllocList.item(0);
            xDmaChs = xDmaChAllocList.getElementsByTagName('Channel');
            for k = 0:xDmaChs.getLength-1;
                xDmaCh = xDmaChs.item(k);
                fifoname = char(xDmaCh.getAttribute('name'));    
                fifoname = regexprep(fifoname,'[^\w\d'']','');
                fifoname = sprintf('fifo_%s',fifoname);
               
                xNumber = xDmaCh.getElementsByTagName('Number');
                xNumber = xNumber.item(0);
                fifonumber = uint32(str2double(char(xNumber.getFirstChild.getData)));
                
                xDatatype = xDmaCh.getElementsByTagName('SubType');
                xDatatype = xDatatype.item(0);
                fifodatatype = char(xDatatype.getFirstChild.getData);
                
                xDirection = xDmaCh.getElementsByTagName('Direction');
                xDirection = xDirection.item(0);
                fifodirection = char(xDirection.getFirstChild.getData);
                
                fifomatlabdatatype = obj.matlabDataTypeMap(fifodatatype);
                
                proph = obj.addprop(fifoname);
                proph.GetAccess = 'public';
                proph.SetAccess = 'private';
                
                obj.(fifoname) = dabs.ni.rio.NiFIFO(obj,fifoname,fifodirection,fifonumber,fifodatatype,fifomatlabdatatype);

            end
 
            %get registers
            obj.registerMap = containers.Map();
            
            xRegisterList = xDoc.getElementsByTagName('RegisterList');
            xRegisterList = xRegisterList.item(0);
            xRegisters = xRegisterList.getElementsByTagName('Register');
            
            for k = 0:xRegisters.getLength-1;
                regprops = {};
                xRegister =  xRegisters.item(k);
                
                %get the register name
                xName = xRegister.getElementsByTagName('Name');
                % TODO this needs to be improved
                xName = xName.item(1);

                
                if isempty(xName.getFirstChild)
                    % skip over unnamed entries like LabVIEW internal
                    % registers (e.g. ViSignature, DiagramReset ...)
                    continue
                end
                
                name = char(xName.getFirstChild.getData);
                name = regexprep(name,'[^\w\d'']',''); %remove all special characters from name

                %get the register datatype
                xDatatype = xRegister.getElementsByTagName('Datatype');
                xDatatype = xDatatype.item(0);
                xDatatype = xDatatype.getFirstChild;
                xDatatype = xDatatype.getNextSibling; %Compensate for the newline character
                regprops.datatype = char(xDatatype.getTagName);

                % check if datatype is of type Array
                if strcmp(regprops.datatype,'Array');
                   xArrayType = xRegister.getElementsByTagName('Type');
                   xArrayType = xArrayType.item(0);
                   xArrayType = xArrayType.getFirstChild;
                   xArrayType = xArrayType.getNextSibling; %Compensate for the newline character
                   regprops.datatype = strcat('Array', char(xArrayType.getTagName)); %Overwirte datatype

                   xArraySize = xRegister.getElementsByTagName('Size');
                   xArraySize = xArraySize.item(0);
                   regprops.arraySize = uint32(str2double(char(xArraySize.getFirstChild.getData)));
                end

                if ~isKey(obj.matlabDataTypeMap,regprops.datatype)
                   warning('Datatype %s of register %s is not supported. Register is not added to object.', ...
                       regprops.datatype,name);
                   continue; %skip to the next Register
                end

                %get the register offset
                xOffset = xRegister.getElementsByTagName('Offset');
                xOffset = xOffset.item(0);
                regprops.offset = uint32(str2double(char(xOffset.getFirstChild.getData)));

                xIndicator = xRegister.getElementsByTagName('Indicator');
                xIndicator = xIndicator.item(0);
                regprops.indicator = strcmp(char(xIndicator.getFirstChild.getData),'true');

                %get datatype mapping
                regprops.matlabdatatype = obj.matlabDataTypeMap(regprops.datatype);
                regprops.fpgawritemethod = obj.fpgaWriteMethodMap(regprops.datatype);
                regprops.fpgareadmethod = obj.fpgaReadMethodMap(regprops.datatype);

                %check if datatype is of type Enum
                if ~isempty(strfind(regprops.datatype,'Enum'));
                   enumStrings = {};
                   enumValues = {};
                   xStringList = xRegister.getElementsByTagName('StringList');
                   xStringList = xStringList.item(0);
                   xStringArray = xStringList.getElementsByTagName('String');
                   for l = 0:xStringArray.getLength-1;
                       xString = xStringArray.item(l);
                       xString = xString.getFirstChild;
                       if isempty(xString)
                           string = '';
                       else
                           string = char(xString.getData);
                       end
                       enumValues{l+1} = cast(l, regprops.matlabdatatype); %#ok<AGROW>
                       enumStrings{l+1} = string; %#ok<AGROW>
                   end
                   enumValToStr = containers.Map(enumValues,enumStrings);
                   enumStrToVal = containers.Map(enumStrings,enumValues);
                   regprops.enumValToStr = enumValToStr;
                   regprops.enumStrToVal = enumStrToVal;
                end

                % add the dynamic property to the object. Make sure
                % if two registers have same name or name of register
                % matches a method of the class, append a suffix
                suffix = 0;
                namewithsuffix = name;
                while isprop(obj,namewithsuffix) || ismethod(obj,namewithsuffix)
                    suffix = suffix + 1;
                    namewithsuffix = sprintf('%s_%d',name,suffix);
                end
                name = namewithsuffix;

                obj.registerMap(name) = regprops;
                proph = obj.addprop(name);
                proph.GetAccess = 'public';
                proph.SetAccess = 'public';
                proph.Dependent = true;
                proph.GetMethod = @(obj)obj.getDynPropValue(name);
                proph.SetMethod = @(obj,value)obj.setDynPropValue(name,value);
            end 
        end
        
        function varargout = nifpgaCall(obj,funcName,varargin)
            varargout = cell(nargout,1);
            [status, varargout{:}] = calllib(obj.dllName,funcName,varargin{:});

            statusString = sprintf('NI RIO Driver Status Code: %d',status);

            if status > 0
                warning(statusString); %#ok<WNTAG,SPWRN>
            elseif status < 0
                error(statusString); %#ok<SPERR>
            end
        end
        
        function obj = setDynPropValue(obj,propName,val)
            if obj.session == 0
                %warning('No active FPGA session');
            else
                r = obj.registerMap(propName);
                
                assert(~r.indicator,'Cannot write to indicator %s.',propName);
                
                % translate enum char into integer value
                if isfield(r,'enumStrToVal') && isfield(r,'enumValToStr')
                    if ischar(val);
                        enumStrToVal = getfield(r,'enumStrToVal'); %#ok<GFLD>
                        
                        if ~isKey(enumStrToVal,val)
                            if exist('strjoin','file')
                                error('''%s'' is not a valid value for Enum property %s. Valid Values are:\n\t''%s''',val,propName,strjoin(enumStrToVal.keys,'''\n\t'''));
                            else
                                %Workaround for Matlab R2012a or earlier
                                error('''%s'' is not a valid value for Enum property %s',val,propName);
                            end
                        end
                        val = enumStrToVal(val);
                    else
                        enumValToStr = getfield(r,'enumValToStr'); %#ok<GFLD>
                        keys = enumValToStr.keys;
                        assert(isKey(enumValToStr,val),...
                            '%s is not a valid value for Enum property %s. Valid Values are one of: {%s\b\b}',...
                            num2str(val),propName,sprintf('%d, ',keys{:}));
                    end
                end
                
                %Handle Arrays
                if isfield(r,'arraySize')
                    validateattributes(val,{'numeric','logical'},{'vector'});%,'numel',r.arraySize}); Note/TODO: array size derived from xmlfile can differ from array size derived from counting #chans on adapter board
                    castval = cast(val, r.matlabdatatype);
                    if val ~= castval
                        warning([propName ' is of datatype ' r.matlabdatatype ...
                            '. Values ' num2str(val) ' coerced to ' num2str(castval)]);
                    end
                    obj.nifpgaCall(r.fpgawritemethod,obj.session,r.offset,castval,r.arraySize);
                else
                    assert(isscalar(val),'Register %s cannot be assigned nonscalar values',propName);
                    castval = cast(val, r.matlabdatatype);
                    if val ~= castval
                        warning([propName ' is of datatype ' r.matlabdatatype ...
                            '. Value ' num2str(val) ' coerced to ' num2str(castval)]);
                    end
                    obj.nifpgaCall(r.fpgawritemethod,obj.session,r.offset,castval);
                end
                
            end
        end
        
        function val = getDynPropValue(obj,propName)
            if obj.session == 0
                %warning('No active FPGA session');
                val = [];
            else
                r = obj.registerMap(propName);
                
                %handle arrays
                if isfield(r,'arraySize')
                    val = zeros(1,r.arraySize,r.matlabdatatype);
                    val = obj.nifpgaCall(r.fpgareadmethod,obj.session,r.offset,val,r.arraySize);
                else
                    val = zeros(1,r.matlabdatatype); %preallocate datatype
                    val = obj.nifpgaCall(r.fpgareadmethod,obj.session,r.offset,val);
                    
                    %handle enums
                    if obj.returnEnumsAsStrings && isfield(r,'enumValToStr')
                        enumValToStr = getfield(r,'enumValToStr'); %#ok<GFLD>
                        if isKey(enumValToStr,val) %handle out of bound values gracefully
                            val = enumValToStr(val);
                        end
                    end
                end
            end
        end
    end  
end



%--------------------------------------------------------------------------%
% NiFPGA.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
