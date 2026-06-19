%% Kernel quality comparison from raw measurement and recovered kernels
% Goal:
%   Quantitatively compare user-cropped kernels (from raw Y) against
%   algorithm-recovered kernels across energy slices.
%
% Comparison approaches implemented:
%   A) Raw-data-referenced SNR:
%      SNR = p2v / sigma_noise, where sigma_noise is from user noise ROI.
%   B) P2V-only enhancement:
%      p2v_output / p2v_drawn (noise-independent phenomenological factor).
%   C) Reference-aligned SNR:
%      Normalize both sides (size-invariant), then apply a shared per-kernel
%      scale to match drawn normalized SNR back to drawn raw-SNR baseline.
%
% Notes:
%   - We use RMS normalization for apples-to-apples shape comparisons
%     when comparing recovered kernels to drawn kernels of different sizes.
%   - For absolute SNR in measurement units, use the raw-data sigma_noise path.

%% Setup
if ~exist('estimateMeasurementSNRFromWindows', 'file') || ~exist('estimateKernelSNRWithFixedNoise', 'file')
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(script_dir, '..', 'Dong_func'));
end

%% 1) Load / validate measurement Y
Y = load_measurement_Y_if_needed();
validateattributes(Y, {'numeric'}, {'real', 'finite', 'nonempty'});
if ndims(Y) == 2
    Y = reshape(Y, size(Y,1), size(Y,2), 1);
elseif ndims(Y) ~= 3
    error('Y must be 2D or 3D with size [H,W,E].');
end
[h, w, e] = size(Y);
fprintf('Loaded Y with size [%d, %d, %d].\n', h, w, e);
energy_axis = 1:e;

%% 2) User inputs: kernel ROIs and noise ROI
n = ask_positive_integer('Enter number of kernel windows n: ');
draw_slice = choose_draw_slice(e);
roi_positions = select_square_windows(Y(:,:,draw_slice), n);
noise_roi_position = select_noise_rectangle(Y(:,:,draw_slice));

%% 3) Baseline drawn-kernel SNR from raw data
[snr_matrix, snr_details] = estimateMeasurementSNRFromWindows(Y, roi_positions, noise_roi_position);
snr_list = reshape(snr_matrix, 1, []);

fprintf('\nBaseline drawn-kernel evaluation complete.\n');
fprintf('SNR matrix size: [%d kernels x %d slices]\n', size(snr_matrix,1), size(snr_matrix,2));
fprintf('Flattened list length: %d (= n*e)\n', numel(snr_list));
disp('snr_matrix (rows=kernel windows, cols=energy slices):');
disp(snr_matrix);

assignin('base', 'snr_matrix', snr_matrix);
assignin('base', 'snr_list', snr_list);
assignin('base', 'snr_details', snr_details);
assignin('base', 'snr_roi_positions', roi_positions);
assignin('base', 'snr_noise_roi_position', noise_roi_position);
fprintf(['Saved to workspace variables: snr_matrix, snr_list, snr_details, ' ...
    'snr_roi_positions, snr_noise_roi_position\n']);

%% 4) Baseline visualizations
plot_snr_vs_energy(energy_axis, snr_matrix, 'Drawn Kernel SNR');
plot_sigma_noise_vs_energy(energy_axis, snr_details.noise_std_per_slice);

%% 5) Optional recovered-kernel comparison
compare_output = input('Compare recovered kernels against drawn kernels? (y/n, default n): ', 's');
if strcmpi(strtrim(compare_output), 'y')
    normalization_mode = 'rms'; % size-invariant comparison mode

    drawn_kernel_stacks = extract_drawn_kernel_stacks(Y, roi_positions);
    output_kernels = get_output_kernels_input();

    % A) Post-normalization SNR with same raw-data sigma_noise
    [drawn_snr_norm, drawn_snr_norm_details] = estimateKernelSNRWithFixedNoise( ...
        drawn_kernel_stacks, snr_details.noise_std_per_slice, normalization_mode);
    [output_snr_norm, output_snr_norm_details] = estimateKernelSNRWithFixedNoise( ...
        output_kernels, snr_details.noise_std_per_slice, normalization_mode);

    % Save normalized kernels used in scoring
    drawn_kernels_normalized = drawn_snr_norm_details.normalized_kernels;
    output_kernels_normalized = output_snr_norm_details.normalized_kernels;

    % B) P2V-only enhancement (noise-independent factor)
    drawn_p2v = drawn_snr_norm_details.p2v_matrix;
    output_p2v = output_snr_norm_details.p2v_matrix;
    p2v_enhancement_factor = safe_ratio(output_p2v, drawn_p2v);

    % C) SNR factor post-normalization
    snr_factor_postnorm = safe_ratio(output_snr_norm, drawn_snr_norm);

    % D) Reference-aligned SNR (shared scale per kernel)
    [drawn_snr_scaled, output_snr_scaled, snr_scale_factors] = ...
        scale_snr_to_drawn_reference(snr_matrix, drawn_snr_norm, output_snr_norm);
    snr_factor_reference = safe_ratio(output_snr_scaled, snr_matrix);

    % Save comparison outputs
    assignin('base', 'drawn_kernel_snr_norm_matrix', drawn_snr_norm);
    assignin('base', 'drawn_kernel_snr_norm_details', drawn_snr_norm_details);
    assignin('base', 'output_kernel_snr_matrix', output_snr_norm);
    assignin('base', 'output_kernel_snr_details', output_snr_norm_details);
    assignin('base', 'output_kernel_snr_list', reshape(output_snr_norm, 1, []));
    assignin('base', 'drawn_kernels_normalized', drawn_kernels_normalized);
    assignin('base', 'output_kernels_normalized', output_kernels_normalized);
    assignin('base', 'drawn_p2v_matrix', drawn_p2v);
    assignin('base', 'output_p2v_matrix', output_p2v);
    assignin('base', 'p2v_enhancement_factor', p2v_enhancement_factor);
    assignin('base', 'snr_factor_postnorm', snr_factor_postnorm);
    assignin('base', 'drawn_kernel_snr_scaled_matrix', drawn_snr_scaled);
    assignin('base', 'output_kernel_snr_scaled_matrix', output_snr_scaled);
    assignin('base', 'snr_scale_factors', snr_scale_factors);
    assignin('base', 'snr_factor_reference', snr_factor_reference);

    fprintf(['Saved comparison workspace variables: drawn/output normalized kernels, ' ...
        'post-normalization SNR, P2V enhancement, and reference-aligned SNR factors.\n']);

    % Display key matrices
    disp('drawn_kernel_snr_norm_matrix:'); disp(drawn_snr_norm);
    disp('output_kernel_snr_matrix:'); disp(output_snr_norm);
    disp('p2v_enhancement_factor = output_p2v ./ drawn_p2v:'); disp(p2v_enhancement_factor);
    disp('snr_factor_postnorm = output_snr_norm ./ drawn_snr_norm:'); disp(snr_factor_postnorm);
    disp('snr_scale_factors (per kernel):'); disp(snr_scale_factors);
    disp('snr_factor_reference = output_snr_scaled ./ snr_matrix:'); disp(snr_factor_reference);

    % Comparison plots
    plot_pairwise_snr(energy_axis, drawn_snr_norm, output_snr_norm, ...
        'Post-normalization SNR (raw \sigma_{noise})');
    plot_factor_vs_energy(energy_axis, p2v_enhancement_factor, ...
        'P2V Enhancement Factor (output/drawn)');
    plot_factor_vs_energy(energy_axis, snr_factor_postnorm, ...
        'SNR Factor Post-normalization (output/drawn)');
    plot_pairwise_snr(energy_axis, drawn_snr_scaled, output_snr_scaled, ...
        'Reference-aligned SNR (drawn matched to raw baseline)');
    plot_factor_vs_energy(energy_axis, snr_factor_reference, ...
        'SNR Factor Reference-aligned (output/drawn_raw_ref)');
end

%% ---------------------------- Helpers ----------------------------
function Y = load_measurement_Y_if_needed()
    if evalin('base', 'exist(''Y'', ''var'')')
        Y = evalin('base', 'Y');
        return;
    end
    if evalin('caller', 'exist(''Y'', ''var'')')
        Y = evalin('caller', 'Y');
        return;
    end
    [fname, fpath] = uigetfile('*.mat', 'Select MAT file containing measurement Y');
    if isequal(fname, 0)
        error('No file selected and Y is not in workspace.');
    end
    S = load(fullfile(fpath, fname));
    if isfield(S, 'Y')
        Y = S.Y;
        return;
    end
    vars = fieldnames(S);
    fprintf('Variable Y not found. Available variables:\n');
    disp(vars);
    var_name = input('Enter variable name to use as measurement Y: ', 's');
    if ~isfield(S, var_name)
        error('Variable "%s" does not exist in selected MAT file.', var_name);
    end
    Y = S.(var_name);
end

function n = ask_positive_integer(prompt)
    n = input(prompt);
    while ~isscalar(n) || n < 1 || round(n) ~= n
        n = input('Please enter a positive integer: ');
    end
    n = double(n);
end

function draw_slice = choose_draw_slice(e)
    if e <= 1
        draw_slice = 1;
        return;
    end
    default_slice = ceil(e/2);
    draw_slice = input(sprintf('Slice index for ROI drawing [1..%d] (default=%d): ', e, default_slice));
    if isempty(draw_slice)
        draw_slice = default_slice;
    end
    draw_slice = max(1, min(e, round(draw_slice)));
end

function roi_positions = select_square_windows(slice_img, n)
    f = figure('Name', 'Select Kernel Windows', 'Position', [100, 100, 900, 750]);
    imagesc(slice_img); axis image; colormap(gray); colorbar; hold on;
    title({'Draw a square around each designated kernel pattern.', ...
        'Double-click to confirm each ROI.'});

    roi_positions = zeros(n, 4);
    for k = 1:n
        fprintf('Draw window %d/%d and double-click inside to confirm.\n', k, n);
        h = drawrectangle('Color', 'r', 'FixedAspectRatio', true, ...
            'Label', sprintf('Kernel %d', k), 'Rotatable', false);
        center_handle = plot(nan, nan, 'r+', 'MarkerSize', 9, 'LineWidth', 1.4);
        update_center_indicator(h, center_handle);
        addlistener(h, 'MovingROI', @(src, ~) update_center_indicator(src, center_handle)); %#ok<NASGU>
        addlistener(h, 'ROIMoved', @(src, ~) update_center_indicator(src, center_handle)); %#ok<NASGU>
        wait(h);

        pos = h.Position;
        pos(1:2) = round(pos(1:2));
        side_len = max(2, round(mean(pos(3:4))));
        pos(3:4) = [side_len, side_len];

        roi_positions(k,:) = pos;
        rectangle('Position', pos, 'EdgeColor', 'y', 'LineWidth', 1.2);
        cx = pos(1) + (pos(3)-1)/2;
        cy = pos(2) + (pos(4)-1)/2;
        plot(cx, cy, 'y+', 'MarkerSize', 9, 'LineWidth', 1.4);
        text(pos(1), max(1, pos(2)-6), sprintf('#%d', k), 'Color', 'y', 'FontWeight', 'bold');
        if isgraphics(center_handle), delete(center_handle); end
    end

    hold off;
    if isvalid(f), close(f); end
end

function update_center_indicator(rect_roi, center_handle)
    if ~isvalid(rect_roi) || ~isgraphics(center_handle), return; end
    pos = rect_roi.Position;
    center_handle.XData = pos(1) + pos(3)/2;
    center_handle.YData = pos(2) + pos(4)/2;
end

function noise_roi_position = select_noise_rectangle(slice_img)
    f = figure('Name', 'Select Noise Region', 'Position', [120, 120, 900, 750]);
    imagesc(slice_img); axis image; colormap(gray); colorbar; hold on;
    title({'Draw a rectangular ROI for noise estimation.', ...
        'Use a background region with minimal signal, then double-click to confirm.'});

    h = drawrectangle('Color', 'c', 'FixedAspectRatio', false, ...
        'Label', 'Noise ROI', 'Rotatable', false);
    wait(h);
    pos = h.Position;
    pos(1:2) = round(pos(1:2));
    pos(3:4) = max(2, round(pos(3:4)));
    noise_roi_position = pos;

    rectangle('Position', pos, 'EdgeColor', 'c', 'LineWidth', 1.4, 'LineStyle', '--');
    cx = pos(1) + (pos(3)-1)/2;
    cy = pos(2) + (pos(4)-1)/2;
    plot(cx, cy, 'c+', 'MarkerSize', 9, 'LineWidth', 1.4);
    hold off;
    if isvalid(f), close(f); end
end

function plot_snr_vs_energy(energy_axis, snr_matrix, title_prefix)
    num_kernels = size(snr_matrix, 1);
    for k = 1:num_kernels
        figure('Name', sprintf('%s - Kernel %d', title_prefix, k), ...
            'Position', [130 + 20*k, 110 + 20*k, 920, 500]);
        scatter(energy_axis, snr_matrix(k,:), 38, 'o', ...
            'MarkerFaceColor', [0.1 0.45 0.9], 'MarkerEdgeColor', [0.1 0.45 0.9]);
        grid on;
        xlabel('Energy Slice');
        ylabel('SNR');
        title(sprintf('%s - Kernel %d', title_prefix, k));
    end
end

function plot_sigma_noise_vs_energy(energy_axis, sigma_vec)
    figure('Name', 'Sigma Noise vs Energy', 'Position', [140, 140, 900, 420]);
    plot(energy_axis, sigma_vec, '-o', ...
        'LineWidth', 1.3, 'MarkerSize', 5, ...
        'Color', [0.15 0.55 0.85], 'MarkerFaceColor', [0.15 0.55 0.85]);
    xlabel('Energy Slice');
    ylabel('\sigma_{noise}');
    title('\sigma_{noise} from noise ROI vs Energy');
    grid on;
end

function plot_pairwise_snr(energy_axis, drawn_snr_matrix, output_snr_matrix, title_prefix)
    num_drawn = size(drawn_snr_matrix, 1);
    num_output = size(output_snr_matrix, 1);
    num_fig = max(num_drawn, num_output);
    for k = 1:num_fig
        figure('Name', sprintf('%s - Kernel %d', title_prefix, k), ...
            'Position', [180 + 15*k, 150 + 15*k, 920, 520]);
        hold on;
        if k <= num_drawn
            scatter(energy_axis, drawn_snr_matrix(k,:), 42, 'o', ...
                'MarkerFaceColor', [0.12 0.48 0.86], 'MarkerEdgeColor', [0.12 0.48 0.86], ...
                'DisplayName', 'Drawn');
        end
        if k <= num_output
            scatter(energy_axis, output_snr_matrix(k,:), 46, 's', ...
                'MarkerFaceColor', [0.87 0.34 0.16], 'MarkerEdgeColor', [0.87 0.34 0.16], ...
                'DisplayName', 'Recovered');
        end
        hold off; grid on;
        xlabel('Energy Slice');
        ylabel('SNR');
        title(sprintf('%s - Kernel %d', title_prefix, k));
        legend('Location', 'best');
    end
end

function plot_factor_vs_energy(energy_axis, factor_matrix, fig_title_prefix)
    num_kernels = size(factor_matrix, 1);
    for k = 1:num_kernels
        figure('Name', sprintf('%s - Kernel %d', fig_title_prefix, k), ...
            'Position', [210 + 15*k, 180 + 15*k, 920, 460]);
        scatter(energy_axis, factor_matrix(k,:), 40, 'd', ...
            'MarkerFaceColor', [0.3 0.6 0.25], 'MarkerEdgeColor', [0.2 0.45 0.2]);
        hold on; yline(1, '--', 'LineWidth', 1.1, 'Color', [0.4 0.4 0.4]); hold off;
        grid on;
        xlabel('Energy Slice');
        ylabel('Factor (output/drawn)');
        title(sprintf('%s - Kernel %d', fig_title_prefix, k));
    end
end

function [drawn_scaled, output_scaled, scale_factors] = scale_snr_to_drawn_reference(drawn_raw, drawn_norm, output_norm)
    num_kernels = max([size(drawn_raw,1), size(drawn_norm,1), size(output_norm,1)]);
    num_slices = max([size(drawn_raw,2), size(drawn_norm,2), size(output_norm,2)]);
    drawn_scaled = nan(num_kernels, num_slices);
    output_scaled = nan(num_kernels, num_slices);
    scale_factors = ones(num_kernels, 1);

    for k = 1:num_kernels
        if k > size(drawn_norm,1), continue; end
        drawn_norm_k = drawn_norm(k,:);
        if k <= size(drawn_raw,1)
            drawn_raw_k = drawn_raw(k,:);
            valid = isfinite(drawn_raw_k) & isfinite(drawn_norm_k) & (abs(drawn_norm_k) > eps);
            if any(valid)
                alpha = sum(drawn_raw_k(valid).*drawn_norm_k(valid)) / sum(drawn_norm_k(valid).^2);
                if ~isfinite(alpha) || alpha <= 0, alpha = 1; end
            else
                alpha = 1;
            end
        else
            alpha = 1;
        end
        scale_factors(k) = alpha;
        drawn_scaled(k,1:numel(drawn_norm_k)) = alpha * drawn_norm_k;
        if k <= size(output_norm,1)
            output_norm_k = output_norm(k,:);
            output_scaled(k,1:numel(output_norm_k)) = alpha * output_norm_k;
        end
    end
end

function ratio = safe_ratio(num, den)
    [nr, nc] = size(num);
    [dr, dc] = size(den);
    r = min(nr, dr);
    c = min(nc, dc);
    ratio = nan(max(nr, dr), max(nc, dc));

    num_use = num(1:r, 1:c);
    den_use = den(1:r, 1:c);
    valid = isfinite(num_use) & isfinite(den_use) & (abs(den_use) > eps);
    tmp = nan(r, c);
    tmp(valid) = num_use(valid) ./ den_use(valid);
    ratio(1:r, 1:c) = tmp;
end

function drawn_kernel_stacks = extract_drawn_kernel_stacks(Y, roi_positions)
    [h, w, e] = size(Y);
    num_kernels = size(roi_positions, 1);
    drawn_kernel_stacks = cell(1, num_kernels);

    for k = 1:num_kernels
        pos = roi_positions(k,:);
        x = round(pos(1)); y = round(pos(2));
        width = max(2, round(pos(3))); height = max(2, round(pos(4)));
        x = min(max(1, x), w - 1);
        y = min(max(1, y), h - 1);
        width = min(width, w - x + 1);
        height = min(height, h - y + 1);
        drawn_kernel_stacks{k} = Y(y:y+height-1, x:x+width-1, 1:e);
    end
end

function output_kernels = get_output_kernels_input()
    var_name = input(['Enter workspace variable name for recovered kernels ' ...
        '(empty to load from MAT file): '], 's');
    if ~isempty(strtrim(var_name))
        if evalin('base', sprintf('exist(''%s'',''var'')', var_name))
            output_kernels = evalin('base', var_name);
            return;
        end
        error('Variable "%s" not found in workspace.', var_name);
    end

    [fname, fpath] = uigetfile('*.mat', 'Select MAT file containing recovered kernels');
    if isequal(fname, 0), error('No MAT file selected for recovered kernels.'); end
    S = load(fullfile(fpath, fname));
    vars = fieldnames(S);
    if isempty(vars), error('Selected MAT file contains no variables.'); end
    fprintf('Variables found in MAT file:\n');
    disp(vars);
    pick_name = input('Enter variable name to use as recovered kernels: ', 's');
    if ~isfield(S, pick_name)
        error('Variable "%s" not found in selected MAT file.', pick_name);
    end
    output_kernels = S.(pick_name);
end
