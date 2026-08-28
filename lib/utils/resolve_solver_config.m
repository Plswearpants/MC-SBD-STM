function config_path = resolve_solver_config(config_filename)
%RESOLVE_SOLVER_CONFIG Path to an immutable solver template in repo config/.
%   CONFIG_PATH = RESOLVE_SOLVER_CONFIG('Xsolve_config.mat')
%
%   Templates live at <repo>/config/, not next to lib/core/.

    if nargin < 1 || isempty(config_filename)
        error('config_filename is required.');
    end

    repo_root = find_repo_root(fileparts(mfilename('fullpath')));
    config_path = fullfile(repo_root, 'config', config_filename);
    if exist(config_path, 'file') ~= 2
        error('Unable to locate %s under %s.', config_filename, ...
            fullfile(repo_root, 'config'));
    end
end
