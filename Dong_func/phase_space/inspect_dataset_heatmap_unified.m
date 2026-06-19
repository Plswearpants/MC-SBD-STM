function inspect_dataset_heatmap_unified(dataset_metrics, snr_value, metric_type, mode, interp_factor, enable_sigma_analysis)
%INSPECT_DATASET_HEATMAP_UNIFIED Unified click + manual dataset inspector.
%   A single fixed-SNR heatmap UI with:
%     1) click selection on heatmap
%     2) manual parameter entry (SNR, density, axis3, repetition) + Enter button
%   Both selection paths trigger the same dataset visualization backend.
%
% Inputs:
%   dataset_metrics       : struct from loadMetricDataset_new
%   snr_value             : fixed SNR value for heatmap slice (nearest used)
%   metric_type           : 'kernel' | 'combined' | 'multiplied' (default 'combined')
%   mode                  : 1 -> axis3=Nobs, 2 -> axis3=side_length_ratio (default 2)
%   interp_factor         : interpolation factor for heatmap rendering (default 5)
%   enable_sigma_analysis : if true, print denoising sigma diagnostics (default true)

    if nargin < 2 || isempty(snr_value)
        snr_value = 5;
    end
    if nargin < 3 || isempty(metric_type)
        metric_type = 'combined';
    end
    if nargin < 4 || isempty(mode)
        mode = 2;
    end
    if nargin < 5 || isempty(interp_factor)
        interp_factor = 5;
    end
    if nargin < 6 || isempty(enable_sigma_analysis)
        enable_sigma_analysis = true;
    end

    loader_mode = get_loader_axis_mode(dataset_metrics);
    [metric_data, metric_name, theta_values, axis3_values, axis3_label, axis3_tick_fmt] = ...
        resolve_metric_heatmap_inputs(dataset_metrics, metric_type, mode, loader_mode);
    snr_values = dataset_metrics.SNR_values(:)';
    [~, snr_idx_fixed] = min(abs(snr_values - snr_value));
    snr_used = snr_values(snr_idx_fixed);
    metric_slice = squeeze(metric_data(snr_idx_fixed, :, :)); % [theta x axis3]

    ui = struct();
    ui.state = struct();
    ui.state.snr_idx = snr_idx_fixed;
    ui.state.theta_idx = [];
    ui.state.axis_idx = [];
    ui.state.rep_idx = [];
    ui.state.side_idx = [];
    ui.fig = figure('Name', sprintf('Unified Inspector | %s | SNR=%.2f', metric_name, snr_used), ...
        'Position', [120 80 1120 700]);
    ui.ax = axes('Parent', ui.fig, 'Position', [0.07 0.13 0.62 0.80]);
    axes(ui.ax); %#ok<LAXES>
    plot_interpolated_slice(theta_values, axis3_values, metric_slice, ...
        sprintf('%s | SNR=%.2f', metric_name, snr_used), axis3_label, axis3_tick_fmt, interp_factor);
    hold(ui.ax, 'on');

    % --- Control panel
    panel = uipanel('Parent', ui.fig, 'Title', 'Dataset Selector', ...
        'Units', 'normalized', 'Position', [0.72 0.13 0.26 0.80]);

    y = 0.92;
    h = 0.06;
    gap = 0.02;

    uicontrol(panel, 'Style', 'text', 'String', 'SNR', ...
        'Units', 'normalized', 'Position', [0.05 y 0.28 h], 'HorizontalAlignment', 'left');
    ui.edit_snr = uicontrol(panel, 'Style', 'edit', 'String', num2str(snr_used, '%.4g'), ...
        'Units', 'normalized', 'Position', [0.35 y 0.60 h]);
    y = y - h - gap;

    uicontrol(panel, 'Style', 'text', 'String', 'Defect density', ...
        'Units', 'normalized', 'Position', [0.05 y 0.28 h], 'HorizontalAlignment', 'left');
    ui.edit_theta = uicontrol(panel, 'Style', 'edit', 'String', num2str(theta_values(1), '%.4g'), ...
        'Units', 'normalized', 'Position', [0.35 y 0.60 h]);
    y = y - h - gap;

    if mode == 2
        axis3_name = 'Side ratio';
        axis3_default = axis3_values(1);
    else
        axis3_name = 'Nobs';
        axis3_default = axis3_values(1);
    end
    uicontrol(panel, 'Style', 'text', 'String', axis3_name, ...
        'Units', 'normalized', 'Position', [0.05 y 0.28 h], 'HorizontalAlignment', 'left');
    ui.edit_axis3 = uicontrol(panel, 'Style', 'edit', 'String', num2str(axis3_default, '%.4g'), ...
        'Units', 'normalized', 'Position', [0.35 y 0.60 h]);
    y = y - h - gap;

    rep_default = 1;
    if isfield(dataset_metrics, 'repetition_values') && ~isempty(dataset_metrics.repetition_values)
        rep_default = dataset_metrics.repetition_values(1);
    end
    uicontrol(panel, 'Style', 'text', 'String', 'Repetition', ...
        'Units', 'normalized', 'Position', [0.05 y 0.28 h], 'HorizontalAlignment', 'left');
    ui.edit_rep = uicontrol(panel, 'Style', 'edit', 'String', num2str(rep_default), ...
        'Units', 'normalized', 'Position', [0.35 y 0.60 h]);
    y = y - h - 0.03;

    ui.btn_manual = uicontrol(panel, 'Style', 'pushbutton', 'String', 'Enter / Plot (manual)', ...
        'Units', 'normalized', 'Position', [0.05 y 0.90 h], ...
        'Callback', @(~,~) on_manual_submit());
    y = y - h - gap;

    ui.btn_click = uicontrol(panel, 'Style', 'pushbutton', 'String', 'Plot last clicked point', ...
        'Units', 'normalized', 'Position', [0.05 y 0.90 h], ...
        'Callback', @(~,~) on_click_submit());
    y = y - h - gap;

    ui.btn_close = uicontrol(panel, 'Style', 'pushbutton', 'String', 'Close', ...
        'Units', 'normalized', 'Position', [0.05 y 0.90 h], ...
        'Callback', @(~,~) close(ui.fig));
    y = y - h - gap;

    ui.status = uicontrol(panel, 'Style', 'text', ...
        'String', 'Click on heatmap or enter parameters, then press Enter/Plot.', ...
        'Units', 'normalized', 'Position', [0.05 max(0.03, y-0.18) 0.90 0.22], ...
        'HorizontalAlignment', 'left');

    set(ui.fig, 'WindowButtonDownFcn', @(~,~) on_mouse_click());

    fprintf('\nUnified inspector ready at SNR=%.2f.\n', snr_used);
    fprintf('Use click-selection or manual fields + Enter/Plot.\n');

    % -------- nested callbacks --------
    function on_mouse_click()
        obj = hittest(ui.fig);
        if isempty(obj) || ~isgraphics(obj)
            return;
        end
        ax_hit = ancestor(obj, 'axes');
        if isempty(ax_hit) || ax_hit ~= ui.ax
            return;
        end
        cp = get(ui.ax, 'CurrentPoint');
        x_click = cp(1,1);
        y_click = cp(1,2);
        if ~isfinite(x_click) || ~isfinite(y_click) || x_click <= 0
            return;
        end

        [~, theta_idx] = min(abs(log10(theta_values) - log10(x_click)));
        [~, axis3_idx] = min(abs(axis3_values - y_click));
        theta_pick = theta_values(theta_idx);
        axis3_pick = axis3_values(axis3_idx);

        [axis_idx, side_idx] = map_axis_index(snr_idx_fixed, theta_idx, axis3_idx);
        [rep_idx, rep_val] = resolve_available_rep(dataset_metrics, snr_idx_fixed, theta_idx, axis_idx);
        if isempty(rep_idx)
            set(ui.status, 'String', 'No reconstruction payload at clicked location.');
            return;
        end

        ui.state.theta_idx = theta_idx;
        ui.state.axis_idx = axis_idx;
        ui.state.rep_idx = rep_idx;
        ui.state.side_idx = side_idx;

        plot(ui.ax, theta_pick, axis3_pick, 'o', 'Color', [0.95 0.2 0.2], ...
            'MarkerSize', 10, 'LineWidth', 1.8);
        set(ui.edit_theta, 'String', num2str(theta_pick, '%.6g'));
        set(ui.edit_axis3, 'String', num2str(axis3_pick, '%.6g'));
        set(ui.edit_rep, 'String', num2str(rep_val));
        set(ui.status, 'String', sprintf('Clicked: density=%.3g, %s=%.4g, rep=%d', ...
            theta_pick, axis3_name, axis3_pick, rep_val));
        drawnow;
    end

    function on_click_submit()
        if isempty(ui.state.theta_idx) || isempty(ui.state.axis_idx) || isempty(ui.state.rep_idx)
            set(ui.status, 'String', 'No clicked point selected yet.');
            return;
        end
        visualize_selection(ui.state.snr_idx, ui.state.theta_idx, ui.state.axis_idx, ui.state.rep_idx, ui.state.side_idx);
    end

    function on_manual_submit()
        snr_in = str2double(get(ui.edit_snr, 'String'));
        theta_in = str2double(get(ui.edit_theta, 'String'));
        axis3_in = str2double(get(ui.edit_axis3, 'String'));
        rep_in = str2double(get(ui.edit_rep, 'String'));
        if any(~isfinite([snr_in, theta_in, axis3_in, rep_in]))
            set(ui.status, 'String', 'Manual input invalid: enter finite numeric values.');
            return;
        end

        [~, snr_idx] = min(abs(snr_values - snr_in));
        [~, theta_idx] = min(abs(theta_values - theta_in));
        [~, axis3_idx] = min(abs(axis3_values - axis3_in));
        [axis_idx, side_idx] = map_axis_index(snr_idx, theta_idx, axis3_idx);
        [rep_idx, rep_val] = resolve_rep_from_input(dataset_metrics, snr_idx, theta_idx, axis_idx, rep_in);
        if isempty(rep_idx)
            set(ui.status, 'String', 'No reconstruction payload for entered point.');
            return;
        end
        set(ui.edit_snr, 'String', num2str(snr_values(snr_idx), '%.6g'));
        set(ui.edit_theta, 'String', num2str(theta_values(theta_idx), '%.6g'));
        set(ui.edit_axis3, 'String', num2str(axis3_values(axis3_idx), '%.6g'));
        set(ui.edit_rep, 'String', num2str(rep_val));
        visualize_selection(snr_idx, theta_idx, axis_idx, rep_idx, side_idx);
    end

    function visualize_selection(snr_idx, theta_idx, axis_idx, rep_idx, side_idx)
        [Y, Y_clean, A0, A0_noiseless, X0, Aout, Xout, bout, extras] = ...
            get_dataset_payload(dataset_metrics, snr_idx, theta_idx, axis_idx, rep_idx);
        if isempty(Aout) || isempty(Xout) || isempty(Y)
            set(ui.status, 'String', 'Selected payload is incomplete.');
            return;
        end

        rep_val = read_rep_value(dataset_metrics, rep_idx);
        nobs_val = read_nobs_for_slot(dataset_metrics, snr_idx, theta_idx, axis_idx, rep_idx);
        theta_val = theta_values(theta_idx);
        snr_val = snr_values(snr_idx);
        if mode == 2
            side_val = axis3_values(side_idx);
            set(ui.status, 'String', sprintf('Plotting SNR=%.2f, density=%.3g, side=%.4g, rep=%d', ...
                snr_val, theta_val, side_val, rep_val));
        else
            side_val = NaN;
            set(ui.status, 'String', sprintf('Plotting SNR=%.2f, density=%.3g, Nobs=%d, rep=%d', ...
                snr_val, theta_val, round(nobs_val), rep_val));
        end

        % Keep denoising sigma printout.
        if enable_sigma_analysis
            [~, ~, sigma_details] = print_sigma_diagnostics(A0, Aout, A0_noiseless);
            [prebuilt_in_maps, prebuilt_out_maps, has_prebuilt] = ...
                get_prebuilt_residual_maps(dataset_metrics, snr_idx, theta_idx, axis_idx, rep_idx);
            if has_prebuilt
                plot_residual_kernel_maps(prebuilt_in_maps, prebuilt_out_maps);
            else
                plot_sigma_fit_residual_kernels(A0, Aout, A0_noiseless, sigma_details);
            end
        end

        % Single visualization backend (avoid overlapping duplicated plots).
        extras.Y_clean = Y_clean;
        [demix_score, overlap_matrix] = computeDemixingMetric(Xout);
        extras.demixing_score = demix_score;
        extras.demixing_matrix = overlap_matrix;
        fig_before = get(0, 'Children');
        visualizeResults(Y, A0_noiseless, Aout, X0, Xout, bout, extras);
        apply_bone_colormap_to_new_nonactivation_figures(fig_before);
        plot_input_gt_output_kernels(A0, A0_noiseless, Aout);

        fprintf('\nSelected dataset:\n');
        fprintf('  SNR: %.2f\n', snr_val);
        fprintf('  Defect density: %.3g\n', theta_val);
        fprintf('  Nobs: %.0f\n', nobs_val);
        if mode == 2
            fprintf('  Side ratio: %.4f\n', side_val);
        end
        fprintf('  Repetition: %d\n', rep_val);
        fprintf('  Demixing score: %.4f\n', demix_score);
    end

    function [axis_idx, side_idx] = map_axis_index(snr_idx_for_map, theta_idx, axis3_idx)
        side_idx = axis3_idx;
        if mode == 1
            axis_idx = axis3_idx;
            return;
        end
        if loader_mode == 2
            axis_idx = axis3_idx;
            return;
        end
        axis_idx = resolve_nobs_from_side_ratio(dataset_metrics, snr_idx_for_map, theta_idx, axis3_idx);
        if isempty(axis_idx)
            error('No reconstruction data found for selected side-length ratio point.');
        end
    end
end

function plot_input_gt_output_kernels(A_in, A_gt, A_out)
    in_cells = to_kernel_cells_local(A_in);
    gt_cells = to_kernel_cells_local(A_gt);
    out_cells = to_kernel_cells_local(A_out);
    nk = min([numel(in_cells), numel(gt_cells), numel(out_cells)]);
    if nk < 1
        return;
    end

    e_candidates = zeros(1, 3*nk);
    t = 0;
    for k = 1:nk
        t = t + 1; e_candidates(t) = size(in_cells{k}, 3);
        t = t + 1; e_candidates(t) = size(gt_cells{k}, 3);
        t = t + 1; e_candidates(t) = size(out_cells{k}, 3);
    end
    e_eval = max(e_candidates(1:t));
    e_show = max(1, round((e_eval + 1) / 2));

    figure('Name', sprintf('Kernel snapshot (energy slice %d)', e_show), ...
        'Position', [120, 80, 420*3, 280*nk]);
    tl = tiledlayout(nk, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Input noisy / GT / Output kernels at energy slice %d', e_show));

    for k = 1:nk
        in_stack = expand_stack_depth_local(in_cells{k}, e_eval);
        gt_stack = expand_stack_depth_local(gt_cells{k}, e_eval);
        out_stack = expand_stack_depth_local(out_cells{k}, e_eval);

        in_img = in_stack(:,:,e_show);
        gt_img = gt_stack(:,:,e_show);
        out_img = out_stack(:,:,e_show);

        vals = [in_img(:); gt_img(:); out_img(:)];
        vals = vals(isfinite(vals));
        if isempty(vals)
            cmin = 0; cmax = 1;
        else
            cmin = min(vals);
            cmax = max(vals);
            if ~isfinite(cmin) || ~isfinite(cmax) || cmax <= cmin
                cmin = cmin - 0.5;
                cmax = cmax + 0.5;
            end
        end

        nexttile((k-1)*3 + 1);
        imagesc(in_img); axis image off;
        caxis([cmin, cmax]); colormap(gca, bone(256));
        title(sprintf('Input noisy K%d', k));
        colorbar;

        nexttile((k-1)*3 + 2);
        imagesc(gt_img); axis image off;
        caxis([cmin, cmax]); colormap(gca, bone(256));
        title(sprintf('GT K%d', k));
        colorbar;

        nexttile((k-1)*3 + 3);
        imagesc(out_img); axis image off;
        caxis([cmin, cmax]); colormap(gca, bone(256));
        title(sprintf('Output K%d', k));
        colorbar;
    end
end

function [sigma_in, sigma_out, details] = print_sigma_diagnostics(A0, Aout, A0_noiseless)
    if ~exist('estimateKernelGaussianNoiseVsGT', 'file')
        this_dir = fileparts(mfilename('fullpath'));
        addpath(fullfile(this_dir, '..'));
    end
    [sigma_in, sigma_out, details] = estimateKernelGaussianNoiseVsGT(A0, Aout, A0_noiseless, ...
        'sigmaMethod', 'mad');
    ratio = safe_ratio(sigma_in, sigma_out);
    fprintf('\nKernel Noise Amplitude (vs GT) using shift+gain+bias fit:\n');
    fprintf('  Median sigma_in : %.4g\n', median(sigma_in(:), 'omitnan'));
    fprintf('  Median sigma_out: %.4g\n', median(sigma_out(:), 'omitnan'));
    fprintf('  Median denoising (sigma_in/sigma_out): %.4g\n', median(ratio(:), 'omitnan'));
    print_shift_diagnostics(details);
end

function print_shift_diagnostics(details)
    if isempty(details) || ~isfield(details, 'in') || ~isfield(details, 'out') || ...
            ~isfield(details.in, 'shift') || ~isfield(details.out, 'shift')
        return;
    end
    nk = min(size(details.in.shift, 1), size(details.out.shift, 1));
    if nk < 1
        return;
    end
    fprintf('  Shift summary per kernel (dy, dx):\n');
    for k = 1:nk
        in_shift = reshape(details.in.shift(k, :, :), [], 2);
        out_shift = reshape(details.out.shift(k, :, :), [], 2);

        in_valid = all(isfinite(in_shift), 2);
        out_valid = all(isfinite(out_shift), 2);

        in_txt = summarize_shift_block(in_shift(in_valid, :));
        out_txt = summarize_shift_block(out_shift(out_valid, :));
        fprintf('    K%d: in %s | out %s\n', k, in_txt, out_txt);
    end
end

function txt = summarize_shift_block(shift_block)
    if isempty(shift_block)
        txt = '[n/a]';
        return;
    end
    med_shift = median(shift_block, 1, 'omitnan');
    min_shift = min(shift_block, [], 1);
    max_shift = max(shift_block, [], 1);
    txt = sprintf('[med=(%.0f,%.0f), range_dy=%g..%g, range_dx=%g..%g]', ...
        med_shift(1), med_shift(2), min_shift(1), max_shift(1), min_shift(2), max_shift(2));
end

function plot_sigma_fit_residual_kernels(A_in, A_out, A_gt, details)
    if isempty(details) || ~isfield(details, 'in') || ~isfield(details, 'out') || ...
            ~isfield(details, 'energy_indices')
        return;
    end
    in_cells = to_kernel_cells_local(A_in);
    out_cells = to_kernel_cells_local(A_out);
    gt_cells = to_kernel_cells_local(A_gt);
    nk = min([numel(in_cells), numel(out_cells), numel(gt_cells), size(details.in.gain, 1), size(details.out.gain, 1)]);
    if nk < 1
        return;
    end

    energy_indices = details.energy_indices(:)';
    shift_mode = 'circshift';
    if isfield(details, 'shift_mode') && ischar(details.shift_mode)
        shift_mode = lower(details.shift_mode);
    end

    in_res = compute_mean_residual_maps(in_cells, gt_cells, details.in, energy_indices, shift_mode, nk);
    out_res = compute_mean_residual_maps(out_cells, gt_cells, details.out, energy_indices, shift_mode, nk);

    plot_residual_kernel_maps(in_res, out_res);
end

function plot_residual_kernel_maps(in_res, out_res)
    if ~iscell(in_res) || ~iscell(out_res)
        return;
    end
    nk = min(numel(in_res), numel(out_res));
    if nk < 1
        return;
    end

    all_cells = [in_res(1:nk), out_res(1:nk)];
    non_empty = ~cellfun(@isempty, all_cells);
    if ~any(non_empty)
        return;
    end

    vec_cells = cellfun(@(x) x(:), all_cells(non_empty), 'UniformOutput', false);
    all_vals = vertcat(vec_cells{:});
    all_vals = all_vals(isfinite(all_vals));
    if isempty(all_vals)
        return;
    end

    clim_abs = max(abs(prctile(all_vals, [2 98])));
    if ~isfinite(clim_abs) || clim_abs <= eps
        clim_abs = max(abs(all_vals));
    end
    if ~isfinite(clim_abs) || clim_abs <= eps
        clim_abs = 1;
    end

    figure('Name', 'Residual kernels from shift+gain+bias fit', ...
        'Position', [120, 80, 360*nk, 700]);
    t = tiledlayout(2, nk, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Mean residual kernel across evaluated energies');
    for k = 1:nk
        nexttile(k);
        if isempty(in_res{k})
            axis off;
            title(sprintf('Input K%d (empty)', k));
        else
            imagesc(in_res{k});
            axis image off;
            caxis([-clim_abs, clim_abs]);
            title(sprintf('Input residual K%d', k));
        end
        colormap(gca, bone(256));

        nexttile(nk + k);
        if isempty(out_res{k})
            axis off;
            title(sprintf('Output K%d (empty)', k));
        else
            imagesc(out_res{k});
            axis image off;
            caxis([-clim_abs, clim_abs]);
            title(sprintf('Output residual K%d', k));
        end
        colormap(gca, bone(256));
    end
    cb = colorbar;
    cb.Layout.Tile = 'east';
    ylabel(cb, 'Residual intensity');
end

function apply_bone_colormap_to_new_nonactivation_figures(fig_before)
    fig_after = get(0, 'Children');
    if isempty(fig_after)
        return;
    end
    new_figs = setdiff(fig_after, fig_before);
    if isempty(new_figs)
        return;
    end
    for i = 1:numel(new_figs)
        f = new_figs(i);
        if ~ishandle(f) || ~strcmp(get(f, 'Type'), 'figure')
            continue;
        end
        fig_name = '';
        try
            fig_name = lower(char(get(f, 'Name')));
        catch
        end
        % Keep activation figures unchanged; apply bone to observation/kernel views.
        if ~isempty(strfind(fig_name, 'activation')) %#ok<STREMP>
            continue;
        end
        ax_list = findobj(f, 'Type', 'axes');
        for a = 1:numel(ax_list)
            ax = ax_list(a);
            if isprop(ax, 'Tag') && strcmpi(get(ax, 'Tag'), 'Colorbar')
                continue;
            end
            colormap(ax, bone(256));
        end
    end
end

function residual_maps = compute_mean_residual_maps(noisy_cells, gt_cells, side_details, energy_indices, shift_mode, nk)
    residual_maps = cell(1, nk);
    for k = 1:nk
        gt_stack = expand_stack_depth_local(gt_cells{k}, max(energy_indices));
        noisy_stack = expand_stack_depth_local(noisy_cells{k}, max(energy_indices));
        if size(gt_stack,1) ~= size(noisy_stack,1) || size(gt_stack,2) ~= size(noisy_stack,2)
            continue;
        end
        gain_k = side_details.gain(k, :);
        bias_k = side_details.bias(k, :);
        shift_raw = side_details.shift(k, :, :);
        if isempty(shift_raw)
            continue;
        end
        shift_k = reshape(shift_raw, [], 2);
        acc = zeros(size(gt_stack,1), size(gt_stack,2));
        n_valid = 0;
        for ii = 1:numel(energy_indices)
            eidx = energy_indices(ii);
            if eidx > size(gt_stack,3) || eidx > size(noisy_stack,3) || ...
                    ii > numel(gain_k) || ii > numel(bias_k) || ii > size(shift_k,1)
                continue;
            end
            dy = shift_k(ii, 1);
            dx = shift_k(ii, 2);
            a_fit = gain_k(ii);
            b_fit = bias_k(ii);
            if ~all(isfinite([dy, dx, a_fit, b_fit]))
                continue;
            end
            noisy_slice = noisy_stack(:,:,eidx);
            gt_slice = gt_stack(:,:,eidx);
            aligned = apply_shift_local(noisy_slice, round(dy), round(dx), shift_mode);
            fit_slice = a_fit .* gt_slice + b_fit;
            res = aligned - fit_slice;
            acc = acc + res;
            n_valid = n_valid + 1;
        end
        if n_valid > 0
            residual_maps{k} = acc ./ n_valid;
        else
            residual_maps{k} = [];
        end
    end
end

function cells = to_kernel_cells_local(data_in)
    if iscell(data_in)
        cells = data_in(:).';
        for k = 1:numel(cells)
            cells{k} = to_stack_3d_local(cells{k});
        end
        return;
    end
    if ~isnumeric(data_in)
        error('Kernel input must be numeric or cell.');
    end
    if ndims(data_in) == 2 || ndims(data_in) == 3
        cells = {to_stack_3d_local(data_in)};
        return;
    end
    if ndims(data_in) == 4
        nk = size(data_in, 4);
        cells = cell(1, nk);
        for k = 1:nk
            cells{k} = to_stack_3d_local(data_in(:,:,:,k));
        end
        return;
    end
    error('Unsupported kernel dimensions for residual plotting.');
end

function stack = to_stack_3d_local(x)
    if ndims(x) == 2
        stack = reshape(double(x), size(x,1), size(x,2), 1);
    elseif ndims(x) == 3
        stack = double(x);
    else
        error('Kernel slice must be 2D or 3D.');
    end
end

function stack_out = expand_stack_depth_local(stack_in, target_e)
    if size(stack_in, 3) == target_e
        stack_out = stack_in;
    elseif size(stack_in, 3) == 1 && target_e > 1
        stack_out = repmat(stack_in, 1, 1, target_e);
    else
        error('Kernel stack has %d slices; expected 1 or %d.', size(stack_in,3), target_e);
    end
end

function shifted = apply_shift_local(img, dy, dx, shift_mode)
    if strcmpi(shift_mode, 'zeropad')
        [h, w] = size(img);
        shifted = zeros(h, w);
        y = (1:h) - dy;
        x = (1:w) - dx;
        yy = y >= 1 & y <= h;
        xx = x >= 1 & x <= w;
        src_y = y(yy);
        src_x = x(xx);
        shifted(yy, xx) = img(src_y, src_x);
    else
        shifted = circshift(img, [dy, dx]);
    end
end

function [metric_data, metric_name, theta_values, axis3_values, axis3_label, axis3_tick_fmt] = resolve_metric_heatmap_inputs(dataset_metrics, metric_type, mode, loader_mode)
    theta_values = dataset_metrics.theta_cap_values(:)';
    switch mode
        case 1
            axis3_values = dataset_metrics.Nobs_values(:)';
            axis3_label = 'N_{obs}';
            axis3_tick_fmt = '%.0f';
            [metric_data, metric_name] = get_metric_data_mode1(dataset_metrics, metric_type, loader_mode);
        case 2
            if ~isfield(dataset_metrics, 'side_length_ratio_values') || isempty(dataset_metrics.side_length_ratio_values)
                error('mode=2 requires dataset_metrics.side_length_ratio_values.');
            end
            axis3_values = dataset_metrics.side_length_ratio_values(:)';
            axis3_label = 'side length ratio';
            axis3_tick_fmt = '%.3f';
            [metric_data, metric_name] = get_metric_data_mode2(dataset_metrics, metric_type, loader_mode);
        otherwise
            error('mode must be 1 or 2.');
    end
end

function [rep_idx, rep_val] = resolve_rep_from_input(dm, snr_idx, theta_idx, nobs_idx, rep_input)
    rep_idx = [];
    rep_val = [];
    if ndims(dm.Aout) < 4
        if ~isempty(dm.Aout{snr_idx, theta_idx, nobs_idx})
            rep_idx = 1;
            rep_val = 1;
        end
        return;
    end
    rep_values = 1:size(dm.Aout, 4);
    if isfield(dm, 'repetition_values') && numel(dm.repetition_values) == numel(rep_values)
        rep_values = dm.repetition_values;
    end
    [~, ridx] = min(abs(rep_values - rep_input));
    if ~isempty(dm.Aout{snr_idx, theta_idx, nobs_idx, ridx}) && ...
       ~isempty(dm.Xout{snr_idx, theta_idx, nobs_idx, ridx})
        rep_idx = ridx;
        rep_val = rep_values(ridx);
        return;
    end
    [rep_idx, rep_val] = resolve_available_rep(dm, snr_idx, theta_idx, nobs_idx);
end

function rep_val = read_rep_value(dm, rep_idx)
    if ndims(dm.Aout) < 4
        rep_val = 1;
        return;
    end
    if isfield(dm, 'repetition_values') && rep_idx <= numel(dm.repetition_values)
        rep_val = dm.repetition_values(rep_idx);
    else
        rep_val = rep_idx;
    end
end

function [metric_data, metric_name] = get_metric_data_mode1(dataset_metrics, metric_type, loader_mode)
    if loader_mode == 2
        error('Requested mode=1 inspector, but loaded metrics axis mode is 2. Reload with loadMetricDataset_new(1).');
    end
    switch lower(metric_type)
        case 'kernel'
            metric_data = average_over_repetitions(dataset_metrics.kernel_quality_final);
            metric_name = 'Kernel Similarity';
        case 'combined'
            metric_data = average_over_repetitions(dataset_metrics.combined_activationScore);
            metric_name = 'Combined Activation Score';
        case 'multiplied'
            k = average_over_repetitions(dataset_metrics.kernel_quality_final);
            a = average_over_repetitions(dataset_metrics.activation_similarity_final);
            metric_data = k .* a;
            metric_name = 'Kernel x Activation';
        otherwise
            error('metric_type must be ''kernel'', ''combined'', or ''multiplied''.');
    end
end

function [metric_data, metric_name] = get_metric_data_mode2(dataset_metrics, metric_type, loader_mode)
    if loader_mode == 2
        suffix = '';
    else
        suffix = '_by_side_length_ratio';
    end
    switch lower(metric_type)
        case 'kernel'
            metric_data = average_over_repetitions(select_field(dataset_metrics, ['kernel_quality_final' suffix], 'kernel_quality_final'));
            metric_name = 'Kernel Similarity';
        case 'combined'
            metric_data = average_over_repetitions(select_field(dataset_metrics, ['combined_activationScore' suffix], 'combined_activationScore'));
            metric_name = 'Combined Activation Score';
        case 'multiplied'
            k = average_over_repetitions(select_field(dataset_metrics, ['kernel_quality_final' suffix], 'kernel_quality_final'));
            a = average_over_repetitions(select_field(dataset_metrics, ['activation_similarity_final' suffix], 'activation_similarity_final'));
            metric_data = k .* a;
            metric_name = 'Kernel x Activation';
        otherwise
            error('metric_type must be ''kernel'', ''combined'', or ''multiplied''.');
    end
end

function plot_interpolated_slice(theta_values, axis3_values, metric_slice, title_str, axis3_label, axis3_tick_fmt, interp_factor)
    theta_log = log10(theta_values(:)');
    y_vals = axis3_values(:)';
    [X, Y] = meshgrid(theta_log, y_vals);
    Z = metric_slice';
    xq = linspace(min(theta_log), max(theta_log), max(2, interp_factor * numel(theta_values)));
    yq = linspace(min(y_vals), max(y_vals), max(2, interp_factor * numel(y_vals)));
    [Xq, Yq] = meshgrid(xq, yq);
    Zq = interp2(X, Y, Z, Xq, Yq, 'linear');
    imagesc(10.^xq, yq, Zq);
    set(gca, 'YDir', 'normal');
    try
        colormap(slanCM('viridis'));
    catch
        colormap('parula');
    end
    clim([0 1]);
    cb = colorbar;
    ylabel(cb, 'Performance Score');
    xlabel('defect density');
    ylabel(axis3_label);
    title(title_str, 'FontSize', 10);
    ax = gca;
    ax.YScale = 'linear';
    ax.YTick = axis3_values;
    apply_defect_density_tick_style(ax, theta_values);
    ax.YTickLabel = arrayfun(@(x) sprintf(axis3_tick_fmt, x), axis3_values, 'UniformOutput', false);
    axis square tight;
    grid on;
    ax.GridAlpha = 0.3;
end

function [rep_idx, rep_val] = resolve_available_rep(dm, snr_idx, theta_idx, nobs_idx)
    rep_idx = [];
    rep_val = [];
    if ndims(dm.Aout) < 4
        if ~isempty(dm.Aout{snr_idx, theta_idx, nobs_idx})
            rep_idx = 1;
            rep_val = 1;
        end
        return;
    end
    rep_values = 1:size(dm.Aout, 4);
    if isfield(dm, 'repetition_values') && numel(dm.repetition_values) == numel(rep_values)
        rep_values = dm.repetition_values;
    end
    for r = 1:numel(rep_values)
        if ~isempty(dm.Aout{snr_idx, theta_idx, nobs_idx, r}) && ...
           ~isempty(dm.Xout{snr_idx, theta_idx, nobs_idx, r})
            rep_idx = r;
            rep_val = rep_values(r);
            return;
        end
    end
end

function nobs_val = read_nobs_for_slot(dm, snr_idx, theta_idx, axis_idx, rep_idx)
    if isfield(dm, 'Nobs_at_axis3') && ~isempty(dm.Nobs_at_axis3)
        if ndims(dm.Nobs_at_axis3) == 4
            nobs_val = dm.Nobs_at_axis3(snr_idx, theta_idx, axis_idx, rep_idx);
        else
            nobs_val = dm.Nobs_at_axis3(snr_idx, theta_idx, axis_idx);
        end
        if ~isnan(nobs_val)
            return;
        end
    end
    if isfield(dm, 'Nobs_values') && axis_idx <= numel(dm.Nobs_values)
        nobs_val = dm.Nobs_values(axis_idx);
    else
        nobs_val = NaN;
    end
end

function nobs_idx = resolve_nobs_from_side_ratio(dm, snr_idx, theta_idx, side_idx)
    nobs_idx = [];
    if ndims(dm.Aout) < 4
        for ni = 1:numel(dm.Nobs_values)
            if ~isempty(dm.Aout{snr_idx, theta_idx, ni})
                nobs_idx = ni;
                return;
            end
        end
        return;
    end
    rep_count = size(dm.Aout, 4);
    target_side_ratio = dm.side_length_ratio_values(side_idx);
    for ni = 1:numel(dm.Nobs_values)
        for r = 1:rep_count
            if isempty(dm.Aout{snr_idx, theta_idx, ni, r})
                continue;
            end
            if isfield(dm, 'side_length_ratio_at_axis3') && ~isempty(dm.side_length_ratio_at_axis3)
                ratio_here = dm.side_length_ratio_at_axis3(snr_idx, theta_idx, ni, r);
                if isfinite(ratio_here) && abs(ratio_here - target_side_ratio) < 1e-10
                    nobs_idx = ni;
                    return;
                end
            else
                nobs_idx = ni;
                return;
            end
        end
    end
end

function [Y, Y_clean, A0, A0_noiseless, X0, Aout, Xout, bout, extras] = get_dataset_payload(dm, snr_idx, theta_idx, axis_idx, rep_idx)
    if ndims(dm.Y) < 4
        Y = dm.Y{snr_idx, theta_idx, axis_idx};
        Y_clean = dm.Y_clean{snr_idx, theta_idx, axis_idx};
        A0 = dm.A0{snr_idx, theta_idx, axis_idx};
        A0_noiseless = dm.A0_noiseless{snr_idx, theta_idx, axis_idx};
        X0 = dm.X0{snr_idx, theta_idx, axis_idx};
        Aout = dm.Aout{snr_idx, theta_idx, axis_idx};
        Xout = dm.Xout{snr_idx, theta_idx, axis_idx};
        bout = dm.bout{snr_idx, theta_idx, axis_idx};
        extras = dm.extras{snr_idx, theta_idx, axis_idx};
    else
        Y = dm.Y{snr_idx, theta_idx, axis_idx, rep_idx};
        Y_clean = dm.Y_clean{snr_idx, theta_idx, axis_idx, rep_idx};
        A0 = dm.A0{snr_idx, theta_idx, axis_idx, rep_idx};
        A0_noiseless = dm.A0_noiseless{snr_idx, theta_idx, axis_idx, rep_idx};
        X0 = dm.X0{snr_idx, theta_idx, axis_idx, rep_idx};
        Aout = dm.Aout{snr_idx, theta_idx, axis_idx, rep_idx};
        Xout = dm.Xout{snr_idx, theta_idx, axis_idx, rep_idx};
        bout = dm.bout{snr_idx, theta_idx, axis_idx, rep_idx};
        extras = dm.extras{snr_idx, theta_idx, axis_idx, rep_idx};
    end
end

function [in_maps, out_maps, has_prebuilt] = get_prebuilt_residual_maps(dm, snr_idx, theta_idx, axis_idx, rep_idx)
    in_maps = {};
    out_maps = {};
    has_prebuilt = false;
    if ~isfield(dm, 'denoising_residual_in_maps') || ~isfield(dm, 'denoising_residual_out_maps')
        return;
    end
    if isempty(dm.denoising_residual_in_maps) || isempty(dm.denoising_residual_out_maps)
        return;
    end

    if ndims(dm.Aout) < 4
        in_maps = dm.denoising_residual_in_maps{snr_idx, theta_idx, axis_idx};
        out_maps = dm.denoising_residual_out_maps{snr_idx, theta_idx, axis_idx};
    else
        in_maps = dm.denoising_residual_in_maps{snr_idx, theta_idx, axis_idx, rep_idx};
        out_maps = dm.denoising_residual_out_maps{snr_idx, theta_idx, axis_idx, rep_idx};
    end
    has_prebuilt = iscell(in_maps) && iscell(out_maps) && (~isempty(in_maps) || ~isempty(out_maps));
end

function avg_data = average_over_repetitions(data)
    if ndims(data) == 4
        avg_data = mean(data, 4, 'omitnan');
    else
        avg_data = data;
    end
end

function data = select_field(metrics, preferred_name, fallback_name)
    if isfield(metrics, preferred_name)
        data = metrics.(preferred_name);
    elseif isfield(metrics, fallback_name)
        data = metrics.(fallback_name);
    else
        error('Missing metric field(s): %s and %s', preferred_name, fallback_name);
    end
end

function loader_mode = get_loader_axis_mode(dm)
    if isfield(dm, 'axis3_mode') && isscalar(dm.axis3_mode)
        loader_mode = dm.axis3_mode;
    else
        loader_mode = 1;
    end
end

function ratio = safe_ratio(sigma_in, sigma_out)
    [nr, nc] = size(sigma_in);
    [dr, dc] = size(sigma_out);
    r = min(nr, dr);
    c = min(nc, dc);
    ratio = nan(max(nr, dr), max(nc, dc));
    in_use = sigma_in(1:r, 1:c);
    out_use = sigma_out(1:r, 1:c);
    valid = isfinite(in_use) & isfinite(out_use) & (abs(out_use) > eps);
    tmp = nan(r, c);
    tmp(valid) = in_use(valid) ./ out_use(valid);
    ratio(1:r, 1:c) = tmp;
end
