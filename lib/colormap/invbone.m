function cmap = invbone(m)
%INVBONE  Inverted custom bone colormap for synthetic FT / QPI panels.
%   Same role as INVGRAY for real data: real-space uses BONE, Fourier
%   space uses INVBONE (flipud of the LUT).
%
%   Example:
%       colormap(invbone)
%       colormap(invbone(256))
%
%   See also BONE, INVGRAY, SBD_IMAGE_CMAP.

    if nargin < 1
        f = get(groot, 'CurrentFigure');
        if isempty(f)
            m = size(get(groot, 'DefaultFigureColormap'), 1);
        else
            m = size(f.Colormap, 1);
        end
    end
    cmap = flipud(bone(m));
end
