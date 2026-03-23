function h = sha256_file(filepath)
% SHA256_FILE  Compute SHA-256 hex digest of a file.
%   h = sha256_file(filepath) returns a lowercase hex string.

fid = fopen(filepath, 'r');
if fid == -1
    error('sha256_file:fileNotFound', 'Cannot open file: %s', filepath);
end
data = fread(fid, '*uint8');
fclose(fid);

md = java.security.MessageDigest.getInstance('SHA-256');
md.update(data);
hash_bytes = typecast(md.digest(), 'uint8');
h = lower(sprintf('%02x', hash_bytes));

end
