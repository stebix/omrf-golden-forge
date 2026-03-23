function cases = expand_case_templates(templates, Q_lib, N_q_list)
% EXPAND_CASE_TEMPLATES  Resolve template definitions into concrete test cases.
%
%   cases = expand_case_templates(templates, Q_lib, N_q_list)
%
%   Converts an array of template structs into a concrete struct array of
%   test cases by resolving each template's N_q selection policy against
%   the available sizes in Q_lib.
%
%   Template struct fields
%   ----------------------
%   Each template must contain the following three metadata fields:
%
%     .type      Q state type key (string).  Must match a field family in
%                Q_lib (see make_q_states, pick_q).  Examples:
%                  'equilibrium', 'post_45rf', 'random_symmetric',
%                  'random_arbitrary', 'sparse', 'post_90rf'
%
%     .policy    N_q selection rule (string).  See "N_q selection policies"
%                below.
%
%     .tag_stem  Base tag string (string).  The resolved N_q is appended as
%                '_Nq<N>' to form the final case tag, so every generated
%                case has an unambiguous, size-explicit identifier.
%                Example: 'equilibrium_90deg_x' -> 'equilibrium_90deg_x_Nq8'
%
%   All remaining fields are treated as operator parameters and are copied
%   verbatim into each generated case struct.
%
%   N_q selection policies
%   ----------------------
%   'representative'
%       Picks a single N_q using pick_representative_nq (upper-median of
%       sorted N_q_list).  Use for semantic tests where the state-space size
%       is incidental to the mathematical behaviour being verified.
%
%   'all'
%       Generates one case for every N_q in N_q_list (sorted ascending).
%       Use for explicit size-sweep tests that verify an operator handles
%       different dimensionalities correctly.
%
%   'smallest'
%       Picks min(N_q_list).  Use for edge cases that benefit from a minimal
%       state space (e.g. zero-flip, dt=0 identity checks).
%
%   'largest'
%       Picks max(N_q_list).  Use for cases that benefit from extra coherence
%       orders, such as multi-twist spoiler tests where many orders are
%       shifted in a single step.
%
%   'min:<N>'
%       Picks the smallest N_q in N_q_list that is >= N.  Use when a test
%       requires at least N coherence orders to be meaningful.  Raises an
%       error if no qualifying N_q exists.  Example: 'min:12'
%
%   Output
%   ------
%   A struct array where each element has:
%     .tag   '<tag_stem>_Nq<N_q>'
%     .Q_in  Q state matrix returned by pick_q(Q_lib, type, N_q)
%     plus all operator-parameter fields copied from the template.
%
%   See also: pick_q, pick_representative_nq, make_q_states

META_FIELDS = {'type', 'policy', 'tag_stem'};
N_q_sorted  = sort(N_q_list(:)');

cases = [];

for t = 1:numel(templates)
    tmpl = templates(t);

    % Determine which N_q sizes this template expands to
    nq_for_template = resolve_policy(tmpl.policy, N_q_sorted);

    % Operator-parameter fields: everything except the three metadata keys
    all_fields   = fieldnames(tmpl);
    param_fields = setdiff(all_fields, META_FIELDS, 'stable');

    for s = 1:numel(nq_for_template)
        N_q = nq_for_template(s);

        % Build the concrete case
        c.tag  = sprintf('%s_Nq%d', tmpl.tag_stem, N_q);
        c.Q_in = pick_q(Q_lib, tmpl.type, N_q);

        % Copy operator parameters verbatim from the template
        for p = 1:numel(param_fields)
            f    = param_fields{p};
            c.(f) = tmpl.(f);
        end

        % Append to output (AGROW is expected: size is data-driven)
        if isempty(cases)
            cases = c;
        else
            cases(end+1) = c; %#ok<AGROW>
        end
    end
end

end


% =========================================================================
%  Local helper: map a policy string to a concrete list of N_q values
% =========================================================================

function nq_sizes = resolve_policy(policy, N_q_sorted)
% RESOLVE_POLICY  Return the N_q value(s) prescribed by a policy string.
%
%   N_q_sorted must be a row vector of integers sorted in ascending order.

switch policy

    case 'representative'
        nq_sizes = pick_representative_nq(N_q_sorted);

    case 'all'
        nq_sizes = N_q_sorted;

    case 'smallest'
        nq_sizes = N_q_sorted(1);

    case 'largest'
        nq_sizes = N_q_sorted(end);

    otherwise
        % Attempt to parse a 'min:<N>' policy
        min_val = sscanf(policy, 'min:%d');
        if numel(min_val) == 1
            candidates = N_q_sorted(N_q_sorted >= min_val);
            if isempty(candidates)
                error('expand_case_templates:noCandidateForMinPolicy', ...
                    ['Policy "%s" requires N_q >= %d, but the available ' ...
                     'sizes are [%s].\nAdd a sufficiently large N_q to ' ...
                     'N_q_list or relax the min constraint.'], ...
                    policy, min_val, num2str(N_q_sorted));
            end
            nq_sizes = candidates(1);
        else
            error('expand_case_templates:unknownPolicy', ...
                ['Unknown N_q selection policy: "%s".\n' ...
                 'Valid policies: ''representative'', ''all'', ' ...
                 '''smallest'', ''largest'', ''min:<N>''.'], ...
                policy);
        end
end

end
