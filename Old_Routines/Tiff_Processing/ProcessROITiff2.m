function [imageData] = ProcessROITiff2(filename, roisOrder, trim)

[roiData, ~, ~, ~] = scanimage.util.getMroiDataFromTiff(filename);

%% Videos and save the data

strip = 1;
frame = 1;

image_temp = roiData{1,strip}.imageData{1,1}{1,frame}{1,1};
stripwidth = size(image_temp,2);

totalFrame = length(roiData{1}.imageData{1});

totalChannel = length(roiData{1}.imageData);
    
imageData = single([]);

for channel = 1:totalChannel

    image_roi_temp = single([]);

    for strip = roisOrder

       image_frame_temp = single([]);

       for frame = 1:totalFrame
           current_strip = single(roiData{1,strip}.imageData{1,channel}{1,frame}{1,1});
           image_frame_temp = cat(4,image_frame_temp,current_strip);
       end

       offset = returnScanOffset2(image_frame_temp,1);
       image_frame_temp = fixScanPhase2(image_frame_temp,offset,1);
       image_roi_temp = cat(2,image_roi_temp,image_frame_temp);

    end
    
    imageData = cat(3,imageData,image_roi_temp);
    disp(['Channel ' num2str(channel) ' of ' num2str(totalChannel) ' assembled...'])
    
end

if trim

    crosswidth = 6;

    numROI = numel(roisOrder);

    vals = [];
    for ijk = 1:numROI
        vals = cat(2,vals, [num2str(stripwidth*(ijk-1)+crosswidth) ':' num2str(ijk*stripwidth - crosswidth) ' ']);
    end

    eval(['imageData = imageData(:,[' vals '],:,:);'])
    
    val = round(size(imageData,1)*0.03);
    
    imageData = imageData(val:end,:,:,:);

end

disp('Volume assembled.')