function save_golden_record(operator_name, cases, metadata, output_dir)
% SAVE_GOLDEN_RECORD  Serialize one operator's test cases to a JSON file.
%   save_golden_record(operator_name, cases, metadata, output_dir)
%
%   cases: struct array with tag, Q_in, Q_out, and operator-specific params.
%   metadata: struct from collect_metadata.

if ~isfolder(output_dir)
    mkdir(output_dir);
end

record.operator = operator_name;
record.metadata = metadata;

test_cases = cell(1, numel(cases));
for k = 1:numel(cases)
    tc.tag  = cases(k).tag;
    tc.nstates = size(cases(k).Q_in, 2);
    tc.Q_in  = encode_complex_matrix(cases(k).Q_in);
    tc.Q_out = encode_complex_matrix(cases(k).Q_out);

    % Extract scalar parameters (everything except tag, Q_in, Q_out)
    params = rmfield(cases(k), {'tag', 'Q_in', 'Q_out'});
    fnames = fieldnames(params);
    for f = 1:numel(fnames)
        val = params.(fnames{f});
        if ~isreal(val)
            params.(fnames{f}) = struct('real', real(val), 'imag', imag(val));
        end
    end
    tc.params = params;

    test_cases{k} = tc;
end

record.test_cases = test_cases;

json_str = jsonencode(record, 'PrettyPrint', true);
filepath = fullfile(output_dir, [operator_name '.json']);
fid = fopen(filepath, 'w');
fprintf(fid, '%s', json_str);
fclose(fid);

fprintf('  Saved %d test cases -> %s\n', numel(cases), filepath);

end
