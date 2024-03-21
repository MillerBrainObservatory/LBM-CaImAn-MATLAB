function [imageData] = ProcessROITiff(filename, roisOrder, trim)

[roiData, roiGroup, header, ~] = scanimage.util.getMroiDataFromTiff(filename);


%% Videos and save the data

strip = 1;
frame = 1;

image_temp = roiData{1,strip}.imageData{1,1}{1,frame}{1,1};
stripwidth = size(image_temp,2);

imageData = [];
totalFrame = length(roiData{1}.imageData{1});

totalChannel = length(roiData{1}.imageData);

val = round(totalFrame/50);

for frame = 1:totalFrame
    
    image_channel_temp = [];
    for channel = 1:totalChannel
    
        if frame/val == round(frame/val)
            disp(['Processing frame:' ,num2str(frame),' of ',num2str(totalFrame)]);
        end

       image_temp = [];
       
       for strip = roisOrder
           image_temp = cat(2,image_temp,single(roiData{1,strip}.imageData{1,channel}{1,frame}{1,1}));
       end
       
       image_channel_temp = cat(3,image_channel_temp,image_temp);
    end

    imageData = cat(4,imageData,image_channel_temp);

end

if trim

    crosswidth = 6;

    numROI = numel(roisOrder);

    vals = [];
    for ijk = 1:numROI
        vals = [vals num2str(stripwidth*(ijk-1)+crosswidth) ':' num2str(ijk*stripwidth - crosswidth) ' '];
    end

    eval(['imageData = imageData(:,[' vals '],:,:);'])
    
    val = round(size(imageData,1)*0.03);
    
    imageData = imageData(val:end,:,:,:);

end