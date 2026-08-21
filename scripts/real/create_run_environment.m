function env = create_run_environment(run_dir, varargin)
%CREATE_RUN_ENVIRONMENT Create a self-contained MT-SBD run folder.
%   ENV = CREATE_RUN_ENVIRONMENT(RUN_DIR)
%   ENV = CREATE_RUN_ENVIRONMENT(RUN_DIR, 'InputFiles', {'a.mat','b.3ds'})
%   ENV = CREATE_RUN_ENVIRONMENT(..., 'SharedInputDir', 'runtime/all_inputs')
%   ENV = CREATE_RUN_ENVIRONMENT(..., 'CopyInputFiles', false)
%
%   The run folder includes:
%     <run_dir>/input
%     <run_dir>/output
%     <run_dir>/logs
%     <run_dir>/config
%       - Xsolve_config.mat
%       - Asolve_config.mat
%       - Xsolve_config_tunable.mat
%       - Asolve_config_tunable.mat
%     <run_dir>/run_mtsbd_block_realdata1.m
%     <run_dir>/run_real_data.m
%     <run_dir>/activate_env.m
%
%   Launchers set MT_SBD_RUN_ENV so tunable solver configs are always read
%   from <run_dir>/config and expose ALL_INPUTS_DIR for data loading.

    if nargin < 1 || isempty(run_dir)
        error('run_dir is required.');
    end

    parser = inputParser;
    addParameter(parser, 'InputFiles', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    addParameter(parser, 'SharedInputDir', '', @(x) ischar(x) || isstring(x));
    addParameter(parser, 'CopyInputFiles', false, @(x) islogical(x) && isscalar(x));
    parse(parser, varargin{:});
    input_files = parser.Results.InputFiles;
    shared_input_dir = char(parser.Results.SharedInputDir);
    copy_input_files = parser.Results.CopyInputFiles;
    if ischar(input_files) || isstring(input_files)
        input_files = cellstr(input_files);
    end

    run_dir = char(run_dir);
    if ~is_absolute_path(run_dir)
        run_dir = fullfile(pwd, run_dir);
    end
    if ~isfolder(run_dir)
        mkdir(run_dir);
    end

    input_dir = fullfile(run_dir, 'input');
    output_dir = fullfile(run_dir, 'output');
    logs_dir = fullfile(run_dir, 'logs');
    cfg_dir = fullfile(run_dir, 'config');
    ensure_dir(input_dir);
    ensure_dir(output_dir);
    ensure_dir(logs_dir);
    ensure_dir(cfg_dir);

    repo_root = fileparts(mfilename('fullpath'));
    while ~exist(fullfile(repo_root, 'init_sbd.m'), 'file')
        parent = fileparts(repo_root);
        if isempty(parent) || strcmp(parent, repo_root)
            error('Could not locate repo root (init_sbd.m).');
        end
        repo_root = parent;
    end
    if isempty(shared_input_dir)
        shared_input_dir = fullfile(repo_root, 'runtime', 'all_inputs');
    elseif ~is_absolute_path(shared_input_dir)
        shared_input_dir = fullfile(repo_root, shared_input_dir);
    end
    ensure_dir(shared_input_dir);

    repo_cfg_dir = fullfile(repo_root, 'config');
    xsolve_src = fullfile(repo_cfg_dir, 'Xsolve_config.mat');
    asolve_src = fullfile(repo_cfg_dir, 'Asolve_config.mat');

    if ~exist(xsolve_src, 'file') || ~exist(asolve_src, 'file')
        addpath(repo_root);
        addpath(genpath(fullfile(repo_root, 'config')));
        default_config_settings('quiet');
    end

    copyfile(xsolve_src, fullfile(cfg_dir, 'Xsolve_config.mat'));
    copyfile(asolve_src, fullfile(cfg_dir, 'Asolve_config.mat'));
    copyfile(xsolve_src, fullfile(cfg_dir, 'Xsolve_config_tunable.mat'));
    copyfile(asolve_src, fullfile(cfg_dir, 'Asolve_config_tunable.mat'));

    registered_inputs = {};
    for i = 1:numel(input_files)
        src = char(input_files{i});
        if ~exist(src, 'file')
            warning('Input file not found and was skipped: %s', src);
            continue;
        end
        [~, name, ext] = fileparts(src);
        filename = [name ext];

        if copy_input_files
            dst = fullfile(input_dir, filename);
            copyfile(src, dst);
            registered_inputs{end+1} = dst; %#ok<AGROW>
        else
            dst = fullfile(shared_input_dir, filename);
            if ~exist(dst, 'file')
                copyfile(src, dst);
            end
            registered_inputs{end+1} = dst; %#ok<AGROW>
        end
    end

    write_launcher(run_dir, repo_root, 'run_mtsbd_block_realdata1.m', ...
        fullfile(repo_root, 'scripts', 'real', 'MTSBD_block_realdata1.m'), shared_input_dir);
    write_launcher(run_dir, repo_root, 'run_real_data.m', ...
        fullfile(repo_root, 'scripts', 'real', 'run_real_data.m'), shared_input_dir);
    write_activate_launcher(run_dir, repo_root, shared_input_dir);

    write_input_manifest(run_dir, shared_input_dir, registered_inputs, copy_input_files);

    env = struct();
    env.run_dir = run_dir;
    env.input_dir = input_dir;
    env.output_dir = output_dir;
    env.logs_dir = logs_dir;
    env.config_dir = cfg_dir;
    env.shared_input_dir = shared_input_dir;
    env.copy_input_files = copy_input_files;
    env.registered_inputs = registered_inputs;
    env.repo_root = repo_root;
    env.launchers = { ...
        fullfile(run_dir, 'run_mtsbd_block_realdata1.m'), ...
        fullfile(run_dir, 'run_real_data.m'), ...
        fullfile(run_dir, 'activate_env.m') ...
    };

    setappdata(0, 'MT_SBD_RUN_ENV', run_dir);
    setenv('MT_SBD_RUN_ENV', run_dir);

    fprintf('Run environment created at: %s\n', run_dir);
    if copy_input_files
        fprintf('Per-run input files directory: %s\n', input_dir);
    else
        fprintf('Shared all-inputs directory: %s\n', shared_input_dir);
    end
    fprintf('Outputs should be saved to: %s\n', output_dir);
    fprintf('Run with: activate_env (manual sections) or run_* launchers\n');
end

function ensure_dir(path_str)
    if ~exist(path_str, 'dir')
        mkdir(path_str);
    end
end

function write_launcher(run_dir, repo_root, launcher_name, target_script, shared_input_dir)
    launcher_path = fullfile(run_dir, launcher_name);
    fid = fopen(launcher_path, 'w');
    if fid < 0
        error('Failed to create launcher file: %s', launcher_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'clc;\n');
    fprintf(fid, 'run_env = ''%s'';\n', escape_single_quotes(run_dir));
    fprintf(fid, 'all_inputs_dir = ''%s'';\n', escape_single_quotes(shared_input_dir));
    fprintf(fid, 'repo_root = ''%s'';\n', escape_single_quotes(repo_root));
    fprintf(fid, 'target_script = ''%s'';\n', escape_single_quotes(target_script));
    fprintf(fid, 'setappdata(0, ''MT_SBD_RUN_ENV'', run_env);\n');
    fprintf(fid, 'setenv(''MT_SBD_RUN_ENV'', run_env);\n');
    fprintf(fid, 'setappdata(0, ''MT_SBD_ALL_INPUTS_DIR'', all_inputs_dir);\n');
    fprintf(fid, 'setenv(''MT_SBD_ALL_INPUTS_DIR'', all_inputs_dir);\n');
    fprintf(fid, 'cd(run_env);\n');
    fprintf(fid, 'addpath(repo_root);\n');
    fprintf(fid, 'init_sbd(''quiet'', false);\n');
    fprintf(fid, 'run(target_script);\n');
end

function write_input_manifest(run_dir, shared_input_dir, registered_inputs, copy_input_files)
    manifest_path = fullfile(run_dir, 'input_manifest.txt');
    fid = fopen(manifest_path, 'w');
    if fid < 0
        warning('Failed to create input manifest: %s', manifest_path);
        return;
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'MT-SBD input manifest\n');
    fprintf(fid, 'shared_input_dir=%s\n', shared_input_dir);
    fprintf(fid, 'copy_input_files=%d\n', copy_input_files);
    fprintf(fid, 'registered_inputs:\n');
    for i = 1:numel(registered_inputs)
        fprintf(fid, '- %s\n', registered_inputs{i});
    end
end

function write_activate_launcher(run_dir, repo_root, shared_input_dir)
    launcher_path = fullfile(run_dir, 'activate_env.m');
    fid = fopen(launcher_path, 'w');
    if fid < 0
        error('Failed to create launcher file: %s', launcher_path);
    end
    cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'clc;\n');
    fprintf(fid, 'run_env = ''%s'';\n', escape_single_quotes(run_dir));
    fprintf(fid, 'all_inputs_dir = ''%s'';\n', escape_single_quotes(shared_input_dir));
    fprintf(fid, 'env = activate_run_environment(run_env, ''SharedInputDir'', all_inputs_dir);\n');
    fprintf(fid, 'disp(env);\n');
end

function out = escape_single_quotes(in)
    out = strrep(in, '''', '''''');
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

