%CREATE_BONE_COLORMAP  Preview custom bone / invbone and save bone.mat.

this_dir = fileparts(mfilename('fullpath'));
bone_map = bone(256);
save(fullfile(this_dir, 'bone.mat'), 'bone_map');

figure;
colormap(bone_map);
colorbar;
title('Bone (synthetic real-space, extra blue in shadows)');

figure;
colormap(flipud(bone_map));
colorbar;
title('Invbone (synthetic FT / QPI)');
