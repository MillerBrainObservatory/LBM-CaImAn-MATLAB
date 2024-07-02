function log_struct(metadata, struct_name, log_full_path, fid)
    % log_struct Log the contents of a structure to a log file and the command window.
    %
    % Parameters
    % ----------
    % metadata : struct
    %     The structure to log.
    % struct_name : char
    %     The name of the structure.
    % log_full_path : char
    %     The path to the log file.
    % fid : file identifier
    %     The file identifier for the log file.

    fprintf(fid, '%s : %s contents:\n', datestr(datetime('now'), 'yyyy_mm_dd-HH_MM_SS'), struct_name);
    fprintf('%s contents:\n', struct_name);

    fields = fieldnames(metadata);
    for i = 1:numel(fields)
        field_value = metadata.(fields{i});
        if isstruct(field_value)
            fprintf(fid, '%s : %s.%s:\n', datestr(datetime('now'), 'yyyy_mm_dd-HH_MM_SS'), struct_name, fields{i});
            fprintf('%s.%s:\n', struct_name, fields{i});
            log_struct(field_value, [struct_name '.' fields{i}], log_full_path, fid);
        else
            fprintf(fid, '%s : %s.%s = %s\n', datestr(datetime('now'), 'yyyy_mm_dd-HH_MM_SS'), struct_name, fields{i}, mat2str(field_value));
            fprintf('%s.%s = %s\n', struct_name, fields{i}, mat2str(field_value));
        end
    end
end
