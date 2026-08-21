% Compatibility stub — relocated under scripts/real/postprocessing.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'postprocessing.m', 'real/postprocessing.m');
target = fullfile(fileparts(mfilename('fullpath')), 'real/postprocessing.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
