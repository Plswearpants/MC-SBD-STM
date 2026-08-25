function [log, data, params, meta, cfg] = initProliferationReal(log, data, params, meta, cfg)
%INITPROLIFERATIONREAL Initialize kernels for all slices (proliferation).
%
%   [log, data, params, meta, cfg] = initProliferationReal(log, data, params, meta, cfg)
%
%   This wrapper encapsulates the "Block 3: Find Most Isolated Points and
%   Initialize Kernels" logic from historical/real/hist_MTSBD_block_realdata1.m, with
%   the most-isolated-points AUTO mode treated as retired. It:
%       - previews the K1...Kn kernel ordering on the reference slice
%       - resolves kernel centers (reference centers or manual selection)
%       - proliferates kernels across all slices via initialize_kernels_proliferation
%       - enforces kernel polarity per slice
%       - converts A1_all to matrix form A1_all_matrix
%       - estimates per-slice noise (eta_data3d)
%
%   Results are stored under data.real.proliferation.* and params.proliferation.
%
%   Presets:
%       cfg.blockInit.center_source - 'manual' (default; click every center),
%           'reference' (reuse data.real.ref.ref_kernel_centers), or 'ask'
%           (show the ordering preview and prompt for one of the two).
%       cfg.blockInit.show_order_preview - draw the K1...Kn preview figure
%           before resolving centers (default: true for 'ask', else false).
%       cfg.blockInit.reuse_noise_roi - estimate 3D noise from the reference
%           background ROI instead of the whole volume (default: false).
%
%   Defaults preserve the original behavior: manual selection, no preview,
%   whole-volume noise estimate.

    arguments
        log  struct
        data struct
        params struct
        meta struct
        cfg  struct
    end

    if ~isfield(data, "real") || ~isfield(data.real, "Y")
        error('initProliferationReal: data.real.Y is missing. Run preprocessRealData first.');
    end
    if ~isfield(data.real, "ref") || ~isfield(data.real.ref, "Y_ref")
        error('initProliferationReal: data.real.ref.Y_ref is missing. Run decomposeRefSliceReal first.');
    end

    Y     = data.real.Y;
    Y_ref = data.real.ref.Y_ref;
    kernel_sizes = data.real.ref.kernel_sizes;
    num_kernels  = params.refSlice.num_kernels;
    ref_slice    = params.refSlice.ref_slice;

    num_slices = size(Y, 3);

    % ---------------------------------------------------------------------
    % Resolve kernel centers (AUTO isolation logic retired)
    % ---------------------------------------------------------------------
    if ~isfield(cfg, "blockInit"); cfg.blockInit = struct(); end

    center_source = 'manual';
    if isfield(cfg.blockInit, "center_source") && ~isempty(cfg.blockInit.center_source)
        center_source = lower(char(cfg.blockInit.center_source));
    end

    show_order_preview = strcmp(center_source, 'ask');
    if isfield(cfg.blockInit, "show_order_preview") && ~isempty(cfg.blockInit.show_order_preview)
        show_order_preview = logical(cfg.blockInit.show_order_preview);
    end

    ref_kernel_centers = [];
    if isfield(data.real.ref, "ref_kernel_centers")
        ref_kernel_centers = data.real.ref.ref_kernel_centers;
    end
    have_ref_centers = ~isempty(ref_kernel_centers) && size(ref_kernel_centers, 1) == num_kernels;

    % Show the K-index mapping so the user can keep K1...Kn consistent.
    if show_order_preview && ~isfield(data.real.ref, "A1_ref")
        warning('initProliferationReal: reference kernels unavailable; skipping order preview.');
        show_order_preview = false;
    end
    if show_order_preview
        A1_ref = data.real.ref.A1_ref;
        figure('Name', 'Reference Kernel Order Preview');
        tlo = tiledlayout(2, num_kernels, 'TileSpacing', 'compact', 'Padding', 'compact');
        for k = 1:num_kernels
            axk = nexttile(k);
            imagesc(axk, A1_ref{k});
            colormap(axk, gray);
            colorbar(axk);
            axis(axk, 'square');
            title(axk, sprintf('K%d Reference Kernel', k));
        end
        axref = nexttile(num_kernels + 1, [1, num_kernels]);
        imagesc(axref, Y_ref);
        colormap(axref, gray);
        colorbar(axref);
        axis(axref, 'square');
        hold(axref, 'on');
        if have_ref_centers
            for k = 1:num_kernels
                scatter(axref, ref_kernel_centers(k,2), ref_kernel_centers(k,1), 120, 'r', '*', 'LineWidth', 1.5);
                text(axref, ref_kernel_centers(k,2) + 4, ref_kernel_centers(k,1), sprintf('K%d', k), ...
                    'Color', 'r', 'FontWeight', 'bold', 'FontSize', 11);
            end
            title(axref, 'Reference Slice with Ordered Centers (K1...Kn)');
        else
            title(axref, 'Reference Slice (reference centers unavailable)');
        end
        hold(axref, 'off');
        title(tlo, 'Kernel Ordering Preview: use this K-index mapping consistently');
    end

    if strcmp(center_source, 'ask')
        use_ref_centers = input('Use reference-kernel centers for all-slice initialization? [1 default / 0 reselect]: ');
        if isempty(use_ref_centers)
            use_ref_centers = 1;
        end
        if use_ref_centers
            center_source = 'reference';
        else
            center_source = 'manual';
        end
    end

    if strcmp(center_source, 'reference') && ~have_ref_centers
        warning(['initProliferationReal: reference kernel centers unavailable; ', ...
            'falling back to manual selection.']);
        center_source = 'manual';
    end

    if strcmp(center_source, 'reference')
        kernel_centers = ref_kernel_centers;
        fprintf('Using reference-kernel centers:\n');
    else
        fprintf('Manual kernel center selection mode...\n');

        figure('Name', 'Manual Kernel Center Selection (Proliferation)');
        imagesc(Y_ref);
        axis square;
        title('Click on centers to select kernel positions. Press Enter when done.');
        colormap(gray);
        colorbar;

        kernel_centers = zeros(num_kernels, 2);
        for k = 1:num_kernels
            fprintf('Click on center for kernel %d/%d\n', k, num_kernels);
            [x, y] = ginput(1);
            kernel_centers(k,:) = [round(y), round(x)];  % [row, col]

            hold on;
            scatter(x, y, 100, 'r', '*');
            text(x+5, y+5, sprintf('K%d', k), 'Color', 'red', ...
                'FontSize', 12, 'FontWeight', 'bold');
            hold off;
        end

        fprintf('Kernel centers selected:\n');
    end

    for k = 1:num_kernels
        fprintf('Kernel %d: (%d, %d)\n', k, kernel_centers(k,1), kernel_centers(k,2));
    end

    % Target kernel sizes: use reference kernel sizes by default
    target_kernel_sizes = kernel_sizes;

    % ---------------------------------------------------------------------
    % Initialize kernels for all slices (initialize_kernels_proliferation)
    % ---------------------------------------------------------------------
    A1_all      = cell(num_slices, num_kernels);
    A1_all_crop = cell(num_slices, num_kernels);

    matrix      = cfg.blockInit.use_matrix;
    change_size = cfg.blockInit.change_size;
    window_type = cfg.reference.window_type;

    for s = 1:num_slices
        fprintf('Initializing kernels for slice %d/%d...\n', s, num_slices);
        if matrix
            [A1_all(s,:), A1_all_crop(s,:)] = initialize_kernels_proliferation( ...
                Y(:,:,s), num_kernels, kernel_centers, window_type, ...
                target_kernel_sizes, 'interactive', change_size);
        else
            [A1_all(s,:), A1_all_crop(s,:)] = initialize_kernels_proliferation( ...
                Y(:,:,s), num_kernels, kernel_centers, window_type, ...
                squeeze(kernel_sizes(s,:,:)), 'interactive', change_size);
        end
    end

    % Enforce kernel polarity per slice
    flip_slices_by_kernel = cell(1, num_kernels);
    for s = 1:num_slices
        for k = 1:num_kernels
            [A1_all{s,k}, flipped] = enforce_kernel_polarity(A1_all{s,k}, A1_all_crop{s,k});
            if flipped
                flip_slices_by_kernel{k}(end+1) = s; %#ok<AGROW>
                fprintf('[kernel flip] kernel %d flipped at slice %d\n', k, s);
            end
        end
    end

    fprintf('==== Kernel flip summary (block init) ====\n');
    for k = 1:num_kernels
        if isempty(flip_slices_by_kernel{k})
            fprintf('Kernel %d: flipped slices = []\n', k);
        else
            flip_slices_by_kernel{k} = unique(flip_slices_by_kernel{k});
            fprintf('Kernel %d: flipped slices = %s\n', k, mat2str(flip_slices_by_kernel{k}));
        end
    end

    % Visualize initialized kernels for reference slice
    figure('Name', 'Initialized Kernels (Reference Slice)');
    for k = 1:num_kernels
        subplot(1, num_kernels, k);
        imagesc(A1_all{ref_slice,k});
        colormap(gray);
        colorbar;
        title(sprintf('Initialized Kernel %d', k));
        axis square;
    end

    % Convert A1_all to matrix form
    A1_all_matrix = cell(num_kernels, 1);
    for k = 1:num_kernels
        A1_all_matrix{k} = zeros(size(A1_all{1,k},1), size(A1_all{1,k},2), num_slices);
        for s = 1:num_slices
            A1_all_matrix{k}(:,:,s) = A1_all{s,k};
        end
    end

    % Noise estimate per slice, optionally reusing the reference background ROI
    reuse_noise_roi = false;
    if isfield(cfg.blockInit, "reuse_noise_roi") && ~isempty(cfg.blockInit.reuse_noise_roi)
        reuse_noise_roi = logical(cfg.blockInit.reuse_noise_roi);
    end

    noise_roi = [];
    if reuse_noise_roi && isfield(params, "refSlice") && isfield(params.refSlice, "noise_roi")
        noise_roi = params.refSlice.noise_roi;
    end

    if ~isempty(noise_roi)
        eta_data3d = estimate_noise3D(Y, 'std', noise_roi);
    else
        eta_data3d = estimate_noise3D(Y, 'std');
    end

    % ---------------------------------------------------------------------
    % Store results
    % ---------------------------------------------------------------------
    if ~isfield(data.real, "proliferation")
        data.real.proliferation = struct();
    end

    data.real.proliferation.A1_all       = A1_all;
    data.real.proliferation.A1_all_crop  = A1_all_crop;
    data.real.proliferation.A1_all_matrix = A1_all_matrix;
    data.real.proliferation.kernel_centers = kernel_centers;
    data.real.proliferation.target_kernel_sizes = target_kernel_sizes;
    data.real.proliferation.eta_data3d   = eta_data3d;

    params.proliferation.kernel_centers      = kernel_centers;
    params.proliferation.target_kernel_sizes = target_kernel_sizes;
    params.proliferation.center_source       = center_source;

    % Stage remains "pre-run" (still preparation for block run)
    meta.stage = "pre-run";

    LOGcomment = sprintf(['initProliferationReal: center_source=%s, centers=%s, ', ...
        'num_slices=%d, num_kernels=%d, reuse_noise_roi=%d'], ...
        center_source, mat2str(kernel_centers), num_slices, num_kernels, reuse_noise_roi);
    logBlockIfEnabled(log, "IP01R", LOGcomment);

end

