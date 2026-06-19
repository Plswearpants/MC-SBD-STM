function [sigma_in, sigma_out, details] = estimateKernelGaussianNoiseVsGT(A_in_noisy, A_out_noisy, A_gt, varargin)
%ESTIMATEKERNELGAUSSIANNOISEVSGT Estimate per-slice Gaussian amplitude vs GT.
%   [sigma_in, sigma_out, details] = estimateKernelGaussianNoiseVsGT( ...
%       A_in_noisy, A_out_noisy, A_gt)
%   estimates noise amplitude for input and output kernels against the same
%   noiseless ground-truth kernels. The fitting model per slice is:
%       A_noisy_aligned ~= a * A_gt + b + noise
%   where alignment uses bounded normalized cross-correlation shift search.
%
%   Supported input formats for each of A_in_noisy / A_out_noisy / A_gt:
%     - numeric [H,W]
%     - numeric [H,W,E]
%     - numeric [H,W,E,K]
%     - cell array, each cell [H,W] or [H,W,E]
%
%   Name-value options:
%     'kplus'         : [1x2] nonnegative integer shift half-window.
%                       default: ceil(0.5 * [H,W]) from first GT kernel.
%     'sigmaMethod'   : 'mad' (default) or 'std'
%     'energyIndices' : subset of energy slices to evaluate (default all).
%     'returnAligned' : logical, include aligned stacks in details (default false).
%
%   Outputs:
%     sigma_in        : [K x E_eval] estimated noise amplitude for input kernels.
%     sigma_out       : [K x E_eval] estimated noise amplitude for output kernels.
%     details         : struct with fields:
%                       .energy_indices
%                       .sigma_method
%                       .kplus
%                       .in / .out, each containing:
%                         .shift [K x E_eval x 2] (dy, dx)
%                         .gain  [K x E_eval]
%                         .bias  [K x E_eval]
%                         .mre   [K x E_eval] min relative error
%                         .rmse  [K x E_eval] residual RMS
%                         .r2    [K x E_eval]
%                         .gauss_r2 [K x E_eval] QQ-linearity R^2 of residual
%                         .gauss_rmse [K x E_eval] RMS mismatch in QQ fit
%                         .gauss_chi2 [K x E_eval] chi-square GOF statistic
%                         .gauss_pvalue [K x E_eval] p-value of chi-square GOF
%                         .gauss_dof [K x E_eval] DOF used in chi-square GOF
%                         .gauss_reject [K x E_eval] reject normality at alpha=0.05
%                         .sigma [K x E_eval]
%                         .aligned_stacks (optional cell)

    opts = parse_options(varargin{:});

    in_cells = to_kernel_cells(A_in_noisy);
    out_cells = to_kernel_cells(A_out_noisy);
    gt_cells = to_kernel_cells(A_gt);

    num_kernels = max([numel(in_cells), numel(out_cells), numel(gt_cells)]);
    in_cells = expand_kernel_count(in_cells, num_kernels, 'A_in_noisy');
    out_cells = expand_kernel_count(out_cells, num_kernels, 'A_out_noisy');
    gt_cells = expand_kernel_count(gt_cells, num_kernels, 'A_gt');

    [e_eval, energy_indices] = resolve_energy_axis(in_cells, out_cells, gt_cells, opts.energyIndices);

    first_gt = gt_cells{1};
    default_kplus = ceil(0.5 * [size(first_gt,1), size(first_gt,2)]);
    if isempty(opts.kplus)
        opts.kplus = default_kplus;
    end

    want_details = nargout >= 3;
    [sigma_in, in_details] = evaluate_side(in_cells, gt_cells, opts, energy_indices, e_eval, want_details);
    [sigma_out, out_details] = evaluate_side(out_cells, gt_cells, opts, energy_indices, e_eval, want_details);

    if want_details
        details = struct();
        details.energy_indices = energy_indices;
        details.sigma_method = opts.sigmaMethod;
        details.kplus = opts.kplus;
        details.in = in_details;
        details.out = out_details;
    else
        details = [];
    end
end

function opts = parse_options(varargin)
    p = inputParser;
    p.FunctionName = 'estimateKernelGaussianNoiseVsGT';
    addParameter(p, 'kplus', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2 && all(isfinite(x)) && all(x >= 0)));
    addParameter(p, 'sigmaMethod', 'mad', @(x) any(strcmpi(x, {'mad','std'})));
    addParameter(p, 'energyIndices', [], @(x) isempty(x) || (isnumeric(x) && isvector(x) && all(isfinite(x))));
    addParameter(p, 'returnAligned', false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    opts = p.Results;
    opts.sigmaMethod = lower(opts.sigmaMethod);
    if ~isempty(opts.kplus)
        opts.kplus = round(double(opts.kplus(:).'));
    end
end

function cells = to_kernel_cells(data_in)
    if iscell(data_in)
        cells = data_in(:).';
        for k = 1:numel(cells)
            cells{k} = to_stack_3d(cells{k});
        end
        return;
    end

    if ~isnumeric(data_in)
        error('Kernel input must be numeric or cell.');
    end

    if ndims(data_in) == 2
        cells = {to_stack_3d(data_in)};
        return;
    end

    if ndims(data_in) == 3
        cells = {to_stack_3d(data_in)};
        return;
    end

    if ndims(data_in) == 4
        nk = size(data_in, 4);
        cells = cell(1, nk);
        for k = 1:nk
            cells{k} = to_stack_3d(data_in(:,:,:,k));
        end
        return;
    end

    error('Unsupported numeric input dimensions. Use 2D/3D/4D numeric or cell.');
end

function stack = to_stack_3d(x)
    validateattributes(x, {'numeric'}, {'real', 'finite', 'nonempty'});
    if ndims(x) == 2
        stack = reshape(double(x), size(x,1), size(x,2), 1);
    elseif ndims(x) == 3
        stack = double(x);
    else
        error('Each kernel must be 2D or 3D.');
    end
end

function cells_out = expand_kernel_count(cells_in, target_k, name_in)
    if numel(cells_in) == target_k
        cells_out = cells_in;
        return;
    end
    if numel(cells_in) == 1 && target_k > 1
        cells_out = repmat(cells_in, 1, target_k);
        return;
    end
    error('%s kernel count (%d) incompatible with target count (%d).', name_in, numel(cells_in), target_k);
end

function [e_eval, energy_indices] = resolve_energy_axis(in_cells, out_cells, gt_cells, requested_indices)
    e_candidates = [];
    for k = 1:numel(gt_cells)
        e_candidates(end+1) = size(gt_cells{k}, 3); %#ok<AGROW>
        e_candidates(end+1) = size(in_cells{k}, 3); %#ok<AGROW>
        e_candidates(end+1) = size(out_cells{k}, 3); %#ok<AGROW>
    end
    e_eval = max(e_candidates);
    if isempty(requested_indices)
        energy_indices = 1:e_eval;
    else
        energy_indices = unique(round(double(requested_indices(:).')));
        if any(energy_indices < 1) || any(energy_indices > e_eval)
            error('energyIndices must be within [1, %d].', e_eval);
        end
    end
end

function [sigma_matrix, details_side] = evaluate_side(noisy_cells, gt_cells, opts, energy_indices, e_eval, want_details)
    num_kernels = numel(noisy_cells);
    num_eval = numel(energy_indices);

    sigma_matrix = nan(num_kernels, num_eval);
    if want_details
        shift = nan(num_kernels, num_eval, 2);
        gain = nan(num_kernels, num_eval);
        bias = nan(num_kernels, num_eval);
        mre = nan(num_kernels, num_eval);
        rmse = nan(num_kernels, num_eval);
        r2 = nan(num_kernels, num_eval);
        gauss_r2 = nan(num_kernels, num_eval);
        gauss_rmse = nan(num_kernels, num_eval);
        gauss_chi2 = nan(num_kernels, num_eval);
        gauss_pvalue = nan(num_kernels, num_eval);
        gauss_dof = nan(num_kernels, num_eval);
        gauss_reject = nan(num_kernels, num_eval);
    end

    if want_details && opts.returnAligned
        aligned_stacks = cell(1, num_kernels);
    else
        aligned_stacks = {};
    end

    for k = 1:num_kernels
        gt_stack = expand_stack_depth(gt_cells{k}, e_eval, sprintf('A_gt kernel %d', k));
        noisy_stack = expand_stack_depth(noisy_cells{k}, e_eval, sprintf('noisy kernel %d', k));
        validate_size_match(gt_stack, noisy_stack, k);

        if want_details && opts.returnAligned
            aligned_stacks{k} = nan(size(gt_stack));
        end

        for ii = 1:num_eval
            s = energy_indices(ii);
            gt_slice = gt_stack(:,:,s);
            noisy_slice = noisy_stack(:,:,s);

            [aligned_slice, dy, dx, min_err] = best_shift_xcorr_style(gt_slice, noisy_slice, opts.kplus);

            [a_fit, b_fit, residual, rmse_val, r2_val] = fit_gain_bias_residual(aligned_slice, gt_slice);
            sigma_val = estimate_sigma(residual, opts.sigmaMethod);
            [gauss_r2_val, gauss_rmse_val, gauss_chi2_val, gauss_p_val, gauss_dof_val, gauss_h_val] = ...
                evaluate_gaussian_fit_stats(residual);

            sigma_matrix(k, ii) = sigma_val;
            if want_details
                shift(k, ii, :) = [dy, dx];
                gain(k, ii) = a_fit;
                bias(k, ii) = b_fit;
                mre(k, ii) = min_err;
                rmse(k, ii) = rmse_val;
                r2(k, ii) = r2_val;
                gauss_r2(k, ii) = gauss_r2_val;
                gauss_rmse(k, ii) = gauss_rmse_val;
                gauss_chi2(k, ii) = gauss_chi2_val;
                gauss_pvalue(k, ii) = gauss_p_val;
                gauss_dof(k, ii) = gauss_dof_val;
                gauss_reject(k, ii) = gauss_h_val;
            end

            if want_details && opts.returnAligned
                aligned_stacks{k}(:,:,s) = aligned_slice;
            end
        end
    end

    if want_details
        details_side = struct();
        details_side.shift = shift;
        details_side.gain = gain;
        details_side.bias = bias;
        details_side.mre = mre;
        details_side.rmse = rmse;
        details_side.r2 = r2;
        details_side.gauss_r2 = gauss_r2;
        details_side.gauss_rmse = gauss_rmse;
        details_side.gauss_chi2 = gauss_chi2;
        details_side.gauss_pvalue = gauss_pvalue;
        details_side.gauss_dof = gauss_dof;
        details_side.gauss_reject = gauss_reject;
        details_side.sigma = sigma_matrix;
        if opts.returnAligned
            details_side.aligned_stacks = aligned_stacks;
        end
    else
        details_side = [];
    end
end

function stack_out = expand_stack_depth(stack_in, target_e, stack_name)
    if size(stack_in, 3) == target_e
        stack_out = stack_in;
        return;
    end
    if size(stack_in, 3) == 1 && target_e > 1
        stack_out = repmat(stack_in, 1, 1, target_e);
        return;
    end
    error('%s has %d slices; expected 1 or %d.', stack_name, size(stack_in, 3), target_e);
end

function validate_size_match(gt_stack, noisy_stack, kernel_idx)
    if size(gt_stack,1) ~= size(noisy_stack,1) || size(gt_stack,2) ~= size(noisy_stack,2)
        error(['Spatial size mismatch for kernel %d: GT is [%d,%d], noisy is [%d,%d]. ' ...
            'Provide pre-cropped kernels with matching size.'], ...
            kernel_idx, size(gt_stack,1), size(gt_stack,2), size(noisy_stack,1), size(noisy_stack,2));
    end
end

function [best_slice, best_dy, best_dx, min_err] = best_shift_xcorr_style(gt_slice, noisy_slice, kplus)
    gt_slice = double(gt_slice);
    noisy_slice = double(noisy_slice);
    gt_norm = norm(gt_slice(:));
    if ~isfinite(gt_norm) || gt_norm <= eps
        error('GT slice has near-zero norm; cannot perform shift search.');
    end
    if all(kplus == 0)
        best_dy = 0;
        best_dx = 0;
        best_slice = noisy_slice;
    else
        c = normxcorr2(gt_slice, noisy_slice);
        center_y = size(gt_slice, 1);
        center_x = size(gt_slice, 2);

        y_range = max(1, center_y - kplus(1)) : min(size(c,1), center_y + kplus(1));
        x_range = max(1, center_x - kplus(2)) : min(size(c,2), center_x + kplus(2));
        c_roi = c(y_range, x_range);
        if isempty(c_roi) || all(~isfinite(c_roi(:)))
            best_dy = 0;
            best_dx = 0;
        else
            c_roi(~isfinite(c_roi)) = -inf;
            [~, local_idx] = max(c_roi(:));
            [iy, ix] = ind2sub(size(c_roi), local_idx);
            y_peak = y_range(iy);
            x_peak = x_range(ix);
            best_dy = y_peak - center_y;
            best_dx = x_peak - center_x;
        end
        best_slice = circshift(noisy_slice, [-best_dy, -best_dx]);
    end

    gt_unit = gt_slice / gt_norm;
    best_norm = norm(best_slice(:));
    if ~isfinite(best_norm) || best_norm <= eps
        min_err = inf;
    else
        min_err = norm(gt_unit - best_slice / best_norm, 'fro');
    end
end

function [a_fit, b_fit, residual, rmse_val, r2_val] = fit_gain_bias_residual(noisy_aligned, gt_slice)
    y = noisy_aligned(:);
    g = gt_slice(:);
    X = [g, ones(size(g))];
    theta = X \ y;
    a_fit = theta(1);
    b_fit = theta(2);

    y_hat = X * theta;
    residual_vec = y - y_hat;
    residual = reshape(residual_vec, size(noisy_aligned));
    rmse_val = sqrt(mean(residual_vec.^2, 'omitnan'));

    denom = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
    if ~isfinite(denom) || denom <= eps
        r2_val = NaN;
    else
        r2_val = 1 - sum(residual_vec.^2, 'omitnan') / denom;
    end
end

function sigma = estimate_sigma(residual, sigma_method)
    r = residual(:);
    switch sigma_method
        case 'mad'
            sigma = robust_std_from_mad(r);
            if ~isfinite(sigma) || sigma <= 0
                sigma = std(r, 0, 'omitnan');
            end
        case 'std'
            sigma = std(r, 0, 'omitnan');
        otherwise
            error('Unsupported sigmaMethod: %s', sigma_method);
    end
    sigma = max(sigma, eps);
end

function sigma = robust_std_from_mad(x)
    x = x(:);
    medx = median(x, 'omitnan');
    mad_raw = median(abs(x - medx), 'omitnan');
    sigma = 1.4826 * mad_raw;
end

function [r2_qq, rmse_qq, chi2_stat, p_val, dof, h_reject] = evaluate_gaussian_fit_stats(residual)
    r = residual(:);
    r = r(isfinite(r));
    if numel(r) < 8
        r2_qq = NaN;
        rmse_qq = NaN;
        chi2_stat = NaN;
        p_val = NaN;
        dof = NaN;
        h_reject = NaN;
        return;
    end

    y = sort(r);
    n = numel(y);
    p = ((1:n).' - 0.5) / n;
    x = sqrt(2) .* erfinv(2 .* p - 1); % normal quantiles without toolbox dependency

    X = [x, ones(n, 1)];
    theta = X \ y;
    yhat = X * theta;
    res = y - yhat;

    rmse_qq = sqrt(mean(res.^2, 'omitnan'));
    denom = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
    if ~isfinite(denom) || denom <= eps
        r2_qq = NaN;
    else
        r2_qq = 1 - sum(res.^2, 'omitnan') / denom;
    end

    % Pearson chi-square GOF against fitted normal N(mu, sigma).
    [chi2_stat, p_val, dof] = gaussian_chi_square_gof(r);
    if isfinite(p_val)
        h_reject = double(p_val < 0.05);
    else
        h_reject = NaN;
    end
end

function [chi2_stat, p_val, dof] = gaussian_chi_square_gof(r)
    n = numel(r);
    if n < 8
        chi2_stat = NaN;
        p_val = NaN;
        dof = NaN;
        return;
    end

    mu_hat = mean(r, 'omitnan');
    sigma_hat = std(r, 0, 'omitnan');
    if ~isfinite(sigma_hat) || sigma_hat <= eps
        chi2_stat = NaN;
        p_val = NaN;
        dof = NaN;
        return;
    end

    z = (r - mu_hat) / sigma_hat;

    nbins = max(8, min(20, round(sqrt(n))));
    pgrid = (1:(nbins-1)) / nbins;
    inner_edges = sqrt(2) .* erfinv(2 .* pgrid - 1);
    edges = [-inf, inner_edges, inf];
    obs = histcounts(z, edges);
    expected = (n / nbins) * ones(1, nbins);

    valid = expected > 0;
    chi2_stat = sum(((obs(valid) - expected(valid)).^2) ./ expected(valid), 'omitnan');
    dof = sum(valid) - 1 - 2; % minus 2 fitted params: mu, sigma
    if dof <= 0 || ~isfinite(chi2_stat)
        p_val = NaN;
        return;
    end
    p_val = gammainc(chi2_stat / 2, dof / 2, 'upper');
end
