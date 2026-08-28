function [snr_matrix, details] = estimateMeasurementSNRFromWindows(Y, roi_positions, noise_roi_position)
%ESTIMATEMEASUREMENTSNRFROMWINDOWS Estimate per-kernel per-slice SNR from measurement Y.
%   [snr_matrix, details] = estimateMeasurementSNRFromWindows(Y, roi_positions)
%   [snr_matrix, details] = estimateMeasurementSNRFromWindows(Y, roi_positions, noise_roi_position)
%   computes an SNR for each designated kernel window and each energy slice.
%
%   Inputs:
%     Y             : measurement, size [H,W] or [H,W,E]
%     roi_positions : [N x 4] rectangle list [x, y, width, height]
%     noise_roi_position (optional): [1 x 4] rectangle [x, y, width, height]
%                                   to estimate noise from a user-defined
%                                   background region.
%
%   Outputs:
%     snr_matrix    : [N x E], one SNR per (kernel window, energy slice)
%     details       : struct with intermediate quantities:
%                     .roi_positions_clipped [N x 4]
%                     .noise_roi_clipped     [1 x 4] or []
%                     .noise_source          'noise_roi' or 'outside_kernel_rois'
%                     .p2v_matrix            [N x E]
%                     .noise_std_per_slice   [1 x E]
%                     .snr_list              [1 x (N*E)] row-major flatten
%
%   Convention:
%     This follows the amplitude-style convention used in properGen_hierarchical:
%       SNR = p2v / sigma_noise
%     where p2v is estimated from 0 deg and 45 deg center cuts using peak
%     prominence inside each designated window.

    validateattributes(Y, {'numeric'}, {'real', 'finite', 'nonempty'});
    validateattributes(roi_positions, {'numeric'}, ...
        {'real', 'finite', 'nonnan', '2d', 'ncols', 4, 'nonempty'});
    if nargin < 3
        noise_roi_position = [];
    end

    if ndims(Y) == 2
        Y = reshape(Y, size(Y,1), size(Y,2), 1);
    elseif ndims(Y) ~= 3
        error('Y must be 2D or 3D with size [H,W,E].');
    end

    Y = double(Y);
    [h, w, num_slices] = size(Y);
    num_windows = size(roi_positions, 1);

    [roi_positions_int, roi_mask_union] = build_window_mask(roi_positions, h, w);
    [noise_mask, noise_roi_clipped, noise_source] = build_noise_mask(noise_roi_position, roi_mask_union, h, w);

    p2v_matrix = nan(num_windows, num_slices);
    noise_std_per_slice = nan(1, num_slices);
    snr_matrix = nan(num_windows, num_slices);

    for s = 1:num_slices
        Ys = Y(:,:,s);

        noise_pixels = Ys(noise_mask);
        if numel(noise_pixels) < 20
            warning(['Noise region is too small on slice %d; ' ...
                'falling back to whole-slice noise estimate.'], s);
            noise_pixels = Ys(:);
        end

        sigma_noise = robust_std_from_mad(noise_pixels);
        if ~isfinite(sigma_noise) || sigma_noise <= 0
            sigma_noise = std(noise_pixels, 0, 'all');
        end
        sigma_noise = max(sigma_noise, eps);
        noise_std_per_slice(s) = sigma_noise;

        for k = 1:num_windows
            pos = roi_positions_int(k,:);
            x1 = pos(1);
            y1 = pos(2);
            x2 = x1 + pos(3) - 1;
            y2 = y1 + pos(4) - 1;

            patch = Ys(y1:y2, x1:x2);
            p2v_val = estimate_patch_p2v(patch);
            p2v_matrix(k, s) = p2v_val;
            snr_matrix(k, s) = p2v_val / sigma_noise;
        end
    end

    details = struct();
    details.roi_positions_clipped = roi_positions_int;
    details.noise_roi_clipped = noise_roi_clipped;
    details.noise_source = noise_source;
    details.p2v_matrix = p2v_matrix;
    details.noise_std_per_slice = noise_std_per_slice;
    details.snr_list = reshape(snr_matrix, 1, []);
end

function [roi_positions_int, union_mask] = build_window_mask(roi_positions, h, w)
    num_windows = size(roi_positions, 1);
    roi_positions_int = zeros(num_windows, 4);
    union_mask = false(h, w);

    for k = 1:num_windows
        x = round(roi_positions(k,1));
        y = round(roi_positions(k,2));
        width = max(2, round(roi_positions(k,3)));
        height = max(2, round(roi_positions(k,4)));

        x = min(max(1, x), w - 1);
        y = min(max(1, y), h - 1);
        width = min(width, w - x + 1);
        height = min(height, h - y + 1);

        roi_positions_int(k,:) = [x, y, width, height];
        union_mask(y:y+height-1, x:x+width-1) = true;
    end
end

function [noise_mask, noise_roi_clipped, noise_source] = build_noise_mask(noise_roi_position, roi_mask_union, h, w)
    if isempty(noise_roi_position)
        noise_mask = ~roi_mask_union;
        noise_roi_clipped = [];
        noise_source = 'outside_kernel_rois';
        return;
    end

    validateattributes(noise_roi_position, {'numeric'}, ...
        {'real', 'finite', 'nonnan', '2d', 'nrows', 1, 'ncols', 4});

    x = round(noise_roi_position(1));
    y = round(noise_roi_position(2));
    width = max(2, round(noise_roi_position(3)));
    height = max(2, round(noise_roi_position(4)));

    x = min(max(1, x), w - 1);
    y = min(max(1, y), h - 1);
    width = min(width, w - x + 1);
    height = min(height, h - y + 1);

    noise_roi_clipped = [x, y, width, height];
    noise_mask = false(h, w);
    noise_mask(y:y+height-1, x:x+width-1) = true;
    noise_source = 'noise_roi';
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

function sigma = robust_std_from_mad(x)
    x = x(:);
    medx = median(x, 'omitnan');
    abs_dev = abs(x - medx);
    mad_raw = median(abs_dev, 'omitnan');
    sigma = 1.4826 * mad_raw;
end
