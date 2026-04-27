%% Aligns particle data with reference image 
% This function takes raw localization data spit out by Vutara (i.e., Exported-Particles001.csv) 
% and converts it to align with a reference image. Why is this necessary,
% you might ask? Well... it seems like there is some offset that Vutara
% applies to the ROI and a tiny tiny tiny amount of rotation. 
% The transformation function used here is based on empirical observation
% of calibration bead data being aligned with reference images

function vutaraOffset

nm2px = 99; % scale of physical space to pixels, 99 nm/px for our scope

% Set up - load in relevant files and adjust a few things
Particles = readtable('ExportedParticles-001.csv');
Particlesx = Particles.x/nm2px;
Particlesy = Particles.y/nm2px;

% transformation - from bead data
[tX,tY] = transformPointsForward(tform,Particlesx,Particlesy);
% DOES Z MATTER FOR TRANSFORM??????

% update particles file
Particles.x = tX*nm2px; % remultiplied here because subsequent analyses need to be in nm
Particles.y = tY*nm2px;

% save transformation function
save('ExportedParticles-001-reg.csv',"Particles");

end 