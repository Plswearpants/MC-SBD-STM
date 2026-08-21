function update_config(config_file, param_path, new_value, new_file_name)
%UPDATE_CONFIG Update one field in a MAT config struct.
%   update_config(CONFIG_FILE, PARAM_PATH, NEW_VALUE)
%   update_config(CONFIG_FILE, PARAM_PATH, NEW_VALUE, NEW_FILE_NAME)
%
%   When NEW_FILE_NAME is provided it must resolve to an absolute path.
%   Bare/relative names are rewritten under:
%     1) <MT_SBD_RUN_ENV>/config/   if a run environment is active
%     2) <repo>/config/runtime_tunables/   otherwise
%   Immutable templates under config/ must not be overwritten via relative names.

    if nargin < 3
        error('update_config requires config_file, param_path, and new_value.');
    end

    if ~exist(config_file, 'file')
        error('Config file %s does not exist.', config_file);
    end

    config = load(config_file);
    fields = strsplit(param_path, '.');

    if numel(fields) == 1
        config.(fields{1}) = new_value;
    else
        config = setfield(config, fields{:}, new_value); %#ok<SFLD>
    end

    if nargin < 4 || isempty(new_file_name)
        save_file = config_file;
    else
        save_file = resolve_tunable_output_path(new_file_name);
    end

    save_dir = fileparts(save_file);
    if ~isempty(save_dir) && ~isfolder(save_dir)
        mkdir(save_dir);
    end

    save(save_file, '-struct', 'config');
end

function save_file = resolve_tunable_output_path(new_file_name)
    new_file_name = char(new_file_name);
    if is_absolute_path(new_file_name)
        save_file = new_file_name;
        return;
    end

    [~, name, ext] = fileparts(new_file_name);
    bare = [name ext];

    run_env = '';
    if isappdata(0, 'MT_SBD_RUN_ENV')
        run_env = getappdata(0, 'MT_SBD_RUN_ENV');
    end
    if isempty(run_env)
        run_env = getenv('MT_SBD_RUN_ENV');
    end

    if ~isempty(run_env)
        save_file = fullfile(run_env, 'config', bare);
        return;
    end

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    save_file = fullfile(repo_root, 'config', 'runtime_tunables', bare);
end

function tf = is_absolute_path(p)
    if ispc
        tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
    else
        tf = startsWith(p, '/');
    end
end
