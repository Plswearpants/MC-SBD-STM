function cmap = sbd_image_cmap(kind, n)
%SBD_IMAGE_CMAP  Image colormap for real vs synthetic STM panels.
%   cmap = sbd_image_cmap('real')           gray
%   cmap = sbd_image_cmap('real_ft')        invgray   (FT / QPI)
%   cmap = sbd_image_cmap('synthetic')      bone      (extra blue in shadows)
%   cmap = sbd_image_cmap('synthetic_ft')   invbone   (FT / QPI)
%   cmap = sbd_image_cmap(kind, n)          N-row version
%
%   Real-space and Fourier-space are inverses of each other, matching
%   visualizeRealResult (gray vs invgray).

    if nargin < 1 || isempty(kind)
        error('sbd_image_cmap:kind', ...
            'Specify ''real'', ''real_ft'', ''synthetic'', or ''synthetic_ft''.');
    end
    if nargin < 2 || isempty(n)
        n = 256;
    end

    switch lower(strtrim(char(kind)))
        case {'real', 'gray', 'grey'}
            cmap = gray(n);
        case {'real_ft', 'real_qpi', 'invgray'}
            cmap = invgray(n);
        case {'synthetic', 'syn', 'bone'}
            cmap = bone(n);
        case {'synthetic_ft', 'synthetic_qpi', 'invbone', 'bone_inv'}
            cmap = invbone(n);
        case {'imola'}
            cmap = imola(n);
        case {'invimola', 'imola_inv'}
            cmap = invimola(n);
        otherwise
            error('sbd_image_cmap:kind', ...
                ['Unknown kind ''%s''. Use real, real_ft, ', ...
                 'synthetic, or synthetic_ft.'], kind);
    end
end
