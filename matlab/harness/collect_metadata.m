function meta = collect_metadata(operator_name, generated_dir)
% COLLECT_METADATA  Gather provenance metadata for golden data.
%   meta = collect_metadata(operator_name, generated_dir)

% Git commit hash
[status, commit] = system('git rev-parse HEAD');
if status == 0
    meta.git_commit = strtrim(commit);
else
    meta.git_commit = 'unknown';
end

% MATLAB version
meta.matlab_version = version();

% Timestamp (ISO 8601 UTC)
meta.generated_at = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% SHA-256 of the operator .m file
operator_file = fullfile(generated_dir, [operator_name '.m']);
if isfile(operator_file)
    meta.operator_file_sha256 = sha256_file(operator_file);
else
    meta.operator_file_sha256 = 'not_found';
end

% SHA-256 of the extraction manifest
manifest_file = fullfile(generated_dir, 'manifest.json');
if isfile(manifest_file)
    meta.source_manifest_sha256 = sha256_file(manifest_file);
else
    meta.source_manifest_sha256 = 'not_found';
end

meta.harness_version = '1.0.0';
meta.rng_seed = 42;

end
