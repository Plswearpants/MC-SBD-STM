function metrics = build_denoising_sigma_metrics(metrics, activation_threshold, varargin)
%BUILD_DENOISING_SIGMA_METRICS Build denoising metric sigma_in/sigma_out.
%
% For each dataset slot, compute kernel denoising metric from:
%   A_in  -> metrics.A0
%   A_out -> metrics.Aout
%   A_gt  -> metrics.A0_noiseless
% using estimateKernelGaussianNoiseVsGT:
%   denoising = sigma_in / sigma_out
%
% Gating:
%   Only compute for slots with activation_similarity_final >= activation_threshold.
%   Slots below threshold are set to NaN.
%
% Added fields:
%   metrics.denoising_sigma_ratio_final        [same size as activation_similarity_final]
%   metrics.denoising_sigma_ratio_per_kernel   cell, per slot [K x 1] (median over energy)
%   metrics.denoising_sigma_ratio_matrix       cell, per slot [K x E]
%   metrics.denoising_sigma_in_final           [same size as activation_similarity_final]
%   metrics.denoising_sigma_in_per_kernel      cell, per slot [K x 1] (median over energy)
%   metrics.denoising_sigma_in_matrix          cell, per slot [K x E]
%   metrics.denoising_sigma_out_final          [same size as activation_similarity_final]
%   metrics.denoising_sigma_out_per_kernel     cell, per slot [K x 1] (median over energy)
%   metrics.denoising_sigma_out_matrix         cell, per slot [K x E]
%   metrics.denoising_residual_in_maps         cell, per slot {1xK}, each [H x W]
%   metrics.denoising_residual_out_maps        cell, per slot {1xK}, each [H x W]
%       (mean residual kernel across evaluated energies after shift+gain+bias fit)
%   metrics.denoising_activation_threshold     scalar
%
% Optional name-value:
%   'enableAlignment' : logical, run shift search if true (default false)
%   'kplus'           : [dy dx] shift window for alignment search (used when
%                       enableAlignment=true)
%   'storeResidualKernels' : logical, store residual kernel maps in metrics
%                            (default false; can be memory-heavy)

    if nargin < 2 || isempty(activation_threshold)
        activation_threshold = 0.95;
    end
    p = inputParser;
    addParameter(p, 'enableAlignment', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'kplus', [0, 0], @(x) isnumeric(x) && numel(x)==2 && all(isfinite(x)) && all(x>=0));
    addParameter(p, 'sigmaMethod', 'mad', @(x) any(strcmpi(x, {'mad','std'})));
    addParameter(p, 'energyStride', 1, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1);
    addParameter(p, 'storeResidualKernels', false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    opts = p.Results;
    opts.enableAlignment = logical(opts.enableAlignment);
    opts.kplus = round(opts.kplus(:).');
    opts.energyStride = round(opts.energyStride);
    if ~opts.enableAlignment
        opts.kplus = [0, 0];
    end
    validateattributes(activation_threshold, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1});

    required_fields = {'A0', 'Aout', 'A0_noiseless', 'activation_similarity_final'};
    for i = 1:numel(required_fields)
        if ~isfield(metrics, required_fields{i})
            error('metrics must contain field "%s".', required_fields{i});
        end
    end

    if ~exist('estimateKernelGaussianNoiseVsGT', 'file')
        this_dir = fileparts(mfilename('fullpath'));
        addpath(fullfile(this_dir, '..'));
    end

    data_dims = size(metrics.Aout);
    num_dims = numel(data_dims);
    if num_dims < 3 || num_dims > 4
        error('metrics.Aout must be indexed as [SNR, density, axis3, rep] (3D/4D).');
    end

    ratio_final = nan(data_dims);
    ratio_per_kernel = cell(data_dims);
    ratio_matrix = cell(data_dims);
    sigma_in_final = nan(data_dims);
    sigma_in_per_kernel = cell(data_dims);
    sigma_in_matrix = cell(data_dims);
    sigma_out_final = nan(data_dims);
    sigma_out_per_kernel = cell(data_dims);
    sigma_out_matrix = cell(data_dims);
    residual_in_maps = cell(data_dims);
    residual_out_maps = cell(data_dims);

    total_slots = numel(metrics.Aout);
    wb = waitbar(0, 'Building denoising sigma metrics...');
    cleanup_obj = onCleanup(@() close_waitbar_safe(wb));

    for linear_idx = 1:total_slots
        if num_dims == 4
            [idx_snr, idx_density, idx_axis3, idx_rep] = ind2sub(data_dims, linear_idx);
            act_sim = metrics.activation_similarity_final(idx_snr, idx_density, idx_axis3, idx_rep);
            A_in = metrics.A0{idx_snr, idx_density, idx_axis3, idx_rep};
            A_out = metrics.Aout{idx_snr, idx_density, idx_axis3, idx_rep};
            A_gt = metrics.A0_noiseless{idx_snr, idx_density, idx_axis3, idx_rep};
        else
            [idx_snr, idx_density, idx_axis3] = ind2sub(data_dims, linear_idx);
            act_sim = metrics.activation_similarity_final(idx_snr, idx_density, idx_axis3);
            A_in = metrics.A0{idx_snr, idx_density, idx_axis3};
            A_out = metrics.Aout{idx_snr, idx_density, idx_axis3};
            A_gt = metrics.A0_noiseless{idx_snr, idx_density, idx_axis3};
        end

        if ~isfinite(act_sim) || act_sim < activation_threshold
            update_waitbar(wb, linear_idx, total_slots);
            continue;
        end
        if isempty(A_in) || isempty(A_out) || isempty(A_gt)
            update_waitbar(wb, linear_idx, total_slots);
            continue;
        end

        try
            energy_indices = infer_energy_indices(A_gt, opts.energyStride);
            [sigma_in, sigma_out, sigma_details] = estimateKernelGaussianNoiseVsGT( ...
                A_in, A_out, A_gt, ...
                'sigmaMethod', opts.sigmaMethod, ...
                'kplus', opts.kplus, ...
                'energyIndices', energy_indices);
            ratio_ke = safe_ratio(sigma_in, sigma_out);      % [K x E]
            ratio_k = median(ratio_ke, 2, 'omitnan');        % [K x 1]
            ratio_slot = mean(ratio_k, 'omitnan');           % scalar
            sigma_in_k = median(sigma_in, 2, 'omitnan');     % [K x 1]
            sigma_out_k = median(sigma_out, 2, 'omitnan');   % [K x 1]
            sigma_in_slot = median(sigma_in(:), 'omitnan');  % scalar
            sigma_out_slot = median(sigma_out(:), 'omitnan');% scalar

            ratio_matrix{linear_idx} = ratio_ke;
            ratio_per_kernel{linear_idx} = ratio_k;
            ratio_final(linear_idx) = ratio_slot;
            sigma_in_matrix{linear_idx} = sigma_in;
            sigma_in_per_kernel{linear_idx} = sigma_in_k;
            sigma_in_final(linear_idx) = sigma_in_slot;
            sigma_out_matrix{linear_idx} = sigma_out;
            sigma_out_per_kernel{linear_idx} = sigma_out_k;
            sigma_out_final(linear_idx) = sigma_out_slot;
            if opts.storeResidualKernels && isstruct(sigma_details)
                [in_maps, out_maps] = build_slot_residual_maps(A_in, A_out, A_gt, sigma_details);
                residual_in_maps{linear_idx} = in_maps;
                residual_out_maps{linear_idx} = out_maps;
            end
        catch ME
            warning('build_denoising_sigma_metrics:SlotFailed', ...
                'Failed at slot %d: %s', linear_idx, ME.message);
        end

        update_waitbar(wb, linear_idx, total_slots);
    end

    metrics.denoising_sigma_ratio_final = ratio_final;
    metrics.denoising_sigma_ratio_per_kernel = ratio_per_kernel;
    metrics.denoising_sigma_ratio_matrix = ratio_matrix;
    metrics.denoising_sigma_in_final = sigma_in_final;
    metrics.denoising_sigma_in_per_kernel = sigma_in_per_kernel;
    metrics.denoising_sigma_in_matrix = sigma_in_matrix;
    metrics.denoising_sigma_out_final = sigma_out_final;
    metrics.denoising_sigma_out_per_kernel = sigma_out_per_kernel;
    metrics.denoising_sigma_out_matrix = sigma_out_matrix;
    metrics.denoising_residual_in_maps = residual_in_maps;
    metrics.denoising_residual_out_maps = residual_out_maps;
    metrics.denoising_activation_threshold = activation_threshold;
    metrics.denoising_sigma_options = opts;
    metrics.denoising_sigma_ratio_axis_mode = get_loader_axis_mode(metrics);

    if should_build_side_ratio_aggregate(metrics, num_dims)
        metrics.denoising_sigma_ratio_by_side_length_ratio = ...
            aggregate_to_side_ratio(metrics, ratio_final, data_dims, num_dims);
    end

    delete(cleanup_obj);
    close_waitbar_safe(wb);
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

function update_waitbar(wb, idx, total_slots)
    if ~ishandle(wb)
        return;
    end
    if idx == 1 || idx == total_slots || mod(idx, max(1, floor(total_slots / 100))) == 0
        waitbar(idx / total_slots, wb, sprintf('Building denoising sigma metrics... %d/%d', idx, total_slots));
    end
end

function close_waitbar_safe(wb)
    if ~isempty(wb) && ishandle(wb)
        close(wb);
    end
end

function tf = should_build_side_ratio_aggregate(metrics, num_dims)
    tf = (get_loader_axis_mode(metrics) ~= 2) && ...
         isfield(metrics, 'side_length_ratio_values') && ~isempty(metrics.side_length_ratio_values) && ...
         isfield(metrics, 'SNR_values') && isfield(metrics, 'theta_cap_values') && ...
         isfield(metrics, 'side_length_ratio_at_axis3') && ...
         ((num_dims == 3) || (num_dims == 4));
end

function ratio_side = aggregate_to_side_ratio(metrics, ratio_final, data_dims, num_dims)
    side_vals = metrics.side_length_ratio_values(:);
    num_snr = numel(metrics.SNR_values);
    num_den = numel(metrics.theta_cap_values);
    num_side = numel(side_vals);
    if num_dims == 4
        num_rep = data_dims(4);
    else
        num_rep = 1;
    end

    sum_tensor = zeros(num_snr, num_den, num_side, num_rep);
    cnt_tensor = zeros(num_snr, num_den, num_side, num_rep);

    total_slots = numel(ratio_final);
    for linear_idx = 1:total_slots
        if num_dims == 4
            [idx_snr, idx_den, idx_nobs, idx_rep] = ind2sub(data_dims, linear_idx);
            ratio_here = metrics.side_length_ratio_at_axis3(idx_snr, idx_den, idx_nobs, idx_rep);
        else
            [idx_snr, idx_den, idx_nobs] = ind2sub(data_dims, linear_idx);
            idx_rep = 1;
            ratio_here = metrics.side_length_ratio_at_axis3(idx_snr, idx_den, idx_nobs);
        end
        if ~isfinite(ratio_here) || ~isfinite(ratio_final(linear_idx))
            continue;
        end
        [~, side_idx] = min(abs(side_vals - ratio_here));
        sum_tensor(idx_snr, idx_den, side_idx, idx_rep) = ...
            sum_tensor(idx_snr, idx_den, side_idx, idx_rep) + ratio_final(linear_idx);
        cnt_tensor(idx_snr, idx_den, side_idx, idx_rep) = ...
            cnt_tensor(idx_snr, idx_den, side_idx, idx_rep) + 1;
    end

    ratio_side = nan(size(sum_tensor));
    valid = cnt_tensor > 0;
    ratio_side(valid) = sum_tensor(valid) ./ cnt_tensor(valid);
end

function mode = get_loader_axis_mode(metrics)
    if isfield(metrics, 'axis3_mode') && isscalar(metrics.axis3_mode)
        mode = metrics.axis3_mode;
    else
        mode = 1;
    end
end

function energy_indices = infer_energy_indices(A_gt, energy_stride)
    num_slices = infer_energy_depth(A_gt);
    energy_indices = 1:energy_stride:num_slices;
    if isempty(energy_indices)
        energy_indices = 1;
    end
end

function depth = infer_energy_depth(A)
    depth = 1;
    if isempty(A)
        return;
    end
    if iscell(A)
        for i = 1:numel(A)
            Ai = A{i};
            if isnumeric(Ai) && ndims(Ai) >= 3
                depth = max(depth, size(Ai, 3));
            end
        end
        return;
    end
    if isnumeric(A) && ndims(A) >= 3
        depth = size(A, 3);
    end
end

function [in_maps, out_maps] = build_slot_residual_maps(A_in, A_out, A_gt, sigma_details)
    in_maps = {};
    out_maps = {};
    if ~isstruct(sigma_details) || ~isfield(sigma_details, 'energy_indices')
        return;
    end
    energy_indices = sigma_details.energy_indices(:)';
    in_cells = to_kernel_cells_local(A_in);
    out_cells = to_kernel_cells_local(A_out);
    gt_cells = to_kernel_cells_local(A_gt);
    nk = min([numel(in_cells), numel(out_cells), numel(gt_cells)]);
    if nk < 1
        return;
    end
    if ~isfield(sigma_details, 'in') || ~isfield(sigma_details, 'out')
        return;
    end
    in_maps = compute_mean_residual_maps_from_details(in_cells, gt_cells, sigma_details.in, energy_indices, nk);
    out_maps = compute_mean_residual_maps_from_details(out_cells, gt_cells, sigma_details.out, energy_indices, nk);
end

function residual_maps = compute_mean_residual_maps_from_details(noisy_cells, gt_cells, side_details, energy_indices, nk)
    residual_maps = cell(1, nk);
    if ~isstruct(side_details) || ~isfield(side_details, 'gain') || ...
            ~isfield(side_details, 'bias') || ~isfield(side_details, 'shift')
        return;
    end
    for k = 1:nk
        gt_stack = expand_stack_depth_local(gt_cells{k}, max(energy_indices));
        noisy_stack = expand_stack_depth_local(noisy_cells{k}, max(energy_indices));
        if size(gt_stack,1) ~= size(noisy_stack,1) || size(gt_stack,2) ~= size(noisy_stack,2)
            continue;
        end

        gain_k = side_details.gain(k, :);
        bias_k = side_details.bias(k, :);
        shift_k = reshape(side_details.shift(k, :, :), [], 2);

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
            aligned = circshift(noisy_stack(:,:,eidx), [-round(dy), -round(dx)]);
            fit_slice = a_fit .* gt_stack(:,:,eidx) + b_fit;
            acc = acc + (aligned - fit_slice);
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
    error('Unsupported kernel dimensions for residual map storage.');
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
        return;
    end
    if size(stack_in, 3) == 1 && target_e > 1
        stack_out = repmat(stack_in, 1, 1, target_e);
        return;
    end
    error('Kernel stack has %d slices; expected 1 or %d.', size(stack_in, 3), target_e);
end
