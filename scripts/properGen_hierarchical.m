% Compatibility stub — relocated under scripts/phase_space/properGen_hierarchical.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'properGen_hierarchical.m', 'phase_space/properGen_hierarchical.m');
target = fullfile(fileparts(mfilename('fullpath')), 'phase_space/properGen_hierarchical.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
