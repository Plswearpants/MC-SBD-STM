% Compatibility stub — relocated under scripts/synthetic/run_synthetic_data.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'run_synthetic_data.m', 'synthetic/run_synthetic_data.m');
target = fullfile(fileparts(mfilename('fullpath')), 'synthetic/run_synthetic_data.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
