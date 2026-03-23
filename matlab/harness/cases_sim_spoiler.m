function cases = cases_sim_spoiler(Q_lib, N_q_list)
% CASES_SIM_SPOILER  Test case templates for the sim_spoiler operator.
%
%   cases = cases_sim_spoiler(Q_lib, N_q_list)
%
%   Returns a struct array of concrete test cases produced by expanding the
%   template definitions below against the available N_q sizes.  Each case
%   has fields: tag, Q_in, nTwists.
%
%   Template design
%   ---------------
%   sim_spoiler shifts coherence orders by nTwists positions; states that
%   shift beyond the allocated N_q columns are discarded.  Consequently:
%
%   - Single-twist tests (policy 'representative') are largely N_q-
%     agnostic: only a narrow boundary region is affected.
%
%   - The multi-twist test (nTwists = 3, policy 'largest') is placed on the
%     largest available state so that several coherence orders survive the
%     shift and the discarded-boundary behaviour is visible without the
%     state being entirely wiped.
%
%   - Edge and sparse tests use 'smallest' / 'representative' because the
%     interesting property is the operator behaviour, not the size.
%
%   See also: expand_case_templates, make_q_states, generate_golden_data

templates = struct([]);
t = 0;

% --- Single positive twist ---
% Standard positive dephasing step; one coherence order shifts inward.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_single_positive';
templates(t).nTwists  = 1;

% --- Double positive twist ---
% Two successive positive steps collapsed into one call; checks accumulation
% of the shift without an intermediate state.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_double_positive';
templates(t).nTwists  = 2;

% --- Single negative twist (rephasing direction) ---
% Negative nTwists shifts coherences in the rephasing direction; tests the
% conjugate branch of the shift operator.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'post_rf_single_negative';
templates(t).nTwists  = -1;

% --- Random symmetric state, single positive twist ---
% Symmetric state with multiple non-zero orders; confirms the shift
% correctly handles conjugate pairs (F+ and F- shift in opposite
% directions).
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_positive_1';
templates(t).nTwists  = 1;

% --- Random symmetric state, multi-twist, largest available N_q ---
% nTwists = 3 shifts three coherence orders at once.  The largest available
% state is used so that a meaningful number of orders survive the shift and
% the boundary-truncation behaviour can be verified against states that are
% not entirely zeroed out.
t = t+1;
templates(t).type     = 'random_symmetric';
templates(t).policy   = 'largest';
templates(t).tag_stem = 'random_positive_3';
templates(t).nTwists  = 3;

% --- Random arbitrary state, negative multi-twist ---
% An unconstrained state shifted two steps in the rephasing direction;
% stress-tests the shift on a state that does not obey EPG symmetry.
t = t+1;
templates(t).type     = 'random_arbitrary';
templates(t).policy   = 'representative';
templates(t).tag_stem = 'random_negative_2';
templates(t).nTwists  = -2;

% --- Sparse state, single twist ---
% Sparse state with few non-zero orders; confirms that zero entries remain
% zero after the shift and that the single non-trivial order moves correctly.
t = t+1;
templates(t).type     = 'sparse';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'sparse_single';
templates(t).nTwists  = 1;

% --- Edge: zero twist (identity) ---
% nTwists = 0: neither the positive nor negative shift branch executes;
% the state must be returned unchanged.
t = t+1;
templates(t).type     = 'post_45rf';
templates(t).policy   = 'smallest';
templates(t).tag_stem = 'edge_zero_twist';
templates(t).nTwists  = 0;

cases = expand_case_templates(templates, Q_lib, N_q_list);

end
