function Q_lib = make_q_states(nstates_list)
% MAKE_Q_STATES  Build a library of named Q state matrices for test cases.
%   Q_lib = make_q_states(nstates_list) returns a struct of Q matrices for
%   each nstates in nstates_list (default [4, 8, 16]).
%   All random states use rng(42, 'twister') for reproducibility.
%
%   Requires sim_rf on the MATLAB path (from matlab/generated/).

if nargin < 1
    nstates_list = [4, 8, 16];
end

rng(42, 'twister');

for nstates = nstates_list
    sfx = num2str(nstates);

    % 1. Equilibrium: Mz = 1 at zeroth order
    Q = zeros(3, nstates);
    Q(3, 1) = 1.0;
    Q_lib.(['equilibrium_' sfx]) = Q;

    % 2. Post-90-deg RF about x: all magnetisation in F+(0)
    Q = zeros(3, nstates);
    Q(3, 1) = 1.0;
    Q = sim_rf(Q, pi/2, 0);
    Q_lib.(['post_90rf_' sfx]) = Q;

    % 3. Post-45-deg RF about x
    Q = zeros(3, nstates);
    Q(3, 1) = 1.0;
    Q = sim_rf(Q, pi/4, 0);
    Q_lib.(['post_45rf_' sfx]) = Q;

    % 4. Random complex state with EPG conjugate symmetry
    Q_rand = (randn(3, nstates) + 1i * randn(3, nstates)) * 0.1;
    Q_rand(2, :) = conj(Q_rand(1, :));   % F-(k) = conj(F+(k))
    Q_rand(3, :) = real(Q_rand(3, :));    % Z states are real
    Q_lib.(['random_symmetric_' sfx]) = Q_rand;

    % 5. Random complex state (no symmetry — stress test)
    Q_arb = (randn(3, nstates) + 1i * randn(3, nstates)) * 0.2;
    Q_lib.(['random_arbitrary_' sfx]) = Q_arb;

    % 6. Sparse state (few non-zero orders)
    Q_sparse = zeros(3, nstates);
    Q_sparse(1, 1) = 0.3 + 0.1i;
    Q_sparse(2, 1) = conj(Q_sparse(1, 1));
    Q_sparse(3, 1) = 0.7;
    if nstates >= 4
        Q_sparse(1, 3) = 0.05 - 0.02i;
        Q_sparse(2, 3) = conj(Q_sparse(1, 3));
    end
    Q_lib.(['sparse_' sfx]) = Q_sparse;
end

end
