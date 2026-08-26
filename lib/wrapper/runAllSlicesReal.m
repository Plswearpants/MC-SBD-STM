function [log, data, params, meta, cfg] = runAllSlicesReal(log, data, params, meta, cfg)
%RUNALLSLICESREAL Run MC-SBD on all slices (block run).
%
%   [log, data, params, meta, cfg] = runAllSlicesReal(log, data, params, meta, cfg)
%
%   This wrapper encapsulates the core "block run" logic from
%   historical/real/hist_MCSBD_block_realdata1.m:
%       - selects the slice and kernel subset to run
%       - builds A1_used / Y_used / X_ref_used for that subset
%       - computes trusted-slice weights via build_auto_trusted_slice_weights
%       - sets lambda1_base and weighted/unweighted variants
%       - configures params for MCSBD_all_slice_modified or hist_MCSBD_synthetic_Xregulated_all_slices
%       - runs the chosen algorithm
%       - computes observation_fidelity
%       - stores results under data.real.blockRun
%
%   Visualization-heavy and experimental sections from the legacy script
%   (movies, additional padded runs, sequential runs) are intentionally
%   omitted.
%
%   Presets (all opt-in; defaults reproduce the previous behavior):
%       params.blockRun.slices_to_run   - slice subset ([] = all / prompt)
%       params.blockRun.kernels_to_run  - kernel subset ([] = all kernels)
%       cfg.blockRun.use_xinit_from_ref - seed X from the reference-slice
%           activations instead of letting the solver cold-start (false)
%       params.blockRun.save_tagged_output - write a slice/kernel-tagged .mat
%           of the solver output (false)
%       cfg.io.run_label                - filename stem for that tagged .mat
%       cfg.blockRun.notify_on_completion  - beep/popup/webhook/email (false)
%       params.blockRun.plot_observation_fidelity - fidelity-vs-slice plot (false)
%
%   Kernel-indexed presets (cfg.blockRun.lambda1_base, cfg.blockRun.lambda2)
%   are specified over the FULL kernel set and sliced down to the requested
%   kernel subset.

    arguments
        log  struct
        data struct
        params struct
        meta struct
        cfg  struct
    end

    if ~isfield(data, "real") || ~isfield(data.real, "proliferation")
        error('runAllSlicesReal: proliferation results missing. Run initProliferationReal first.');
    end
    if ~isfield(data.real, "Y")
        error('runAllSlicesReal: data.real.Y is missing. Run preprocessRealData first.');
    end

    Y = data.real.Y;

    A1_all_matrix = data.real.proliferation.A1_all_matrix;
    eta_data3d    = data.real.proliferation.eta_data3d;
    kernel_sizes  = data.real.ref.kernel_sizes;
    num_kernels_full = params.refSlice.num_kernels;
    num_slices_full  = size(Y, 3);

    % ---------------------------------------------------------------------
    % Optional: run only a chosen subset of slices
    % ---------------------------------------------------------------------
    slice_indices = 1:num_slices_full;
    if isfield(params, "blockRun") && isfield(params.blockRun, "slices_to_run") ...
            && ~isempty(params.blockRun.slices_to_run)
        slice_indices = params.blockRun.slices_to_run;
    elseif isfield(params, "blockRun") && isfield(params.blockRun, "interactive") ...
            && params.blockRun.interactive
        slice_indices_in = input('Enter slice indices to run (e.g. 1:10 or [1 3 5]; empty = all): ');
        if ~isempty(slice_indices_in)
            slice_indices = slice_indices_in;
        end
    end

    if islogical(slice_indices)
        if numel(slice_indices) ~= num_slices_full
            error('params.blockRun.slices_to_run logical mask must have length equal to number of slices.');
        end
        slice_indices = find(slice_indices);
    end

    if ~isnumeric(slice_indices) || isempty(slice_indices)
        error('params.blockRun.slices_to_run must be a numeric vector of slice indices or a logical mask.');
    end
    slice_indices = slice_indices(:).';
    if any(mod(slice_indices, 1) ~= 0)
        error('params.blockRun.slices_to_run must contain integer indices.');
    end
    if any(slice_indices < 1) || any(slice_indices > num_slices_full)
        error('params.blockRun.slices_to_run indices must be within 1..%d.', num_slices_full);
    end
    slice_indices = unique(slice_indices, 'stable');

    num_slices_run = numel(slice_indices);
    if num_slices_run ~= num_slices_full
        fprintf('Running block algorithm on slice subset (%d/%d): %s\n', ...
            num_slices_run, num_slices_full, mat2str(slice_indices));
    else
        fprintf('Running block algorithm on all slices (%d).\n', num_slices_full);
    end

    % ---------------------------------------------------------------------
    % Optional: run only a chosen subset of kernels
    % ---------------------------------------------------------------------
    kernel_indices = 1:num_kernels_full;
    if isfield(params, "blockRun") && isfield(params.blockRun, "kernels_to_run") ...
            && ~isempty(params.blockRun.kernels_to_run)
        kernel_indices = params.blockRun.kernels_to_run;
    end

    if islogical(kernel_indices)
        if numel(kernel_indices) ~= num_kernels_full
            error('params.blockRun.kernels_to_run logical mask must have length equal to number of kernels.');
        end
        kernel_indices = find(kernel_indices);
    end

    if ~isnumeric(kernel_indices) || isempty(kernel_indices)
        error('params.blockRun.kernels_to_run must be a numeric vector of kernel indices or a logical mask.');
    end
    kernel_indices = kernel_indices(:).';
    if any(mod(kernel_indices, 1) ~= 0)
        error('params.blockRun.kernels_to_run must contain integer indices.');
    end
    if any(kernel_indices < 1) || any(kernel_indices > num_kernels_full)
        error('params.blockRun.kernels_to_run indices must be within 1..%d.', num_kernels_full);
    end
    kernel_indices = unique(kernel_indices, 'stable');

    num_kernels = numel(kernel_indices);
    if num_kernels ~= num_kernels_full
        fprintf('Running block algorithm on kernel subset (%d/%d): %s\n', ...
            num_kernels, num_kernels_full, mat2str(kernel_indices));
    end

    % ---------------------------------------------------------------------
    % Build the truncated run inputs
    % ---------------------------------------------------------------------
    Y_used = Y(:,:,slice_indices);
    A1_used = A1_all_matrix(kernel_indices);
    for k = 1:num_kernels
        A1_used{k} = A1_used{k}(:,:,slice_indices);
    end
    eta_data3d_used = eta_data3d(slice_indices);
    kernel_sizes_used = kernel_sizes(kernel_indices, :);

    X_ref_used = [];
    if isfield(data.real, "ref") && isfield(data.real.ref, "X_ref") && ~isempty(data.real.ref.X_ref)
        X_ref_used = data.real.ref.X_ref(:,:,kernel_indices);
    end

    % Optional: trusted-slice weighting (still alpha; off unless requested)
    use_trusted_weights = false;
    if isfield(cfg, "blockRun") && isfield(cfg.blockRun, "use_trusted_slice_weights") ...
            && ~isempty(cfg.blockRun.use_trusted_slice_weights)
        use_trusted_weights = logical(cfg.blockRun.use_trusted_slice_weights);
    end
    if isfield(params, "blockRun") && isfield(params.blockRun, "use_trusted_slice_weights") ...
            && ~isempty(params.blockRun.use_trusted_slice_weights)
        use_trusted_weights = logical(params.blockRun.use_trusted_slice_weights);
    end

    trusted_ratio_threshold = cfg.blockRun.trusted_ratio_threshold_default;
    if use_trusted_weights
        if isfield(params, "blockRun") && isfield(params.blockRun, "interactive") ...
                && params.blockRun.interactive
            trusted_ratio_threshold_in = input(sprintf('Enter trusted-slice std-ratio threshold (e.g. %.2f): ', ...
                cfg.blockRun.trusted_ratio_threshold_default));
            if ~isempty(trusted_ratio_threshold_in)
                trusted_ratio_threshold = trusted_ratio_threshold_in;
            end
        end

        manual_trusted_slices = cell(1, num_kernels);
        if cfg.blockRun.use_default_manual_trusted_slices && num_kernels >= 5
            manual_trusted_slices{1} = [1,4,5,8,10];
            manual_trusted_slices{2} = [1,5,8,9,10];
            manual_trusted_slices{3} = 7:11;
            manual_trusted_slices{4} = 7:11;
            manual_trusted_slices{5} = [3,5,6,7];
        end

        % manual_trusted_slices values are specified in FULL slice indices; map to
        % positions within the chosen slice subset for build_auto_trusted_slice_weights.
        manual_trusted_slices_used = manual_trusted_slices;
        if num_slices_run ~= num_slices_full
            for k = 1:num_kernels
                if isempty(manual_trusted_slices{k})
                    manual_trusted_slices_used{k} = [];
                    continue;
                end
                abs_idx = manual_trusted_slices{k}(:).';
                [tf, loc] = ismember(abs_idx, slice_indices);
                manual_trusted_slices_used{k} = loc(tf);
            end
        end

        if exist('build_auto_trusted_slice_weights', 'file') ~= 2
            warning(['build_auto_trusted_slice_weights.m not found on path. ', ...
                'Falling back to unweighted mode (all slices treated as trusted).']);
            use_trusted_weights = false;
        else
            [params.slice_weights, params.slice_weight_details] = ...
                build_auto_trusted_slice_weights(A1_used, eta_data3d_used, trusted_ratio_threshold, ...
                cfg.blockRun.show_trusted_plot, manual_trusted_slices_used);
        end
    end

    if ~use_trusted_weights
        % Unweighted: allow MCSBD_all_slice_modified to default slice_weights = ones
        params.slice_weights = [];
        params.slice_weight_details = struct();
        params.slice_weight_details.trusted_counts = num_slices_run * ones(1, num_kernels);
        params.slice_weight_details.method = "unweighted_all_trusted";
        params.slice_weight_details.trusted_ratio_threshold = trusted_ratio_threshold;
    end

    % ---------------------------------------------------------------------
    % Configure block-run parameters
    % ---------------------------------------------------------------------
    miniloop_iteration = cfg.blockRun.miniloop_iteration;
    outerloop_maxIT    = cfg.blockRun.outerloop_maxIT;

    % lambda1_base is specified over the full kernel set, then sliced.
    lambda1_base_full = cfg.blockRun.lambda1_base;
    if numel(lambda1_base_full) < max(kernel_indices)
        error(['cfg.blockRun.lambda1_base must cover all selected kernel indices ', ...
            '(needs at least %d values, got %d).'], max(kernel_indices), numel(lambda1_base_full));
    end
    params.lambda1_base = lambda1_base_full(kernel_indices);

    trusted_counts = params.slice_weight_details.trusted_counts;
    params.lambda1_weighted   = sqrt(trusted_counts) .* params.lambda1_base;
    params.lambda1_unweighted = sqrt(num_slices_run) .* params.lambda1_base;
    params.lambda1            = params.lambda1_unweighted;

    params.phase2   = cfg.blockRun.phase2;
    params.kplus    = ceil(cfg.blockRun.kplus_factor * kernel_sizes_used);

    % lambda2 is only meaningful per kernel; slice it when long enough,
    % otherwise pass it through unchanged (legacy callers set fewer values).
    lambda2_full = cfg.blockRun.lambda2;
    if numel(lambda2_full) >= max(kernel_indices)
        params.lambda2 = lambda2_full(kernel_indices);
    else
        if num_kernels ~= num_kernels_full
            warning(['cfg.blockRun.lambda2 has %d values but kernel index %d was ', ...
                'requested; passing lambda2 through without slicing.'], ...
                numel(lambda2_full), max(kernel_indices));
        end
        params.lambda2 = lambda2_full;
    end

    params.nrefine  = cfg.blockRun.nrefine;
    params.signflip = cfg.blockRun.signflip;
    params.xpos     = cfg.blockRun.xpos;
    params.getbias  = cfg.blockRun.getbias;
    params.Xsolve   = cfg.blockRun.Xsolve;
    params.use_Xregulated = cfg.blockRun.use_Xregulated;
    params.noise_var       = eta_data3d_used;
    params.kernel_update_order = 1:num_kernels;

    % Optional: warm-start X from the reference-slice activations.
    use_xinit_from_ref = false;
    if isfield(cfg, "blockRun") && isfield(cfg.blockRun, "use_xinit_from_ref") ...
            && ~isempty(cfg.blockRun.use_xinit_from_ref)
        use_xinit_from_ref = logical(cfg.blockRun.use_xinit_from_ref);
    end
    if use_xinit_from_ref
        if isempty(X_ref_used)
            error(['runAllSlicesReal: cfg.blockRun.use_xinit_from_ref is set but ', ...
                'data.real.ref.X_ref is missing. Run decomposeRefSliceReal first.']);
        end
        params.xinit = cell(1, num_kernels);
        for k = 1:num_kernels
            params.xinit{k}.X = X_ref_used(:,:,k);
            params.xinit{k}.b = zeros(num_slices_run, 1);
        end
        fprintf('Warm-starting X from reference-slice activations.\n');
    end

    use_custom_order = false;
    if cfg.blockRun.allow_custom_update_order
        use_custom_order = input('Use custom kernel update order for MCSBD_all_slice_modified? (0/1): ');
    end
    if ~isempty(use_custom_order) && use_custom_order
        custom_order = input(sprintf('Enter kernel update permutation of 1:%d (e.g. [2 1 3 ...]): ', num_kernels));
        custom_order = custom_order(:).';
        if numel(custom_order) ~= num_kernels || any(custom_order < 1) || ...
                any(custom_order > num_kernels) || numel(unique(custom_order)) ~= num_kernels
            error('Invalid kernel update order. Must be a permutation of 1:num_kernels.');
        end
        params.kernel_update_order = custom_order;
    end
    fprintf('Kernel update order: %s\n', mat2str(params.kernel_update_order));

    kernel_sizes_single = squeeze(max(kernel_sizes_used, [], 1));
    if use_trusted_weights
        fprintf('Trusted-slice weights ready. Counts per kernel: %s\n', mat2str(trusted_counts));
        fprintf('Lambda weighted (sqrt(trusted_count)): %s\n', mat2str(params.lambda1_weighted, 4));
    else
        fprintf('Trusted-slice weighting disabled (unweighted mode; all slices treated as trusted).\n');
    end
    fprintf('Lambda unweighted (sqrt(total_slices)): %s\n', mat2str(params.lambda1_unweighted, 4));

    % ---------------------------------------------------------------------
    % Set up display functions
    % ---------------------------------------------------------------------
    figure;
    dispfun = cell(1, num_kernels);
    for n = 1:num_kernels
        if isempty(X_ref_used)
            X_ref_disp = [];
        else
            X_ref_disp = X_ref_used(:,:,n);
        end
        dispfun{n} = @(Y_, A, X, kernel_sizes_sing, kplus) ... %#ok<NASGU,INUSD>
            showims(Y_used, A1_used{n}, X_ref_disp, A, X, kernel_sizes_single, kplus, 1);
    end

    % ---------------------------------------------------------------------
    % Run block algorithm
    % ---------------------------------------------------------------------
    if params.use_Xregulated
        [REG_Aout_ALL, REG_Xout_ALL, REG_bout_ALL, REG_extras_ALL] = ...
            hist_MCSBD_synthetic_Xregulated_all_slices(Y_used, kernel_sizes_used, params, dispfun, ...
            A1_used, miniloop_iteration, outerloop_maxIT); %#ok<NASGU,INUSD>
        error('X-regulated variant not yet wired into data.real storage. Use non-regulated path for now.');
    else
        [Aout_ALL, Xout_ALL, bout_ALL, ALL_extras] = ...
            MCSBD_all_slice_modified(Y_used, kernel_sizes_used, params, dispfun, ...
            A1_used, miniloop_iteration, outerloop_maxIT);
    end

    % Observation fidelity
    eta3dall = permute(repmat(eta_data3d_used, [outerloop_maxIT, 1]), [2,1]);
    observation_fidelity = eta3dall ./ squeeze(var(ALL_extras.phase1.residuals, 0, [1,2]));

    % ---------------------------------------------------------------------
    % Store results
    % ---------------------------------------------------------------------
    if ~isfield(data.real, "blockRun")
        data.real.blockRun = struct();
    end

    data.real.blockRun.Aout_ALL           = Aout_ALL;
    data.real.blockRun.Xout_ALL           = Xout_ALL;
    data.real.blockRun.bout_ALL           = bout_ALL;
    data.real.blockRun.ALL_extras         = ALL_extras;
    data.real.blockRun.observation_fidelity = observation_fidelity;
    data.real.blockRun.trusted_counts     = trusted_counts;
    data.real.blockRun.slice_indices      = slice_indices;
    data.real.blockRun.kernel_indices     = kernel_indices;
    data.real.blockRun.num_slices_full    = num_slices_full;
    data.real.blockRun.num_kernels_full   = num_kernels_full;
    data.real.blockRun.Y_used             = Y_used;
    data.real.blockRun.A1_used            = A1_used;
    data.real.blockRun.X_ref_used         = X_ref_used;
    data.real.blockRun.kernel_sizes_used  = kernel_sizes_used;
    data.real.blockRun.eta_data3d_used    = eta_data3d_used;

    meta.stage = "run";

    % ---------------------------------------------------------------------
    % Optional: slice/kernel-tagged solver output
    % ---------------------------------------------------------------------
    save_tagged = false;
    if isfield(params, "blockRun") && isfield(params.blockRun, "save_tagged_output") ...
            && ~isempty(params.blockRun.save_tagged_output)
        save_tagged = logical(params.blockRun.save_tagged_output);
    end

    allslice_file = '';
    if save_tagged
        allslice_file = save_tagged_solver_output(log, cfg, Y_used, Aout_ALL, Xout_ALL, ...
            bout_ALL, ALL_extras, A1_used, params, eta_data3d_used, observation_fidelity, ...
            slice_indices, kernel_indices);
        data.real.blockRun.output_file = allslice_file;
    end

    % ---------------------------------------------------------------------
    % Optional: completion notification
    % ---------------------------------------------------------------------
    notify_on_completion = false;
    if isfield(cfg, "blockRun") && isfield(cfg.blockRun, "notify_on_completion") ...
            && ~isempty(cfg.blockRun.notify_on_completion)
        notify_on_completion = logical(cfg.blockRun.notify_on_completion);
    end
    if notify_on_completion
        if isempty(allslice_file)
            allslice_file = fullfile(resolve_output_dir(log, cfg), 'blockrun_no_tagged_output.mat');
        end
        notify_allslice_completion(allslice_file, slice_indices, kernel_indices);
    end

    % ---------------------------------------------------------------------
    % Optional: observation-fidelity plot
    % ---------------------------------------------------------------------
    plot_fidelity = false;
    if isfield(params, "blockRun") && isfield(params.blockRun, "plot_observation_fidelity") ...
            && ~isempty(params.blockRun.plot_observation_fidelity)
        plot_fidelity = logical(params.blockRun.plot_observation_fidelity);
    end
    if plot_fidelity
        figure;
        hold on;
        for i = 1:outerloop_maxIT
            plot(1:num_slices_run, observation_fidelity(:,i), ...
                'DisplayName', sprintf('Outer iteration %d', i));
        end
        hold off;
        xlabel('Slice index (within run subset)');
        ylabel('Observation fidelity');
        title('Observation fidelity vs slice');
        legend('show', 'Location', 'best');
    end

    % ---------------------------------------------------------------------
    % Save block-run checkpoint (optional)
    % ---------------------------------------------------------------------
    if isfield(params, "blockRun") && isfield(params.blockRun, "save_checkpoint") ...
            && params.blockRun.save_checkpoint
        if isfield(cfg, "io") && isfield(cfg.io, "blockrun_output_file") ...
                && ~isempty(cfg.io.blockrun_output_file)
            blockrun_file = cfg.io.blockrun_output_file;
        else
            base = 'realdata';
            if isfield(cfg, "load") && isfield(cfg.load, "data_file") && ~isempty(cfg.load.data_file)
                [~, base, ~] = fileparts(cfg.load.data_file);
            end
            blockrun_file = sprintf('%s_blockrun_checkpoint.mat', base);
        end
        % Avoid overwriting an existing checkpoint: if the target file
        % already exists, append a timestamp suffix.
        if exist(blockrun_file, 'file')
            [fpath, fname, fext] = fileparts(blockrun_file);
            ts = datestr(now, 'yyyymmdd_HHMMSS');
            blockrun_file = fullfile(fpath, sprintf('%s_%s%s', fname, ts, fext));
        end
        save(blockrun_file, 'log', 'data', 'params', 'meta', 'cfg', '-v7.3');
        fprintf('Saved block-run checkpoint to %s.\n', blockrun_file);
    end

    LOGcomment = sprintf(['runAllSlicesReal: slices=%s, kernels=%s, miniloop=%d, ', ...
        'outerloop=%d, lambda1=%s, trusted_weights=%d, xinit_from_ref=%d, output=%s'], ...
        mat2str(slice_indices), mat2str(kernel_indices), miniloop_iteration, ...
        outerloop_maxIT, mat2str(params.lambda1, 4), use_trusted_weights, ...
        use_xinit_from_ref, allslice_file);
    logBlockIfEnabled(log, "BR01A", LOGcomment);

end


function output_dir = resolve_output_dir(log, cfg)
%RESOLVE_OUTPUT_DIR Prefer the project folder, then the run output root, then pwd.

    output_dir = '';

    if isstruct(log) && isfield(log, 'path') && ~isempty(log.path)
        output_dir = log.path;
        if iscell(output_dir); output_dir = output_dir{1}; end
        output_dir = char(output_dir);
    end

    if isempty(output_dir) && isfield(cfg, 'io') && isfield(cfg.io, 'output_root') ...
            && ~isempty(cfg.io.output_root)
        output_dir = char(cfg.io.output_root);
    end

    if isempty(output_dir)
        output_dir = pwd;
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
end


function allslice_file = save_tagged_solver_output(log, cfg, Y_used, Aout_ALL, Xout_ALL, ...
    bout_ALL, ALL_extras, A1_used, params, eta_data3d_used, observation_fidelity, ...
    slice_indices, kernel_indices)
%SAVE_TAGGED_SOLVER_OUTPUT Write solver output under a slice/kernel-tagged name.

    output_dir = resolve_output_dir(log, cfg);

    run_label = 'realblock';
    if isfield(cfg, 'io') && isfield(cfg.io, 'run_label') && ~isempty(cfg.io.run_label)
        run_label = char(cfg.io.run_label);
    end

    if isscalar(slice_indices) || all(diff(slice_indices) == 1)
        slice_tag = sprintf('s%dto%d', slice_indices(1), slice_indices(end));
    else
        slice_tag = sprintf('s%s', compact_index_tag(slice_indices));
    end
    kernel_tag = sprintf('k%s', compact_index_tag(kernel_indices));

    allslice_file = fullfile(output_dir, sprintf('%s_%s_%s_ALL.mat', run_label, slice_tag, kernel_tag));
    if exist(allslice_file, 'file')
        ts = datestr(now, 'yyyymmdd_HHMMSS');
        [fpath, fname, fext] = fileparts(allslice_file);
        allslice_file = fullfile(fpath, sprintf('%s_%s%s', fname, ts, fext));
    end

    save(allslice_file, 'Y_used', 'Aout_ALL', 'Xout_ALL', 'bout_ALL', 'ALL_extras', ...
        'A1_used', 'params', 'eta_data3d_used', 'observation_fidelity', ...
        'slice_indices', 'kernel_indices', '-v7.3');
    fprintf('Saved all-slice solver output to %s.\n', allslice_file);
end


function tag = compact_index_tag(idx)
%COMPACT_INDEX_TAG Render an index vector as a filename-safe tag.
    tag = mat2str(idx);
    tag = strrep(tag, ' ', '');
    tag = strrep(tag, '[', '');
    tag = strrep(tag, ']', '');
    tag = strrep(tag, ':', 'to');
end
