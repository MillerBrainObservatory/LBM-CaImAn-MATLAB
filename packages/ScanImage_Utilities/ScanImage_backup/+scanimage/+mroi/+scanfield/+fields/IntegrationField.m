classdef IntegrationField < scanimage.mroi.scanfield.ScanField
    %% Abstract property realization scanimage.mroi.scanfield.ScanField    
    properties (SetAccess = protected)
        shortDescription = 'Integration field';
    end
    
    %% Class properties
    properties(SetObservable, AbortSet)
        threshold = NaN;
        channel = 1;
        
        processor = 'cpu';   % one of {'fpga','cpu'}
        mask = 1;
    end
    
    properties(SetObservable,Hidden)
        pixelStart = [NaN NaN];  % [x,y] pixel start - for display purposes only
        pixelStop  = [NaN NaN];  % [x,y] pixel start - for display purposes only
    end
    
    properties (SetAccess = protected, Dependent)
        pixelResolutionXY;
    end
    
    %% Lifecycle
    methods
        function obj = IntegrationField()
            obj = obj@scanimage.mroi.scanfield.ScanField();
        end
    end
    
    %% Abstract methods realization of scanimage.mroi.scanfield.ScanField
    methods            
        function rect = boundingbox(obj)
            disp('Todo: scanimage.mroi.scanfield.fields.IntegrationField.boundingbox: implement this properly');
            rect = [];
        end
        
        function [xs,ys]=transform(obj,xs,ys)
           %% Transforms points from unit-scan space to fov space
           [xs,ys] = scanimage.mroi.util.xformPointsXY(xs,ys,obj.affine);
        end
       
        function T=affine(obj)
            % Returns the affine transform
            
            % scaling
            S=diag([obj.sizeXY 1]);
            
            % rotation
            R=eye(3);
            radians = obj.rotation*pi/180;
            c = cos(radians);
            s = sin(radians);
            R(1:2,1:2) = [c -s; s c];
            
            % translation
            C=eye(3);
            C(:,3)=[obj.centerXY 1];
            
            T = C*R*S;
        end
        
        function setByAffineParams(obj, p)
            most.idioms.warn('TODO: Implement setByAffineParams for IntegrationField');
        end
        
        function pts = cornerpoints(obj)
            pts = [-.5 -.5; .5 -.5; .5 .5; -.5 .5];
            pts = scanimage.mroi.util.xformPoints(pts,obj.affine);
        end
    end
    
    %% Public functions
    methods
        function s = saveobj(obj)
            s = struct();
            s = saveobj@scanimage.mroi.scanfield.ScanField(obj,s);
            
            s.threshold = obj.threshold;
            s.channel   = obj.channel;
            s.processor = obj.processor;
            s.mask      = obj.mask;
            s.affine    = obj.affine;
        end
        
        function out = interpolate(obj,other,frac)
            out = scanimage.mroi.scanfield.fields.IntegrationField();
            out = interpolate@scanimage.mroi.scanfield.ScanField(obj,other,frac,out);
            
            out.channel = obj.channel;
            out.processor = obj.processor;
            out.threshold = interpolateProp(obj,other,frac,'threshold');
            
            if isequal(size(obj.mask),size(other.mask))
                mask1 = obj.mask;
                mask2 = other.mask;
            else
                mask1 = obj.mask;
                mask2 = other.mask;
                res = round(size(mask1) + frac.*(size(mask2)-size(mask1)));
                
                [xx,yy] = meshgrid(linspace(0,1,res(2)),linspace(0,1,res(1)));
                
                % we need to padd to account for numerical artifacts in
                % interpolation of meshgrids
                [xx1,yy1] = paddedMeshgrid(mask1);
                [xx2,yy2] = paddedMeshgrid(mask2);
                mask1 = padMask(mask1);
                mask2 = padMask(mask2);
                
                mask1 = interp2(xx1,yy1,mask1,xx,yy,'linear',0);
                mask2 = interp2(xx2,yy2,mask2,xx,yy,'linear',0);
            end
            
            out.mask = mask1 + frac.*(mask2-mask1);
            
            %%% local functions
            function [xx,yy] = paddedMeshgrid(maskin)
                szx = size(maskin,2);
                szy = size(maskin,1);
                [xx,yy] = meshgrid(...
                    linspace(-1/szx,1+1/szx,szx+2),...
                    linspace(-1/szy,1+1/szy,szy+2));
            end
            
            function maskout = padMask(maskin)
                maskout = zeros(size(maskin)+2,'like',maskin);
                maskout(2:size(maskin,1)+1,2:size(maskin,2)+1) = maskin;
            end
        end
        
        function [xx,yy] = meshgrid(obj,transformToRefSpace)
            if nargin<2 || isempty(transformToRefSpace)
                transformToRefSpace = true;
            end
            
            xres = size(obj.mask,2);
            yres = size(obj.mask,1);
            [xx,yy] = meshgrid(linspace(1/xres-1,1-1/xres,xres),linspace(1/yres-1,1-1/yres,yres));
            
            if transformToRefSpace
                [xx,yy] = scanimage.mroi.util.xformMesh(xx,yy,obj.affine());
            end
        end
        
        function [xx,yy] = cornersurf(obj)
            [xx,yy] = meshgrid([-.5,.5],[-.5,.5]);
            [xx,yy] = scanimage.mroi.util.xformMesh(xx,yy,obj.affine);
        end
        
        function [owningscanfield,owningroi] = owningImagingScanField(obj,roiGroup_or_Roi_or_Sf,z,mode)
            if nargin<4 || isempty(mode)
                mode = 'centeronly';
            end
            
            owningscanfield = [];
            owningroi = [];
            
            if isa(roiGroup_or_Roi_or_Sf,'scanimage.mroi.RoiGroup')
                [scanfields,rois] = roiGroup_or_Roi_or_Sf.scanFieldsAtZ(z);
            elseif isa(roiGroup_or_Roi_or_Sf,'scanimage.mroi.Roi')
                scanfields = roiGroup_or_Roi_or_Sf.get(z);
                    if ~isempty(scanfields)
                        scanfields = {scanfields};
                        rois = {roiGroup_or_Roi_or_Sf};
                    else
                        scanfields = {};
                        rois = {};
                    end
            elseif isa(roiGroup_or_Roi_or_Sf,'scanimage.mroi.scanfield.ImagingField')
                scanfields = {roiGroup_or_Roi_or_Sf};
                rois = {[]};
            else
                assert(false);
            end
            
            for idx = 1:length(scanfields)
                sf = scanfields{idx};
                roi = rois{idx};
                assert(isa(sf,'scanimage.mroi.scanfield.ImagingField'));
                
                switch mode
                    case 'fullfit'
                        % tests if the entire integrationroi fits into the
                        % imaging scanfield
                        v = sf.cornerpoints;
                        q = obj.cornerpoints;
                    case 'centeronly'
                        % tests if the center of the integrationroi is within
                        % the bounds of the imaging scanfield
                        v = sf.cornerpoints;
                        q = obj.centerXY;
                    otherwise
                        assert(false);
                end
                [in,on] = inpolygon(q(:,1),q(:,2),v(:,1),v(:,2));
                hit = all(or(in,on));
                
                if hit
                    owningscanfield = sf;
                    owningroi = roi;
                    break
                end
            end
        end
        
        function [xyPixelStart,xyPixelStop] = fitToImagingRoi(obj,scanfield)
            if isempty(scanfield)
                xyPixelStart = [];
                xyPixelStop = [];
                return
            end
            
            assert(isa(scanfield,'scanimage.mroi.scanfield.ImagingField'));
            obj.rotation = scanfield.degrees; % hard constraint
            
            sfAff = scanfield.affine();
            ifPts = obj.cornerpoints();
            
            ifPtsFov = scanimage.mroi.util.xformPoints(ifPts,sfAff,true);
            
            xres = scanfield.pixelResolutionXY(1);
            yres = scanfield.pixelResolutionXY(2);
            
            ifPtsFovNew(:,1) = round(ifPtsFov(:,1).*xres)./xres;
            ifPtsFovNew(:,2) = round(ifPtsFov(:,2).*yres)./yres;
            
            ifPtsFovNew = max(min(ifPtsFovNew,1),0);
            
            scalingXfactor = (ifPtsFovNew(1,1) - ifPtsFovNew(2,1)) / (ifPtsFov(1,1) - ifPtsFov(2,1));
            scalingYfactor = (ifPtsFovNew(1,2) - ifPtsFovNew(4,2)) / (ifPtsFov(1,2) - ifPtsFov(4,2));
            
            xyPixelStart(1) = round(min(ifPtsFovNew(:,1)) * xres + 1);
            xyPixelStart(2) = round(min(ifPtsFovNew(:,2)) * yres + 1);
            
            xyPixelStop(1) = round(max(ifPtsFovNew(:,1)) * xres);
            xyPixelStop(2) = round(max(ifPtsFovNew(:,2)) * yres);
            
            ifPtsNew = scanimage.mroi.util.xformPoints(ifPtsFovNew,sfAff);
            ifCtrPtNew = ifPtsNew(1,:)+(ifPtsNew(3,:)-ifPtsNew(1,:))./2;
            
            obj.centerXY = ifCtrPtNew;
            obj.sizeXY = obj.sizeXY .* [scalingXfactor, scalingYfactor];
        end
        
        function sfmask = maskImagingScanfield(obj,sf)
            [sfxx,sfyy] = sf.meshgrid(false); % do not transform this to reference space for performance reasons
            
            if isscalar(obj.mask) 
                resXY = ceil(2 .* obj.sizeXY ./ sf.sizeXY .* sf.pixelResolutionXY);
                xres = resXY(1);
                yres = resXY(2);
                
                mask_ = zeros(yres+2,xres+2); % pad the mask with zeros for the interpolation
                mask_(2:end-1,2:end-1) = repmat(obj.mask,yres,xres);
            else
                xres = size(obj.mask,2);
                yres = size(obj.mask,1);
                mask_ = zeros(yres+2,xres+2); % pad the mask with zeros for the interpolation
                mask_(2:end-1,2:end-1) = obj.mask;
            end
            [xx,yy] = meshgrid(linspace(-0.5-0.5/xres,0.5+0.5/xres,xres+2),linspace(-0.5-0.5/yres,0.5+0.5/yres,yres+2)); % padded meshgrid
            
            intSfToImSfTransform = sf.affine()\obj.affine();
            if scanimage.mroi.util.isTransformRotating(intSfToImSfTransform) % interp2 does not accept rotated xx and yy
                [sfxx,sfyy] = scanimage.mroi.util.xformMesh(sfxx,sfyy,inv(intSfToImSfTransform)); % this is slow since we have to transform each point of the imaging scanfield
            else
                %performance optimization
                [xx,yy] = scanimage.mroi.util.xformMesh(xx,yy,intSfToImSfTransform); % transform intagration field space to imaging scanfield space
            end
            
            sfmask = interp2(xx,yy,mask_,sfxx,sfyy,'nearest',0);
            
%             %%% code for debugging
%             hFig = figure();
%             hAx = axes('Parent',hFig);
%             imagesc(sfmask,'Parent',hAx);
%             axis(hAx,'image');
%             title(hAx,'sfmask');
% 
%             hFig = figure();
%             hAx = axes('Parent',hFig,'YDir','reverse');
%             hold(hAx,'on');
%             plot(hAx,sfxx(:),sfyy(:),'.');
%             plot(hAx,xx(:),yy(:),'o');
%             hold(hAx,'off');
%             axis(hAx,'image');
%             title(hAx,'sfmask interpolation points');
        end
    end
    
    %% Static methods
    methods(Static)
        function obj=loadobj(s)
            obj=scanimage.mroi.scanfield.fields.IntegrationField();
            obj=scanimage.mroi.scanfield.ScanField.loadobj(s,obj);
            
            if isfield(s,'threshold'); obj.threshold = s.threshold; end
            if isfield(s,'channel')  ; obj.channel   = s.channel  ; end
            if isfield(s,'processor'); obj.processor = s.processor; end
            if isfield(s,'mask')     ; obj.mask      = s.mask     ; end
        end
    end
    
    %% Property setters / getters
    methods        
        function val = get.pixelResolutionXY(obj)
            val = [size(obj.mask,2) size(obj.mask,1)];
        end
        
        function set.threshold(obj,val)
            validateattributes(val,{'numeric'},{'scalar'});
            oldVal = obj.threshold;
            obj.threshold = val;
            
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.channel(obj,val)
            validateattributes(val,{'numeric'},{'scalar'});
            oldVal = obj.channel;
            obj.channel = val;
            
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.pixelStart(obj,val)
            oldVal = obj.pixelStart;
            obj.pixelStart = val;
            
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.pixelStop(obj,val)
            oldVal = obj.pixelStop;
            obj.pixelStop = val;
            
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.processor(obj,val)
            oldVal = obj.processor;
            if isempty(val)
                val = 'cpu';
            end
            val = lower(val);
            assert(~ismember(val,{'fpga'}),'Only supported processor is CPU'); % TODO: Implement support for FPGA integration
            assert(ismember(val,{'cpu','fpga'}),'Invalid processor: %s. Valid processors are ''FPGA'' or ''CPU''');
            obj.processor = val;
            
            obj.fireChangedEvent(oldVal,val);
            
            if strcmpi(obj.processor,'fpga');
                obj.mask = 1;
            end
        end
        
        function set.mask(obj,val)
            if isempty(val)
                val = 1;                
            end
            
            if strcmpi(obj.processor,'fpga');
                assert(val==1,'If scanfield processor is ''FPGA'', the mask value needs to be [1]');
            end
            
            oldVal = obj.mask;
            obj.mask = val;
            
            obj.fireChangedEvent(oldVal,val);
        end
    end
    
    methods (Access = protected)        
        function cpObj = copyElement(obj)
            cpObj = scanimage.mroi.scanfield.fields.IntegrationField();
            copyElement@scanimage.mroi.scanfield.ScanField(obj,cpObj);
            cpObj.threshold = obj.threshold;
            cpObj.channel = obj.channel;            
            cpObj.processor = obj.processor;
            cpObj.mask = obj.mask;
        end
    end
    
    methods (Static)
        function sf = createFromMask(imagingScanfield,mask)
            %% Creates an IntegrationField, where mask is applied to the given imagingScanfield
            % mask can have two formats:
            %  1) a mask that stretches over the entire imagingScanfield,
            %  so that for each pixel in the imagingScanfield a weighing
            %  value is given
            %  2) a nx3 array [x1,y1,v1; ... xn,yn,vn] xn and yn are the
            %  pixel coordinates (1 based) for the underlying
            %  imagingScanfield and vn is the weighing value for that pixel
            
            if isequal(fliplr(size(mask)),imagingScanfield.pixelResolutionXY)
                maskIdxs = find(mask);
                vals = mask(maskIdxs);
                [y,x] = ind2sub(fliplr(imagingScanfield.pixelResolutionXY),maskIdxs);
                mask = [x,y,vals];
            end
            
            assert(size(mask,2)==3);
            
            startXY = [min(mask(:,1)),min(mask(:,2))];
            stopXY = [max(mask(:,1)),max(mask(:,2))];
            width = stopXY(1)-startXY(1)+1;
            height = stopXY(2)-startXY(2)+1;
            
            sfmask = zeros(height,width);
            mask(:,1) = mask(:,1) - startXY(1) + 1;
            mask(:,2) = mask(:,2) - startXY(2) + 1;
            
            idxs = sub2ind(size(sfmask),mask(:,2),mask(:,1));
            sfmask(idxs) = mask(:,3);
            if length(unique(sfmask)) == 1
                sfmask = sfmask(1);
            end
            
            startXY = startXY-0.5;
            stopXY = stopXY+0.5;
            cornerXY = [startXY(1)+(stopXY(1)-startXY(1)),startXY(2)];
            
            startXYRef = scanimage.mroi.util.xformPoints(startXY,imagingScanfield.pixelToRefTransform);
            stopXYRef = scanimage.mroi.util.xformPoints(stopXY,imagingScanfield.pixelToRefTransform);
            cornerXYRef = scanimage.mroi.util.xformPoints(cornerXY,imagingScanfield.pixelToRefTransform);
            
            centerXY = startXYRef + (stopXYRef-startXYRef)./2;
            width = scanimage.mroi.util.distancePtPt(startXYRef,cornerXYRef);
            height = scanimage.mroi.util.distancePtPt(stopXYRef,cornerXYRef);
            
            rotationDegrees = imagingScanfield.rotationDegrees;
            
            sf = scanimage.mroi.scanfield.fields.IntegrationField();
            sf.centerXY = centerXY;
            sf.sizeXY = [width height] ./ 2;
            sf.rotationDegrees = rotationDegrees;
            sf.mask = sfmask;
        end
    end
end


%--------------------------------------------------------------------------%
% IntegrationField.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
