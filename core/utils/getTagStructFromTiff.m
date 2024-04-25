function [tagstruct] = getTagStructFromTiff(hTiff)

    tagstruct = struct();
    tagstruct.BitsPerSample = 16;
    tagstruct.Photometric = hTiff.getTag("Photometric");
    tagstruct.Orientation = hTiff.getTag("Orientation");
    tagstruct.SubFileType = hTiff.getTag("SubFileType");

    tagstruct.SamplesPerPixel = hTiff.getTag("SamplesPerPixel");    
    tagstruct.SampleFormat = Tiff.SampleFormat.UInt;
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.ImageLength = hTiff.getTag("ImageLength");
    tagstruct.ImageWidth = hTiff.getTag("ImageWidth");

end