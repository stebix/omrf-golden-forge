function generate_golden_data(nstates_list)
% GENERATE_GOLDEN_DATA  Generate golden data for all registered EPG operators.
%   generate_golden_data()          — uses config.json, then default [4,8,16]
%   generate_golden_data([4,8,16])  — uses the supplied nstates sizes
%
%   Resolution order for nstates sizes:
%     1. Explicit argument
%     2. config.json in the harness directory
%     3. Built-in default [4, 8, 16]

% Resolve paths relative to this file
harness_dir   = fileparts(mfilename('fullpath'));
matlab_dir    = fileparts(harness_dir);
generated_dir = fullfile(matlab_dir, 'generated');

% Resolve repo root via git (robust to directory depth changes)
[status, repo_root] = system('git rev-parse --show-toplevel');
if status ~= 0
    error('generate_golden_data:noGitRoot', ...
          'Could not determine repository root via git');
end
repo_root  = strtrim(repo_root);
output_dir = fullfile(repo_root, 'golden_data');

% Resolve nstates_list
if nargin < 1
    cfg_file = fullfile(harness_dir, 'config.json');
    if isfile(cfg_file)
        cfg = jsondecode(fileread(cfg_file));
        nstates_list = cfg.nstates(:)';
        fprintf('nstates from config.json: [%s]\n\n', num2str(nstates_list));
    else
        nstates_list = [4, 8, 16];
        fprintf('nstates default: [%s]\n\n', num2str(nstates_list));
    end
else
    fprintf('nstates from argument: [%s]\n\n', num2str(nstates_list));
end

% Add generated operators to path so they are callable
addpath(generated_dir);

% Build deterministic Q state library
Q_lib = make_q_states(nstates_list);

% Operator registry: {name, case_generator_function_handle}
% To add a new operator, append a row here and add a case to run_operator.
operators = {
    'sim_free_relax',  @cases_sim_free_relax
    'sim_dephasing',   @cases_sim_dephasing
    'sim_rf',          @cases_sim_rf
    'sim_spoiler',     @cases_sim_spoiler
};

for i = 1:size(operators, 1)
    op_name     = operators{i, 1};
    case_gen_fn = operators{i, 2};

    fprintf('--- %s ---\n', op_name);

    % Generate test case inputs; nstates_list is forwarded so each generator
    % can expand its templates against the actual available sizes
    cases = case_gen_fn(Q_lib, nstates_list);

    % Run operator on each case, store output
    for k = 1:numel(cases)
        cases(k).Q_out = run_operator(op_name, cases(k));
    end

    % Collect provenance metadata
    meta = collect_metadata(op_name, generated_dir);

    % Serialize to JSON
    save_golden_record(op_name, cases, meta, output_dir);
end

fprintf('\n=== Golden data generation complete ===\n');
fprintf('Output: %s\n', output_dir);

end


%% --- local function: operator dispatch ---
function Q_out = run_operator(op_name, tc)
% RUN_OPERATOR  Call the named EPG operator with parameters from a test case.

Q = tc.Q_in;

switch op_name
    case 'sim_free_relax'
        Q_out = sim_free_relax(Q, tc.T1, tc.T2, tc.dt);
    case 'sim_dephasing'
        Q_out = sim_dephasing(Q, tc.dphi);
    case 'sim_rf'
        Q_out = sim_rf(Q, tc.alpha, tc.phi);
    case 'sim_spoiler'
        Q_out = sim_spoiler(Q, tc.nTwists);
    case 'sim_diffusion'
        Q_out = sim_diffusion(Q, tc.B, tc.ADC);
    case 'sim_sl'
        Q_out = sim_sl(Q, tc.tSL, tc.wSL, tc.T1p, tc.m1p);
    otherwise
        error('generate_golden_data:unknownOperator', ...
              'Unknown operator: %s', op_name);
end

end
