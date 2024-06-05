classdef LSCAnalogOption < dabs.interfaces.LinearStageController & dabs.interfaces.LinearScanner
    %LSCANALOGOPTION LinearStageController that provides option for controlling position via an analog signal
    %   Class operates directly as a standard LinearStageController by default
    %   When analogCmdEnable is set True, then analog signal is used for position control
    
    
    %% VISIBLE PROPERTIES
    properties  (Dependent)
        analogCmdEnable; %Logical; if true, analog command signal is in use to control LSC position
    end
    
    properties
        analogPosnOffset = 0;
    end
    
    %% ABSTRACT PROPERTIES
    properties (Abstract,SetAccess=protected,Hidden)        
       analogCmdEnableRaw; %Implements concrete subclass actions, if any, on change of analogCmdEnable
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (dabs.interfaces.LinearStageController)
    properties (Dependent,SetAccess=protected)
        isMoving;
    end
    
    properties (Dependent,SetAccess=protected,Hidden)
        positionAbsoluteRaw;
    end
    
    %% ABSTRACT METHODS
    methods (Abstract)
        voltage = analogCmdPosn2Voltage(obj,posn); %Convert LSC position values into analog voltage (scalar function, applies to all dimensions)
        posn = analogCmdVoltage2Posn(obj,voltage); %Convert LSC position values into analog voltage (scalar function, applies to all dimensions)
        posn = analogSensorVoltage2Posn(obj,voltage); %Convert analog voltage into LSC position values (scalar function, applies to all dimensions) 
    end

    methods (Abstract,Access=protected)        
        posn = positionAbsoluteRawDigitalHook(obj); %Provide default ('digital') readout of LSC's absolute position
        tf = isMovingDigitalHook(obj); %Provide default ('digital') determination of whether LSC is moving when analogCndEnable=false
        moveStartDigitalHook(obj,absTargetPosn); %Provide default ('digital') LSC move behavior when analogCmdEnable=false                        
    end
    
    %% OBJECT LIFECYCLE    
    methods
        function obj = LSCAnalogOption(varargin)       
            % obj = LSCAnalogOption(p1,v1,p2,v2,...)
            %
            % P-V options:
            %            
                        
            % The LinearStageController ignores unrecognized PVs
            obj = obj@dabs.interfaces.LinearStageController(varargin{:});
            
            obj.feedbackVoltFcn = @(x)obj.position2Volts(obj.analogSensorVoltage2Posn(x));
            obj.volt2PositionFcn = @(x)obj.analogCmdVoltage2Posn(x);
            obj.position2VoltFcn = @(x)obj.analogCmdPosn2Voltage(x);
            
            pvCell = most.util.filterPVArgs(varargin,{'positionDeviceName' 'positionChannelID' 'feedbackDeviceName' 'feedbackChannelID'});
            pvStruct = struct(pvCell{:});
            
            nms = fieldnames(pvStruct);
            for i = 1:numel(nms)
                obj.(nms{i}) = pvStruct.(nms{i});
            end
            
            obj.lscCalibrateOffset();
        end

        function delete(obj)
        end
    end
    
    %% USER METHODS
    methods
        function lscCalibrateOffset(obj)
            if obj.positionAvailable
                obj.moveCompleteAbsolute([0 nan nan]);
            end
            if obj.feedbackAvailable && obj.feedbackCalibrated
                obj.analogPosnOffset = obj.readFeedbackPosition(10);
            end
        end
    end
    
    %% PROPERTY ACCESS 
    methods
        function val = get.analogCmdEnable(obj)
            val = obj.analogCmdEnableRaw;
        end
        
        function set.analogCmdEnable(obj,val)
            validateattributes(val,{'numeric' 'logical'},{'binary' 'scalar'});
            
            assert(obj.positionAvailable || ~val,'No analog output channel has been configured; cannot set analogCmdEnable=true');
            
            obj.analogCmdEnableRaw = val;
        end
        
        function val = get.isMoving(obj)
            if obj.analogCmdEnable
                val = obj.isMovingAnalogHook();
            else
                val = obj.isMovingDigitalHook();
            end
        end
        
        function posn = get.positionAbsoluteRaw(obj)
            if obj.analogCmdEnable
                if obj.feedbackAvailable && obj.feedbackCalibrated
                    posn = obj.readFeedbackPosition(1);
                else
                    posn = nan;
                end
            else
                posn = obj.positionAbsoluteRawDigitalHook();
            end
        end
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS (dabs.interfaces.LinearStageController)
    methods (Access=protected,Hidden)
        function moveStartHook(obj,absTargetPosn)
            if obj.analogCmdEnable
                %Write new AO voltage, ensuring it's within AO range
                absTargetPosn = min(max(absTargetPosn,obj.travelRange(1)),obj.travelRange(2));
                obj.pointPosition(absTargetPosn);
            else
               obj.moveStartDigitalHook(absTargetPosn); 
            end
        end
    end 
  
    %% ABSTRACT METHODS
    %'Semi-abstract' methods, with default implementations provided
    methods (Access=protected)
        function tf = isMovingAnalogHook(obj)
            if obj.feedbackAvailable && obj.feedbackCalibrated
                numReadings = 10;
                
                initialPosition = obj.readFeedbackPosition(numReadings);
                pause(0.01);
                finalPosition = obj.readFeedbackPosition(numReadings);
                
                tf = abs(finalPosition-initialPosition) > obj.resolutionBest(1);
            else
                tf = false;
            end
        end
    end
end



%--------------------------------------------------------------------------%
% LSCAnalogOption.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
