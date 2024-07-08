function log_message(fid, msg, varargin)
    % log_message Log a message to both a file and the command window.
    %
    % Parameters
    % ----------
    % fid : file identifier
    %     The file identifier for the log file.
    % msg : char
    %     The message to log, with formatting placeholders.
    % varargin : any
    %     Additional arguments to format the message.
    
    timestamp = datestr(datetime('now'), 'yyyy_mm_dd-HH:MM:SS');

    % Sanitize varargin to escape backslashes, but allow \n
    for arg = 1:numel(varargin)
        if ischar(varargin{arg})
            varargin{arg} = regexprep(varargin{arg}, '(\\(?!n))', '\\\\');
        end
    end

    log_window_msg = sprintf('%s', sprintf(msg, varargin{:}));
    log_file_msg = sprintf('%s : %s', timestamp, log_window_msg);

    fprintf(fid, '%s', log_file_msg);

    fprintf('%s', log_window_msg);
end
