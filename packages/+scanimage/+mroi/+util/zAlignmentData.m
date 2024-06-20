classdef zAlignmentData
    properties (SetAccess = private)
        refZ = [];
        scannerZ = [];
        alignmentCompensation = double.empty(3,3,0);
    end
    
    properties
        interpolationMethod = 'linear';
        extrapolationMethod = 'linear';
    end
    
    %% LifeCycle
    methods
        function obj = zAlignmentData(struct_)
            if nargin > 0 && ~isempty(struct_)
                obj = obj.loadStruct(struct_);
            end
        end
    end
    
    methods
        function obj = loadStruct(obj,struct_)
            if isstruct(struct_)
                if isfield(struct_,'refZ')
                    obj.refZ = struct_.refZ;
                end
                
                if isfield(struct_,'scannerZ')
                    obj.scannerZ = struct_.scannerZ;
                end
                
                if isfield(struct_,'alignmentCompensation')
                    obj.alignmentCompensation = struct_.alignmentCompensation;
                end
                
                if isfield(struct_,'interpolationMethod')
                    obj.interpolationMethod = struct_.interpolationMethod;
                end
                
                if isfield(struct_,'extrapolationMethod')
                    obj.extrapolationMethod = struct_.extrapolationMethod;
                end
            end
        end
        
        function out = toStruct(obj)
            out = struct();
            out.refZ = obj.refZ;
            out.scannerZ = obj.scannerZ;
            out.alignmentCompensation = obj.alignmentCompensation;
            out.interpolationMethod = obj.interpolationMethod;
            out.extrapolationMethod = obj.extrapolationMethod;
        end
        
        function path = compensateScannerZ(obj,path,invert)
            if nargin < 3 || isempty(invert)
                invert = false;
            end
            
            if ischar(invert)
                switch lower(invert)
                    case 'invert'
                        invert = true;
                    otherwise
                        error('Unknown parameter: %s',invert);
                end
            end
            
            if isempty(obj.refZ)
                return
            end
            
            if ~invert
                path(:,3) = obj.interpolateZ(path(:,3),invert);
                path = compensateAlignment(path,invert);
            else
                path(:,3) = compensateAlignment(path(:,3),invert);
                path = obj.interpolateZ(path,invert);
            end
            
            %%% local function
            function path = compensateAlignment(path,invert)
                if isempty(obj.alignmentCompensation)
                    return
                end
                
                zs = unique(path(:,3));
                Ts = obj.interpolateAlignment(zs);
                
                for zIdx = 1:length(zs)
                    z = zs(zIdx);
                    
                    zMask = path(:,3)==z;
                    path(zMask,1:2) = scanimage.mroi.util.xformPoints(path(zMask,1:2),Ts(:,:,zIdx),invert);
                end
            end
        end
        
        function zs = refZtoScannerZ(obj,zs)
            zs = obj.interpolateZ(zs);
        end
        
        function zs = scannerZtoRefZ(obj,zs)
            zs = obj.interpolateZ(zs,true);
        end
        
        function zs = interpolateZ(obj,zs,invert)
            if nargin < 3 || isempty(invert)
                invert = false;
            end
            
            if isempty(obj.refZ)
                return;
            end
            
            % interpolate Z
            refZ_ = obj.refZ(:);
            scannerZ_ = obj.scannerZ(:);
            
            if isscalar(refZ_)
                refZ_ = [refZ_; refZ_+1];
                scannerZ_ = [scannerZ_; scannerZ_+1];
            end
            
            if ischar(invert)
                switch lower(invert)
                    case 'invert'
                        invert = true;
                    otherwise
                        error('Unknown parameter: %s',invert);
                end
            end
            
            
            
            if ~invert
                [refZ_,idxs] = sort(refZ_);
                scannerZ_ = scannerZ_(idxs);
                zInt = griddedInterpolant(refZ_(:),scannerZ_(:),...
                    obj.getActualInterpolationMethod(obj.interpolationMethod),...
                    obj.getActualInterpolationMethod(obj.extrapolationMethod));
                zs = zInt(zs);
            else
                [scannerZ_,idxs] = sort(scannerZ_);
                refZ_ = refZ_(idxs);
                zInt = griddedInterpolant(scannerZ_(:),refZ_(:),...
                    obj.getActualInterpolationMethod(obj.interpolationMethod),...
                    obj.getActualInterpolationMethod(obj.extrapolationMethod));
                zs = zInt(zs);
            end
        end
        
        function Ts = interpolateAlignment(obj,zs)
            scannerZ_ = obj.scannerZ(:);
            alignmentCompensation_ = obj.alignmentCompensation;
            
            if isempty(scannerZ_)
                Ts = repmat(eye(3),1,1,numel(zs));
                return
            end
            
            if isscalar(scannerZ_)
                Ts = alignmentCompensation_;
                return
            end
            
            [scannerZ_,idxs] = sort(scannerZ_);
            alignmentCompensation_ = alignmentCompensation_(:,:,idxs);
            
            [meshXX,meshYY,meshZZ] = ndgrid(1:3,1:3,scannerZ_);
            meshInt = griddedInterpolant(meshXX,meshYY,meshZZ,alignmentCompensation_,...
                obj.getActualInterpolationMethod(obj.interpolationMethod),...
                obj.getActualInterpolationMethod(obj.extrapolationMethod));
            
            zs = shiftdim(zs(:),-2);
            Ts = meshInt(repmat(meshXX(:,:,1),1,1,length(zs)),repmat(meshYY(:,:,1),1,1,length(zs)),repmat(zs,3,3,1));
        end
        
        function obj = addPoint(obj,refZ,scannerZ,alignmentCompensation)
            validateattributes(refZ,{'numeric'},{'scalar','finite','nonnan'});
            validateattributes(scannerZ,{'numeric'},{'scalar','finite','nonnan'});
            validateattributes(alignmentCompensation,{'numeric'},{'size',[3,3],'finite','nonnan'});
            
            obj = obj.removePoint(refZ); % ensure there are no duplicate entries
            
            refZ = vertcat(obj.refZ,refZ(:));
            scannerZ = vertcat(obj.scannerZ,scannerZ(:));
            alignmentCompensation = cat(3,obj.alignmentCompensation,alignmentCompensation);
            
            [refZ,sortIdxs] = sort(refZ);
            obj.refZ = refZ;
            obj.scannerZ = scannerZ(sortIdxs);
            obj.alignmentCompensation = alignmentCompensation(:,:,sortIdxs);
        end
        
        function obj = removePoint(obj,refZ)
            if ~isempty(refZ)
                validateattributes(refZ,{'numeric'},{'vector','finite','nonnan'}); 
                refZ = unique(refZ);
                [tf,idx] = ismember(refZ,obj.refZ);
                idx = idx(tf);
                
                obj.refZ(idx) = [];
                obj.scannerZ(idx) = [];
                obj.alignmentCompensation(:,:,idx) = [];
            end
        end
        
        function obj = removePointByIdx(obj,idx)
            if ~isempty(idx)
                validateattributes(idx,{'numeric'},{'vector','finite','nonnan','integer','>',0});
                idx = unique(idx);
                
                obj.refZ(idx) = [];
                obj.scannerZ(idx) = [];
                obj.alignmentCompensation(:,:,idx) = [];
            end
        end
        
        function method = getActualInterpolationMethod(obj,method)
            numPoints = length(obj.refZ);
            
            if numPoints < 4 && ismember(lower(method),{'pchip','cubic','spline'})
                % pchip, cubic, spline need at least 4 points for
                % interpolation. If less then 4 points are available,
                % overwrite method with linear
                method = 'linear';
            end
        end
    end
end



%--------------------------------------------------------------------------%
% zAlignmentData.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
