% Compatibility stub — relocated under scripts/phase_space/run_parallel_dataset.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'run_parallel_dataset.m', 'phase_space/run_parallel_dataset.m');
target = fullfile(fileparts(mfilename('fullpath')), 'phase_space/run_parallel_dataset.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
