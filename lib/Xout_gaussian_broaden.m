function Xout_gaussian = Xout_gaussian_broaden(X_out, kernel_sizes)
%XOUT_GAUSSIAN_BROADEN Apply Gaussian broadening to each channel of X_out based on kernel size.
%   Xout_gaussian = Xout_gaussian_broaden(X_out, kernel_sizes)
%   - X_out: [H x W x num_kernels] activation map
%   - kernel_sizes: [num_kernels x 2] array, each row is [height, width] for the kernel
%   - Xout_gaussian: [H x W x num_kernels] activation map after Gaussian broadening
%
%   Promoted from a local function in historical/real/hist_MCSBD_block_realdata1.m so
%   that trunk scripts (scripts/real/run_real_block.m) can call it directly.

    [h, w, num_kernels] = size(X_out);
    Xout_gaussian = zeros(h, w, num_kernels);
    for k = 1:num_kernels
        sigma = min(kernel_sizes(k,:)) / 10;
        window_size = ceil(3 * sigma);
        [x, y] = meshgrid(-window_size:window_size);
        gaussian_kernel = exp(-(x.^2 + y.^2)/(2*sigma^2));
        gaussian_kernel = gaussian_kernel / sum(gaussian_kernel(:));
        % Apply Gaussian broadening
        Xout_gaussian(:,:,k) = conv2(X_out(:,:,k), gaussian_kernel, 'same');
    end
end
