function [tagstruct] = getTagStructFromTiff(hTiff)

    tagstruct = struct();
    tagstruct.BitsPerSample = hTiff.getTag("BitsPerSample");
    tagstruct.Photometric = hTiff.getTag("Photometric");
    tagstruct.Orientation = hTiff.getTag("Orientation");
    tagstruct.SubFileType = hTiff.getTag("SubFileType");

    tagstruct.Compression = hTiff.getTag("Compression");
    tagstruct.RowsPerStrip = hTiff.getTag("RowsPerStrip");
    tagstruct.SamplesPerPixel = hTiff.getTag("SamplesPerPixel");    
    tagstruct.SampleFormat = hTiff.getTag("SampleFormat");

    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.ImageLength = hTiff.getTag("ImageLength");
    tagstruct.ImageWidth = hTiff.getTag("ImageWidth");

end