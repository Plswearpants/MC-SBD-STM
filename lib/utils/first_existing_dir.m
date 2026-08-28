function d = first_existing_dir(candidates, fallback)
%FIRST_EXISTING_DIR First directory in CANDIDATES that exists.
%   D = FIRST_EXISTING_DIR(CANDIDATES)
%   D = FIRST_EXISTING_DIR(CANDIDATES, FALLBACK)
%
%   CANDIDATES is a cell array of paths. FALLBACK defaults to pwd.

    if nargin < 2 || isempty(fallback)
        fallback = pwd;
    end
    if ischar(candidates) || isstring(candidates)
        candidates = {char(candidates)};
    end
    for i = 1:numel(candidates)
        cand = candidates{i};
        if ~isempty(cand) && isfolder(cand)
            d = cand;
            return;
        end
    end
    d = fallback;
end
