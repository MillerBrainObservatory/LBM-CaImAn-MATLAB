classdef AttributableProperties < handle
    %AttributableProperties
    
    % API changes from implementation in Model.m:
    %   * Validation/conversion information is set via the
    %   setPropertyAttributeFeatures method at any time rather than the structure
    %   created and used during construction in the original implementation.
    %
    %   * Preferred method is validateAttributes(...) rather than
    %   validatePropArg(..).  validatePropArg will be removed.
    %
    %   * DependsOn is no longer part of property validation/conversion attributes.
    %   It was only used by the controller for dependent property event
    %   notifications.  This functionality is now implemented in
    %   DependentProperties.
    %
    %   * This class offers convenience methods to return information about
    %   attributes (e.g., does it allow empty, what are the options).  These should
    %   be instead of directly inspecting/manipulating the attribute struct for a
    %   property. Access to the struct will become protected in the near future if
    %   it is not already which will require this for everything but subclasses.
    %   This keeps the particular implementation of attribute storage/configuration
    %   internal and easy to change if needed.
    %
    %   Syntax change for feature registration:
    %     * 'Attributes' argument should be single cell, not double cell.
    %     * It is now a function call on the object.
    %     * Example
    %         s.myprop = struct('Classes', 'numeric', 'Attributes', {{'scalar', 'positive', 'finite'}});
    %         becomes (note 'Attributes' PV pair change as well as method call)
    %         obj.setPropertyAttributeFeatures('myprop', 'Classes', 'numeric', 'Attributes', {'scalar', 'positive', 'finite'});
    
    properties (Hidden = true)
        AllowsAttributesForUnknownProperty = false;
        ValidatesPropertyDuringRegistration = true;
    end
    
    properties (Access = private)
        prvAttributedProperties = struct([]);
    end
    
    methods
        function self = AttributableProperties()
            self.defineDefaultPropertyAttributes();
        end
    end
    
    methods % Property Validation Methods        
        function val = validateAttributes(self, propertyName, val)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            
            if ~isfield(self.prvAttributedProperties, customFieldName)
                return;
            end
            
            attrCopy = self.prvAttributedProperties.(customFieldName);
            
            errorArs = {'AttributableProperties:invalidPropertyValue', 'Invalid value for property ''%s''.  Supplied:\n\t%s\n', propertyName};
            
            if ~isempty(attrCopy.CustomValidateFcn)
                try
                    val = feval(attrCopy.CustomValidateFcn, val);
                catch me
                    error(errorArs{:}, me.message);
                end
                return;
            end
            
            if ~isempty(attrCopy.Range)
                try
                    rangeAttribs = obj.zprvRangeData2Attribs(propname, attrCopy.Range);
                catch me
                    me.throwAsCaller();
                end
                attrCopy.Attributes = [attrCopy.Attributes, rangeAttribs];
            end
            
            if ~isempty(attrCopy.Size)
                try
                    sizeAttribs = obj.zprvSizeData2Attribs(propname, attrCopy.Size);
                catch me
                    me.throwAsCaller();
                end
                attrCopy.Attributes = [attrCopy.Attributes, sizeAttribs];
            end
            
            if ~isempty(attrCopy.Options)
                if ischar(attrCopy.Options)
                    attrCopy.Options = obj.(attrCopy.Options);
                end
            end
            
            if ~isempty(attrCopy.List)
                listVal = attrCopy.List;
                if ischar(listVal)
                    switch lower(listVal)
                        case {'vector' 'fullvector'}
                        otherwise
                            attrCopy.List = obj.(listVal);
                    end
                end
            end
            
            if attrCopy.AllowEmpty
                assert(~any(cellfun(@(item)ischar(item) && strcmpi(item, 'nonempty'), attrCopy.Attributes)), ...
                    'AttributableProperties:conflictingattributes', '%s: AllowEmpty is true however, ''nonempty'' is specified attribute.', propertyName);
                
                attrCopy.AllowEmpty = true;
            else
                if ~isempty(attrCopy.Options) && iscell(attrCopy.Options)
                    % Attribs ignored when using cell options (TODO?).
                else
                    attrCopy.Attributes = [attrCopy.Attributes 'nonempty'];
                end
            end
            
            stringAttributes = attrCopy.Attributes(cellfun(@ischar, attrCopy.Attributes));
            
            if isempty(attrCopy.Options) && ~attrCopy.AllowEmpty && ~any(strcmpi('string', attrCopy.Classes)) && ~any(ismember({'nonscalar' 'size' 'numel' 'vector'}, lower(stringAttributes)))
                attrCopy.Attributes = [attrCopy.Attributes, 'scalar'];
            end
            
            cellPV = most.util.structPV2cellPV(attrCopy);
            
            try
                most.mimics.validateAttributes(val, cellPV{:});
            catch me
                error(errorArs{:}, me.message);
            end
        end
    end
    
    methods
        function out = isAttributedProperty(self, propertyName)
            out = isfield(self.prvAttributedProperties, most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName));
        end
        
        function out = allowedClasses(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                out = self.prvAttributedProperties.(customFieldName).Classes;
            else
                out = [];
            end
        end
        
        function out = propertyIsNumeric(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                classList = self.prvAttributedProperties.(customFieldName).Classes;
                out = ismember(classList, {'numeric' 'single' 'double' 'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'});
            else
                out = false;
            end
        end
        
        function out = propertyIsLogical(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                % If Options is non-empty, just look at the individual
                % options to see if they're all logical.
                % If Options is empty, check Classes.
                if ~isempty(self.prvAttributedProperties.(customFieldName).Options) ,
                    optionList=self.prvAttributedProperties.(customFieldName).Options;
                    isLogicalEach=cellfun(@(x)(ismember(x, {'logical', 'binaryflex', 'binarylogical', 'binarynumeric'})), ...
                                          optionList);
                    out = all(isLogicalEach);                  
                else
                    classList = self.prvAttributedProperties.(customFieldName).Classes;
                    out = ismember(classList, {'logical', 'binaryflex', 'binarylogical', 'binarynumeric'});
                end
            else
                out = false;
            end
        end
        
        function out = propertyIsString(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                classList = self.prvAttributedProperties.(customFieldName).Classes;
                out = ismember(classList, {'char'});
            else
                out = false;
            end
        end
        
         function out = propertyIsEnum(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                classList = self.prvAttributedProperties.(customFieldName).Classes;
                out = numel(classList) == 1 && most.idioms.isenum(classList{1});
            else
                out = false;
            end
        end
        
       function out = propertyAllowsEmpty(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                out = self.prvAttributedProperties.(customFieldName).AllowEmpty;
            else
                out = false;
            end
        end
        
        function out = propertyIsList(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if isfield(self.prvAttributedProperties, customFieldName)
                out = ~isempty(self.prvAttributedProperties.(customFieldName).List);
            else
                out = false;
            end
        end
        
        function options = getPropertyOptions(self, propertyName)
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            
            options = [];
            
            if isfield(self.prvAttributedProperties, customFieldName) && ~isempty(self.prvAttributedProperties.(customFieldName).Options)
                
                options = self.prvAttributedProperties.(customFieldName).Options;
                
                if ischar(options)
                    assert(isprop(self, options), 'AttributableProperties:invalidoptionsproperty', 'Invalid Options property metadata supplied for property ''%s''.', propertyName);
                    options = self.(options);
                end
            end
        end
        
        function attrCopy = propertyAttributes(self, propertyName)
            warning('AttributableProperties:invalidoptionsproperty', 'Use an existing convenience function or add an appropriate one.');
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            if self.isAttributedProperty(customFieldName)
                attrCopy = self.prvAttributedProperties.(customFieldName);
            else
                attrCopy = struct();
            end
        end
    end
    
    methods (Access = protected)
        function setPropertyAttributeFeatures(self, propertyName, varargin)
            narginchk(2, Inf);
            
            if ~self.AllowsAttributesForUnknownProperty
                if isempty(strfind(propertyName, '.'))
                    assert(isprop(self, propertyName), 'AttributableProperties:invalidproperty', '%s is not a recognized property for %s', propertyName, class(self));
                else
                    % TODO else check for valid key path.
                end
            end
            
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            
            if isempty(self.prvAttributedProperties) || ~isfield(self.prvAttributedProperties, customFieldName)
                self.prvAttributedProperties(1).(customFieldName) = most.mixin.AttributableProperties.zsprvCreateDefaultAttribute(propertyName);
            end
            
            requestDefault = false;
            
            for idx = 1:2:(nargin-2)
                value = varargin{idx + 1};
                
                assert(isfield(self.prvAttributedProperties.(customFieldName), varargin{idx}), 'AttributableProperties:invalidfeature', '%s is not a recognized property attribute feature.', varargin{idx});
                
                switch varargin{idx}
                    case 'Classes'
                        validateattributes(value, {'char', 'cell'}, {});
                        if ~iscell(value)
                            value = {value};
                        else
                            assert(iscellstr(value), 'AttributableProperties:invalidclasslist', 'Valid classes must be a string or cellstr.');
                        end
                    case 'Attributes'
                        validateattributes(value, {'char', 'cell'}, {});
                        if ~iscell(value)
                            value = {value};
                        end
                        if isempty(self.prvAttributedProperties.(customFieldName).Classes)
                            self.prvAttributedProperties.(customFieldName).Classes = {'numeric'};
                        end
                    case {'Range', 'Size'}
                        if isempty(self.prvAttributedProperties.(customFieldName).Classes)
                            self.prvAttributedProperties.(customFieldName).Classes = {'numeric'};
                        end
                    case {'Options', 'List'}
                        requestDefault = true;
                end
                
                self.prvAttributedProperties.(customFieldName).(varargin{idx}) = value;
            end
            
            if requestDefault
                self.requestPropertyDefaultValue(customFieldName);
            end
            
            if self.ValidatesPropertyDuringRegistration
                % TODO
                % validateAttributes(self, propertyName, self.(propertyName));
            end
        end
        
        function removePropertyAttributeFeatures(self, propertyName)
            narginchk(2, 2);
            
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            
            if ~isempty(self.prvAttributedProperties) && isfield(self.prvAttributedProperties, customFieldName)
                self.prvAttributedProperties = rmfield(self.prvAttributedProperties, customFieldName);
            end
        end
        
        function defineDefaultPropertyAttributes(~)
            %defineDefaultPropertyAttributes Configure default property attributes.
            %
            %   defineDefaultPropertyAttributes is called by the AttributableProperties
            %   constructor.  This method provides an opportunity for subclasses to define
            %   attributed properties and to have that method automatically called when the
            %   object is created. The default implementation isempty.
            %
            %   Subclasses can define attributed properties at any time during or after
            %   object constructor and do not need to rely on this method.
        end
    end
    
    methods (Access = private)
        function sizeAttributes = zprvSizeData2Attribs(obj, propname, sizeData)
            
            errorArgs = {'Invalid ''Size'' property metadata supplied for property ''%s''.', propname};
            
            if ischar(sizeData)
                sizeAttributes = obj.zprvSizeData2Attribs(propname, obj.(sizeData));
            elseif isnumeric(sizeData)
                sizeAttributes = {'Size', sizeData};
            elseif iscell(sizeData)
                sizeVal = zeros(size(sizeData));
                for j=1:numel(sizeData)
                    sizeDataVal = sizeData{j};
                    if isnumeric(sizeDataVal)
                        sizeVal(j) = sizeDataVal;
                    elseif ischar(sizeDataVal) && ~isempty(findprop(obj,sizeDataVal))
                        tmp = obj.(sizeDataVal);
                        try
                            validateattributes(tmp, {'numeric'}, {'scalar' 'integer' 'nonnegative'});
                        catch %#ok<CTCH>
                            error('AttributableProperties:invalidSize',  errorArgs{:});
                        end
                        sizeVal(j) = tmp;
                    else
                        error('AttributableProperties:invalidSize', errorArgs{:});
                    end
                end
                sizeAttributes = {'Size', sizeVal};
            else
                error('AttributableProperties:invalidSize', errorArgs{:});
            end
        end
        
        function attribs = zprvRangeData2Attribs(obj, propname, rangeMD)
            errorArgs = {'Invalid ''Range'' property metadata supplied for property ''%s''.' propname};
            
            if ischar(rangeMD)
                attribs = obj.zprvRangeData2Attribs(propname, obj.(rangeMD));
            elseif isnumeric(rangeMD)
                assert(numel(rangeMD) == 2, errorArgs{:});
                attribs = {'Range', rangeMD};
            elseif iscell(rangeMD)
                assert(numel(rangeMD) == 2, errorArgs{:});
                rangeVal = nan(1 ,2);
                for idx = 1:2
                    if isnumeric(rangeMD{idx})
                        rangeVal(idx) = rangeMD{idx};
                    elseif ischar(rangeMD{idx})
                        rangeVal(idx) = obj.(rangeMD{idx}); % better be a numeric scalar
                    else
                        error('AttributableProperties:invalidRange',errorArgs{:});
                    end
                end
                attribs = {'Range', rangeVal};
            else
                error('AttributableProperties:invalidRange',errorArgs{:});
            end
        end
        
        function requestPropertyDefaultValue(self, propertyName)
            
            customFieldName = most.mixin.AttributableProperties.zsprvFieldnameForProperty(propertyName);
            
            attrCopy = self.prvAttributedProperties.(customFieldName);
            
            if ~isempty(attrCopy.Options) && isempty(self.(customFieldName)) && ~attrCopy.AllowEmpty
                optionsList = attrCopy.Options;
                
                if ischar(optionsList)
                    optionsList = self.(attrCopy.Options);
                end
                
                if isnumeric(optionsList)
                    if isvector(optionsList)
                        defaultOption = optionsList(1);
                    elseif ndims(optionsList)
                        defaultOption = optionsList(1,:);
                    else
                        assert(false);
                    end
                elseif iscellstr(optionsList)
                    defaultOption = optionsList{1};
                else
                    assert(false);
                end
                
                
                if isfield(attrCopy, 'List')
                    listSpec = attrCopy.List;
                    
                    if ischar(listSpec) && ~ismember(lower(listSpec), {'vector' 'fullvector'})
                        listSpec = self.(attrCopy.List);
                    end
                    
                    if isnumeric(listSpec)
                        if isscalar(listSpec)
                            initSize = [listSpec 1];
                        else
                            initSize = listSpec;
                        end
                    else %inf, 'vector', 'fullvector' options -- init with scalar value
                        initSize = [1 1];
                    end
                    
                    self.(propertyName) = repmat({defaultOption}, initSize);
                else
                    self.(propertyName) = defaultOption;
                end
                
            end
        end
    end
    
    methods (Static = true, Access = private)
        function out = zsprvFieldnameForProperty(propertyName)
            if isempty(strfind(propertyName, '.'))
                out = propertyName;
            else
                out = strrep(propertyName, '.', '___');
            end
        end
        
        function attrib = zsprvCreateDefaultAttribute(name)
            attrib.PropertyName = name;
            attrib.Classes = {};
            attrib.Attributes = {};
            attrib.AllowEmpty = false;
            attrib.Size = [];
            attrib.Range = [];
            attrib.Options = {};
            attrib.List = [];
            attrib.CustomValidateFcn = [];
        end
    end
end


%--------------------------------------------------------------------------%
% AttributableProperties.m                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
