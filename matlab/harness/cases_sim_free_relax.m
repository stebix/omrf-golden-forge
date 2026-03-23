function cases = cases_sim_free_relax(Q_lib, N_q_list)
% CASES_SIM_FREE_RELAX  Test case templates for the sim_free_relax operator.
%
%   cases = cases_sim_free_relax(Q_lib, N_q_list)
%
%   Returns a struct array of concrete test cases produced by expanding the
%   template definitions below against the available N_q sizes.  Each case
%   has fields: tag, Q_in, T1, T2, dt.
%
%   Template design
%   ---------------
%   The 'all' policy is used for the canonical tissue-parameter set (typical
%   brain white matter, equilibrium state) because free relaxation should be
%   size-independent and this is the primary case where that invariance is
%   worth verifying across every available N_q.
%
%   All other templates use 'representative' (parameter-regime coverage) or
%   'smallest' (edge cases where a minimal state is sufficient).  T1/T2
%   values reflect realistic tissue categories to ensure the exponential
%   decay spans a broad dynamic range.
%
%   See also: expand_case_templates, make_q_states, generate_golden_data

templates = struct([]);
t = 0;

% --- Typical brain white matter, equilibrium state — size sweep ---
% Canonical parameter set tested across all available N_q.  Verifies that
% the relaxation operator is truly state-space-size-independent.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'all';
templates(t).tag_stem = 'equilibrium_typical_brain';
templates(t).T1       = 1.0;
templates(t).T2       = 0.080;
templates(t).dt       = 0.010;

% --- Post-RF state, short time step ---
% dt << T2: transverse decay is small; tests numerical precision in the
% near-identity limit.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_short_dt';
templates(t).T1       = 1.0;
templates(t).T2       = 0.080;
templates(t).dt       = 0.001;

% --- Post-RF state, long time step ---
% dt >> T2: most transverse magnetisation has decayed; tests the large-
% argument branch of the exponential.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_long_dt';
templates(t).T1       = 1.0;
templates(t).T2       = 0.080;
templates(t).dt       = 0.500;

% --- Random symmetric state, CSF-like (long T1 and T2) ---
% Very long relaxation times; the exponential factors are close to 1.
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_state_csf';
templates(t).T1       = 4.0;
templates(t).T2       = 2.0;
templates(t).dt       = 0.010;

% --- Random symmetric state, fat-like (short T1) ---
% Short T1 drives rapid longitudinal recovery; tests the recovery term
% of the relaxation matrix.
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_state_fat';
templates(t).T1       = 0.3;
templates(t).T2       = 0.060;
templates(t).dt       = 0.010;

% --- Edge: very short T2 (near-complete transverse decay) ---
% T2 << dt: almost all transverse magnetisation decays within one step.
% Uses the smallest available state; the extreme T2 is the point, not N_q.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'edge_very_short_T2';
templates(t).T1       = 1.0;
templates(t).T2       = 0.001;
templates(t).dt       = 0.010;

% --- Edge: very long T1 on a sparse state ---
% T1 >> dt: longitudinal recovery contribution per step is negligible.
% Sparse state confirms that zero-order entries are not corrupted.
t = t+1;
templates(t).type     = 'sparse';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'edge_very_long_T1';
templates(t).T1       = 10.0;
templates(t).T2       = 0.080;
templates(t).dt       = 0.010;

% --- Edge: dt = 0 (identity) ---
% Zero time step must leave the state unchanged.  Smallest state keeps the
% record compact.
t = t+1;
templates(t).type     = 'equilibrium';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'edge_dt_zero';
templates(t).T1       = 1.0;
templates(t).T2       = 0.080;
templates(t).dt       = 0.0;

cases = expand_case_templates(templates, Q_lib, N_q_list);

end
