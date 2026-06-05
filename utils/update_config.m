function update_config(config_file, param_path, new_value, new_file_name)
%UPDATE_CONFIG Update one field in a MAT config struct.
%   update_config(CONFIG_FILE, PARAM_PATH, NEW_VALUE)
%   update_config(CONFIG_FILE, PARAM_PATH, NEW_VALUE, NEW_FILE_NAME)

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
        save_file = new_file_name;
    end

    save(save_file, '-struct', 'config');
end

