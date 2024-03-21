classdef MotorRegistry < scanimage.interfaces.Class
    
    properties (Constant, Hidden)
        controllerMap = zlclInitControllerMap();
    end
    
    methods (Static)
        function info = getControllerInfo(type)
            assert(ischar(type),'''type'' must be a stage controller type.');
            m = scanimage.components.motors.MotorRegistry.controllerMap;            
           
            if m.isKey(type)
                info = m(type);
            else
                info = [];
            end
        end
    end
end

function m = zlclInitControllerMap
    m = containers.Map();
    
    s = struct();
    s.Names = {'analog'};
    s.Class = 'dabs.generic.LSCPureAnalog';
    s.ListName = 'Generic Analog Controller';
    s.SupportFastZ = true;
    s.SubType = '';
    s.TwoStep.Enable = false;
    s.SafeReset = true;
    s.NumDimensionsPreset = false;
    zlclAddMotor(m,s);
    
    s = struct();
    s.Names = {'simulated.stage'};
    s.Class = 'dabs.simulated.Stage';
    s.ListName = 'Simulated Stage';
    s.SupportFastZ = false;
    s.SubType = '';
    s.TwoStep.Enable = false;
    s.SafeReset = true;
    s.NumDimensionsPreset = false;
    zlclAddMotor(m,s);
    
    s = struct();
    s.Names = {'simulated.piezo'};
    s.Class = 'dabs.simulated.Piezo';
    s.ListName = 'Simulated Piezo';
    s.SupportFastZ = true;
    s.SubType = '';
    s.TwoStep.Enable = false;
    s.SafeReset = true;
    s.NumDimensionsPreset = true;
    zlclAddMotor(m,s);
    
    list = what('scanimage/components/motors/MotorRegistry');
    if numel(list)
        assert(numel(list)<2,'Multiple motor registries found on path. Make sure only one scanimage installation is on the path.');
        
        [~,list] = cellfun(@fileparts,list.m,'UniformOutput',false);
        list = strcat('scanimage.components.motors.MotorRegistry.',list);
        for i = 1:numel(list)
            mtr = eval(list{i});
            zlclAddMotor(m,mtr);
        end
    else
        most.idioms.warn('Motor registry not found.');
    end
end

function zlclAddMotor(m,s)
    names = s.Names;
    for c = 1:length(names)
        m(names{c}) = s;
    end
end


%--------------------------------------------------------------------------%
% MotorRegistry.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
