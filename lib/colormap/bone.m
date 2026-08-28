function cmap = bone(m)
%BONE  Custom bone colormap for synthetic STM image panels.
%   BONE(M) returns an M-by-3 matrix. BONE, by itself, uses the current
%   figure colormap length (or the MATLAB default if no figure exists).
%
%   Starts from classic MATLAB/Octave bone (gray with a blue tinge), then
%   adds extra blue in the dark end so shadows read colder. Highlights
%   still go to bone-white. Real-data plots use GRAY; synthetic FT/QPI
%   uses INVBONE.
%
%   Example:
%       colormap(bone)
%       colormap(bone(256))
%
%   See also INVBONE, GRAY, INVGRAY, SBD_IMAGE_CMAP, COLORMAP.

    if nargin < 1
        f = get(groot, 'CurrentFigure');
        if isempty(f)
            m = size(get(groot, 'DefaultFigureColormap'), 1);
        else
            m = size(f.Colormap, 1);
        end
    end

    if isempty(m) || m < 1
        cmap = zeros(0, 3);
        return
    end
    if m == 1
        cmap = [0, 0, 0];
        return
    end

    x = linspace(0, 1, m)';

    % Classic bone: R=G=(7/8)x, B=(9/8)x, then blend to white above 3/4.
    r = (7/8) * x;
    g = (7/8) * x;
    b = min(1, (9/8) * x);
    hi = x >= 3/4;
    r(hi) = (11/8) * x(hi) - 3/8;
    g(hi) = r(hi);
    b(hi) = 1;

    % Extra blue in the shadows (zero at black so the floor stays black).
    % Peaks near x~0.15 and fades before mid-gray so highlights stay bone.
    dark_lobe = x .* exp(-((x - 0.15) / 0.22).^2);
    peak = max(dark_lobe);
    if peak > 0
        dark_lobe = dark_lobe / peak;
    end
    extra = 0.28 * dark_lobe;
    b = min(1, b + extra);
    r = max(0, r - 0.14 * extra);
    g = max(0, g - 0.05 * extra);

    cmap = [r, g, b];
    cmap = min(max(cmap, 0), 1);
end
