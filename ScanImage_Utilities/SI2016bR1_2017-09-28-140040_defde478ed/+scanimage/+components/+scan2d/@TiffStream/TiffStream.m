classdef TiffStream < handle
    
    properties(Access = private)
        twhandle = uint64(0);  % Handle, pointer to a memory location, where the TifWriter object created and used within an instance of this class, is stored. This is passed to the various TifStream Mex functions.
    end
    
    methods (Access = public)
        
        function obj = TiffStream()            
        end % function - Constructor
        
        function boolResult = appendFrame(obj, image, sizeInBytes)
        %appendFrame  Write the given image to the end of the open Tiff file.
        % Function appendFrame calls the Mex function, AppendFrameMex,
        % which validates the parameters and calls the underlying TifWriter 
        % object to write the given image to the end of the Tiff file managed 
        % by that TifWriter object. 
        %
        % The Mex function, AppendFrameMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.appendFrame(image, sizeInBytes)
        % 
        % Define Variables:
        %   image           -- const char * -- Required -- The image to be written to the Tiff file.
        %   sizeInBytes     -- unsigned int -- Required -- Size, in bytes, of the associated image.
        %   boolResult      -- bool -- true if successful, false otherwise.
        %     
            boolResult = true;
            
            if (obj.AppendFrameMex(uint64(obj.twhandle), image, uint32(sizeInBytes)) == 0)
                boolResult = false;   
            end
            
        end % appendFrame
        
        function cleanUp(obj)
        %cleanUp  Closes the Tiff file, if open, and frees any allocated memory.
        % Function cleanUp calls the Mex function, CleanUpMex,
        % which validates the parameters and calls the underlying TifWriter 
        % object to close any open Tiff file, then frees memory allocated to 
        % the location pointed to by the 'twhandle' variable.
        %
        % The Mex function, CleanUpMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   obj.cleanUp()
        % 
        % Define Variables:
        %   None.
        %
            obj.CleanUpMex(uint64(obj.twhandle));
            
            obj.twhandle = uint64(0);
            
        end % function - cleanUp

        function boolResult = close(obj)
        %close  Closes the Tiff file.
        % Function close calls the Mex function, CloseMex,
        % which validates the parameters and calls the underlying TifWriter 
        % object to close any open Tiff file.
        %
        % The Mex function, CloseMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.close()
        % 
        % Define Variables:
        %   boolResult      -- bool -- true if successful, false otherwise.
        %            
            boolResult = true;
            
            if (obj.CloseMex(uint64(obj.twhandle)) == 0)
                boolResult = false;        
            end
            
        end % function - close

        function boolResult = closeWithAppendedData(obj, appendedData, datalength)
        %closeWithAppendedData  Writes out the given data to the Tiff file and then closes that file.
        % Function closeWithAppendedData calls the Mex function, CloseWithAppendedDataMex,
        % which validates the parameters and calls the underlying TifWriter 
        % object to write the given data to the Tiff file and then closes that file.
        %
        % The Mex function, CloseWithAppendedDataMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.closeWithAppendedData(appendedData, datalength)
        % 
        % Define Variables:
        %   appendedData    -- const char * -- Required -- Data to write out at the end of the Tiff file.
        %   datalength      -- unsigned int -- Required -- Length, in bytes, of the data to be written to the Tiff file.
        %   boolResult      -- bool -- true if successful, false otherwise.
        %            
            boolResult = true;
            
            if (~ischar(appendedData))
                appendedData = '';
            end
            
            if (obj.CloseWithAppendedDataMex(uint64(obj.twhandle), char(appendedData), uint32(datalength)) == 0)
                boolResult = false;        
            end
            
        end % function - close

        function boolResult = configureImage(obj, imageWidth, imageLength, bytesPerPixel, numberOfChannels, signedData, imageDescription, targerBytesPerFullStrip)
        %configureImage  Configures the specification to use for images that are written out to the Tiff file.
        % Function configureImage calls the Mex function, ConfigureImageMex,
        % which validates the parameters and calls the underlying TifWriter 
        % object to configures the specification to use for images that are written out to the Tiff file.
        %
        % The Mex function, ConfigureImageMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.configureImage(imageWidth, imageLength, bytesPerPixel, numberOfChannels, signedData, imageDescription, targerBytesPerFullStrip)
        % 
        % Define Variables:
        %   imageWidth              -- unsigned short -- Required -- The width of the image, in pixels.
        %   imageLength             -- unsigned short -- Required -- The length of the image, in pixels.
        %   bytesPerPixel           -- unsigned short -- Required -- The number of bytes that make up a pixel.
        %   numberOfChannels        -- unsigned short -- Required -- The number of channels, per frame, used to capture the image.
        %   signedData              -- bool -- Required -- The 'signedData'
        %       parameter is a flag that indicates whether (true) or not (false) the image is 
        %       to have the capability to store image related data using the two's complement 
        %       signed integer data type or the unsigned integer data type.
        %   imageDescription        -- const char * -- Optional -- Metadata information to be
        %       stored with the image, in the Tiff file. Must have a value if
        %       the parameter 'targerBytesPerFullStrip' is used. The value can
        %       be NaN.
        %   targerBytesPerFullStrip -- unsigned int -- Optional -- The
        %       number of bytes to apply for a full (not partial) strip.
        %   boolResult              -- bool -- true if successful, false otherwise.
        %               
            res = 0;
            boolResult = true;
            
            if (~ischar(imageDescription))
                imageDescription = '';
            end
            
            if (nargin == 8)
                res = obj.ConfigureImageMex(uint64(obj.twhandle), uint16(imageWidth), uint16(imageLength), uint16(bytesPerPixel), uint16(numberOfChannels), signedData, char(imageDescription), uint32(targerBytesPerFullStrip));
            else
                res = obj.ConfigureImageMex(uint64(obj.twhandle), uint16(imageWidth), uint16(imageLength), uint16(bytesPerPixel), uint16(numberOfChannels), signedData, char(imageDescription));
            end
            
            if (res == 0)
                boolResult = false;        
            end
            
        end % configureImage
        
        function boolResult = newFile(obj, filename)
        %newFile  Closes the Tiff file, if open, and opens a new Tiff file with the given name and mode.
        % Function newFile calls the Mex function, NewFileMex, which validates the parameters and calls 
        % the underlying TifWriter object to open a Tiff file. The TifWriter object first closes any 
        % open file before attempting to open a new Tiff file.
        %
        % The Mex function, NewFileMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.newFile(filename, filemode)
        % 
        % Define Variables:
        %   filename        -- const char * -- Required -- The file name to use for the new Tiff file.
        %   boolResult      -- bool -- true if successful, false otherwise.
        %                        
            boolResult = true;
            
            if (~ischar(filename))
                filename = '';
            end
            
            if (obj.NewFileMex(uint64(obj.twhandle), char(filename)) == 0)
                boolResult = false;        
            end
            
        end % function - newFile
        
        function boolResult = open(obj, filename, metadataBuffer, softwareTagDataOffset, artistTagDataOffset)
        %open  Closes the Tiff file, if open, and opens a new Tiff file with the given name and mode.
        % Function open calls the Mex function, OpenMex, which validates the parameters and calls 
        % the underlying TifWriter object to open a Tiff file. The TifWriter object first closes any 
        % open file before attempting to open a new Tiff file.
        %
        % The Mex function, OpenMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.open(filename, filemode)
        % 
        % Define Variables:
        %   filename        -- const char * -- Required -- The file name to use for the new Tiff file.
        %   boolResult      -- bool -- true if successful, false otherwise.
        %                                    
            boolResult = true;

            if (~ischar(filename))
                filename = '';
            end
            
            obj.twhandle = obj.OpenMex(obj.twhandle, char(filename), uint8(metadataBuffer), int32(length(metadataBuffer)), int32(softwareTagDataOffset), int32(artistTagDataOffset));
            
            if (obj.twhandle == 0)
                boolResult = false;        
            end
            
        end % function - open
        
        function boolResult = replaceImageDescription(obj, description)
        %replaceImageDescription  Replaces the image description with the given description.
        %
        % The Mex function, ReplaceDescriptionMex, writes any errors to the Matlab console.
        % 
        % Calling Sequence:
        %   boolResult = obj.replaceImageDescription(description)
        % 
        % Define Variables:
        %   description     -- const char * -- Required -- The replacement image description. 
        %   boolResult      -- bool -- true if successful, false otherwise.
        %                                                
            boolResult = true;
            
            if (ischar(description))
                if (obj.ReplaceDescriptionMex(uint64(obj.twhandle), char(description)) == 0)
                    boolResult = false;        
                end
            else
                boolResult = false;
            end 
            
        end % function - replaceImageDescription
        
    end % methods - public 

   methods (Access = private, Static = true)
        
       % Mex Method Declarations
       
        resultHandle = AppendFrameMex(twhandle, image, sizeInBytes);
        CleanUpMex(twhandle);
        resultHandle = CloseMex(twhandle);
        resultHandle = CloseWithAppendedDataMex(twhandle, appendedData, datalength);
        resultHandle = ConfigureImageMex(twhandle, imageWidth, imageLength, bytesPerPixel, numChannels, signedData, description, targetBytes);
        resultHandle = NewFileMex(twhandle, filename, metadataBuffer, metadataBufferSize, metadataForIFDOffset, filemode);
        resultHandle = OpenMex(twhandle, filename, metadataBuffer, metadataBufferSize, metadataForIFDOffset, filemode);
        resultHandle = ReplaceDescriptionMex(twhandle, description);
    
    end % methods - private
    
end % classdef - TiffStream


%--------------------------------------------------------------------------%
% TiffStream.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
