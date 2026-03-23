function cases = cases_sim_rf(Q_lib, N_q_list)
% CASES_SIM_RF  Test case templates for the sim_rf operator.
%
%   cases = cases_sim_rf(Q_lib, N_q_list)
%
%   Returns a struct array of concrete test cases produced by expanding the
%   template definitions below against the available N_q sizes.  Each case
%   has fields: tag, Q_in, alpha, phi.
%
%   Template design
%   ---------------
%   Semantic tests (policy 'representative') verify that sim_rf computes the
%   correct rotation matrix for a particular (alpha, phi) combination.  The
%   state-space size is incidental for these checks, so a single
%   representative N_q is used.
%
%   The 'smallest' policy is reserved for edge-case inputs (zero flip,
%   360-deg) where a minimal state is sufficient and keeps the golden record
%   compact.
%
%   The 'largest' policy is used for cases where the intent is to exercise
%   the operator on a non-trivial state that occupies more coherence orders.
%
%   See also: expand_case_templates, make_q_states, generate_golden_data

templates = struct([]);
t = 0;

% --- Classic 90-deg excitation about x ---
% Canonical starting point: takes equilibrium entirely into transverse plane.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'equilibrium_90deg_x';
templates(t).alpha    = pi/2;
templates(t).phi      = 0;

% --- 180-deg inversion about x ---
% Full inversion pulse; net result should negate Mz.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'equilibrium_180deg_x';
templates(t).alpha    = pi;
templates(t).phi      = 0;

% --- 180-deg inversion about y ---
% Same flip angle, orthogonal phase: verifies phase dependence.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'equilibrium_180deg_y';
templates(t).alpha    = pi;
templates(t).phi      = pi/2;

% --- Arbitrary angle and phase on a larger state ---
% Non-axis-aligned rotation applied to a larger state space to confirm that
% all coherence orders are rotated independently and correctly.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'largest';
templates(t).tag_stem = 'equilibrium_45deg_arb_phase';
templates(t).alpha    = pi/4;
templates(t).phi      = pi/3;

% --- Second RF pulse applied to an already-excited state ---
% Verifies that the rotation correctly handles non-zero transverse
% magnetisation as input (superposition of F+ / F- / Z).
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_second_pulse';
templates(t).alpha    = pi/2;
templates(t).phi      = 0;

% --- Near-zero flip angle on a symmetric random state ---
% Small-angle limit: rotation matrix should be close to identity.
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_small_flip';
templates(t).alpha    = 0.01;
templates(t).phi      = 0;

% --- Full inversion on an arbitrary random state ---
% 180-deg pulse on an unconstrained state; stress-tests the rotation for
% states that do not obey EPG conjugate symmetry.
t = t+1;
templates(t).type     = 'random_arbitrary';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_large_flip';
templates(t).alpha    = pi;
templates(t).phi      = pi/4;

% --- Edge: zero flip angle (identity) ---
% alpha = 0 must leave the state entirely unchanged.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'edge_zero_flip';
templates(t).alpha    = 0.0;
templates(t).phi      = 0;

% --- Edge: 360-deg rotation (identity mod floating-point) ---
% A full rotation should return the state to itself within numerical
% precision; useful for catching sign-convention errors.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'edge_360deg';
templates(t).alpha    = 2*pi;
templates(t).phi      = 0;

cases = expand_case_templates(templates, Q_lib, N_q_list);

end
