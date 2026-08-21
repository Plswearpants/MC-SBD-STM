function [QPI_symm, QPI_symm_45, tform, rotation_angle] = Symmetrizing2( ...
    QPI_cropped, tform_in, angle_in, symm_method, skip_symmetrization)

%SYMmetrizing2
% Takes cropped QPI, locates Bragg peaks, applies geometric correction,
% pads to square, and optionally symmetrizes in a four-fold manner.
%
% Outputs:
%   QPI_symm       - symmetrized data, or transformed+padded data if skipped
%   QPI_symm_45    - 45-degree rotated version of QPI_symm
%   tform          - projective transform matrix
%   rotation_angle - extracted or provided rotation angle
%
% Inputs:
%   QPI_cropped         - cropped QPI data, size [Nx, Ny, Nz]
%   tform_in            - optional transformation matrix
%   angle_in            - optional rotation angle; if given, skips angle extraction
%   symm_method         - optional symmetrization method:
%                         'default' or 'xy_mirror'
%   skip_symmetrization - optional logical flag; true skips symmetrization
%
% Notes:
%   - If angle_in is provided, rotation is done by imrotate.
%   - If angle_in is empty, the projective transform is used.
%   - If skip_symmetrization is true, QPI_symm is just the transformed
%     and padded data.

    if nargin < 2
        tform_in = [];
    end
    if nargin < 3
        angle_in = [];
    end
    if nargin < 4 || isempty(symm_method)
        symm_method = 'default';
    end
    if nargin < 5 || isempty(skip_symmetrization)
        skip_symmetrization = false;
    end

    [x_num_cropped, y_num_cropped, z_num_cropped] = size(QPI_cropped);
    ref_idx = min(100, z_num_cropped);

    %% Find Bragg peaks or use provided transform
    if isempty(tform_in)
        fprintf('Finding Bragg peaks using slice %d...\n', ref_idx);

        % Quadrant ranges
        x45 = round(0.45 * x_num_cropped);
        x55 = round(0.55 * x_num_cropped);
        y45 = round(0.45 * y_num_cropped);
        y55 = round(0.55 * y_num_cropped);
        x50 = round(x_num_cropped / 2);
        y50 = round(y_num_cropped / 2);

        ref_im = QPI_cropped(:,:,ref_idx);

        % Bragg peak for (-1, 1)
        block1 = ref_im(1:x45, 1:y45);
        val1 = max(block1(:));
        [row1, col1] = find(block1 == val1, 1, 'first');

        % Bragg peak for (1, 1)
        block2 = ref_im(1:x45, y55:y_num_cropped);
        val2 = max(block2(:));
        [row2, col2] = find(block2 == val2, 1, 'first');
        col2 = col2 + y55 - 1;

        % Bragg peak for (-1, -1)
        block3 = ref_im(x55:x_num_cropped, 1:y45);
        val3 = max(block3(:));
        [row3, col3] = find(block3 == val3, 1, 'first');
        row3 = row3 + x55 - 1;

        % Bragg peak for (1, -1)
        block4 = ref_im(x50:x_num_cropped, y50:y_num_cropped);
        val4 = max(block4(:));
        [row4, col4] = find(block4 == val4, 1, 'first');
        row4 = row4 + x50 - 1;
        col4 = col4 + y50 - 1;

        fprintf('Constructing projective transform from Bragg peak positions...\n');
        tform = fitgeotrans( ...
            [col1 row1; col2 row2; col4 row4; col3 row3], ...
            [0 0; 0 301; 301 301; 301 0], ...
            'projective');
    else
        fprintf('Using the provided transformation matrix.\n');
        tform = tform_in;
    end

    %% Determine transform mode
    if ~isempty(angle_in)
        rotation_angle = angle_in;
        use_rotation = true;
        fprintf('Using the provided rotation angle: %.4f degrees.\n', rotation_angle);
    else
        T = tform.T;
        rotation_angle = atan2d(T(2,1), T(1,1));
        use_rotation = false;
        fprintf('Extracted rotation angle from tform: %.4f degrees.\n', rotation_angle);
    end

    %% Perform transform
    if use_rotation
        fprintf('Applying slice-by-slice rotation...\n');

        test_rotation = imrotate(QPI_cropped(:,:,1), rotation_angle);
        [lx, ly] = size(test_rotation);
        D = zeros(lx, ly, z_num_cropped, 'like', QPI_cropped);

        for k = 1:z_num_cropped
            D(:,:,k) = imrotate(QPI_cropped(:,:,k), rotation_angle);
        end
    else
        fprintf('Applying slice-by-slice projective transform...\n');

        test_warp = imwarp(QPI_cropped(:,:,1), tform);
        [lx, ly] = size(test_warp);
        D = zeros(lx, ly, z_num_cropped, 'like', QPI_cropped);

        for k = 1:z_num_cropped
            D(:,:,k) = imwarp(QPI_cropped(:,:,k), tform);
        end
    end

    %% Pad to square
    if lx > ly
        fprintf('Padding the transformed data to a square array (%d x %d)...\n', lx, lx);
        D_int_pad = zeros(lx, lx, z_num_cropped, 'like', D);
        y_start = floor((lx - ly)/2) + 1;
        D_int_pad(:, y_start:(y_start + ly - 1), :) = D;
    elseif ly > lx
        fprintf('Padding the transformed data to a square array (%d x %d)...\n', ly, ly);
        D_int_pad = zeros(ly, ly, z_num_cropped, 'like', D);
        x_start = floor((ly - lx)/2) + 1;
        D_int_pad(x_start:(x_start + lx - 1), :, :) = D;
    else
        fprintf('Transformed data is already square; no padding applied.\n');
        D_int_pad = D;
    end

    %% Symmetrize or skip
    [d_lx, d_ly, d_lz] = size(D_int_pad);

    if skip_symmetrization
        fprintf('Skipping symmetrization as requested.\n');
        QPI_symm = D_int_pad;
    else
        fprintf('Applying symmetrization using method: %s.\n', symm_method);
        QPI_symm = zeros(d_lx, d_ly, d_lz, 'like', D_int_pad);

        switch symm_method
            case 'default'
                for k = 1:d_lz
                    A    = D_int_pad(:,:,k);
                    A90  = imrotate(A, 90);
                    A180 = imrotate(A, 180);
                    A270 = imrotate(A, 270);

                    QPI_symm(:,:,k) = ...
                        A90 + A180 + A270 + ...
                        flip(A,1) + flip(A,2) + flip(flip(A,1),2) + ...
                        flip(A90,1) + flip(A90,2) + flip(flip(A90,1),2);
                end

            case 'xy_mirror'
                for k = 1:d_lz
                    A = D_int_pad(:,:,k);
                    QPI_symm(:,:,k) = ...
                        (A + flip(A,1) + flip(A,2) + flip(flip(A,1),2)) / 4;
                end

            otherwise
                error('Unknown symm_method: %s', symm_method);
        end
    end

    %% Rotate output by 45 degrees
    fprintf('Generating the 45-degree rotated output...\n');
    test_rot45 = imrotate(QPI_symm(:,:,1), 45);
    [r45x, r45y] = size(test_rot45);
    QPI_symm_45 = zeros(r45x, r45y, d_lz, 'like', QPI_symm);

    for k = 1:d_lz
        QPI_symm_45(:,:,k) = imrotate(QPI_symm(:,:,k), 45);
    end

    fprintf('Done.\n');
end