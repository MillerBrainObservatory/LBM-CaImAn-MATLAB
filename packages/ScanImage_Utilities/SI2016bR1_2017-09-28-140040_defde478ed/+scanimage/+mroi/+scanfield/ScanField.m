classdef ScanField < scanimage.mroi.RoiTree
    %% property definitions
    properties (Abstract, SetAccess = protected)
        shortDescription;   % string, description for GUI
    end
    
    properties(SetObservable,AbortSet)
        enable = true;
        centerXY = [0 0];  % [x,y] center of the scanfield in reference coordinates
        sizeXY = [10 10];        % size [width, height] of the scanfield in reference coordinates
        rotationDegrees = 0;   % rotation in degrees of the scanfield in reference coordinates
    end
    
    properties(Dependent, Hidden)
        %%% legacy properties, maintain for backwards compatibility
        rect;
        rotation;
        degrees;
    end
    
    properties (Dependent)
        transformParams;
    end
    
    properties (SetAccess = protected, Hidden)
        transformParams_ = [];
    end
    
    %% Lifcecycle
    methods
        function obj = ScanField()
            obj = obj@scanimage.mroi.RoiTree();
        end
        
        function delete(obj)
            % No-op
        end
    end
    
    %% Abstract methods
    methods(Abstract)        
        % Returns the bounding rectangle as [x y width height]
        % in field-of-view coordinates: (0,0) is top-left and
        % (1,1) is bottom right.
        rect=boundingbox(obj);
        pts=cornerpoints(obj);
        
        % Transforms points from a a unit box to
        % field-of-view coordinates.
        [xs,ys]=transform(obj,xs,ys);
        
        % Affine matrix that transform scanfield coordinates to scanner
        % coordinates
        T = affine(obj);
        
        % Set the scanfield position using parameters of an affine matrix
        setByAffineParams(obj,prms);
    end
    
    %% Public methods
    methods
        % Generate a new scan field by interpolating between this and other
        % frac should be between 0 and 1.
        function out = interpolate(obj,other,frac,out)
            assert(isa(other,class(obj)),'MROI:TypeError','Got an argument of class %s. Expected %s.',class(other),class(obj));
            
            out.centerXY = interpolateProp(obj,other,frac,'centerXY');
            out.sizeXY = interpolateProp(obj,other,frac,'sizeXY');
            
            shortest_angle=mod( mod(other.rotationDegrees-obj.rotationDegrees,360)+540,360) - 180;
            out.rotationDegrees = shortest_angle.*frac + obj.degrees;
        end

        function s=saveobj(obj,s)
            s = saveobj@scanimage.mroi.RoiTree(obj,s);
            
            s.centerXY = obj.centerXY;
            s.sizeXY = obj.sizeXY;
            s.rotationDegrees = obj.rotationDegrees;            
            s.enable = obj.enable;
        end
        
        function tf = isnan(~)
            tf = false;
        end
    end
    
    %% protected methods
    methods(Access = protected)
        % Override copyElement method:
        % cpObj = copyElement(obj);
        function cpObj = copyElement(obj,cpObj)            
            cpObj = copyElement@scanimage.mroi.RoiTree(obj,cpObj);
            
            cpObj.centerXY = obj.centerXY;
            cpObj.sizeXY = obj.sizeXY;
            cpObj.rotationDegrees = obj.rotationDegrees;
        end
        
        function val = interpolateProp(obj,other,frac,propname)
            otherprop = other.(propname);
            thisprop = obj.(propname);
            
            if isequal(size(otherprop),size(thisprop)) || (numel(otherprop) == 1) || (numel(thisprop) == 1)
                val = (otherprop - thisprop) .* frac + thisprop;
            else
                fprintf(2, 'Could not interpolate scanfields. Inconsistent matrix sizes for property %s.%s. Expected: %s Actual: %s\n',...
                    obj.shortDescription,propname,mat2str(size(otherprop)),mat2str(size(thisprop)));
                val = thisprop;
            end
        end

        function fireChangedEvent(obj,oldVal,newVal)
            if nargin == 3
                changed = ~isequal(oldVal,newVal);
            else
                changed = true;
            end
            
            if changed
                fireChangedEvent@scanimage.mroi.RoiTree(obj);
            end
        end
    end
    
    %% Property getter/setter methods
    methods        
        function set.centerXY(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2});
            oldVal = obj.centerXY;
            obj.centerXY = val;
            
            obj.transformParams_ = [];
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.sizeXY(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',2});
            oldVal = obj.sizeXY;
            obj.sizeXY = val;
            
            obj.transformParams_ = [];
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.rotationDegrees(obj,val)
            validateattributes(val,{'numeric'},{'scalar'});
            
            oldVal = obj.rotationDegrees;
            val = mod(val,360);
            obj.rotationDegrees = val;
            
            obj.transformParams_ = [];
            obj.fireChangedEvent(oldVal,val);
        end
        
        function set.enable(obj,val)
            oldVal = obj.enable;
            obj.enable = logical(val);
            obj.fireChangedEvent(oldVal,val);
        end
        
        function v = get.transformParams(obj)
            if isempty(obj.transformParams_)
                [a.offsetX,a.offsetY,a.scaleX,a.scaleY,a.rotation,a.shear] = scanimage.mroi.util.paramsFromTransform(obj.affine);
                obj.transformParams_ = a;
            end
            v = obj.transformParams_;
        end
        
        
        function setByAffine(obj,T)
            [a.offsetX,a.offsetY,a.scaleX,a.scaleY,a.rotation,a.shear] = scanimage.mroi.util.paramsFromTransform(T);
            obj.setByAffineParams(a);
        end
        
        %%% legacy properties, maintain for backwards compatibility
        function set.rotation(obj,val)
            obj.rotationDegrees = val;
        end
        
        function val = get.rotation(obj)
            val = obj.rotationDegrees;            
        end
        
        function set.degrees(obj,val)
            obj.rotationDegrees = val;
        end
        
        function val = get.degrees(obj)
            val = obj.rotationDegrees;
        end
        
        function set.rect(obj,val)
            validateattributes(val,{'numeric'},{'row','numel',4});
            obj.centerXY = [val(1)+val(3)/2 val(2)+val(4)/2];
            obj.sizeXY = val(3:4);
        end
        
        function val = get.rect(obj)
            topcorner = obj.centerXY - obj.sizeXY./2;
            val = [topcorner, obj.sizeXY];
        end
    end
    
    %% static methods
    methods(Static)
        function obj=loadobj(s,obj)
            if nargin < 2 || isempty(obj) || ~isvalid(obj)
                if isfield(s,'classname'); classname=s.classname;end
                if isfield(s,'type')     ; classname=s.type ;end % maintain backward compatibility
                
                mc=meta.class.fromName(classname);
                if(any(mc.SuperclassList==?scanimage.mroi.scanfield.ImagingField))
                    obj=scanimage.mroi.scanfield.ImagingField.loadobj(s);
                elseif mc==?scanimage.mroi.scanfield.fields.StimulusField
                    obj=scanimage.mroi.scanfield.fields.StimulusField.loadobj(s);
                elseif mc==?scanimage.mroi.scanfield.fields.IntegrationField
                    obj=scanimage.mroi.scanfield.fields.IntegrationField.loadobj(s);
                else
                    error('MROI:loadobj','Unrecognized scanfield type.');
                end
            else
                loadobj@scanimage.mroi.RoiTree(obj,s);
                
                if isfield(s,'enable')  ; obj.enable = s.enable    ; end
                if isfield(s,'centerXY'); obj.centerXY = s.centerXY; end
                if isfield(s,'sizeXY')  ; obj.sizeXY = s.sizeXY    ; end
                if isfield(s,'rotationDegrees'); obj.rotationDegrees = s.rotationDegrees; end
                
                %%% maintain compatibility with legacy properties
                if isfield(s,'rect')     ; obj.rect = s.rect               ; end
                if isfield(s,'scalingXY'); obj.sizeXY = s.scalingXY*2      ; end
                if isfield(s,'rotation') ; obj.rotationDegrees = s.rotation; end
                if isfield(s,'degrees')  ; obj.rotationDegrees = s.degrees ; end
            end
        end
    end
end

% CONCEPTS
%{

# Spaces

These functions need to do mapping between a few different coordinate
systems.  It's important to understand what they are.

## Scan-unit space

A unit-square spanning the bounding rectangle of a 2d scan field for a
region of interest.  This space is used to generate the control points for
which analog output will be generated.  (0,0) is the top-left corner of the
scanfield; (1,1) the farthest corner.

## Field-of-view space

This is a unit square.  The origin is at (0,0).  The far corner is at
(1,1).

Conceptually, this represents the two-dimensional field of view that can be
scanned by a set of scanners.  For example: (0,0) would be full negative
deflection on a couple of mirrors and (1,1) would be the full positive
deflection.

%}


%--------------------------------------------------------------------------%
% ScanField.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
