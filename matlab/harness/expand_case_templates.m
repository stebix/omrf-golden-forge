function cases = expand_case_templates(templates, Q_lib, nstates_list)
% EXPAND_CASE_TEMPLATES  Resolve template definitions into concrete test cases.
%
%   cases = expand_case_templates(templates, Q_lib, nstates_list)
%
%   Converts an array of template structs into a concrete struct array of
%   test cases by resolving each template's nstates selection policy against
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
%     .policy    nstates selection rule (string).  See "nstates selection
%                policies" below.
%
%     .tag_stem  Base tag string (string).  The resolved nstates is appended
%                as '_nstates<N>' to form the final case tag, so every
%                generated case has an unambiguous, size-explicit identifier.
%                Example: 'equilibrium_90deg_x' -> 'equilibrium_90deg_x_nstates8'
%
%   All remaining fields are treated as operator parameters and are copied
%   verbatim into each generated case struct.
%
%   nstates selection policies
%   --------------------------
%   'representative'
%       Picks a single nstates using pick_representative_nstates (upper-
%       median of sorted nstates_list).  Use for semantic tests where the
%       state-space size is incidental to the mathematical behaviour being
%       verified.
%
%   'all'
%       Generates one case for every nstates in nstates_list (sorted
%       ascending).  Use for explicit size-sweep tests that verify an
%       operator handles different dimensionalities correctly.
%
%   'smallest'
%       Picks min(nstates_list).  Use for edge cases that benefit from a
%       minimal state space (e.g. zero-flip, dt=0 identity checks).
%
%   'largest'
%       Picks max(nstates_list).  Use for cases that benefit from extra
%       coherence orders, such as multi-twist spoiler tests where many
%       orders are shifted in a single step.
%
%   'min:<N>'
%       Picks the smallest nstates in nstates_list that is >= N.  Use when
%       a test requires at least N coherence orders to be meaningful.
%       Raises an error if no qualifying nstates exists.  Example: 'min:12'
%
%   Output
%   ------
%   A struct array where each element has:
%     .tag   '<tag_stem>_nstates<nstates>'
%     .Q_in  Q state matrix returned by pick_q(Q_lib, type, nstates)
%     plus all operator-parameter fields copied from the template.
%
%   See also: pick_q, pick_representative_nstates, make_q_states

META_FIELDS    = {'type', 'policy', 'tag_stem'};
nstates_sorted = sort(nstates_list(:)');

cases = [];

for t = 1:numel(templates)
    tmpl = templates(t);

    % Determine which nstates sizes this template expands to
    nstates_for_template = resolve_policy(tmpl.policy, nstates_sorted);

    % Operator-parameter fields: everything except the three metadata keys
    all_fields   = fieldnames(tmpl);
    param_fields = setdiff(all_fields, META_FIELDS, 'stable');

    for s = 1:numel(nstates_for_template)
        nstates = nstates_for_template(s);

        % Build the concrete case
        c.tag  = sprintf('%s_nstates%d', tmpl.tag_stem, nstates);
        c.Q_in = pick_q(Q_lib, tmpl.type, nstates);

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
%  Local helper: map a policy string to a concrete list of nstates values
% =========================================================================

function nstates_sizes = resolve_policy(policy, nstates_sorted)
% RESOLVE_POLICY  Return the nstates value(s) prescribed by a policy string.
%
%   nstates_sorted must be a row vector of integers sorted in ascending order.

switch policy

    case 'representative'
        nstates_sizes = pick_representative_nstates(nstates_sorted);

    case 'all'
        nstates_sizes = nstates_sorted;

    case 'smallest'
        nstates_sizes = nstates_sorted(1);

    case 'largest'
        nstates_sizes = nstates_sorted(end);

    otherwise
        % Attempt to parse a 'min:<N>' policy
        min_val = sscanf(policy, 'min:%d');
        if numel(min_val) == 1
            candidates = nstates_sorted(nstates_sorted >= min_val);
            if isempty(candidates)
                error('expand_case_templates:noCandidateForMinPolicy', ...
                    ['Policy "%s" requires nstates >= %d, but the available ' ...
                     'sizes are [%s].\nAdd a sufficiently large nstates to ' ...
                     'nstates_list or relax the min constraint.'], ...
                    policy, min_val, num2str(nstates_sorted));
            end
            nstates_sizes = candidates(1);
        else
            error('expand_case_templates:unknownPolicy', ...
                ['Unknown nstates selection policy: "%s".\n' ...
                 'Valid policies: ''representative'', ''all'', ' ...
                 '''smallest'', ''largest'', ''min:<N>''.'], ...
                policy);
        end
end

end
