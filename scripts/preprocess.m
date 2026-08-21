% Compatibility stub — relocated under scripts/real/preprocess.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'preprocess.m', 'real/preprocess.m');
target = fullfile(fileparts(mfilename('fullpath')), 'real/preprocess.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
