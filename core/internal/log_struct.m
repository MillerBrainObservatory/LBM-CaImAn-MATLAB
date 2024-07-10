function log_struct(fid, in_struct, struct_name, log_full_path)
    % log_struct Log the contents of a structure to a log file and the command window.
    %
    % Parameters
    % ----------
    % fid : file identifier (optional)
    %     The file identifier for the log file. If not provided, logs only to the command window.
    % in_struct : struct
    %     The structure to log.
    % struct_name : char
    %     The name of the structure.
    % log_full_path : char
    %     The path to the log file.

    if nargin < 1 || isempty(fid); fid = 1;  end
    if isempty(log_full_path); log_full_path = ''; end

    if ~isstruct(in_struct)
        error('log_struct:InvalidInput', 'Input argument in_struct must be a structure.');
    end

    log_message(fid, '%s contents:\n', struct_name);

    fields = fieldnames(in_struct);
    for i = 1:numel(fields)
        try
            field_value = in_struct.(fields{i});
             switch class(field_value)
                case 'struct'
                    log_struct(fid, field_value, [struct_name '.' fields{i}], log_full_path);
                case 'double'
                    log_message(fid, '       %s = %s\n', fields{i}, mat2str(field_value));
                case 'char'
                    log_message(fid, '       %s = %s\n', fields{i}, convertCharsToStrings(field_value));
                case 'logical'
                    log_message(fid, '       %s = %d\n', fields{i}, field_value);
                case 'cell'
                    log_message(fid, '       %s = %s\n', fields{i}, mat2str(field_value));
                otherwise
                    log_message(fid, '       %s = %s\n', fields{i}, 'Unsupported data type');
            end
        catch
            warning('Invalid field name: %s of type %s', fields{i}, class(fields{i}));
            continue
        end
    end
end

