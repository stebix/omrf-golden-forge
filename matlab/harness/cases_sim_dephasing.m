function cases = cases_sim_dephasing(Q_lib, N_q_list)
% CASES_SIM_DEPHASING  Test case templates for the sim_dephasing operator.
%
%   cases = cases_sim_dephasing(Q_lib, N_q_list)
%
%   Returns a struct array of concrete test cases produced by expanding the
%   template definitions below against the available N_q sizes.  Each case
%   has fields: tag, Q_in, dphi.
%
%   Template design
%   ---------------
%   Semantic tests (policy 'representative') cover the key behavioural
%   regimes: identity (dphi=0), pi-shift, small positive, large positive,
%   negative, and a full 2*pi cycle.  State-space size is incidental for
%   these checks; a representative N_q is sufficient.
%
%   The 'largest' policy is used for the 2*pi identity test to provide a
%   richer state (more non-zero coherence orders) where floating-point
%   round-trip errors are more visible.
%
%   The 'smallest' policy is used for the sparse-state test; sparse states
%   are already a stress test at any size, so the smallest available N_q is
%   adequate.
%
%   See also: expand_case_templates, make_q_states, generate_golden_data

templates = struct([]);
t = 0;

% --- Zero dephasing (identity) ---
% dphi = 0: operator must leave the state unchanged.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'equilibrium_zero_dephasing';
templates(t).dphi     = 0.0;

% --- Pi dephasing ---
% Half-cycle phase shift; F+ and F- coherences acquire a sign-alternating
% phase pattern across orders.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'equilibrium_pi_dephasing';
templates(t).dphi     = pi;

% --- Post-RF state, small dephasing (B0-offset-like) ---
% Typical sub-voxel off-resonance magnitude; exercises the common imaging
% scenario.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_small_dephasing';
templates(t).dphi     = 0.1;

% --- Post-RF state, large dephasing ---
% Super-pi dephasing: verifies phase accumulation beyond one full cycle.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_large_dephasing';
templates(t).dphi     = 2.5;

% --- Random symmetric state, negative dephasing ---
% Negative dphi exercises the conjugate branch of the phase operator on a
% state that obeys EPG symmetry.
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_state_neg_dephasing';
templates(t).dphi     = -pi/3;

% --- Arbitrary random state, full 2*pi cycle ---
% A complete cycle should return each coherence to its original phase
% within numerical precision.  Uses the largest available state to expose
% floating-point accumulation across many coherence orders.
t = t+1;
templates(t).type     = 'random_arbitrary';
templates(t).policy   = 'largest';
templates(t).tag_stem = 'random_state_2pi';
templates(t).dphi     = 2*pi;

% --- Sparse state, typical offset ---
% Dephasing on a state with few non-zero orders; confirms that zero
% entries remain zero after the phase rotation.
t = t+1;
templates(t).type     = 'sparse';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'sparse_typical';
templates(t).dphi     = pi/6;

cases = expand_case_templates(templates, Q_lib, N_q_list);

end
