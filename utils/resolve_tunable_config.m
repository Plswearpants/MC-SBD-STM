function config_path = resolve_tunable_config(config_filename)
%RESOLVE_TUNABLE_CONFIG Resolve tunable config path for current run env.
%   Priority:
%   1) run env from appdata/getenv:
%        <run_env>/config/<config_filename>
%        <run_env>/<config_filename>
%   2) session runtime tunables:
%        <repo>/config/runtime_tunables/<config_filename>
%   3) repository templates (immutable defaults):
%        <repo>/config/<config_filename>
%        <repo>/config/Xsolve_config.mat or Asolve_config.mat (name remap)

    if nargin < 1 || isempty(config_filename)
        error('config_filename is required.');
    end

    candidates = {};

    run_env = '';
    if isappdata(0, 'MT_SBD_RUN_ENV')
        run_env = getappdata(0, 'MT_SBD_RUN_ENV');
    end
    if isempty(run_env)
        run_env = getenv('MT_SBD_RUN_ENV');
    end
    if ~isempty(run_env)
        candidates{end+1} = fullfile(run_env, 'config', config_filename); %#ok<AGROW>
        candidates{end+1} = fullfile(run_env, config_filename); %#ok<AGROW>
    end

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    candidates{end+1} = fullfile(repo_root, 'config', 'runtime_tunables', config_filename);
    candidates{end+1} = fullfile(repo_root, 'config', config_filename);

    % Fall back to immutable templates when no tunable copy exists yet.
    if strcmp(config_filename, 'Xsolve_config_tunable.mat')
        candidates{end+1} = fullfile(repo_root, 'config', 'Xsolve_config.mat');
    elseif strcmp(config_filename, 'Asolve_config_tunable.mat')
        candidates{end+1} = fullfile(repo_root, 'config', 'Asolve_config.mat');
    end

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            config_path = candidates{i};
            return;
        end
    end

    error('Unable to locate %s in run env, config/runtime_tunables, or config/.', config_filename);
end
