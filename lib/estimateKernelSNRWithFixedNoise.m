function [snr_matrix, details] = estimateKernelSNRWithFixedNoise(output_kernels, noise_std_per_slice, normalization_mode)
%ESTIMATEKERNELSNRWITHFIXEDNOISE Estimate output-kernel SNR using fixed sigma_noise.
%   [snr_matrix, details] = estimateKernelSNRWithFixedNoise(output_kernels, noise_std_per_slice)
%   [snr_matrix, details] = estimateKernelSNRWithFixedNoise(output_kernels, noise_std_per_slice, normalization_mode)
%   computes kernel SNR using:
%       SNR = p2v / sigma_noise
%   where p2v is extracted from 0/45 degree center-cut peak prominence,
%   and sigma_noise comes from raw data (one value per energy slice).
%
%   Inputs:
%     output_kernels       : kernel data in one of formats:
%                            - cell array, each cell [H,W] or [H,W,E]
%                            - numeric [H,W,E] for one kernel
%                            - numeric [H,W,E,K] for K kernels
%     noise_std_per_slice  : [1 x E] or [E x 1] sigma_noise values
%     normalization_mode   : optional 'none' (default) or 'rms'
%                            'rms' subtracts patch mean and divides by RMS
%                            before p2v extraction (size-invariant scaling)
%
%   Outputs:
%     snr_matrix : [K x E]
%     details    : struct with .p2v_matrix, .noise_std_per_slice, .num_kernels

    if nargin < 3 || isempty(normalization_mode)
        normalization_mode = 'none';
    end
    normalization_mode = validatestring(normalization_mode, {'none', 'rms'});

    validateattributes(noise_std_per_slice, {'numeric'}, {'real', 'finite', 'nonempty'});
    noise_std_per_slice = double(noise_std_per_slice(:)).';
    noise_std_per_slice = max(noise_std_per_slice, eps);
    num_slices_target = numel(noise_std_per_slice);

    kernel_cells = normalize_kernel_input(output_kernels, num_slices_target);
    num_kernels = numel(kernel_cells);

    p2v_matrix = nan(num_kernels, num_slices_target);
    snr_matrix = nan(num_kernels, num_slices_target);
    normalized_kernel_cells = cell(1, num_kernels);

    for k = 1:num_kernels
        Kstack = kernel_cells{k};
        Kstack_norm = normalize_kernel_stack(Kstack, normalization_mode);
        normalized_kernel_cells{k} = Kstack_norm;
        for s = 1:num_slices_target
            patch = Kstack_norm(:,:,s);
            p2v_val = estimate_patch_p2v(patch);
            p2v_matrix(k, s) = p2v_val;
            snr_matrix(k, s) = p2v_val / noise_std_per_slice(s);
        end
    end

    details = struct();
    details.p2v_matrix = p2v_matrix;
    details.noise_std_per_slice = noise_std_per_slice;
    details.num_kernels = num_kernels;
    details.normalization_mode = normalization_mode;
    details.normalized_kernels = normalized_kernel_cells;
    details.snr_list = reshape(snr_matrix, 1, []);
end

function kernel_cells = normalize_kernel_input(output_kernels, num_slices_target)
    if iscell(output_kernels)
        kernel_cells = output_kernels(:).';
    elseif isnumeric(output_kernels)
        if ndims(output_kernels) == 2
            kernel_cells = {reshape(double(output_kernels), size(output_kernels,1), size(output_kernels,2), 1)};
        elseif ndims(output_kernels) == 3
            kernel_cells = {double(output_kernels)};
        elseif ndims(output_kernels) == 4
            nk = size(output_kernels, 4);
            kernel_cells = cell(1, nk);
            for k = 1:nk
                kernel_cells{k} = double(output_kernels(:,:,:,k));
            end
        else
            error('Unsupported numeric kernel input. Use 2D/3D/4D numeric or cell array.');
        end
    else
        error('output_kernels must be numeric array or cell array.');
    end

    for k = 1:numel(kernel_cells)
        Ki = kernel_cells{k};
        validateattributes(Ki, {'numeric'}, {'real', 'finite', 'nonempty'});
        if ndims(Ki) == 2
            Ki = reshape(double(Ki), size(Ki,1), size(Ki,2), 1);
        elseif ndims(Ki) == 3
            Ki = double(Ki);
        else
            error('Each kernel must be 2D or 3D.');
        end

        if size(Ki,3) == 1 && num_slices_target > 1
            Ki = repmat(Ki, 1, 1, num_slices_target);
        elseif size(Ki,3) ~= num_slices_target
            error(['Kernel %d slice count (%d) does not match noise slice count (%d). ' ...
                'Provide kernels with matching E or single-slice kernels.'], ...
                k, size(Ki,3), num_slices_target);
        end

        kernel_cells{k} = Ki;
    end
end

function p2v_val = estimate_patch_p2v(patch)
    cut0 = center_cut_profile(patch, 0);
    cut45 = center_cut_profile(patch, 45);

    p2v0 = first_peak_prominence(cut0);
    p2v45 = first_peak_prominence(cut45);

    p2v_val = max([p2v0, p2v45], [], 'omitnan');
    if ~isfinite(p2v_val) || p2v_val <= 0
        p2v_val = max(patch(:)) - min(patch(:));
    end
end

function stack_out = normalize_kernel_stack(stack_in, normalization_mode)
    stack_out = double(stack_in);
    num_slices = size(stack_out, 3);

    switch normalization_mode
        case 'none'
            return;
        case 'rms'
            for s = 1:num_slices
                patch = stack_out(:,:,s);
                patch = patch - mean(patch(:), 'omitnan');
                denom = sqrt(mean(patch(:).^2, 'omitnan'));
                if ~isfinite(denom) || denom <= eps
                    denom = 1;
                end
                stack_out(:,:,s) = patch / denom;
            end
    end
end

function prof = center_cut_profile(A, angle_deg)
    [h, w] = size(A);
    cx = (w + 1) / 2;
    cy = (h + 1) / 2;
    dx = cosd(angle_deg);
    dy = sind(angle_deg);

    lims = [];
    if abs(dx) > eps
        lims(end+1) = (w - cx) / abs(dx); %#ok<AGROW>
        lims(end+1) = (cx - 1) / abs(dx); %#ok<AGROW>
    end
    if abs(dy) > eps
        lims(end+1) = (h - cy) / abs(dy); %#ok<AGROW>
        lims(end+1) = (cy - 1) / abs(dy); %#ok<AGROW>
    end
    half_len = max(1, min(lims));

    x1 = cx - half_len * dx;
    y1 = cy - half_len * dy;
    x2 = cx + half_len * dx;
    y2 = cy + half_len * dy;

    ns = max(2, round(2 * half_len) + 1);
    prof = improfile(A, [x1 x2], [y1 y2], ns, 'bilinear');
    prof = double(prof(:)).';
    prof = prof(~isnan(prof));
end

function p2v = first_peak_prominence(sig)
    sig = sig(:).';
    if isempty(sig)
        p2v = NaN;
        return;
    end

    x = 1:numel(sig);
    [~, ~, ~, proms] = findpeaks(sig, x, ...
        'Annotate', 'extents', ...
        'WidthReference', 'halfheight');

    if isempty(proms)
        p2v = max(sig) - min(sig);
    else
        p2v = max(proms);
    end
end
