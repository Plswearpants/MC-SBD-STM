function env = hist_activate_run_environment(run_dir, varargin)
%HIST_ACTIVATE_RUN_ENVIRONMENT Retired run-folder helper (hist_).
%   Official trial record is the project folder + *_LOGfile.txt from the
%   RUN_ trunks. Do not use this for new work.
%   ENV = ACTIVATE_RUN_ENVIRONMENT(RUN_DIR)
%   ENV = ACTIVATE_RUN_ENVIRONMENT(..., 'SharedInputDir', DIR)
%
%   This function does not execute pipeline scripts. It only sets paths and
%   environment variables so users can run script sections manually.

    if nargin < 1 || isempty(run_dir)
        error('run_dir is required.');
    end

    parser = inputParser;
    addParameter(parser, 'SharedInputDir', '', @(x) ischar(x) || isstring(x));
    parse(parser, varargin{:});
    shared_input_dir = char(parser.Results.SharedInputDir);

    run_dir = char(run_dir);
    if ~is_absolute_path(run_dir)
        run_dir = fullfile(pwd, run_dir);
    end
    if ~exist(run_dir, 'dir')
        error('Run directory does not exist: %s', run_dir);
    end

    repo_root = fileparts(mfilename('fullpath'));
    while ~exist(fullfile(repo_root, 'init_sbd.m'), 'file')
        parent = fileparts(repo_root);
        if isempty(parent) || strcmp(parent, repo_root)
            error('Could not locate repo root (init_sbd.m).');
        end
        repo_root = parent;
    end
    if isempty(shared_input_dir)
        shared_input_dir = getenv('MT_SBD_ALL_INPUTS_DIR');
    end
    if isempty(shared_input_dir) || ~exist(shared_input_dir, 'dir')
        shared_input_dir = fullfile(repo_root, 'runtime', 'all_inputs');
    end

    setappdata(0, 'MT_SBD_RUN_ENV', run_dir);
    setenv('MT_SBD_RUN_ENV', run_dir);
    setappdata(0, 'MT_SBD_ALL_INPUTS_DIR', shared_input_dir);
    setenv('MT_SBD_ALL_INPUTS_DIR', shared_input_dir);

    cd(run_dir);
    addpath(repo_root);
    init_sbd('quiet', false);

    env = struct();
    env.run_dir = run_dir;
    env.repo_root = repo_root;
    env.shared_input_dir = shared_input_dir;
    env.output_dir = fullfile(run_dir, 'output');
    env.config_dir = fullfile(run_dir, 'config');
    env.input_dir = fullfile(run_dir, 'input');

    fprintf('Runtime environment activated.\n');
    fprintf('run_dir          : %s\n', env.run_dir);
    fprintf('shared_input_dir : %s\n', env.shared_input_dir);
    fprintf('output_dir       : %s\n', env.output_dir);
    fprintf('Open scripts/real/real_block.m (split path) or historical/real/hist_run_real_data.m (combined).\n');
end

function tf = is_absolute_path(path_str)
    tf = false;
    if isempty(path_str)
        return;
    end
    if ispc
        tf = numel(path_str) >= 2 && path_str(2) == ':';
    else
        tf = path_str(1) == '/';
    end
end

