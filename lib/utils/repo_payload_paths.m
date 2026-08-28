function p = repo_payload_paths(start_dir)
%REPO_PAYLOAD_PATHS Canonical store / paper / session directories.
%   P = REPO_PAYLOAD_PATHS()
%   P = REPO_PAYLOAD_PATHS(START_DIR)
%
%   Settled layout after the store/ migration. Callers should seed pickers
%   and defaults from these paths rather than examples/, experimental data/,
%   or synthetic results/.

    if nargin < 1 || isempty(start_dir)
        start_dir = fileparts(mfilename('fullpath'));
    end
    root = find_repo_root(start_dir);

    p = struct();
    p.repo_root = root;
    p.ldos = fullfile(root, 'store', 'synthetic', 'ldos');
    p.syn_datasets = fullfile(root, 'store', 'synthetic', 'datasets');
    p.syn_runs = fullfile(root, 'store', 'synthetic', 'runs');
    p.real_raw = fullfile(root, 'store', 'real', 'raw');
    p.real_processed = fullfile(root, 'store', 'real', 'processed');
    p.real_runs = fullfile(root, 'store', 'real', 'runs');
    p.phase_datasets = fullfile(root, 'store', 'phase_space', 'datasets');
    p.phase_parallel = fullfile(root, 'store', 'phase_space', 'parallel_runs');
    p.phase_metrics = fullfile(root, 'store', 'phase_space', 'metrics');
    p.paper_freeze_real = fullfile(root, 'paper', 'freeze', 'real');
    p.paper_freeze_phase = fullfile(root, 'paper', 'freeze', 'phase_space');
    p.projects = fullfile(root, 'run entrance', 'projects');
    p.examples = fullfile(root, 'examples');
    p.examples_data = fullfile(root, 'examples', 'example_data');
end
