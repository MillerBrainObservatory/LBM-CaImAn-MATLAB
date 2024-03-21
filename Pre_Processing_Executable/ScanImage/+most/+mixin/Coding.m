classdef Coding < handle
%most.mixin.Coding   Mixin class to provide saving and loading of settings.
%
%   most.mixin.Coding is a mixin class that provides support for saving and
%   loading aspects of an object's state.  This is similar to picking
%   (a.k.a. serializing), but note that the intended use case of this is
%   really _not_ to entirely capture an object's state in a serialized
%   form.  Rather, this mixin allows one to tag object properties with
%   information about what file types (cfg, usr, header) they should be
%   included in, and then only pickle the properties appropriate to a given
%   file type.  This allows different aspects of object state to be stored in
%   different files.  For instance, Ephus has (at least) two different
%   kinds of configuration files: .usr files and .cfg files.  .usr files
%   store per-user configuration settings (like a .bashrc or a .emacs file
%   in Unix), whereas .cfg stores the setup for a particular kind of trial
%   (like a .pro "protocol" file in Clampex).  The properties that get
%   stored in the different file types can be tagged appropriately, so that
%   the ones that should be stored in the .usr can be easily extracted and
%   stored there, and the ones that should be stored in the .cfg file can
%   be extracted and stored there.
%
%   Further, it provides the useful guarantee that when serialized settings
%   are applied (decoded) to an object, they will be applied in the order
%   they occur in the serialized form.  (This is often helpful when dealing
%   with hardware settings.)
%
%   At present, all of the encode*() methods return Matlab structs, but
%   this is an implementation detail, and may change in the future.  (Yes,
%   Matlab structs preserve field ordering.)
%
%   A trivial use case of this mixin would be something like this:
%
%       classdef MyThing < most.mixin.Coding
%           properties
%               A
%               B
%           end
%           methods
%               function self = MyThing(a,b)
%                   self.A=a;
%                   self.B=b;
%               end
%           end
%       end
%
%       mt1=MyThing(1,{1 2 3})
%       mt2=MyThing('alpha','beta')
%       s1=mt1.encodePublicProperties()  % s1 is a struct that looks a lot
%                                        % like mt1
%       originalValues=mt2.decodeProperties(s1);  % Don't care about originalValues
%       mt2  % is now a clone of mt1
%
%   This is not necessarrily a great example, because it doesn't really
%   illustrate the true power of this mixin...
%
%   (ALT, 2014-05-06, hopefully all of the above is true...)


    % API changes from implementation in Model.m:
    %   * The methods in this class encode property values (in a struct, but this is
    %   an implementation detail), but do not perform loading/saving from/to disk.
    %   This is still handled in the model class.  The allows object property
    %   encoding to be used for other purposes (e.g, transmit across the network).
    
    %   * Saving and loading different sets of properties has been made more
    %   generic.  There are no specific properties such as mdlHeaderExclude or
    %   defaults for 'config' and 'header'.
    %      * You can encode properties that were returned by defaultConfigProps with
    %      encodeConfigurableProperties.  This uses the same predicate for filtering
    %      properties.
    %      * You can encode properties that were returned by defaultHeaderProps with
    %      encodePublicNonhiddenPropertiesForFileType.  This uses the same predicate as well.
    %      * To include or exclude specific properties use the IncludeInFileTypes and
    %      ExcludeInFileTypes attributes, and pass the tag name to the encodeXYZ method.
    %      * encodeOnlyPropertiesExplicityTaggedForFileType can be used only save properties with the
    %      specified tag and does not pull anything in by default like the other
    %      encode methods do.
    %
    %      Example 1: This is same as calling mdlSaveHeader on an old Model with
    %      mdlDefaultHeaderProps empty:
    %        propSet = obj.encodePublicProperties()
    %      or
    %        propSet = obj.encodePublicNonhiddenPropertiesForFileType('');
    %
    %      Example 2: There is public property MoonPhase that should not be saved to
    %      the header, i.e., mdlDefaultHeaderProps would have been set to
    %      {'MoonPhase'}:
    %      First the Model object must set the exclude tag.  It does not have to be
    %      'hdr' - it just has to be whatever you are going to use in the encode
    %      call. (Somewhere in the model object you have called the following,
    %      perhaps during construction or initialization.  The could also be the
    %      standard Classes, Attributes, arguments, ignored here for simplicity.)
    %          obj.setPropertyAttributeFeatures('MoonPhase', 'ExcludeInFileTypes', {'hdr'});
    %      then when it is time to save/encode
    %          obj.encodePublicNonhiddenPropertiesForFileType('hdr');
    
    % Notes on object encoding:
    %   * If a child property is of type Coding, it will be encoded
    %   with the same rules being applied to the parent object.
    %   * If a child property is any other type of object, it will be encoded as
    %   itself (an object).  If the encoded parent is saved and loaded from MAT
    %   files the child object must support that (e.g., zero arg constructor).
    %   * To make an exception:
    %      * Mark the property name in the parent object containing the child object
    %      as an excluded property.  The object as a full unit (Coding
    %      or not) will be ignored during encoded.
    %      * To then save only specific fields of the child object use property
    %      paths.
    %
    %      Example: obj has a property called ChildObj and that child has a Name
    %      property that should be encoded.  ChildObj itself should not be included
    %      as a full object (perhaps it is not possible to save and load directly as
    %      an object in a MAT file because it is linked to hardware resources).
    %      First, tell object one to exclude the 'ChildObj' property for the 'cfg'
    %      tag:
    %        obj.setPropertyAttributeFeatures('ChildObj', 'ExcludeInFileTypes', {'cfg'});
    %      However, mark the 'Name' property of that child object for encoding:
    %        obj.setPropertyAttributeFeatures('ChildObj.Name', 'IncludeInFileTypes', {'cfg'});
    %      At this point any encoding method of obj that uses the 'cfg' tag will
    %      create an encoded structure that contains an entry for ChildObj.Name, but
    %      does not contain any other entries related to ChildObj.

    properties (Access = private)
        prvTaggedProperties = struct([]);
            % A struct with each field representing the set of tags
            % associated with a single property.  The name of each field is
            % a sanitized version of the property name, and the "tag set"
            % (the contents of the field) is itself a struct with at least three
            % fields:
            %
            %     PropertyName : the property name
            %     IncludeInFileTypes : a cellstring containing the list of
            %                          all file types into which this
            %                          property should be encoded.  (Can
            %                          also be a singleton cellstring with
            %                          the string '*', meaning include this
            %                          property in all file types.)
            %     ExcludeInFileTypes : a cellstring containing the list of
            %                          all file types into which this
            %                          property should _not_ be encoded.  (Can
            %                          also be a singleton cellstring with
            %                          the string '*', meaning exclude this
            %                          property from all file types.)
            %                          Exlusion overrides inclusion,
            %                          although having a file type in both
            %                          should probably generally be
            %                          avoided.
            %
            % (I'm not sure what's up with using a sanitized version of the
            % property name as the tag set field name.  The sanitization
            % replaces '.'s with '___'s [sic], so it seems to be intended
            % to supporting the tagging of subproperties.  But none of the
            % existing Wavesurfer code seems to take advantage of this.  So
            % it is likely vestigial. ---ALT, 2014-07-20)
    end
    
    events
        WillChangePropertySet  % generated just before one of the decode methods is called
        DidChangePropertySet  % generated just after one of the decode methods is called
    end
    
    methods
        function self = Coding()
            self.defineDefaultPropertyTags();  % subclasses override this method to tag properties
        end
        
        function out = encodeOnlyPropertiesExplicityTaggedForFileType(self, fileType)
            narginchk(2, 2);
            out = self.encodePropertiesSatisfyingPredicateForFileType([], fileType);
        end
        
%         function out = encodePublicProperties(self)
%             out = self.encodePublicNonhiddenPropertiesForFileType('');
%         end
        
        function out = encodePublicNonhiddenPropertiesForFileType(self, fileType)
            narginchk(2, 2);
            
            % Get all "public" properties (what used to be the default for "Header" props).
            fcn = @(x)(strcmpi(x.GetAccess,'public') && ~x.Hidden);
            out = self.encodePropertiesSatisfyingPredicateForFileType(fcn, fileType);
        end
        
%         function out = encodeConfigurableProperties(self)
%             out = self.encodeConfigurablePropertiesForFileType('');
%         end
        
        function out = encodeConfigurablePropertiesForFileType(self, fileType)
            narginchk(2, 2);
            
            % Get all "public" properties (what used to be the default for "Config" props).
            isConfigurableTest = ...
                @(x)(strcmpi(x.SetAccess,'public') && strcmpi(x.GetAccess,'public') && ...
                     ~x.Transient && ~x.Dependent && ~x.Constant && ~x.Hidden);
            out = self.encodePropertiesSatisfyingPredicateForFileType(isConfigurableTest, fileType);
        end
        
        function propNames = listPropertiesSatisfyingPredicateForFileType(self, predicateFunction, fileType)
            % List properties that satisfy the given predicate function,
            % or are explicitly tagged for inclusion in the given file type, but are not tagged for
            % exclusion in the given file type.  I.e. exclusion overrides
            % all.  If fileType is empty, encodes all properties satisfying
            % the predicate.  Properties are listed in the order they occur
            % in the classdef.
            narginchk(3, 3);
            
            if ~isempty(predicateFunction)
                propNamesSatisfyingPredicate = most.mixin.Coding.classPropertyNamesSatisfyingPredicate_(class(self), predicateFunction);
            else
                propNamesSatisfyingPredicate = {};
            end
            
            % Filter out or in any properies with the specified fileType.
            if ~isempty(fileType)
                includes = self.propertyNamesForFileType('IncludeInFileTypes',fileType);
                excludes = self.propertyNamesForFileType('ExcludeInFileTypes',fileType);
                propNames = setdiff(union(propNamesSatisfyingPredicate, includes, 'stable'), excludes, 'stable');
                  % Note that properties satisfying the predicate AND
                  % properties that were explicitly tagged as included are
                  % encoded, unless they are explicitly excluded.  Hence,
                  % exclusion overrides inclusion.
            else
                propNames=propNamesSatisfyingPredicate;
            end
        end
        
        function out = encodePropertiesSatisfyingPredicateForFileType(self, predicateFunction, fileType)
            % Encode properties that satisfy the given predicate function,
            % or are explicitly tagged for inclusion in the given file type, but are not tagged for
            % exclusion in the given file type.  I.e. exclusion overrides
            % all.  If fileType is empty, encodes all properties satisfying
            % the predicate.
            narginchk(3, 3);
            
            propNames = self.listPropertiesSatisfyingPredicateForFileType(predicateFunction, fileType);
            
            % Encode values into a structure.
            out = struct();
            for c = 1:numel(propNames)
                out = self.encodePropertyValue(out, propNames{c}, predicateFunction, fileType);
            end
        end
        
        function originalValues = decodeProperties(self, propSet)
            % Sets the properties in self to the values encoded in propSet.
            % Returns the _old_ property values from self in
            % originalValues.
            assert(isstruct(propSet));
            
            propNames = fieldnames(propSet);
            
            notify(self, 'WillChangePropertySet');
            
            try
                originalValues = struct();
                for c = 1:numel(propNames)
                    propName = propNames{c};
                    originalValue = self.decodePropertyValue(self, propSet, propName);
                    if ~isempty(originalValue) || ~isfield(originalValues, propName)
                        originalValues.(propName) = originalValue;
                    end
                end
            catch me
                notify(self, 'DidChangePropertySet');
                me.rethrow();
            end
            
            notify(self, 'DidChangePropertySet');
        end
        
        function setPropertyTags(self, propertyName, varargin)
            narginchk(2, Inf);
            
            tagSetName = most.mixin.Coding.tagSetNameFromPropertyName_(propertyName);
            
            if isempty(self.prvTaggedProperties) || ~isfield(self.prvTaggedProperties, tagSetName)
                self.prvTaggedProperties(1).(tagSetName) = most.mixin.Coding.createDefaultTagSet_(propertyName);
            end
            
            for idx = 1:2:(nargin-2)
                value = varargin{idx + 1};
                assert(isfield(self.prvTaggedProperties.(tagSetName), varargin{idx}), ...
                       'Coding:invalidfeature', ...
                       '%s is not a recognized property attribute feature.', ...
                       varargin{idx});
                self.prvTaggedProperties.(tagSetName).(varargin{idx}) = value;
            end
        end
        
%         function setPropertyTagsForObject(self, propertyName, childPropertyNames, varargin)
%             % Allows you to tag specific properties to include/exclude on a child object
%             % that is not a subclass of Coding.
%             self.setPropertyTags(propertyName);
%             for idx = 1:numel(childPropertyNames)
%                 self.setPropertyTags(sprintf('%s.%s', propertyName, childPropertyNames{idx}), varargin{:});
%             end
%         end
        
        function out = encodedVariableName(self)
            out = self.createDefaultEncodedVariableName();
        end
    
%         % TODO make generic to transform any property set into a string (encodeAsString)
%         % xxx make this more consistent with config?
%         function str = modelGetHeader(obj,subsetType,subsetList,numericPrecision)
%             % Get string encoding of the header properties of obj.
%             %   subsetType: One of {'exclude' 'include'}
%             %   subsetList: String cell array of properties to exclude from or include in header string
%             %   numericPrecision: <optional> Number of digits to use in string encoding of properties with numeric values. Default value used otherwise.
%             
%             if nargin < 4 || isempty(numericPrecision)
%                 numericPrecision = []; %Use default
%             end
%             
%             if nargin < 2 || isempty(subsetType)
%                 pnames =  obj.mdlDefaultHeaderProps;
%             else
%                 assert(nargin >= 3,'If ''subsetType'' is specified, then ''subsetList'' must also be specified');
%                 
%                 switch subsetType
%                     case 'exclude'
%                         pnames = setdiff(obj.mdlDefaultHeaderProps,subsetList);
%                     case 'include'
%                         pnames = subsetList;
%                     otherwise
%                         assert('Unrecognized ''subsetType''');
%                 end
%             end
%             
%             pnames = setdiff(pnames,obj.mdlHeaderExcludeProps);
%             
%             str = most.util.structOrObj2Assignments(obj,class(obj),pnames,numericPrecision);
%         end        
        
        function value=propertyNames(self)
            % Get the property names of self, in the same order as they are
            % specified in the classdef.
            className=class(self);
            value=most.mixin.Coding.classPropertyNames_(className);
        end        
    end  % public methods
    
    
    methods (Access = protected)
        function out = createDefaultEncodedVariableName(self)
            out = regexprep(class(self), '\.', '_');
        end
        
        function out = getPropertyValue(self, name)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to encode protected/private variables, or do
            % some other kind of transformation on encoding, this method can be overridden.
%             if isa(self,'ephus.system.Ephys') ,
%                 1+1;
%             end
            out = self.(name);
        end
        
        function setPropertyValue(self, name, value)
            % By default this behaves as expected - allowing access to public properties.
            % If a Coding subclass wants to decode protected/private variables, or do
            % some other kind of transformation on decoding, this method can be overridden.
            self.(name) = value;
        end
        
        function defineDefaultPropertyTags(~)
            % This method is called by the Coding constructor.  The intent
            % is that subclasses override this method to set the tags for
            % the object properties.  But if subclasses don't want to
            % bother to do that, then this do-nothing method gets called.
        end
    end  % protected methods
    
    
    methods (Access = private)        
        function out = encodeChildProperty(self, out, obj, parts)
            if isempty(obj)
                return;
            end
            
            if numel(parts) == 1
                out(1).(parts{1}) = obj.(parts{1});
            else
                if isfield(out, parts{1})
                    out(1).(parts{1}) = self.encodeChildProperty(out.(parts{1}), obj.(parts{1}), parts{2:end});
                else
                    out(1).(parts{1}) = self.encodeChildProperty(struct(), obj.(parts{1}), parts{2:end});
                end
            end
        end
                
        function s = encodePropertyValue(self, s, pname, fcn, fileType)
            pnameParts = regexp(pname, '\.', 'split');
            
            fieldName = pnameParts{1};
            
            if numel(pnameParts) > 1
                if isfield(s, pnameParts{1})
                    out = self.encodeChildProperty(s.(pnameParts{1}), self.(pnameParts{1}), pnameParts(2:end));
                else
                    out = self.encodeChildProperty(struct(), self.(pnameParts{1}), pnameParts(2:end));
                end
            else
                propertyValue = self.getPropertyValue(pname);
                if isobject(propertyValue) && ismethod(propertyValue,'encodeSettings') ,
                    % If the value has a custom settings serialization method, use that.
                    out = propertyValue.encodeSettings();
                elseif isa(propertyValue, 'most.mixin.Coding')
                    if isempty(propertyValue)
                        out = [];
                    else
                        for idx = 1:numel(propertyValue)
                            out(idx) = encodePropertiesSatisfyingPredicateForFileType(propertyValue(idx), fcn, fileType); %#ok<AGROW>
                        end
                    end
                else
                    try
                        out = propertyValue;
                    catch %#ok<CTCH>
                        out = [];
                        warning('Model:encodePropertyValue:ErrDuringPropGet',  'An error occured while getting property ''%s''.', pname);
                    end
                end
            end
            
            s.(fieldName) = out;
        end
        
        function originalValue = decodePropertyValue(self, target, propSet, pname)
            % In the target object, set the single property named by pname to the
            % value for pname given in the property settings structure
            % propSet.
            
            % Define a couple of useful utility functions
            function value=getPropertyValueOfTarget(self,target,propertyName)
                % Gets the value of propertyName from target, taking
                % advantage of self.getPropertyValue() if self==target
                if self == target
                    value = self.getPropertyValue(propertyName);
                else
                    value = target.(propertyName);
                end
            end                

            function setPropertyValueOfTarget(self,target,propertyName,newValue)
                % Sets the value of propertyName in target, taking
                % advantage of self.setPropertyValue() if self==target
                if self == target
                    self.setPropertyValue(propertyName, newValue);
                else
                    target.(propertyName) = newValue;
                end
            end
            
            % Get the current value of the property to be set (which might
            % be a handle, and thus suitable as a LHS)
            % something we can assign to, generally a handle.
            % if self == target
            %     property = self.getPropertyValue(pname);
            % else
            %     property = target.(pname);
            % end
            property=getPropertyValueOfTarget(self,target,pname);
            
            % At this point, property should be a handle to the object to
            % be set.
            
            %if isequal(pname,'StimulusLibrary') ,
            %    keyboard
            %end                
            
            propSetForName=propSet.(pname);
            %if isstruct(propSetForName) && ismethod(property,'restoreSettingsAndReturnCopyOfOriginal') ,
            if ismethod(property,'restoreSettingsAndReturnCopyOfOriginal') ,
                % If there's a custom decoder, use that
                originalValue=property.restoreSettingsAndReturnCopyOfOriginal(propSetForName);
            elseif isstruct(propSetForName) && isa(property, 'most.mixin.Coding')
                % If we get here, property is a handle object
                % Make sure the property is large enough
                if length(propSetForName)>length(property) ,
                    % Need to make property bigger to accomodate the new
                    % setting
                    wasPropertyEmpty=isempty(property);
                    className = class(property);
                    property(length(propSetForName))=feval(className);  % the class of property needs to have a zero-arg constructor
                    % If property was originally empty, then the line above is not
                    % sufficient, b/c empty handle objects have different
                    % semantics in matlab than non-empty ones.
                    if wasPropertyEmpty ,
                        setPropertyValueOfTarget(self,target,pname,property);
                        property=getPropertyValueOfTarget(self,target,pname);
                    end
                elseif length(propSetForName)<length(property) ,
                    % Make property smaller, to match propSetForName
                    % In this case, property can't be empty, so things are
                    % easier.
                    property=property(1:length(propSetForName));
                end
                % Now that the lengths are the same, set the individual
                % elements one at a time.
                for idx = 1:numel(property)
                    originalValue.(pname)(idx) = decodeProperties(property(idx), propSetForName(idx));
                end
            elseif isstruct(propSetForName) && isobject(property)
                propNames = fieldnames(propSetForName);
                for idx = 1:numel(propNames)
                    originalValue.(pname) = self.decodePropertyValue(property, propSetForName, propNames{idx});
                end
            else
                try
                    originalValue = property;
                    % TODO Is this still necessary or are enumerations being saved directly as
                    % objects now in the MAT files?
                    if ~isempty(enumeration(property))
                        className = class(property);
                        val = feval(className,  propSetForName);
                    else
                        val =  propSetForName;
                    end
                    % if self == target
                    %     self.setPropertyValue(pname, val);
                    % else
                    %     target.(pname) = val;
                    % end
                    setPropertyValueOfTarget(self,target,pname,val)
                catch me
                    warning('Coding:errSettingProp', ...
                            'Error getting/setting property ''%s''. (Line %d of function ''%s'')', ...
                            pname, ...
                            me.stack(1).line, ...
                            me.stack(1).name);
                    originalValue = [];
                end
            end
        end  % function
        
%         function propertyNameList = findIncludePropertiesWithTag(self, tag)
%             propertyNameList = self.propertyNamesForFileType('IncludeInFileTypes', tag);
%         end
%         
%         function propertyNameList = findExcludePropertiesWithTag(self, tag)
% %             if isa(self,'ephus.display.Scope') ,
% %                 1+1;
% %             end
%             propertyNameList = self.propertyNamesForFileType('ExcludeInFileTypes', tag);
%         end
        
        function propertyNameList = propertyNamesForFileType(self, tagName, fileType)
            % Get the object properties that are tagged, and have the given
            % fileType listed in the given tagName.  tagName must be either
            % 'IncludeInFileTypes' or 'ExcludeInFileTypes'.  E.g.
            % the tagName might be 'ExcludeInFileTypes', and the fileType
            % might be 'cfg'.  The property names are in same order as
            % declared in the classdefs.
            function result=isFileTypeOnTheListForTagSetName(tagSetName)
                listOfFileTypesForThisTagName=self.prvTaggedProperties.(tagSetName).(tagName);
                result=any(ismember(fileType, listOfFileTypesForThisTagName)) || ...
                       any(ismember('*', listOfFileTypesForThisTagName));
            end
                
            function result=propertyNameFromTagSetName(fieldName)
                result=self.prvTaggedProperties.(fieldName).PropertyName;
            end
            
            if ~isempty(self.prvTaggedProperties)
                %allPropertyNames=self.propertyNames();                
                tagSetNames = fieldnames(self.prvTaggedProperties);
                includeIndex = cellfun(@isFileTypeOnTheListForTagSetName,tagSetNames);
                tagSetNameList = tagSetNames(includeIndex);
                propertyNameListInBadOrder = cellfun(@propertyNameFromTagSetName, tagSetNameList, 'UniformOutput', false);
                % Want propertyNameList to be in an order determined by the
                % order in which props were declared in the classdefs
                allPropertyNames=self.propertyNames();
                propertyNameList=intersect(allPropertyNames,propertyNameListInBadOrder,'stable');
            else
                propertyNameList = {};
            end
        end
    end  % private methods
    
    methods (Static = true, Access = protected)
        % PredicateFcn is a function that returns a logical when given a
        % meta.Property object
        function propertyNames = classPropertyNamesSatisfyingPredicate_(className, predicateFunction)
            % Return a list of all the property names for the class that satisfy the predicate, in the
            % order they were defined in the classdef.
            mc = meta.class.fromName(className);
            allClassProperties = mc.Properties;
            isMatch = cellfun(predicateFunction, allClassProperties);
            matchingClassProperties = allClassProperties(isMatch);
            propertyNames = cellfun(@(x)x.Name, matchingClassProperties, 'UniformOutput', false);
        end
    
        function propertyNames = classPropertyNames_(className)
            % Return a list of all the property names for the class, in the
            % order they were defined in the classdef.
            mc = meta.class.fromName(className);
            allClassProperties = mc.Properties;
            propertyNames = cellfun(@(x)x.Name, allClassProperties, 'UniformOutput', false);
        end        
    end  % class methods
    
    methods (Static = true, Access = private)
        function out = tagSetNameFromPropertyName_(propertyName)
            % Sanitizes compound property names by replacing '.' with
            % '___'.
            if isempty(strfind(propertyName, '.'))
                out = propertyName;
            else
                out = strrep(propertyName, '.', '___');
            end
        end
        
        function tagSet = createDefaultTagSet_(propertyName)            
            tagSet.PropertyName = propertyName;
            tagSet.IncludeInFileTypes = {};
            tagSet.ExcludeInFileTypes = {};
        end
    end
end


%--------------------------------------------------------------------------%
% Coding.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
