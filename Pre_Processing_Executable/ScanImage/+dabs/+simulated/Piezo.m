classdef Piezo < dabs.interfaces.LSCAnalogOption
    %Simulated.Piezo is a simulated Piezo device. This is used for full-up
    %software test systems for ScanImage.
    %
    %   Detailed explanation goes here

    %% PROPERTIES (Constructor-initialized)
    properties (SetAccess=immutable)
        
        commandVoltsPerMicron; %Conversion factor for command signal to analog linear stage controller
        commandVoltsOffset; %Offset value, in volts, for command signal to analog linear stage controller
        
        sensorVoltsPerMicron; %Conversion signal for sensor signal from analog linear stage controller
        sensorVoltsOffset; %Offset value, in volts, for sensor signal from analog linear stage controller
                
    end
    
    %% HIDDEN PROPS
    properties (Hidden, SetAccess=private)
       analogOptionInitialized = false;
       
       targetPosition = 0.0;
    end
    
    %% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Simulated ';
        
        %Value-Optional properties
        mdfDependsOnClasses;
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
    end
    
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LSCAnalogOption)
    properties (SetAccess=protected,Hidden)
        analogCmdEnableRaw = false
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
        function obj = Piezo(varargin)
            
            pvArgs = most.util.filterPVArgs(varargin,{'numDeviceDimensions'});
            if isempty(pvArgs)
                pvArgs = {'numDeviceDimensions' 1};
            end
            
            %Construct dabs.interfaces.analogLSC
            obj = obj@dabs.interfaces.LSCAnalogOption(pvArgs{:});
            
            disp('Simulated piezo initialized.');
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function set.analogCmdEnableRaw(obj,val)
            obj.analogCmdEnableRaw = val;
        end
        
        function val = get.infoHardware(~)
            val = 'Simulated Piezo Actuator Device';                                    
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
            %Convert LSC position values into analog voltage (scalar function, applies to all dimensions)
            %set target position.
            %obj.targetPosition = posn;
            %calculate voltage for compatibility purposes.
            %voltage = 0.5;
            voltage = posn / 40; % * (10V)/(400um)
        end
        
        function posn = analogCmdVoltage2Posn(obj,voltage)
            %Convert analog voltage (scalar function, applies to all dimensions) into LSC position values
            posn = voltage * 40;
        end
        
        function posn = analogSensorVoltage2Posn(obj,voltage)
            %Convert analog voltage into LSC position values (scalar function, applies to all dimensions)
            %posn = obj.targetPosition;
            posn = voltage * 40 - obj.analogPosnOffset; % * (400um)/(10V)
        end       
    end

    methods (Access=protected,Hidden)
        function recoverHook(obj)
            fprintf('Simulated Piezo: Recovering from motor error.\n');
        end
    end
    
    methods (Access=protected)
        function posn = positionAbsoluteRawDigitalHook(obj)
            posn = obj.targetPosition;
        end
        
        function tf = isMovingDigitalHook(obj)
            %Provide default ('digital') determination of whether LSC is moving when analogCndEnable=false
            tf = false;
        end

        function tf = isMovingAnalogHook(obj)
            %Provide default ('digital') determination of whether LSC is moving when analogCndEnable=true
            tf = false;
        end         
        
        function moveStartDigitalHook(obj,absTargetPosn)
            %Provide default ('digital') LSC move behavior when analogCmdEnable=false
            obj.targetPosition = absTargetPosn;
        end                
    end
end



%--------------------------------------------------------------------------%
% Piezo.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
