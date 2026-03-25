% RUN_HARNESS  Main entry point for EPG golden data generation.
%
% Usage (from project root):
%   run('matlab/harness/run_harness.m')
%
% With custom nstates sizes, call generate_golden_data directly:
%   addpath('matlab/harness');
%   generate_golden_data([4, 8, 16, 32])

fprintf('EPG Golden Data Harness\n');
fprintf('=======================\n\n');

harness_dir = fileparts(mfilename('fullpath'));
addpath(harness_dir);

generate_golden_data();
