classdef SampleBuffer < handle
    properties (SetAccess = private)
        startSample = 0;
        endSample = 0;
        bufferSize = 0;
        numChannels = 0;
        buffer;
    end
    
    methods
        function obj = SampleBuffer()
        end
        
        function delete(~)
        end
        
        function initialize(obj,numSamples,numChannels,datatype)
            obj.buffer = zeros(numSamples,numChannels,datatype);
            obj.bufferSize = numSamples;
            obj.numChannels = numChannels;
            obj.startSample = 0;
            obj.endSample = 0;
        end
        
        function appendData(obj,data)
            [newDataSize,numChs] = size(data);
            assert(newDataSize <= obj.bufferSize && numChs == obj.numChannels);
            
            if obj.endSample == 0
                obj.endSample = newDataSize;
            else
                obj.endSample = mod(obj.endSample+newDataSize-1,obj.bufferSize)+1;
            end
            
            if obj.startSample == 0
                obj.startSample = 1;
            else
                obj.startSample = mod(obj.startSample+newDataSize-1,obj.bufferSize)+1;
            end
            
            assert(obj.startSample <= obj.endSample && obj.endSample <= obj.bufferSize); % sanity check
            
            if newDataSize == obj.bufferSize
                obj.buffer = data; % performance tweak for non-striping display: avoid memory copy
            else
                obj.buffer(obj.startSample:obj.endSample,:) = data;
            end
            
        end
        
        function [data,startSample,endSample] = getData(obj)
            data = obj.buffer;
            [startSample,endSample] = obj.getPositionInFrame();
        end
        
        function [startSample,endSample] = getPositionInFrame(obj)
            startSample = obj.startSample;
            endSample = obj.endSample;
        end
        
        function reset(obj)
            obj.endSample = 0;
            obj.startSample = 0;
        end
    end
end

%--------------------------------------------------------------------------%
% SampleBuffer.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
