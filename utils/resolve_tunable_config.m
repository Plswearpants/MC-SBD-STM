function config_path = resolve_tunable_config(config_filename)
%RESOLVE_TUNABLE_CONFIG Resolve tunable config path for current run env.
%   Priority:
%   1) run env from appdata/getenv:
%        <run_env>/config/<config_filename>
%        <run_env>/<config_filename>
%   2) repository default:
%        <repo>/examples/<config_filename>

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
    candidates{end+1} = fullfile(repo_root, 'examples', config_filename);

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            config_path = candidates{i};
            return;
        end
    end

    error('Unable to locate %s in run env or repository examples.', config_filename);
end

