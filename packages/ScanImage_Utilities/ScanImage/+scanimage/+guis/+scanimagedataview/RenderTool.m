classdef RenderTool < handle
    properties
        hSIDV;
        hFig;
        hRenderFig;
        hFovAxes;
        
        hAllFlow;
        hCfgCamFlow;
        hAspectFlow;
        hPixResFlow;
        hQualityFlow;
        
        hStartButton;
        hAutoResButton;
        hStatusTxt;
        
        hRenderer;
        
        zSurfs;
        rendering = false;
    end
    
    properties (SetObservable)
        renderMode = '2d';
        asp = 1;
        xres = 2400;
        yres = 1600;
        quality = 80;
    end
    
    methods
        function obj = RenderTool(hSIDV)
            obj.hSIDV = hSIDV;
        end
        
        function init(obj)
            if ~most.idioms.isValidObj(obj.hFig)
                obj.hFig = figure('numbertitle','off','name','Render Frame Sequence','menubar','none','units',...
                    'pixels','position',[0 0 440 204],'CloseRequestFcn',@obj.hideDialog,'visible','off','resize','off');
                
                g = 4;
                m = 220;
                
                of = most.gui.uiflowcontainer('parent',obj.hFig,'flowdirection','topdown','margin',0.0001);
                    obj.hStatusTxt = most.gui.staticText('parent',of,'string','','FontSize',12,'horizontalalignment','center','visible','off','HeightLimits',34);
                obj.hAllFlow = most.gui.uiflowcontainer('parent',of,'flowdirection','topdown','margin',0.0001);
                    hf = most.gui.uiflowcontainer('parent',obj.hAllFlow,'flowdirection','lefttoright','HeightLimits',34);
                        most.gui.staticText('parent',hf,'string','','WidthLimits',g);
                        most.gui.staticText('parent',hf,'string','Render Type:','FontSize',12,'WidthLimits',m);
                        most.gui.uicontrol('Parent',hf,'String','2D (Tiff)','style','togglebutton','Bindings',{obj 'renderMode' 'match' '2d'},'WidthLimits',80,'FontSize',12);
                        most.gui.uicontrol('Parent',hf,'String','3D (AVI)','style','togglebutton','Bindings',{obj 'renderMode' 'match' '3d'},'WidthLimits',80,'FontSize',12);
                    obj.hCfgCamFlow = most.gui.uiflowcontainer('parent',obj.hAllFlow,'flowdirection','lefttoright','HeightLimits',34);
                        most.gui.staticText('parent',obj.hCfgCamFlow,'string','','WidthLimits',g);
                        most.gui.staticText('parent',obj.hCfgCamFlow,'string','Camera Angle/Aspect Ratio:','FontSize',12,'WidthLimits',m);
                        most.gui.uicontrol('Parent',obj.hCfgCamFlow,'String','Configure','callback',@obj.configureCamera,'WidthLimits',100,'FontSize',12);
                    obj.hAspectFlow = most.gui.uiflowcontainer('parent',obj.hAllFlow,'flowdirection','lefttoright','HeightLimits',34);
                        most.gui.staticText('parent',obj.hAspectFlow,'string','','WidthLimits',g);
                        most.gui.staticText('parent',obj.hAspectFlow,'string','Aspect Ratio:','FontSize',12,'WidthLimits',m);
                        most.gui.uicontrol('Parent',obj.hAspectFlow,'style','edit','enable','inactive','WidthLimits',44,'FontSize',12,'backgroundcolor',.945*ones(1,3),'Bindings',{obj 'asp' 'value'});
                    obj.hPixResFlow = most.gui.uiflowcontainer('parent',obj.hAllFlow,'flowdirection','lefttoright','HeightLimits',34);
                        most.gui.staticText('parent',obj.hPixResFlow,'string','','WidthLimits',g);
                        most.gui.staticText('parent',obj.hPixResFlow,'string','Pixel Resolution:','FontSize',12,'WidthLimits',m);
                        most.gui.uicontrol('Parent',obj.hPixResFlow,'style','edit','WidthLimits',60,'FontSize',12,'Bindings',{obj 'xres' 'value'});
                        most.gui.staticText('parent',obj.hPixResFlow,'string','x','FontSize',12,'WidthLimits',20,'horizontalalignment','center');
                        most.gui.uicontrol('Parent',obj.hPixResFlow,'style','edit','WidthLimits',60,'FontSize',12,'Bindings',{obj 'yres' 'value'});
                        most.gui.uipanel('parent',obj.hPixResFlow,'Bordertype','none','WidthLimits',4);
                        obj.hAutoResButton = most.gui.uicontrol('Parent',obj.hPixResFlow,'String','Auto','callback',@obj.auto2dRes,'WidthLimits',54,'FontSize',12);
                    obj.hQualityFlow = most.gui.uiflowcontainer('parent',obj.hAllFlow,'flowdirection','lefttoright','HeightLimits',34);
                        most.gui.staticText('parent',obj.hQualityFlow,'string','','WidthLimits',g);
                        most.gui.staticText('parent',obj.hQualityFlow,'string','Quality:','FontSize',12,'WidthLimits',m);
                        most.gui.uicontrol('Parent',obj.hQualityFlow,'style','edit','WidthLimits',60,'FontSize',12,'Bindings',{obj 'quality' 'value'});
                        f2 = most.gui.uiflowcontainer('parent',obj.hQualityFlow,'flowdirection','topdown','margin',3);
                        most.gui.slider('Parent',f2,'Bindings',{obj 'quality' 100},'HeightLimits',24);
                f = most.gui.uiflowcontainer('parent',of,'flowdirection','bottomup','margin',0.0001,'HeightLimits',34);
                    hf = most.gui.uiflowcontainer('parent',f,'flowdirection','lefttoright');
                        obj.hStartButton = most.gui.uicontrol('Parent',hf,'String','Start','callback',@obj.start,'WidthLimits',100,'FontSize',12);
                        most.gui.uicontrol('Parent',hf,'String','Cancel','callback',@obj.hideDialog,'WidthLimits',100,'FontSize',12);
            end
            
            if ~most.idioms.isValidObj(obj.hRenderFig)
                obj.hRenderFig = figure('numbertitle','off','name','Render Preview','menubar','none','units','pixels','Color','k',...
                    'position',[0 0 600 600],'CloseRequestFcn',@obj.hideRenderFig,'visible','off','SizeChangedFcn',@obj.resizeRenderWindow);
                
                obj.hFovAxes = axes('parent',obj.hRenderFig,'Color','None','xcolor','none','ycolor','none','Zcolor','none','DataAspectRatio',[1 1 1],'hittest','off');
                colormap(obj.hFovAxes,repmat((0:.01:1)',1,3));
                
                hMnu = uicontextmenu('Parent',obj.hRenderFig);
                    uimenu('Parent',hMnu,'Label','Reset View','Callback',@obj.resetView);
                    
                obj.hRenderFig.WindowButtonDownFcn = @obj.mouseFcn;
                obj.hRenderFig.WindowScrollWheelFcn = @obj.scrollWheelFcn;
                obj.hRenderFig.UIContextMenu = hMnu;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hFig);
            most.idioms.safeDeleteObj(obj.hRenderFig);
        end
    end
    
    methods
        function doDialog(obj)
            obj.rendering = false;
            obj.init();
            
            delete(obj.hFovAxes.Children);
            
            %% re-center figs
            obj.hSIDV.hFig.Units = 'pixels';
            p = obj.hSIDV.hFig.Position;
            
            obj.hFig.Units = 'pixels';
            mp = obj.hFig.Position;
            mp = [(p([1 2]) + 0.5*(p([3 4]) - mp([3 4]))) mp([3 4])];
            obj.hFig.Position = mp;
            
            obj.hRenderFig.Units = 'pixels';
            obj.hRenderFig.Position = [max(mp(1)-640, 4) (p(2)+.5*p(4)-300) 600 600];
            obj.hRenderFig.Visible = 'off';
            
            %% create surfs,prepare display
            obj.zSurfs = obj.hSIDV.zSurfs;
            for zi = 1:numel(obj.zSurfs)
                for si = 1:numel(obj.zSurfs{zi})
                    s = obj.zSurfs{zi}(si);
                    obj.zSurfs{zi}(si) = surface(s.XData,s.YData,s.ZData,'Parent',obj.hFovAxes,'linewidth',1,'FaceColor','texturemap','CData',nan(3),'EdgeColor','b');
                end
            end
            
            obj.hFovAxes.XLim = obj.hSIDV.dataXLims;
            obj.hFovAxes.YLim = obj.hSIDV.dataYLims;
            obj.hFovAxes.ZLim = [min(obj.hSIDV.zs)-1 max(obj.hSIDV.zs)+1];
            obj.hFovAxes.CLim = obj.hSIDV.clim;
            
            obj.hFovAxes.CameraViewAngleMode = 'auto';
            view(obj.hFovAxes,-135,-45);
            camup(obj.hFovAxes,[0,0,-1]);
            
            
            %% show
            obj.renderMode = obj.hSIDV.viewMode;
            obj.hStatusTxt.Visible = 'off';
            obj.hAllFlow.Visible = 'on';
            obj.hStartButton.Visible = 'on';
            obj.hRenderFig.Visible = 'off';
            obj.hFig.Visible = 'on';
            figure(obj.hFig);
        end
        
        function hideDialog(obj,varargin)
            obj.hRenderFig.Visible = 'off';
            if obj.rendering
                obj.hStatusTxt.String = 'Cancelling...';
                obj.rendering = false;
            else
                obj.hFig.Visible = 'off';
                if most.idioms.isValidObj(obj.hRenderer)
                    obj.hRenderer.close();
                    delete(obj.hRenderer);
                end
            end
        end
        
        function hideRenderFig(obj,varargin)
            obj.hRenderFig.Visible = 'off';
        end
        
        function configureCamera(obj,varargin)
            obj.hRenderFig.Visible = 'on';
            figure(obj.hRenderFig);
        end
        
        function start(obj,varargin)
            obj.hAllFlow.Visible = 'off';
            obj.hStartButton.Visible = 'off';
            obj.hRenderFig.Visible = 'off';
            obj.hStatusTxt.Visible = 'on';
            
            p = obj.hFig.Position;
            obj.hFig.Position = [p(1) p(2)+.5*p(4)-34 p(3) 68];
            
            obj.hStatusTxt.String = 'Preparing render...';
            
            obj.rendering = true;
            if strcmp(obj.renderMode,'3d')
                obj.render3d();
            else
                obj.render2d();
            end
        end
        
        function render3d(obj)
            cn = 'scanimage.guis.ScanImageDataView';
            most.HasClassDataFile.ensureClassDataFileStatic(cn,struct('lastOutPath',''));
            [filename,pathname] = uiputfile({'*.avi' 'AVI Video (*.avi)'},'Output video file...',fileparts(most.HasClassDataFile.getClassDataVarStatic(cn,'lastOutPath',[],false)));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            most.HasClassDataFile.setClassDataVarStatic(cn,'lastOutPath',pathname,[],false);
            
            obj.hRenderFig.Units = 'pixels';
            obj.hRenderFig.Position([3 4]) = [obj.xres obj.yres];
            obj.hFovAxes.Position([3 4]) = [obj.xres obj.yres];
            
            
            if most.idioms.isValidObj(obj.hRenderer)
                obj.hRenderer.close();
                delete(obj.hRenderer);
            end
            obj.hRenderer = VideoWriter(filename,'Motion JPEG AVI');
            obj.hRenderer.Quality = obj.quality;
            obj.hRenderer.open();
            
            Ts = obj.hSIDV.frameTs;
            N = numel(Ts);
            for i = 1:N
                t = Ts(i);
                
                if ~obj.rendering
                    break;
                end
                obj.hStatusTxt.String = sprintf('Rendering frame (%d of %d)...',i,N);
                obj.hSIDV.updateAxesToT(obj.zSurfs,t);
                
                fr = getframe(obj.hRenderFig);
                obj.hRenderer.writeVideo(fr.cdata);
            end
            
            obj.hRenderer.close();
            obj.rendering = false;
            obj.hFig.Visible = 'off';
        end
        
        function render2d(obj)
            cn = 'scanimage.guis.ScanImageDataView';
            most.HasClassDataFile.ensureClassDataFileStatic(cn,struct('lastOutPath',''));
            [filename,pathname] = uiputfile({'*.tif' 'Tiff image (*.tif)'},'Output image file...',fileparts(most.HasClassDataFile.getClassDataVarStatic(cn,'lastOutPath',[],false)));
            if filename==0;return;end
            filename = fullfile(pathname,filename);
            most.HasClassDataFile.setClassDataVarStatic(cn,'lastOutPath',pathname,[],false);
            
            obj.hRenderFig.Units = 'pixels';
            obj.hRenderFig.Position([3 4]) = [obj.xres obj.yres];
            obj.hFovAxes.Position([3 4]) = [obj.xres obj.yres];
            set([obj.zSurfs{:}],'EdgeColor','none');
            
            obj.hFovAxes.CameraViewAngleMode = 'auto';
            view(obj.hFovAxes,0,-90);
            
            Ts = obj.hSIDV.frameTs;
            N = numel(Ts);
            Nch = numel(obj.hSIDV.data.channels);
            
            mn = single(min(obj.hSIDV.data.imageData(:)));
            canvas = zeros(obj.yres,obj.xres,'single');
            canvasHit = zeros(obj.yres,obj.xres,'single');
            
            %% develop a map for each roi of what points it hits on the render canvas
            canvasMap = cell(1,numel(obj.hSIDV.zs));
            
            ps = [diff(obj.hSIDV.dataXLims) diff(obj.hSIDV.dataYLims)] ./ [obj.xres obj.yres];
            fovxs = obj.hSIDV.dataXLims(1)-ps(1)/2 + (1:obj.xres)*ps(1);
            fovys = obj.hSIDV.dataYLims(1)-ps(2)/2 + (1:obj.yres)*ps(2);
            [fovxs,fovys] = meshgrid(fovxs,fovys);
            fovxs = fovxs(:);
            fovys = fovys(:);
            Np = size(fovys,1);
            
            for pz = 1:numel(obj.hSIDV.zs)
                zrois = obj.hSIDV.zRois{pz};
                for ri = 1:numel(zrois)
                    ps = scanimage.mroi.util.xformPoints([fovxs fovys],zrois(ri).ref2PixT);
                    hitroi = sum((ps >= .5) .* (ps <= repmat(zrois(ri).scanfield.pixelResolutionXY,Np,1)),2) > 1;
                    canvasMap{pz}{ri} = [ps hitroi];
                end
            end
            
            
            if most.idioms.isValidObj(obj.hRenderer)
                obj.hRenderer.close();
                delete(obj.hRenderer);
            end
            obj.hRenderer = Tiff(filename,'w8');
            
            for i = 1:N
                if ~obj.rendering
                    break;
                end
                obj.hStatusTxt.String = sprintf('Rendering frame (%d of %d)...',i,N);
                pause(0.001);
                
                for ch = 1:Nch
                    renderFrame(i,ch);
                    
                    obj.hRenderer.setTag('ImageLength',obj.yres);
                    obj.hRenderer.setTag('ImageWidth', obj.xres);
                    obj.hRenderer.setTag('Photometric', Tiff.Photometric.MinIsBlack);
                    obj.hRenderer.setTag('BitsPerSample', 16);
                    obj.hRenderer.setTag('SamplesPerPixel', 1);
                    obj.hRenderer.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
                    obj.hRenderer.setTag('Software', 'SI Data Viewer');
                    obj.hRenderer.setTag('SampleFormat', Tiff.SampleFormat.Int);
                    obj.hRenderer.write(int16(canvas));
                    obj.hRenderer.writeDirectory()
                end
            end
            
            obj.hRenderer.close();
            obj.rendering = false;
            obj.hFig.Visible = 'off';
            
            function renderFrame(frameIdx,chIdx)
                z = obj.hSIDV.frameZs(frameIdx);
                zIdx = find(obj.hSIDV.zs == z);
                frame = obj.hSIDV.getFrame(zIdx,obj.hSIDV.frameTs(frameIdx),chIdx);
                
                canvas(:) = 0;
                canvasHit(:) = 0;
                
                for rIdx = 1:numel(frame.roiData)
                    mp = canvasMap{zIdx}{rIdx};
                    dat = single(frame.roiData(rIdx).imageData');
                    sz = size(dat);
                    hitInds = logical(mp(:,3));
                    
                    canvas(hitInds) = canvas(hitInds) + interp2(1:sz(2),1:sz(1),dat,mp(hitInds,1),mp(hitInds,2),'linear',mn);
                    canvasHit(hitInds) = canvasHit(hitInds) + 1;
                end
                
                hitInds = logical(canvasHit);
                canvas(hitInds) = canvas(hitInds) ./ canvasHit(hitInds);
                canvas(~hitInds) = mn;
            end
        end
        
        function resizeRenderWindow(obj,varargin)
            if ~obj.rendering
                obj.hRenderFig.Units = 'pixels';
                p = obj.hRenderFig.Position;
                obj.xres = p(3);
                obj.asp = p(3)/p(4);
                
                obj.hFovAxes.Units = 'pixels';
                obj.hFovAxes.Position = [0 0 p([3 4])];
            end
        end
        
        function mouseFcn(obj,~,evt)
            persistent ppt
            
            if strcmp(evt.EventName, 'WindowMousePress')
                ppt = pixpt();
                set(obj.hRenderFig,'WindowButtonMotionFcn',@obj.mouseFcn,'WindowButtonUpFcn',@obj.mouseFcn);
            elseif strcmp(evt.EventName, 'WindowMouseMotion')
                p = pixpt();
                deltaPix = p - ppt;
                ppt = p;
                
                if strcmp(obj.hRenderFig.SelectionType,'extend')
                    camorbit(obj.hFovAxes,deltaPix(1),-deltaPix(2),'data',[0 0 1])
                else
                    camdolly(obj.hFovAxes,-deltaPix(1),-deltaPix(2),0,'movetarget','pixels');
                end
            else
                set(obj.hRenderFig,'WindowButtonMotionFcn',[],'WindowButtonUpFcn',[]);
            end
            
            function pt = pixpt()
                pt = hgconvertunits(obj.hRenderFig,[0 0 obj.hRenderFig.CurrentPoint],obj.hRenderFig.Units,'pixels',0);
                pt = pt(3:4);
            end
        end
        
        function scrollWheelFcn(obj,~,evt)
            oAngle = obj.hFovAxes.CameraViewAngle;
            obj.hFovAxes.CameraViewAngle = oAngle * 1.1^double(-evt.VerticalScrollCount);
        end
        
        function resetView(obj,varargin)
            view(obj.hFovAxes,-135,-45);
            camup(obj.hFovAxes,[0,0,-1]);
        end
        
        function auto2dRes(obj,varargin)
            obj.asp = diff(obj.hSIDV.dataXLims) / diff(obj.hSIDV.dataYLims);
            
            s = [obj.hSIDV.data.roiGroup.rois.scanfields];
            pr = reshape([s.pixelRatio],2,[])';
            res = max(pr(:,1));
            obj.xres = res*diff(obj.hSIDV.dataXLims);
        end
    end
    
    methods
        function set.quality(obj,v)
            obj.quality = round(v);
        end
        
        function set.renderMode(obj,v)
            obj.renderMode = lower(v);
            
            if strcmp(obj.renderMode,'3d')
                set([obj.hCfgCamFlow obj.hQualityFlow],'Visible','on');
                set(obj.hAutoResButton,'Visible','off');
                obj.hFig.Units = 'pixels';
                obj.hFig.Position(4) = 204;
                obj.resizeRenderWindow();
            else
                set([obj.hCfgCamFlow obj.hQualityFlow],'Visible','off');
                set(obj.hAutoResButton,'Visible','on');
                obj.hFig.Position(4) = 138;
                obj.hRenderFig.Visible = 'off';
                obj.auto2dRes();
            end
        end
        
        function set.asp(obj,v)
            obj.asp = v;
            obj.yres = obj.xres/v;
        end
        
        function set.xres(obj,v)
            obj.xres = round(v);
            
            yr = round(obj.xres / obj.asp);
            if obj.yres ~= yr
                obj.yres = yr;
            end
        end
        
        function set.yres(obj,v)
            obj.yres = round(v);
            
            xr = round(obj.yres * obj.asp);
            if obj.xres ~= xr
                obj.xres = xr;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% RenderTool.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
