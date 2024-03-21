classdef SIChannel < handle
    properties (SetAccess = private)
        siChannelNumber;
        chStrFpga;
        hSampler;
        hFpga;
    end
    
    events
        configurationChanged
    end
    
    properties (Dependent)
        physicalChannelSelect;
        photonCountingEnable;
        scaleByPowerOf2;
        photonSelectionMask;
    end
    
    methods
        function obj = SIChannel(hSampler,siChannelNumber)
            obj.hSampler = hSampler;
            obj.hFpga = obj.hSampler.hFpga;
            obj.siChannelNumber = siChannelNumber;
            obj.chStrFpga = num2str(obj.siChannelNumber-1);
            
            % initialize values
            obj.physicalChannelSelect = mod(obj.siChannelNumber-1,2);
            obj.photonCountingEnable = false;
            obj.scaleByPowerOf2 = 0;
            obj.photonSelectionMask = true(16,1);
        end
        
        function delete(obj)
            %No-Op
        end
    end
    
    methods
        function set.physicalChannelSelect(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.hFpga.(['NI5771Channel' obj.chStrFpga 'PhysicalChannelSel']) = val;
            notify(obj,'configurationChanged');
        end
        
        function val = get.physicalChannelSelect(obj)
            val = obj.hFpga.(['NI5771Channel' obj.chStrFpga 'PhysicalChannelSel']);
        end
        
        function set.photonCountingEnable(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.hFpga.(['NI5771PhotonCountingChannel' obj.chStrFpga 'Enable']) = val;
            notify(obj,'configurationChanged');
        end
        
        function val = get.photonCountingEnable(obj)
            val = obj.hFpga.(['NI5771PhotonCountingChannel' obj.chStrFpga 'Enable']);
        end
        
        function set.scaleByPowerOf2(obj,val)
            validateattributes(val,{'numeric'},{'scalar','integer','>=',-128,'<',127});
            obj.hFpga.(['NI5771Channel' obj.chStrFpga 'ScaleByPowerOf2']) = val;
            notify(obj,'configurationChanged');
        end
        
        function val = get.scaleByPowerOf2(obj)
            val = obj.hFpga.(['NI5771Channel' obj.chStrFpga 'ScaleByPowerOf2']);
        end
        
        function set.photonSelectionMask(obj,val)
            if isempty(val)
                val = true(1,16);
            end
            validateattributes(val,{'logical'},{'vector'});
            if length(val) < 16
               val(end+1:16) = false; 
            end
            assert(length(val)==16);
            obj.hFpga.(['NI5771SampleMaskChannel' obj.chStrFpga]) = logicalChannelMaskToUint32(val);
            notify(obj,'configurationChanged');
        end
        
        function val = get.photonSelectionMask(obj)
           val = uint32ToLogicalChannelMask(obj.hFpga.(['NI5771SampleMaskChannel' obj.chStrFpga]));
        end
    end
       
    methods
        function s = saveStruct(obj)
            s = struct();
            s.physicalChannelSelect = obj.physicalChannelSelect;
            s.photonCountingEnable = obj.photonCountingEnable;
            s.scaleByPowerOf2 = obj.scaleByPowerOf2;
            s.photonSelectionMask = obj.photonSelectionMask;
        end
        
        function loadStruct(obj,s)
            assert(isa(s,'struct'));
            
            props = fieldnames(s);
            for idx = 1:length(props)
                prop = props{idx};
                try
                    obj.(prop) = s.(prop);
                catch ME
                    most.idioms.reportError(ME);
                end
            end
        end
    end
end

      
%%% local functions
function mask_uint32 = logicalChannelMaskToUint32(mask)
    mask_uint32 = zeros(1,1,'uint32');
    for bitidx = 1:length(mask)
        mask_uint32 = bitset(mask_uint32,bitidx,mask(bitidx));
    end
end

function mask16 = uint32ToLogicalChannelMask(mask_uint32)
    validateattributes(mask_uint32,{'uint32'},{'scalar'});
    mask16 = false(1,16);
    for bitidx = 1:length(mask16)
        mask16(bitidx) = logical(bitget(mask_uint32,bitidx));
    end
end

%--------------------------------------------------------------------------%
% SIChannel.m                                                              %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
