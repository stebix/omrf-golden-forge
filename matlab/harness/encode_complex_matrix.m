function s = encode_complex_matrix(M)
% ENCODE_COMPLEX_MATRIX  Encode a complex matrix for JSON serialization.
%   s = encode_complex_matrix(M) returns a struct with fields:
%     .shape  - [rows, cols]
%     .real   - real part (double matrix)
%     .imag   - imaginary part (double matrix)
%
%   jsonencode produces nested JSON arrays for 2D double matrices,
%   e.g. [[1,2],[3,4]]. The Python consumer reconstructs via:
%     Q = np.array(s['real']) + 1j * np.array(s['imag'])

s.shape = size(M);
s.real  = real(M);
s.imag  = imag(M);

end
