function write_metadata_h5(metadata, h5_fullfile, loc)
% Write scanimage metadata fields to HDF5
% attributes, taking care of flattening structured arrays to their
% key:value pairs.
%
% Parameters
% ----------
% metadata : struct
%     The metadata structure containing the fields to be written as attributes.
% h5_fullfile : char
%     The full file path to the HDF5 file.
% loc : char
%     The path within the HDF5 file where the attributes will be written.
%
% Notes
% -----
% This function handles nested structures by flattening the fields and
% converting them into a format that is compatible with HDF5 attributes.
%
% Examples
% --------
% metadata = struct('name', 'LBM_guru', 'age', 'young_enough');
% h5_fullfile = 'guru.h5';
% loc = '/young_guru';
% write_metadata_h5(metadata, h5_fullfile, loc);
if ~exist('loc', 'var'); loc='/'; end
fields = fieldnames(metadata);

for f = fields'
    value = metadata.(f{1});
    if isstruct(value)
        % Flatten struct fields that aren't supported by hdf5
        subfields = fieldnames(value);

        for sf = subfields'
            subvalue = value.(sf{1});
            att_name = [f{1} '_' sf{1}];
            try
                if ischar(subvalue)
                    h5writeatt(h5_fullfile, loc, att_name, subvalue);
                elseif isnumeric(subvalue)
                    h5writeatt(h5_fullfile, loc, att_name, mat2str(subvalue));
                elseif islogical(subvalue)
                    h5writeatt(h5_fullfile, loc, att_name, num2str(subvalue));
                elseif iscell(subvalue)
                    h5writeatt(h5_fullfile, loc, att_name, mat2str(cell2mat(subvalue)));
                else
                    warning("Unsupported metadata type for attribute: %s", att_name);
                end
            catch ME
                warning("Failed to write attribute '%s': %s", att_name, ME.message);
            end
        end
    elseif islogical(value)
        value=num2str(value);
    end
    try
        h5writeatt(h5_fullfile, loc, f{1}, value);
    catch
        warning("Error writing attribute: %s", f{1});
        continue
    end

end

