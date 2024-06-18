classdef ZernikeGenerator < handle
    properties (Access = private)
        hSlm;
        
        hFig;
        hAx;
        hAxPreview;
        hIm;
        hSurf;
        hTable;
        
        hCtlVortex;
        hCtlZernikeSize;
        hCtlGradientXY;
        hCtlPositionXY;
        hCtlPhaseMaskSizeXY;
        hCtlAutoUpdate;
        
        filePath = [];
        
        cache;
    end
    
    properties
        autoUpdateSLM = false;
        zernikeCoefficients = zeros(15,1);
        vortex = 0;
        bessel = 0;
        gradientXY = [0 0];
        positionXY = [0 0];
        zernikeSize = 300;
        phaseMaskSizeXY = [512 512];
        
        phaseMask;
    end
    
    methods
        function obj = ZernikeGenerator(hSlm,visible)
            if nargin < 1 || isempty(hSlm)
                try
                    hSI = evalin('base','hSI');
                    obj.hSlm = hSI.hSlmScan.hSlm;
                catch ME
                    most.idioms.reportError(ME);
                    warning('Could not connect to ScanImage');
                    obj.hSlm = [];
                end
            else
                obj.hSlm = hSlm;
            end
            
            if nargin < 2 || isempty(visible)
                visible = true;
            end
            
            if ~isempty(obj.hSlm)
                validateattributes(obj.hSlm,{'scanimage.mroi.scanners.SLM'},{'scalar'});
                obj.phaseMaskSizeXY = obj.hSlm.pixelResolutionXY;
            end
            
            validateattributes(visible,{'numeric','logical'},{'binary','scalar'});
            
            obj.initUserInterface(visible);
        end 
        
        function delete(obj)
            delete(obj.hFig);
        end
    end
    
    methods
        function [name,trivialName] = nollIndexToName(obj,p)
            validateattributes(p,{'numeric'},{'positive','integer'});
            names = {'Piston','X-Tilt','Y-Tilt','Defocus','Oblique astigmatism','Vertical astigmatism','Vertical coma','Horizontal coma','Vertical trefoil','Oblique trefoil','Primary spherical','Vertical secondary astigmatism','Oblique secondary astigmatism','Oblique quadrafoil','Vertical quadrafoil'};
            if p <= length(names)
                name = names{p};
                trivialName = true;
            else
                [n,m] = obj.nollIndexToDegree(p);
                name = sprintf('Z_{%d}^{%d}',n,m);
                trivialName = false;
            end
        end
        function [n,m] = nollIndexToDegree(obj,p)
            % inspired by
            % https://www.mathworks.com/matlabcentral/fileexchange/25475-zernfun2a-m/content/zernfun2A.m
            validateattributes(p,{'numeric'},{'positive','integer'});
            n = fix(sqrt(2*p-1)+0.5)-1;
            m = zeros(size(n));
            ind = find(odd(n));
            pind = p(ind); nind = n(ind);
            m(ind) = 2*fix((2*(pind+1) - nind.*(nind+1))/4)-1;
            ind = find(even(n));
            pind = p(ind); nind = n(ind);
            m(ind) = 2*fix((2*pind+1 - nind.*(nind+1))/4);
            ind = find(even(p));
            m(ind) = -m(ind);
            
            function tf = odd(n)
                tf = logical(mod(n,2));
            end
            
            function tf = even(n)
                tf = ~odd(n);
            end
        end
        
        function showGUI(obj,tf)
            if nargin < 2 || isempty(tf)
                tf = true;
            end
            
            if tf
                obj.hFig.Visible = 'on';
            else
                obj.hFig.Visible = 'off';
            end
        end
        
        function [phi,r] = getPolCoords(obj,res)
            inCache = ~isempty(obj.cache) && isequal(obj.cache.res,res);
            
            if inCache
                phi = obj.cache.phi;
                r = obj.cache.r;
            else
                % calculate
                [xx,yy] = meshgrid(linspace(-1,1,res),linspace(-1,1,res));
                [phi,r] = cart2pol(xx,yy); % this is super slow!
                phi(abs(r)>1) = NaN;
                r(abs(r)>1) = NaN;
                
                % cache for performance
                obj.cache = struct();
                obj.cache.res = res;
                obj.cache.phi = phi;
                obj.cache.r = r;
            end
        end
        
        function Z = zernike(obj,n,m,res)            
            if nargin < 4 || isempty(res)
                res = 512;
            end
            assert(n>=0);
            assert(n>=abs(m),'N needs to be greater or equal to M');
            assert(mod(n,2) == mod(m,2))
            
            [phi,r] = obj.getPolCoords(res);
            
            R = 0;
            for k = 0:(n-abs(m))/2
                R = R + ( ((-1)^k*factorial(n-k)) / (factorial(k) * factorial((n+abs(m))/2 - k) * factorial((n-abs(m))/2 - k)) ) .* r.^(n-2*k);
            end
            
            if m>=0
                Z = R .* cos(abs(m) * phi);
            else
                Z = R .* sin(abs(m) * phi);
            end
            
            % normalization
            N = sqrt(2*(n+1)/(1+(m==0)));
            if m>=0
                Z = N .* Z;
            else
                Z = -N .* Z;
            end
            
            if nargout < 1
                hFig_ = figure();
                hAx_  = axes('Parent',hFig_);
                imagesc(Z,'Parent',hAx_);
                axis(hAx_,'image');
            end
        end
        
         function V = makeVortex(obj,res,v)             
             validateattributes(v,{'numeric'},{'integer','scalar','finite','nonnan'});
             [phi,r] = obj.getPolCoords(res);
             
             V = phi * v;
         end
         
         
         function B = makeBessel(obj,res,b)             
             validateattributes(b,{'numeric'},{'integer','scalar','finite','nonnan'});
             [phi,r] = obj.getPolCoords(res);
             
             B = r*b;
         end
    end
    
    methods
        function phaseMask_ = composePhaseMask(obj)
            if any(obj.gradientXY)
                [xx,yy] = meshgrid(1:obj.phaseMaskSizeXY(1),1:obj.phaseMaskSizeXY(2));
                xx = xx * obj.gradientXY(1);
                yy = yy * obj.gradientXY(2);
                phaseMask_ = xx+yy;
            else
                phaseMask_ = zeros(fliplr(obj.phaseMaskSizeXY));
            end
            
            nollIdxs = find(obj.zernikeCoefficients);
            [n,m] = arrayfun(@(p)obj.nollIndexToDegree(p),nollIdxs);
            coefficients = obj.zernikeCoefficients(nollIdxs);
            
            z = double.empty(obj.zernikeSize,obj.zernikeSize,0);
            
            if ~isempty(coefficients)
                z_ = arrayfun(@(n,m,c)obj.zernike(n,m,obj.zernikeSize)*c,n,m,coefficients,'UniformOutput',false);
                z_ = cat(3,z_{:});
                z = cat(3,z,z_);
            end
            
            if obj.vortex~=0
                v = obj.makeVortex(obj.zernikeSize,obj.vortex);
                z(:,:,end+1) = v;
            end
            
            if obj.bessel~=0
                v = obj.makeBessel(obj.zernikeSize,obj.bessel);
                z(:,:,end+1) = v;
            end
            
            if ~isempty(z)
                z = sum(z,3);
%                 midPoint = mean(z(:),'omitnan');
%                 z = z - midPoint + pi;
                
                phaseMaskTemp = nan(size(phaseMask_));
                phaseMaskTemp(1:obj.zernikeSize,1:obj.zernikeSize) = z;
                phaseMaskTemp = circshift(phaseMaskTemp,round(fliplr(obj.phaseMaskSizeXY-obj.zernikeSize)/2)+fliplr(obj.positionXY));
                phaseMaskTemp(obj.phaseMaskSizeXY(2)+1:end,:) = [];
                phaseMaskTemp(:,obj.phaseMaskSizeXY(1)+1:end) = [];
                nonnanmask = ~isnan(phaseMaskTemp);
                phaseMask_(nonnanmask) = phaseMaskTemp(nonnanmask);
            end
            
            %phaseMask = phaseMask - min(phaseMask(:));
            phaseMask_ = mod(phaseMask_,2*pi);
            
            phaseMask_ = phaseMask_(1:obj.phaseMaskSizeXY(2),1:obj.phaseMaskSizeXY(1));
        end
    end
    
    methods (Access = private)
        function initUserInterface(obj,visible)
            if visible
                visible = 'on';
            else
                visible = 'off';
            end
            
            obj.hFig = figure('NumberTitle','off','Name','Zernike Generator',...
                'MenuBar','none','Visible',visible,'CloseRequestFcn',@(src,evt)obj.showGUI(false));
            obj.hFig.Position(3:4) = [1000,590];
            most.gui.moveOntoScreen(obj.hFig);
            
            main = most.gui.uiflowcontainer('Parent',obj.hFig,'FlowDirection','LeftToRight');
                left = most.gui.uiflowcontainer('Parent',main,'FlowDirection','TopDown');
                    left.WidthLimits = [360,360];
                    leftTop = most.gui.uiflowcontainer('Parent',left,'FlowDirection','LeftToRight');
                    leftMiddle = most.gui.uiflowcontainer('Parent',left,'FlowDirection','LeftToRight');
                    leftBottom = most.gui.uiflowcontainer('Parent',left,'FlowDirection','LeftToRight');
                        leftBottom.HeightLimits = [200 200];
                right = most.gui.uiflowcontainer('Parent',main,'FlowDirection','TopDown');
                    rightTop = most.gui.uiflowcontainer('Parent',right,'FlowDirection','LeftToRight');
                    rightBottom = most.gui.uiflowcontainer('Parent',right,'FlowDirection','LeftToRight');
                        rightBottom.HeightLimits = [40 40];
                
            obj.makeTable(leftTop);
            obj.makeSettings(leftMiddle);
            obj.initZaxes(leftBottom);
            obj.initMainAxes(rightTop);
            obj.initButtons(rightBottom);
        end
        
        function initMainAxes(obj,Parent)
            obj.hAx = axes('Parent',Parent);
            obj.hIm = imagesc('CData',nan(4));
            axis(obj.hAx,'off');
            box(obj.hAx,'on');
            obj.hAx.DataAspectRatio = [1 1 1];
            view(obj.hAx,0,-90);
            axis(obj.hAx,'image')
            hCb = colorbar(obj.hAx);
            title(obj.hAx,'Phase Mask [rad]');
            obj.hAx.CLim = [0 2*pi];
            
            hCb.Ticks = [0 1/2 1 3/2 2] * pi;
            hCb.TickLabels = {'0 \pi', '1/2 \pi', '\pi', '3/2 \pi', '2 \pi'};
            
            obj.updatePhaseMask();
        end
        
        function makeTable(obj,Parent)
            obj.hTable = uitable('Parent',Parent);
            obj.hTable.ColumnName = {'Name','n','m','Coefficient'};
            obj.hTable.ColumnEditable = [false, false, false, true];
            obj.hTable.ColumnWidth = {165,30,30,'auto'};
            obj.hTable.CellSelectionCallback = @obj.cellSelected;
            obj.hTable.CellEditCallback = @obj.cellEdit;
            obj.hTable.FontName = 'Courier New';
            obj.updateTable();
        end
        
        function makeSettings(obj,Parent)
            Parent.HeightLimits = [70 70];
            top = most.gui.uiflowcontainer('Parent',Parent,'FlowDirection','TopDown');
                row1 = most.gui.uiflowcontainer('Parent',top,'FlowDirection','LeftToRight');
                    uicontrol('Parent',row1,'Style','text','String','Mask Size XY:');
                    obj.hCtlPhaseMaskSizeXY = uicontrol('Parent',row1,'Style','edit','String',mat2str(obj.phaseMaskSizeXY),'Callback',@(src,evt)obj.setProp('phaseMaskSizeXY',str2num(src.String)));
                    uicontrol('Parent',row1,'Style','text','String','Vortex:');
                    obj.hCtlVortex = uicontrol('Parent',row1,'Style','edit','String',num2str(obj.vortex),'Callback',@(src,evt)obj.updateVortex(str2double(src.String)));
                    uicontrol('Parent',row1,'Style','text','String','Zernike Size:');
                    obj.hCtlZernikeSize = uicontrol('Parent',row1,'Style','edit','String',mat2str(obj.zernikeSize),'Callback',@(src,evt)obj.setProp('zernikeSize',str2double(src.String)));
                row2 = most.gui.uiflowcontainer('Parent',top,'FlowDirection','LeftToRight');
                    uicontrol('Parent',row2,'Style','text','String','Gradient XY:');
                    obj.hCtlGradientXY = uicontrol('Parent',row2,'Style','edit','String',mat2str(obj.gradientXY),'Callback',@(src,evt)obj.setProp('gradientXY',str2num(src.String)));
                    uicontrol('Parent',row2,'Style','text','String','Position XY:');
                    obj.hCtlPositionXY = uicontrol('Parent',row2,'Style','edit','String',mat2str(obj.positionXY),'Callback',@(src,evt)obj.setProp('positionXY',str2num(src.String)));
        end
        
        function initButtons(obj,Parent)
            obj.hCtlAutoUpdate = uicontrol('Parent',Parent,'Style','checkbox','String','Auto write to SLM','Value',obj.autoUpdateSLM,'Callback',@(src,evt)obj.setProp('autoUpdateSLM',logical(src.Value)));
            uicontrol('Parent',Parent,'Style','pushbutton','String','Write To SLM','Callback',@(src,evt)obj.writePhaseMaskToSLM);
            uicontrol('Parent',Parent,'Style','pushbutton','String','Save Config','Callback',@(src,evt)obj.saveConfig);
            uicontrol('Parent',Parent,'Style','pushbutton','String','Load Config','Callback',@(src,evt)obj.loadConfig);
        end
        
        function setProp(obj,propName,val)
            obj.(propName) = val;
        end
        
        function updateVortex(obj,val)
            obj.vortex = val;
            obj.drawVortex();
        end
        
        function writePhaseMaskToSLM(obj)
            assert(~isempty(obj.hSlm),'No SLM found');
            
            phaseMask_ = obj.phaseMask;
            slmResXY = obj.hSlm.pixelResolutionXY;
            
            assert(isequal(size(phaseMask_),fliplr(slmResXY)),...
                'testPattern must be of size [%d,%d]',slmResXY(2),slmResXY(1));
            
            if obj.hSlm.computeTransposedPhaseMask
                phaseMask_ = phaseMask_';
            end
            
            obj.hSlm.writePhaseMaskRad(phaseMask_);
        end
        
        function updateTable(obj)            
            numLines = length(obj.zernikeCoefficients);
            
            nollIndex = transpose(1:numLines);
            [n,m] = arrayfun(@(p)obj.nollIndexToDegree(p),nollIndex);
            [name,trivialName] = arrayfun(@(p)obj.nollIndexToName(p),nollIndex,'UniformOutput',false);
            name(~cell2mat(trivialName)) = {''};
            
            nollIndex = mat2cell(nollIndex,ones(numLines,1));
            n         = mat2cell(n        ,ones(numLines,1));
            m         = mat2cell(m        ,ones(numLines,1));
            coefficients = cellstr(num2str(obj.zernikeCoefficients)); 
            coefficients = cellfun(@(c)sprintf('%10s',c),coefficients,'UniformOutput',false);
            
            data = horzcat(name,n,m,coefficients);
            
            obj.hTable.Data = data;
        end
        
        function coefficients = getCoefficientsFromTable(obj)
            data = obj.hTable.Data;
            coefficients = data(:,4);
            coefficients = cellfun(@(c)eval(c),coefficients);
        end
        
        function hAx = makeZAxes(obj,p)
            hAx = axes('Parent',obj.hFig,'Color','none','CLim',[0 2*pi]);
            [n,m] = obj.nollIndexToDegree(p);
            z = obj.zernike(n,m);
            axis(hAx,'off');
            grid(hAx,'off');
            box(hAx,'off');
            axis(hAx,'image');
            [xx,yy,zz] = meshgrid([-1,1],[-1,1],0);
            hSurf_ = surface('Parent',hAx,'XData',xx,'YData',yy,'ZData',zz',...
                'FaceColor','texturemap','EdgeColor','none',...
                'CData',1,'FaceAlpha','texturemap','AlphaData',0);
        end
        
        function initZaxes(obj,Parent)
            obj.hAxPreview = axes('Parent',Parent,'Color','none');
            axis(obj.hAxPreview,'off');
            grid(obj.hAxPreview,'off');
            box(obj.hAxPreview,'off');
            axis(obj.hAxPreview,'image');
            [xx,yy,zz] = meshgrid([-1,1],[-1,1],0);
            obj.hSurf = surface('Parent',obj.hAxPreview,'XData',xx,'YData',yy,'ZData',zz',...
                'FaceColor','texturemap','EdgeColor','none',...
                'CData',1,'FaceAlpha','texturemap','AlphaData',0,'Visible','off');
        end
        
        function drawZernikePolynomial(obj,p)
            if isempty(p)
                obj.hSurf.Visible = 'off';
                title(obj.hAxPreview,'');
            else
                [n,m] = obj.nollIndexToDegree(p);
                c = obj.zernike(n,m,256);
                obj.hSurf.CData = c;
                obj.hSurf.AlphaData = ~isnan(c);
                obj.hSurf.Visible = 'on';
                name = obj.nollIndexToName(p);
                title(obj.hAxPreview,name);
            end
        end
        
        function drawVortex(obj)
            if obj.vortex == 0
                obj.hSurf.Visible = 'off';
                title(obj.hAxPreview,'');
            else
                v = obj.makeVortex(256,obj.vortex);
                v = mod(v,2*pi);
                obj.hSurf.CData = v;
                obj.hSurf.AlphaData = ~isnan(v);
                obj.hSurf.Visible = 'on';
                name = sprintf('Vortex = %d',obj.vortex);
                title(obj.hAxPreview,name);
            end
        end
        
        function drawBessel(obj)
            if obj.bessel == 0
                obj.hSurf.Visible = 'off';
                title(obj.hAxPreview,'');
            else
                v = obj.makeBessel(256,obj.bessel);
                v = mod(v,2*pi);
                obj.hSurf.CData = v;
                obj.hSurf.AlphaData = ~isnan(v);
                obj.hSurf.Visible = 'on';
                name = sprintf('Bessel = %f',obj.bessel);
                title(obj.hAxPreview,name);
            end
        end
        
        function cellSelected(obj,src,evt)
            if isempty(evt.Indices) || size(evt.Indices,1) > 1
                obj.drawZernikePolynomial([])
            else
                nollIndex = evt.Indices(1,1);
                obj.drawZernikePolynomial(nollIndex);
            end
        end
        
        function cellEdit(obj,src,evt)
            try
                coefficients = obj.getCoefficientsFromTable();
                obj.zernikeCoefficients = coefficients;
            catch ME
                obj.updateTable();
                rethrow(ME);
            end
        end
        
        function drawPhaseMask(obj)
            obj.hIm.CData = obj.phaseMask;
        end
        
        function updatePhaseMask(obj)
            obj.phaseMask = obj.composePhaseMask();
            obj.drawPhaseMask();
            
            if obj.autoUpdateSLM
                try
                    obj.writePhaseMaskToSLM();
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
        
        function saveConfig(obj,filename)
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uiputfile('.zcfg','Choose path to save config',fullfile(obj.filePath,'Config.zcfg'));
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            zernikeGenerator = struct();
            zernikeGenerator.autoUpdateSLM = obj.autoUpdateSLM;
            zernikeGenerator.zernikeCoefficients = obj.zernikeCoefficients;
            zernikeGenerator.vortex = obj.vortex;
            zernikeGenerator.gradientXY = obj.gradientXY;
            zernikeGenerator.positionXY = obj.positionXY;
            zernikeGenerator.zernikeSize = obj.zernikeSize;
            zernikeGenerator.phaseMaskSizeXY = obj.phaseMaskSizeXY; %#ok<STRNU>
            
            save(filename,'zernikeGenerator');
            
            obj.filePath = fileparts(filename);
        end
        
        function loadConfig(obj,filename)
            if nargin < 2 || isempty(filename)
                [filename,pathname] = uigetfile('.zcfg','Choose path to load config',fullfile(obj.filePath,'Config.zcfg'));
                if filename==0;return;end
                filename = fullfile(pathname,filename);
            end
            
            S = load(filename,'-mat');
            assert(isfield(S,'zernikeGenerator') && isstruct(S.zernikeGenerator));
            zernikeGenerator = S.zernikeGenerator;
            
            obj.autoUpdateSLM = false;
            
            fields = fieldnames(zernikeGenerator);
            for idx = 1:length(fields)
                field = fields{idx};
                try
                    obj.(field) = zernikeGenerator.(field);
                catch
                    fprintf(2,'Could not apply value for property %s\n',field);
                end
            end
            
            obj.filePath = fileparts(filename);
        end
    end
    
    %% Set/Get Methods
    methods
        function set.zernikeCoefficients(obj,val)
            try
                validateattributes(val,{'numeric'},{'vector','finite','nonnan'});
                val = val(:);
                val(end+1:15) = 0;
                obj.zernikeCoefficients = val(:);               
                obj.updateTable();
                obj.updatePhaseMask();
            catch ME
                obj.updateTable();
                rethrow(ME);
            end
        end
        
        function set.autoUpdateSLM(obj,val)
            validateattributes(val,{'logical'},{'scalar'});
            obj.autoUpdateSLM = val;
            obj.hCtlAutoUpdate.Value = obj.autoUpdateSLM;
            obj.updatePhaseMask();
        end
        
        function set.gradientXY(obj,val)
            oldVal = obj.gradientXY;
            
            ME = [];
            try
            validateattributes(val,{'numeric'},{'nonnan','finite','vector','numel',2});
            obj.gradientXY = val(:)';
            catch ME
                obj.gradientXY = oldVal;
            end
            
            obj.updatePhaseMask();
            obj.hCtlGradientXY.String = mat2str(obj.gradientXY);
            
            if ~isempty(ME)
                rethrow(ME)
            end
        end
        
        function set.positionXY(obj,val)
            oldVal = obj.positionXY;
            
            ME = [];
            try
            validateattributes(val,{'numeric'},{'nonnan','finite','integer','vector','numel',2});
            obj.positionXY = val(:)';
            catch ME
                obj.positionXY = oldVal;
            end
            
            obj.updatePhaseMask();
            obj.hCtlPositionXY.String = mat2str(obj.positionXY);
            
            if ~isempty(ME)
                rethrow(ME)
            end
        end
        
        function set.phaseMaskSizeXY(obj,val)
            oldVal = obj.phaseMaskSizeXY;
            
            ME = [];
            try
            validateattributes(val,{'numeric'},{'nonnan','finite','vector','positive','integer','numel',2});
            obj.phaseMaskSizeXY = val(:)';
            catch ME
                obj.phaseMaskSizeXY = oldVal;
            end
            
            if ~isempty(obj.hSlm)
                obj.phaseMaskSizeXY = obj.hSlm.pixelResolutionXY; % override any user values
            end
            
            obj.updatePhaseMask();
            obj.hCtlPhaseMaskSizeXY.String = mat2str(obj.phaseMaskSizeXY);
            
            if ~isempty(ME)
                rethrow(ME)
            end
        end
        
        function set.vortex(obj,val)
            oldVal = obj.vortex;
            
            ME = [];
            try
                validateattributes(val,{'numeric'},{'nonnan','finite','scalar','integer'});
                val = round(val);
                obj.vortex = val;
            catch ME
                obj.vortex = oldVal;
            end
            
            obj.updatePhaseMask();            
            obj.hCtlVortex.String = num2str(obj.vortex);
            
            if ~isempty(ME)
                ME.rethrow();
            end
        end
        
        function set.bessel(obj,val)
            oldVal = obj.bessel;
            
            ME = [];
            try
                validateattributes(val,{'numeric'},{'nonnan','finite','scalar'});
                obj.bessel = val;
            catch ME
                obj.bessel = oldVal;
            end
            
            obj.drawBessel();
            obj.updatePhaseMask();            
            %obj.hCtlVortex.String = num2str(obj.vortex);
            
            if ~isempty(ME)
                ME.rethrow();
            end
        end
        
        function set.zernikeSize(obj,val)
            oldVal = obj.zernikeSize;
            
            ME = [];
            try 
                validateattributes(val,{'numeric'},{'nonnan','finite','scalar','integer','positive'});
                obj.zernikeSize = val;
            catch ME
                obj.zernikeSize = oldVal;
            end
            
            obj.updatePhaseMask();
            obj.hCtlZernikeSize.String = num2str(obj.zernikeSize);
            
            if ~isempty(ME)
                rethrow(ME);
            end
        end
    end
end

%--------------------------------------------------------------------------%
% ZernikeGenerator.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
