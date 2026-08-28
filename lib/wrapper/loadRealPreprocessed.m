function [log, data, params, meta, cfg] = loadRealPreprocessed(log, data, params, meta, cfg)
%LOADREALPREPROCESSED Load an already-preprocessed real-data volume Y.
%
%   [log, data, params, meta, cfg] = loadRealPreprocessed(log, data, params, meta, cfg)
%
%   Entry point for workflows that start *after* preprocessing, i.e. from a
%   cleaned Y stored in a .mat file, rather than from a raw .3ds file (see
%   loadRealDataset for the raw path). Encapsulates Block 01 of the legacy
%   historical/real/hist_MCSBD_block_realdata1.m:
%       - resolves an optional extra artifact root (pwd unless pinned)
%       - picks a .mat file (uigetfile) and a variable entry (listdlg)
%       - validates the entry is a numeric image stack
%       - stores it as data.real.Y
%
%   Both selections can be pinned via presets so a session can be replayed
%   non-interactively:
%       cfg.load.preprocessed_file - full path to the .mat ([] = ask)
%       cfg.load.preprocessed_var  - variable name inside it ([] = ask)
%       cfg.io.output_root         - extra artifact root ([] = pwd)
%
%   Trial logs live in the project folder from PJ01R, not in this output_root.
%   Output-root resolution: cfg.io.output_root, else pwd (a leftover
%   MC_SBD_RUN_ENV key is still honored if set).

    arguments
        log  struct
        data struct
        params struct
        meta struct
        cfg  struct
    end

    if ~isfield(cfg, 'load');  cfg.load = struct(); end
    if ~isfield(cfg, 'io');    cfg.io   = struct(); end

    % ---------------------------------------------------------------------
    % Resolve extra artifact root (pwd unless pinned). Logs stay on log.path.
    % ---------------------------------------------------------------------
    if ~isfield(cfg.io, 'output_root') || isempty(cfg.io.output_root)
        run_env_dir = getenv('MC_SBD_RUN_ENV');
        if isempty(run_env_dir) && isappdata(0, 'MC_SBD_RUN_ENV')
            run_env_dir = getappdata(0, 'MC_SBD_RUN_ENV');
        end

        if isempty(run_env_dir)
            cfg.io.output_root = pwd;
        else
            output_root = fullfile(run_env_dir, 'output');
            if ~exist(output_root, 'dir')
                mkdir(output_root);
            end
            cfg.io.output_root = output_root;
        end
    end
    fprintf('Run output root: %s\n', cfg.io.output_root);

    % ---------------------------------------------------------------------
    % Select the .mat file holding Y
    % ---------------------------------------------------------------------
    if ~isfield(cfg.load, 'preprocessed_file') || isempty(cfg.load.preprocessed_file)
        all_inputs_dir = getenv('MC_SBD_ALL_INPUTS_DIR');
        if isempty(all_inputs_dir) && isappdata(0, 'MC_SBD_ALL_INPUTS_DIR')
            all_inputs_dir = getappdata(0, 'MC_SBD_ALL_INPUTS_DIR');
        end

        if isempty(all_inputs_dir) || ~exist(all_inputs_dir, 'dir')
            paths = repo_payload_paths(fileparts(mfilename('fullpath')));
            sample_date = '';
            if isfield(cfg, 'io') && isfield(cfg.io, 'sample_date')
                sample_date = char(cfg.io.sample_date);
            end
            sample = '';
            if isfield(cfg, 'io') && isfield(cfg.io, 'sample')
                sample = char(cfg.io.sample);
            end
            if ~isempty(sample) && ~isempty(sample_date)
                processed_folder = [sample '_' sample_date];
            else
                processed_folder = sample_date;
            end
            dated = fullfile(paths.real_processed, processed_folder);
            if ~isempty(processed_folder) && exist(dated, 'dir')
                all_inputs_dir = dated;
            else
                all_inputs_dir = first_existing_dir({paths.real_processed}, pwd);
            end
        end

        [selected_name, selected_path] = uigetfile({'*.mat', 'MAT-files (*.mat)'}, ...
            'Select MAT file containing Y', all_inputs_dir);
        if isequal(selected_name, 0)
            error('loadRealPreprocessed:NoFileSelected', ...
                'No MAT file selected. Y is required to continue.');
        end
        cfg.load.preprocessed_file = fullfile(selected_path, selected_name);
    end

    selected_file = cfg.load.preprocessed_file;
    if exist(selected_file, 'file') ~= 2
        error('loadRealPreprocessed:FileNotFound', ...
            'Preprocessed file not found: %s', selected_file);
    end

    % ---------------------------------------------------------------------
    % Select the variable entry to use as Y
    % ---------------------------------------------------------------------
    file_vars = whos('-file', selected_file);
    if isempty(file_vars)
        error('loadRealPreprocessed:EmptyFile', ...
            'Selected MAT file has no variables: %s', selected_file);
    end
    var_names = {file_vars.name};

    if isfield(cfg.load, 'preprocessed_var') && ~isempty(cfg.load.preprocessed_var)
        selected_var = char(cfg.load.preprocessed_var);
        if ~any(strcmp(var_names, selected_var))
            error('loadRealPreprocessed:VarNotFound', ...
                'Variable "%s" not found in %s. Available: %s', ...
                selected_var, selected_file, strjoin(var_names, ', '));
        end
    else
        entry_labels = cell(1, numel(file_vars));
        for ii = 1:numel(file_vars)
            entry_labels{ii} = sprintf('%s [%s] %s', ...
                file_vars(ii).name, file_vars(ii).class, mat2str(file_vars(ii).size));
        end

        default_idx = find(strcmp(var_names, 'Y'), 1);
        if isempty(default_idx)
            default_idx = 1;
        end

        [picked_idx, ok] = listdlg( ...
            'PromptString', 'Select variable entry to use as Y:', ...
            'SelectionMode', 'single', ...
            'ListString', entry_labels, ...
            'InitialValue', default_idx, ...
            'ListSize', [520, 300]);
        if ~ok || isempty(picked_idx)
            error('loadRealPreprocessed:NoVarSelected', ...
                'No variable entry selected. Y is required to continue.');
        end
        selected_var = var_names{picked_idx};
        cfg.load.preprocessed_var = selected_var;
    end

    loaded_struct = load(selected_file, selected_var);
    Y = loaded_struct.(selected_var);
    if ~isnumeric(Y) || ndims(Y) < 2
        error('loadRealPreprocessed:InvalidEntry', ...
            ['Selected entry "%s" is not a numeric image stack/matrix. ', ...
            'Please select the correct Y variable.'], selected_var);
    end
    fprintf('Loaded Y from %s (entry: %s)\n', selected_file, selected_var);

    % ---------------------------------------------------------------------
    % Store results
    % ---------------------------------------------------------------------
    if ~isfield(data, 'real'); data.real = struct(); end
    if ~isfield(params, 'real'); params.real = struct(); end

    data.real.Y = Y;

    params.real.num_slices   = size(Y, 3);
    params.real.spatial_size = size(Y, 1);
    params.real.source_file  = selected_file;
    params.real.source_var   = selected_var;

    meta.raw_path_project = selected_file;
    meta.stage = "preprocess";

    LOGcomment = sprintf("loadRealPreprocessed: file=%s, entry=%s, size=%s, output_root=%s", ...
        selected_file, selected_var, mat2str(size(Y)), cfg.io.output_root);
    logBlockIfEnabled(log, "LR01B", LOGcomment);

end
