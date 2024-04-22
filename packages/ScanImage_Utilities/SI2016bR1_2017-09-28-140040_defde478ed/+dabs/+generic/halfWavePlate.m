classdef halfWavePlate < dabs.generic.GenericServoController
    properties (SetObservable)
        minPower = 0;
        maxPower = 100; 
        angleAtMinPower =  10;
    end
    
    properties (Dependent, SetObservable)
        power;
        powerRatio;
    end
    
    properties (Access = private)
        hFig;
        hUiControls   = struct();
        hUiContainers = struct();
        listenerhandles = event.proplistener.empty(1,0);
    end
    
    methods
        function obj = halfWavePlate(devName,ctrChannel)
            obj = obj@dabs.generic.GenericServoController(devName,ctrChannel);
            try
                obj.makeGui();
            catch ME
                obj.delete
                rethrow(ME);
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.listenerhandles);
            most.idioms.safeDeleteObj(obj.hFig);
        end
        
        function set.power(obj,val)
            validateattributes(val,{'numeric'},{'scalar','>=',obj.minPower,'<=',obj.maxPower});
            obj.powerRatio = obj.powerToPowerRatio(val);
        end
        
        function val = get.power(obj)
            val = obj.powerRatioToPower(obj.powerRatio);
        end
        
        function set.powerRatio(obj,val)
            validateattributes(val,{'numeric'},{'scalar','>=',0,'<=',1});
            obj.angle = obj.powerRatioToAngle(val);
            obj.updateGui();
        end
        
        function val = get.powerRatio(obj)
            % Malus' law for a perfect polarizer
            val = obj.angleToPowerRatio(obj.angle);
        end
        
        function set.angleAtMinPower(obj,val) 
            powerRatio_ = obj.powerRatio;
            obj.angleAtMinPower = val;
            obj.powerRatio = powerRatio_;
        end
        
        function angle = powerRatioToAngle(obj,ratio)
            angle = 45+obj.angleAtMinPower-(acos(sqrt(ratio))*180/pi)/2;
        end
        
        function ratio = angleToPowerRatio(obj,angle)
            ratio = cos((2*(angle-obj.angleAtMinPower-45))*pi/180)^2;
        end
        
        function ratio = powerToPowerRatio(obj,power)
            ratio = (power-obj.minPower)/(obj.maxPower-obj.minPower);
        end
        
        function power = powerRatioToPower(obj,ratio)
            power = ratio*(obj.maxPower-obj.minPower) + obj.minPower;
        end
    end
    
    %% GUI
    methods
        function makeGui(obj)
            most.idioms.safeDeleteObj(obj.hFig);
            
            obj.hFig = figure('Visible','off');
            % obj.hFig.CloseRequestFcn = @(src,evt)most.gui.minimizeFigure(src);
            obj.hFig.CloseRequestFcn = @(src,evt)obj.delete();
            obj.hFig.NumberTitle = 'off';
            obj.hFig.MenuBar = 'none';
            obj.hFig.Name = 'Halfwave Plate Control';
            obj.hFig.Position(3:4) = [186,238];
             
            obj.hUiContainers.main = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','TopDown');
                obj.hUiContainers.configPanel = uipanel('Parent',obj.hUiContainers.main,'Title','Configuration');
                obj.hUiContainers.configPanel.HeightLimits = [100 100];
                        obj.hUiContainers.configFlow = most.gui.uiflowcontainer('Parent',obj.hUiContainers.configPanel,'FlowDirection','TopDown');
                            obj.hUiContainers.configFlow1 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.configFlow,'FlowDirection','LeftToRight');
                                obj.hUiControls.etPhase = uicontrol('Parent',obj.hUiContainers.configFlow1,'Style','edit','Callback',@obj.phaseChanged);
                                obj.hUiControls.etPhase.WidthLimits = [40 40];
                                obj.hUiControls.txPhase = uicontrol('Parent',obj.hUiContainers.configFlow1,'Style','text','String','Angle at minimal power','HorizontalAlignment','Left');
                            obj.hUiContainers.configFlow2 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.configFlow,'FlowDirection','LeftToRight');
                                obj.hUiControls.etMinPower = uicontrol('Parent',obj.hUiContainers.configFlow2,'Style','edit','Callback',@obj.minPowerChanged);
                                obj.hUiControls.etMinPower.WidthLimits = [40 40];
                                obj.hUiControls.txMinPower = uicontrol('Parent',obj.hUiContainers.configFlow2,'Style','text','String','Min power','HorizontalAlignment','Left');
                            obj.hUiContainers.configFlow3 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.configFlow,'FlowDirection','LeftToRight');
                                obj.hUiControls.etMaxPower = uicontrol('Parent',obj.hUiContainers.configFlow3,'Style','edit','Callback',@obj.maxPowerChanged);
                                obj.hUiControls.etMaxPower.WidthLimits = [40 40];
                                obj.hUiControls.txMaxPower = uicontrol('Parent',obj.hUiContainers.configFlow3,'Style','text','String','Max power','HorizontalAlignment','Left');
                obj.hUiContainers.powerPanel = uipanel('Parent',obj.hUiContainers.main,'Title','Power');
                    obj.hUiContainers.powerPanel.HeightLimits = [100 100];
                    obj.hUiContainers.powerFlow = most.gui.uiflowcontainer('Parent',obj.hUiContainers.powerPanel,'FlowDirection','TopDown');
                        obj.hUiContainers.powerFlow0 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.powerFlow,'FlowDirection','LeftToRight');
                            obj.hUiControls.txPower = uicontrol('Parent',obj.hUiContainers.powerFlow0,'Style','text','String','Power');
                            obj.hUiControls.txPowerPercent = uicontrol('Parent',obj.hUiContainers.powerFlow0,'Style','text','String','Power %');
                            obj.hUiControls.txAngle = uicontrol('Parent',obj.hUiContainers.powerFlow0,'Style','text','String','Angle');
                            set(obj.hUiContainers.powerFlow0.Children,'HeightLimits',[15 15]);
                        obj.hUiContainers.powerFlow1 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.powerFlow,'FlowDirection','LeftToRight');
                            obj.hUiControls.etPower = uicontrol('Parent',obj.hUiContainers.powerFlow1,'Style','edit','Callback',@obj.powerChanged);
                            obj.hUiControls.etPowerPercent = uicontrol('Parent',obj.hUiContainers.powerFlow1,'Style','edit','Callback',@obj.powerPercentChanged);
                            obj.hUiControls.etAngle = uicontrol('Parent',obj.hUiContainers.powerFlow1,'Style','edit','Callback',@obj.angleChanged);
                        obj.hUiContainers.powerFlow2 = most.gui.uiflowcontainer('Parent',obj.hUiContainers.powerFlow,'FlowDirection','LeftToRight');
                            obj.hUiControls.ratioSlider = uicontrol('Parent',obj.hUiContainers.powerFlow2,'Style','slider','Min',0,'Max',1,'Callback',@obj.sliderChanged);

                obj.hUiControls.startButton = uicontrol('Parent',obj.hUiContainers.main,'Style','pushbutton','String','Start','Callback',@obj.toggleStartStop);
            
            obj.hFig.Visible = 'on';
            obj.attachlisteners();
            obj.updateGui();
        end
        
        function attachlisteners(obj)
            most.idioms.safeDeleteObj(obj.listenerhandles);
            obj.listenerhandles = event.proplistener.empty(1,0);
            
            mc = metaclass(obj);
            props = {mc.PropertyList.Name};
            setObservableMask = [mc.PropertyList.SetObservable];
            props = props(setObservableMask);
            
            for idx = 1:length(props)
                obj.listenerhandles(end+1) = obj.addlistener(props{idx},'PostSet',@(src,evt)obj.updateGui);
            end
        end
        
        function updateGui(obj)
            if isempty(obj.hFig) || ~isvalid(obj.hFig)
                obj.makeGui();
            end
            
            obj.hUiControls.ratioSlider.Value = obj.powerRatio;
            if obj.started
                str = 'Started';
                c = [0.94,0.94,0.94];
            else
                str = 'Stopped';
                c = [1,0,0];
            end
            obj.hUiControls.startButton.Value = obj.started;
            obj.hUiControls.startButton.String = str;
            obj.hUiControls.startButton.BackgroundColor = c;
            obj.hUiControls.etPowerPercent.String = sprintf('%.2f%%',obj.powerRatio*100);
            obj.hUiControls.etPower.String = sprintf('%.2f',obj.power);
            obj.hUiControls.etAngle.String = sprintf('%.2f°',obj.angle);
            obj.hUiControls.etPhase.String = [num2str(obj.angleAtMinPower) ,'°'];
            obj.hUiControls.etMinPower.String = num2str(obj.minPower);
            obj.hUiControls.etMaxPower.String = num2str(obj.maxPower);
        end
        
        function sliderChanged(obj,src,~)
            obj.powerRatio = src.Value;
        end
        
        function phaseChanged(obj,src,~)
            str = strrep(src.String,'°','');
            obj.angleAtMinPower = str2double(str);
        end
        
        function minPowerChanged(obj,src,~)
            obj.minPower = str2double(src.String);
        end
        
        function maxPowerChanged(obj,src,~)
            obj.maxPower = str2double(src.String);
        end
        
        function powerPercentChanged(obj,src,~)
            str = strrep(src.String,'%','');
            obj.powerRatio = str2double(str)/100;
        end
        
        function angleChanged(obj,src,~)
            str = strrep(src.String,'°','');
            obj.angle = str2double(str);
        end
        
        function powerChanged(obj,src,~)
            obj.powerRatio = str2double(src.String);
        end
        
        function toggleStartStop(obj,~,~)
            if obj.started
                obj.stop();
            else
                obj.start();
            end
            obj.updateGui();
        end
        
        function plot(obj)
            powerRatio = linspace(0,1,1000);
            power = obj.powerRatioToPower(powerRatio);
            angle = obj.powerRatioToAngle(powerRatio);
            hFig_ = most.idioms.figureSquare('NumberTitle','off','Name','Halfwave plate curve');
            hAx_ = axes('Parent',hFig_);
            plot(hAx_,power,angle);
            xlabel(hAx_,'Power');
            ylabel(hAx_,'Angle [°]');
            axis(hAx_,'square');
        end
    end
end

%--------------------------------------------------------------------------%
% halfWavePlate.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
