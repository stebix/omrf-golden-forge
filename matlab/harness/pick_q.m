function Q = pick_q(Q_lib, type, N_q)
% PICK_Q  Look up a Q state matrix from the state library by type and size.
%
%   Q = pick_q(Q_lib, type, N_q)
%
%   Inputs
%   ------
%   Q_lib  Struct returned by make_q_states.  Fields are named
%          '<type>_<N_q>' (e.g., 'equilibrium_8', 'post_45rf_16').
%   type   Q state type key (string).  Must match one of the prefixes
%          produced by make_q_states:
%            'equilibrium'      Mz = 1 at zeroth order, all else zero
%            'post_90rf'        After a 90-deg RF pulse about x
%            'post_45rf'        After a 45-deg RF pulse about x
%            'random_symmetric' Random state obeying EPG conjugate symmetry
%            'random_arbitrary' Unconstrained random state (stress test)
%            'sparse'           Few non-zero coherence orders
%   N_q    Number of coherence orders (scalar integer).
%
%   Output
%   ------
%   Q      3-by-N_q complex matrix [F+; F-; Z].
%
%   Errors
%   ------
%   Throws a descriptive error if the '<type>_<N_q>' field is absent from
%   Q_lib.  This typically means the corresponding N_q was not included in
%   the N_q_list passed to make_q_states — an early-failure signal rather
%   than a confusing struct-indexing error later.
%
%   See also: make_q_states, expand_case_templates

field = sprintf('%s_%d', type, N_q);

if ~isfield(Q_lib, field)
    available = fieldnames(Q_lib);
    error('pick_q:fieldNotFound', ...
        ['Q_lib has no field "%s".\n' ...
         'Ensure N_q=%d is included in the N_q_list passed to ' ...
         'make_q_states.\nAvailable fields: %s'], ...
        field, N_q, strjoin(available, ', '));
end

Q = Q_lib.(field);

end
