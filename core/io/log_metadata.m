function log_metadata(metadata, logFilePath, fid)
% LOG_METADATA Print metadata to a log file in tabular format.
%
% Parameters
% ----------
% metadata : struct
%     Metadata structure to be printed.
% logFilePath : char
%     Path to the log file.

% Open the log file for writing
% TODO: Append to existing/partial logfile
if ~exist('fid', 'var') || length(nargin) < 3; fid = fopen(logFilePath, 'a'); end
if fid == -1; error('Cannot open log file: %s', logFilePath); end
try
    fprintf(fid, 'Metadata:\n');
    fprintf(fid, '-----------------------------------------------------\n');
    
    fields = fieldnames(metadata);
    for i = 1:numel(fields)
        field = fields{i};
        value = metadata.(field);
        
        if isnumeric(value)
            valueStr = mat2str(value);
        elseif ischar(value)
            valueStr = value;
        elseif isstruct(value)
            valueStr = 'struct';
        else
            valueStr = 'unknown';
        end
        fprintf(fid, '%-30s: %s\n', field, valueStr);
    end
    
    fprintf(fid, '-----------------------------------------------------\n');
catch ME
    rethrow(ME);
end
end
