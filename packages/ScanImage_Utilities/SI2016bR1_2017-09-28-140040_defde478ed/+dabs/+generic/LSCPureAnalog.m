classdef LSCPureAnalog < dabs.interfaces.LSCAnalogOption
    %LSCPureAnalog Summary of this class goes here
    %   Detailed explanation goes here

    %% HIDDEN PROPS
    properties (Hidden, SetAccess=private)
        analogOptionInitialized = false;
    end
    
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LSCAnalogOption)
    properties (SetAccess=protected,Hidden)
        analogCmdEnableRaw = true;
    end
        
        
    %% ABSTRACT PROPERTY REALIZATION (dabs.interface.LinearStageController)
    
    properties (Constant, Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'poll'; % Either 'callback' or 'poll'. If 'callback', this class guarantees that moveDone() will be called when a nonblocking move is complete. See documentation for moveStartHook().
    end
    
    properties (SetAccess=protected,Dependent)
        infoHardware;
    end
    
    properties (SetAccess=protected,Dependent,Hidden)
        velocityRaw;
        accelerationRaw;

        invertCoordinatesRaw;
        maxVelocityRaw;

    end
    
    properties (SetAccess=protected, Hidden)
        resolutionRaw;
        
        positionDeviceUnits = 1e-6;
        velocityDeviceUnits = 1e-6;
        accelerationDeviceUnits = 1e-6;
    end   
    
    
    
    %% OBJECT LIFECYCLE
    methods
        function obj = LSCPureAnalog(varargin)
            obj = obj@dabs.interfaces.LSCAnalogOption(varargin{:});
            
            obj.feedbackVoltFcn = [];
            obj.volt2PositionFcn = [];
            obj.position2VoltFcn = [];
            
            pvCell = most.util.filterPVArgs(varargin,{'voltsPerDistance' 'distanceVoltsOffset' 'feedbackVoltInterpolant'});
            pvStruct = struct(pvCell{:});
            
            nms = fieldnames(pvStruct);
            for i = 1:numel(nms)
                obj.(nms{i}) = pvStruct.(nms{i});
            end
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function set.analogCmdEnableRaw(obj,val)
            %Coerce True value for analogCmdEnable
            assert(val,'Cannot set analogCmdEnable to value False for objects of class ''%s''',mfilename('class'));
        end
        
        function val = get.infoHardware(~)
            val = 'Analog Only FastZ Actuator Device';                                    
        end
        
        function val = get.invertCoordinatesRaw(obj)
            val = false(1,obj.numDeviceDimensions);
        end        
                
        function val = get.velocityRaw(~)
            val = nan;
        end
        
        function val = get.accelerationRaw(~)
            val = nan;
        end
        
        function val = get.maxVelocityRaw(~)
            val = nan;
        end  
   
    end
    
    %% ABSTRACT METHOD IMPLEMENTATION  (dabs.interfaces.LSCAnalogOption)
    methods
        function voltage = analogCmdPosn2Voltage(obj,posn)
            assert(false, 'Use position2Volts instead.');
        end
        
        function posn = analogCmdVoltage2Posn(obj,voltage)
            assert(false, 'Use volts2Position instead.');
        end
        
        function posn = analogSensorVoltage2Posn(obj,voltage)
            assert(false, 'Use feedbackVolts2Position instead.');
        end
    end
    
    methods (Access=protected, Hidden)
        function posn = positionAbsoluteRawDigitalHook(obj)
            %Provide default ('digital') readout of LSC's absolute position
            error('Objects of class ''%s'' do not support digital position readout',mfilename('class'));
        end
        
        function tf = isMovingDigitalHook(obj)
            %Provide default ('digital') determination of whether LSC is moving when analogCndEnable=false
            error('Objects of class ''%s'' do not support digital readout of isMoving status',mfilename('class'));
        end
        
        function moveStartDigitalHook(obj,absTargetPosn)
            %Provide default ('digital') LSC move behavior when analogCmdEnable=false
            error('Objects of class ''%s'' do not support digital move operations',mfilename('class'));
        end
        
        function recoverHook(~)
            %nothing to do to recover
        end
    end
end


%--------------------------------------------------------------------------%
% LSCPureAnalog.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
