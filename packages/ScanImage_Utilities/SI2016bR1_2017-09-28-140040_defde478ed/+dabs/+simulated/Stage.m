classdef Stage < dabs.interfaces.LinearStageController
    
    %% ABSTRACT PROPERTY REALIZATION (dabs.interfaces.LinearStageController)
    properties (Constant,Hidden)
        nonblockingMoveCompletedDetectionStrategy = 'callback'; % Either 'callback' or 'poll'
    end
    
    properties (SetAccess=protected,Dependent)
        isMoving;
    end
    
    properties (SetAccess=protected,Dependent,Hidden)
        invertCoordinatesRaw;
        positionAbsoluteRaw; 
        velocityRaw;
        accelerationRaw;
		maxVelocityRaw;        
    end
    
    properties (SetAccess=protected,Hidden)
        resolutionRaw = 1;
    end

    properties (SetAccess=protected)
        infoHardware = 'I am a simulated stage'; %String providing information about the hardware, e.g. firmware version, manufacture date, etc. Information provided is specific to each device type.
    end
    
    properties (SetAccess=protected,Hidden)
        positionDeviceUnits = .04e-6; %Units, in meters, in which the device's position values (as reported by positionAbsoluteRaw) are given
        velocityDeviceUnits = nan; %Units, in meters/sec, in which the device's velocity values (as reported by its hardware interface) are given. Value of NaN implies arbitrary units.
        accelerationDeviceUnits = nan; %Units, in meters/sec^2, in which the device's acceleration values (as reported by its hardware interface) are given. Value of NaN implies arbitrary units.         
    end
    
    %% DEVELOPER PROPERTIES
    properties (Hidden,SetAccess=protected)
        simulatedPosition;
    end
    
    %% CTOR/DTOR
    methods
        function obj = Stage(varargin)
            pvArgs = most.util.filterPVArgs(varargin,{'numDeviceDimensions'});
            if isempty(pvArgs)
                pvArgs = {'numDeviceDimensions' 3};
            end
            
            obj = obj@dabs.interfaces.LinearStageController(pvArgs{:});  
            obj.simulatedPosition = zeros(1,obj.numDeviceDimensions);
            
            disp('Simulated stage initialized.');
        end
    end
    
    %% PROPERTY ACCESS
    methods
        
        function val = get.positionAbsoluteRaw(obj)
            val = obj.simulatedPosition;            
        end
        
        function val = get.resolutionRaw(obj)
            val = 1;
        end
        
        function val = get.isMoving(obj)
            val = false;
        end        
        
    end
    
    %% ABSTRACT METHOD IMPLEMENTATIONS
    methods (Access=protected,Hidden)

        function moveCompleteHook(obj,targetPosn)            
            obj.simulatedPosition = targetPosn;
            pause(0.01);
        end   
        
        function moveStartHook(obj,targetPosn)                                                              
            obj.simulatedPosition = targetPosn;
            pause(0.01);
            obj.moveDone();
        end    
        
        function interruptMoveHook(obj)
            return;
        end           
        
        function recoverHook(obj)
            return;
        end
        
        function resetHook(obj)
            return;
        end
        
        function zeroHardHook(obj,coords)
            assert(all(coords),'Cannot hard-zero individual coordinates.');
            obj.simulatedPosition = zeros(size(obj.simulatedPosition));
        end    
    
    end    
end


%--------------------------------------------------------------------------%
% Stage.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
