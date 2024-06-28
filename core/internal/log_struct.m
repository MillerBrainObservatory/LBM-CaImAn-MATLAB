function log_struct(structured_arr,label,logFilePath, fid)
% LOG_STRUCT Print struct to a log file in tabular format.
%
% Parameters
% ----------
% structured_arr : struct
%     Metadata structure to be printed.
% label : char
%     Title label to print above the log entry.
% logFilePath : char
%     Path to the log file.
% fid : single
%     Filepath identifyer for this logfile.

% Open the log file for writing
% TODO: Append to existing/partial logfile
if ~exist('fid', 'var') || length(nargin) < 3; fid = fopen(logFilePath, 'a'); end
if fid == -1; error('Cannot open log file: %s', logFilePath); end
try
    fprintf(fid, '\n\n');
    fprintf(fid, '%s\n', label);
    fprintf(fid, '-----------------------------------------------------\n');
    
    fields = fieldnames(structured_arr);
    for i = 1:numel(fields)
        field = fields{i};
        value = structured_arr.(field);
        
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
