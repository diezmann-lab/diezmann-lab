function maskMgmt

%% Step 0: Set up in case fileMgmt didn't need to be run
% user input
rootdir = uigetdir(pwd,'Select folder containing single microscopy day'); % path with single microscopy session
s = filesep;

% all files/folders in rootdir, for debug purposes
all = append('**',s,'*.*');
list = dir(fullfile(rootdir,all)); 

% label proper directories
expdir = append(rootdir,s,'Experiments');
acdcdir = append(rootdir,s,'CellACDC');
tempdir = append(rootdir,s,'TempMasks');

% only experimental gonad folders
explist = dir(expdir);
explist = natsortfiles(explist);
explist = explist(~ismember({explist(:).name},{'.','..'})); % UPDATE TO GET RID OF AAAANNNNNY NON-EXPERIMENT STUFF
explist = explist(~startsWith({explist(:).name},'.')); % update to get rid of any extraneous files
numPos = length(explist); % gonads
expName = {explist.name};


%% Step 1: Organize!
% Proper labeling of masks and copy to tempmasks - AFTER CELL-ACDC/CELLPOSE/SPOTMAX HAVE BEEN RUN
cd(acdcdir) 
for i = 1:numPos
    positionName = sprintf('Position_%d',i);
    imagesdir = append(acdcdir,s,positionName,s,'Images');
    cd(imagesdir) % go into each image folder
    imageslist = dir(imagesdir);
    images = imageslist(~ismember({imageslist(:).name},{'.','..'}));
    images = imageslist(~startsWith({imageslist(:).name},'.')); % update to get rid of any extraneous files
    imagesNames = {images.name};
    numImages = length(images);
    % label
    for j = 1:numImages
        iName = string(imagesNames(j));
        label = append(num2str(i),"_",iName);
        movefile(iName,label) % rename files, now with label to keep track!
    end 
    % move
        npzstruct = dir(fullfile(imagesdir,'*.npz')); 
        if numel(npzstruct) == 0 % check if npz
        else 
        copyfile('*mask.npz',tempdir) % move over only reference masks (follows ACDC naming convention) 
        end 
    cd(acdcdir)
end 


%% Step 2: Convert files

% Convert .npz masks to .mat masks 
cd(tempdir)
% pyenv('Version', "C:\Users\Victoria\anaconda3\envs\seg\python.exe"); %% MAKE SURE TO INTIALIZE, create conda environment: conda create -n NAME python=3.10
% use which (or where) python in anaconda environment. Double check python and Matlab compatability
pyrun(["from scipy.io import savemat", ...
    "import numpy as np", ...
    "import glob", ...
    "import os", ...
    "npzFiles = glob.glob('*.npz')", ...
    "for f in npzFiles:", ...
    "   fm = os.path.splitext(f)[0]+'.mat'", ...
    "   d = np.load(f)", ...
    "   savemat(fm,d)"])
%% Step 3: Move masks to right exp folder
cd(tempdir)
for i = 1:numPos
    naddir = append(expdir,s,string(expName(i)));
    mask = append(num2str(i),'_','*.mat');
    maskName = {dir(mask).name};
    if ~isempty(maskName) % check if mask file exists
        copyfile(mask,naddir)
    end 
end 

%% Step 4: Delete TempMasks folder
%{
clearvars -except rootdir
cd(rootdir)
fclose('all');
rmdir('TempMasks','s') % weird issue with Windows 11... says file is open when it, in fact, is not
%}