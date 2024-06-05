classdef staticText < handle
    %UICONTROL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        hTxt;
        hAx;
        hPnl;
        hLis;
        
        % pass through to hCtl
        String;
        Visible;
        Style = 'text';
    end
    
    methods
        function obj = staticText(varargin)
            ip = most.util.InputParser;
            ip.addOptional('HorizontalAlignment', 'left');
            ip.addOptional('VerticalAlignment','middle');
            ip.addOptional('FontSize',8);
            ip.addOptional('String','');
            ip.addOptional('units','');
            ip.parse(varargin{:});
            othrs = most.util.structPV2cellPV(ip.Unmatched);
            
            if ~isempty(ip.Results.units)
                obj.hPnl = uipanel('units',ip.Results.units,othrs{:},'BorderType','None');
            else
                obj.hPnl = uipanel(othrs{:},'BorderType','None');
            end
            obj.hAx = axes('parent',obj.hPnl,'color','none','XTick',[],'XTickLabel',[],'YTick',[],'YTickLabel',[],'xcolor','none','ycolor','none','position',[0 0 1 1]);
            
            switch lower(ip.Results.HorizontalAlignment)
                case 'left'
                    pos = 0;
                case 'center'
                    pos = 0.5;
                case 'right'
                    pos = 1;
            end
            
            switch lower(ip.Results.VerticalAlignment)
                case 'top'
                    pos(2) = 1;
                case 'middle'
                    pos(2) = 0.55;
                case 'bottom'
                    pos(2) = 0;
            end
            
            obj.hTxt = text(pos(1),pos(2),0,ip.Results.String,'parent',obj.hAx,'HorizontalAlignment',ip.Results.HorizontalAlignment,'VerticalAlignment',ip.Results.VerticalAlignment,'units','normalized','FontSize',ip.Results.FontSize);
            
            obj.hLis = addlistener(obj.hPnl.Parent,'ObjectBeingDestroyed',@(varargin)obj.delete);
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hLis);
            most.idioms.safeDeleteObj(obj.hTxt);
            most.idioms.safeDeleteObj(obj.hAx);
            most.idioms.safeDeleteObj(obj.hPnl);
        end
    end
    
    methods (Hidden)
        function set(obj,prop,val)
            switch lower(prop)
                case 'horizontalalignment'
                    pos = obj.hTxt.Position;
                    switch lower(val)
                        case 'left'
                            pos(0) = 0;
                        case 'center'
                            pos(0) = 0.5;
                        case 'right'
                            pos(0) = 1;
                    end
                    obj.hTxt.Position = pos;
                    obj.hTxt.(prop) = val;
                    
                case 'verticalalignment'
                    pos = obj.hTxt.Position;
                    switch lower(val)
                        case 'top'
                            pos(2) = 1;
                        case 'middle'
                            pos(2) = 0.5;
                        case 'bottom'
                            pos(2) = 0;
                    end
                    obj.hTxt.Position = pos;
                    obj.hTxt.(prop) = val;
                    
                case 'string'
                    obj.hTxt.(prop) = val;
                
                otherwise
                    set(obj.hPnl,prop,val);
            end
        end
        
        function v = get(obj,prop)
            if ismember(lower(prop), {'horizontalalignment' 'verticalalignment' 'string'})
                v = obj.hTxt.(prop);
            else
                v = obj.hAx.(prop);
            end
        end
    end
    
    methods
        function v = get.String(obj)
            v = obj.hTxt.String;
        end
        
        function set.String(obj,v)
            obj.hTxt.String = v;
        end
        
        function v = get.Visible(obj)
            v = obj.hPnl.Visible;
        end
        
        function set.Visible(obj,v)
            obj.hPnl.Visible = v;
        end
    end
end



%--------------------------------------------------------------------------%
% staticText.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
