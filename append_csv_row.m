function append_csv_row(filepath, values)
% APPEND_CSV_ROW  Append one comma-separated row to a CSV file, opening
% and closing the file each call (safer than one long-held file handle:
% if the session crashes mid-experiment, everything written so far is
% already safely on disk rather than lost in a buffer).
%
%   append_csv_row(filepath, values)
%
% INPUT
%   values - cell array of values (strings, numbers, or [] / NaN for
%            missing/skipped data, written as an empty field)

    fid = fopen(filepath, 'a');
    if fid == -1
        error('append_csv_row:cannotOpen', 'Could not open %s for writing.', filepath);
    end

    strs = cell(1, numel(values));
    for i = 1:numel(values)
        v = values{i};
        if isempty(v)
            strs{i} = '';
        elseif ischar(v)
            strs{i} = v;
        elseif isnumeric(v) || islogical(v)
            if isscalar(v) && isnan(v)
                strs{i} = '';
            else
                strs{i} = num2str(v);
            end
        else
            strs{i} = num2str(v);
        end
    end

    fprintf(fid, '%s\n', strjoin(strs, ','));
    fclose(fid);
end
