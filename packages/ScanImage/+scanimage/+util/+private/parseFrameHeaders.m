function s = parseFrameHeaders(s,frameHeaders,verInfo)
    
    numImg = numel(frameHeaders);

    if frameHeaders{1}(1) == '{'
        if verInfo.TIFF_FORMAT_VERSION > 2
            hdrs = cellfun(@(x)most.json.loadjson(strtrim(x)),frameHeaders);
        else
            % legacy. In the old json format (intermediate 2015-2016) the
            % frame varying data was in a section called "FrameHeader"
            hdrs = cellfun(@(x)most.json.loadjson(strtrim(x)).FrameHeader,frameHeaders);
        end
        
        nms = fieldnames(hdrs);
        for nm = nms'
            snm = nm{1};
            
            if ismember(snm, {'epoch' 'I2CData'})
                s.(snm) = {hdrs.(snm)};
            elseif ismember(snm, {'auxTrigger0' 'auxTrigger1' 'auxTrigger2' 'auxTrigger3'})
                s.(snm) = {hdrs.(snm)};
                e = cellfun(@isempty,s.(snm));
                s.(snm)(e) = {[]};
            else
                s.(snm) = [hdrs.(snm)];
            end
        end
    else
        dataEndLine = [];
        nms = {};
        mkCell = [];
        
        for frameIdx = 1:numImg
            rows = textscan(frameHeaders{frameIdx},'%s','Delimiter','\n');
            rows = rows{1};
            
            if isempty(dataEndLine)
                dataEndLine = find(cellfun(@(x)strncmp(x,'SI.',3),rows),1)-1;
            end
            if isempty(dataEndLine)
                dataEndLine = find(cellfun(@(x)strncmp(x,'scanimage.SI.',13),rows),1)-1;
            end
            if isempty(dataEndLine)
                dataEndLine = numel(rows);
            end
            
            for idxLine = 1:dataEndLine
                row = rows{idxLine};
                
                %% replace top-level name with 'obj'
                [nm, valStr] = strtok(row,'=');
                
                nm = strtrim(nm);
                valStr = strtrim(valStr(2:end));
                
                if frameIdx == 1
                    nms{end+1} = matlab.lang.makeValidName(strtrim(nm));
                    nms{end}= regexprep(nms{end},'_$',''); % remove trailing _ for legacy files
                    mkCell(end+1) = ~isempty(valStr) && ismember(valStr(1), {'[' '{'});
                    
                    if mkCell(end)
                        s.(nms{end}) = cell(1,numImg);
                    else
                        s.(nms{end}) = zeros(1,numImg);
                    end
                end
                
                % Check if there is a value to assign
                if isempty(valStr)
                    % This unassigned parameter value will be set to 0
                    continue;
                end
                
                if mkCell(idxLine)
                    s.(nms{idxLine}){frameIdx} = eval([valStr ';']);
                else
                    valStr = regexp(valStr,'-?\d+(\.\d+)?|\[\]', 'match');
                    s.(nms{idxLine})(frameIdx) = sscanf(valStr{1},'%f');
                end
            end
        end
    end
        
    if ~isfield(s.SI, 'hScan2D')
        switch verInfo.ImagingSystemType
            case 'Resonant'
                s.SI.hScan2D = s.SI.hResScan;
                
            case 'Linear'
                s.SI.hScan2D = s.SI.hLinScan;
        end
    end
end


%--------------------------------------------------------------------------%
% parseFrameHeaders.m                                                      %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
