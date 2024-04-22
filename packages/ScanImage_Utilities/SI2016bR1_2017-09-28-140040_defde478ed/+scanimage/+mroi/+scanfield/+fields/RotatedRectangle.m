classdef RotatedRectangle < scanimage.mroi.scanfield.ImagingField
    %% Abstract property realization scanimage.mroi.scanfield.ScanField
    properties (SetAccess = protected)
        shortDescription = 'Rotated Rect';
    end
    
    methods
        function obj=RotatedRectangle(rect,rotationDegrees,pixelResolutionXY)
            obj = obj@scanimage.mroi.scanfield.ImagingField();
            
            % maintain backward compatibility
            if nargin > 0 && ~isempty(rect)
                obj.rect = rect;
            end
            
            if nargin > 1 && ~isempty(rotationDegrees)
                obj.rotationDegrees = rotationDegrees;
            end
            
            if nargin > 2 && ~isempty(pixelResolutionXY)
                obj.pixelResolutionXY = pixelResolutionXY;
            end
        end
    end

    %% Abstract methods realization scanimage.mroi.scanfield.ScanField
    methods
        function T=affine(obj)
            % Returns the affine transform from pre-rotation to post-rotation
            
            %translation to origin (pre scaling)
            O=eye(3);
            O(:,3)=[-0.5 -0.5 1];
            
            %rotation by obj.degrees
            R=eye(3);
            radians=obj.rotationDegrees*pi/180;
            c=cos(radians);
            s=sin(radians);
            R(1:2,1:2)=[c -s; s c];

            %scaling
            S=diag([obj.sizeXY 1]);
            
            %translation to rect center
            C=eye(3);
            C(:,3)=[obj.centerXY(1) obj.centerXY(2) 1];

            T = C*R*S*O;
        end
        
        function rect=boundingbox(obj)
            p=obj.points();
            mns=min(p,[],2);
            d=max(p,[],2)-mns;
            rect=[mns(1) mns(2) d(1) d(2)];
        end
        
        function pts=cornerpoints(obj)
            pts = [0,0;1,0;1,1;0,1];
            pts = scanimage.mroi.util.xformPoints(pts,obj.affine);
        end

        function [xs,ys]=transform(obj,xs,ys)
            % Transforms points from unit-scan space to fov space
            [xs,ys] = scanimage.mroi.util.xformPointsXY(xs,ys,obj.affine);
        end
        
        function setByAffineParams(obj, p)
            obj.rect = [p.offsetX+.5-p.scaleX/2 p.offsetY+.5-p.scaleY/2 p.scaleX p.scaleY];
            obj.degrees = p.rotation;
        end
    end
    
    %% Public methods
    methods
        function out=interpolate(obj,other,frac)
            out = scanimage.mroi.scanfield.fields.RotatedRectangle();
            out = interpolate@scanimage.mroi.scanfield.ImagingField(obj,other,frac,out);
        end
    end
    
    %% Hidden methods
    methods (Hidden)
        function s = saveobj(obj)
            s = struct();
            s = saveobj@scanimage.mroi.scanfield.ImagingField(obj,s);
            
            s.pixelToRefTransform = obj.pixelToRefTransform;
            s.affine = obj.affine;
        end
    end
    
    %% Protected methods
    methods (Access = protected)
        function cpObj = copyElement(obj)
            cpObj = scanimage.mroi.scanfield.fields.RotatedRectangle();
            cpObj = copyElement@scanimage.mroi.scanfield.ImagingField(obj,cpObj);
        end
    end
    
    %% Private methods
    methods (Access = private)
        function r=points(obj)
            % returns 2 x 4 points.  First row xs, second row ys.
            % Corner points of rect rotated about the center.
            xs=[0 0 1 1];
            ys=[0 1 1 0];
            r=[xs;ys;ones(size(xs))];
            r=obj.affine()*r;
            r=r(1:2,:);
        end

        function rr=inverse(obj,xs,ys)
            % Maps points form field-of-view coordinates back to the unrotated
            % space for hit detection
            r=[xs(:) ys(:) ones(size(xs(:)))]';
            rr=obj.affine()\r;
            rr=rr(1:2,:);
        end
    end
    
    %% Static methods
    methods(Static)
        function obj=loadobj(s)            
            obj=scanimage.mroi.scanfield.fields.RotatedRectangle();
            obj=scanimage.mroi.scanfield.ImagingField.loadobj(s,obj);
        end
    end
end


%--------------------------------------------------------------------------%
% RotatedRectangle.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
