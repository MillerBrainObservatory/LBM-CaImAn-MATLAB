function log_struct(fid, in_struct, struct_name, log_full_path)
    % log_struct Log the contents of a structure to a log file and the command window.
    %
    % Parameters
    % ----------
    % fid : file identifier
    %     The file identifier for the log file.
    % in_struct : struct
    %     The structure to log.
    % struct_name : char
    %     The name of the structure.
    % log_full_path : char
    %     The path to the log file.

    if ~isstruct(in_struct)
        error('log_struct:InvalidInput', 'Input argument metadata must be a structure.');
    end

    log_message(fid, '%s contents:\n',struct_name);

    fields = fieldnames(in_struct);
    for i = 1:numel(fields)
        try
            field_value = in_struct.(fields{i});
            if isstruct(field_value)
                log_struct(fid, field_value, [struct_name '.' fields{i}], log_full_path);
            elseif ismatrix(in_struct)
                log_message(fid, '%s = %s\n',fields{i}, mat2str(field_value));
            else
                log_message(fid, '%s = %s',fields{i},convertCharsToString(field_value));
            end
        catch
            warning("Invalid field name: %s", fields{i});
            continue
        end
    end
end
