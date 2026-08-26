function config_path = resolve_tunable_config(config_filename)
%RESOLVE_TUNABLE_CONFIG Resolve tunable config path for the current trial.
%   Priority:
%   1) Suffixed trial copy when MC_SBD_TUNABLE_ID is set:
%        <repo>/config/runtime_tunables/Xsolve_config_tunable_<id>.mat
%   2) Unsuffixed session copy:
%        <repo>/config/runtime_tunables/<config_filename>
%   3) Repository templates (immutable defaults):
%        <repo>/config/<config_filename>
%        <repo>/config/Xsolve_config.mat or Asolve_config.mat (name remap)

    if nargin < 1 || isempty(config_filename)
        error('config_filename is required.');
    end

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    names = {config_filename};
    suffixed = suffixTunableFilename(config_filename);
    if ~strcmp(suffixed, config_filename)
        names = [{suffixed}, names];
    end

    candidates = {};
    for i = 1:numel(names)
        nm = names{i};
        candidates{end+1} = fullfile(repo_root, 'config', 'runtime_tunables', nm); %#ok<AGROW>
        candidates{end+1} = fullfile(repo_root, 'config', nm); %#ok<AGROW>
    end

    % Fall back to immutable templates when no tunable copy exists yet.
    if strcmp(config_filename, 'Xsolve_config_tunable.mat') || ...
            startsWith(config_filename, 'Xsolve_config_tunable_')
        candidates{end+1} = fullfile(repo_root, 'config', 'Xsolve_config.mat');
    elseif strcmp(config_filename, 'Asolve_config_tunable.mat') || ...
            startsWith(config_filename, 'Asolve_config_tunable_')
        candidates{end+1} = fullfile(repo_root, 'config', 'Asolve_config.mat');
    end

    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            config_path = candidates{i};
            return;
        end
    end

    error('Unable to locate %s in config/runtime_tunables or config/.', config_filename);
end
