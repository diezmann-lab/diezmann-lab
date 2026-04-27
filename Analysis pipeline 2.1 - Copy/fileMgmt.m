% A script to automatically process Vutara output data and create a nice file structure for usage
% in Cell-ACDC (Cellpose and SpotMAX). All this requires is a folder that
% contains subfolders for each gonad sample/region

%% Set up
function fileMgmt
% step 0: run Fiji macro!!!
% user input

rootdir = uigetdir(pwd,'Select folder containing single microscopy day'); % path with single microscopy session
s = filesep;

% all files/folders in rootdir, for debug purposes
all = append('**',s,'*.*');
list = dir(fullfile(rootdir,all)); 


% only experimental gonad folders
top = dir(rootdir);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'})); % og
explist = folderlist(~startsWith({folderlist(:).name},'.')); % update to get rid of any extraneous files
numFolders = length(explist); % gonads

% make Experiment and ACDC folders in root dir
cd(rootdir)
mkdir Experiments  
mkdir CellACDC
mkdir TempMasks
expdir = append(rootdir,s,'Experiments');
acdcdir = append(rootdir,s, 'CellACDC');
tempdir = append(rootdir,s,'TempMasks');

% move over gonad folders to Experiments
expName = {explist.name};
for i = 1:numFolders
    nadName = string(expName(i));
    NnadName = append(num2str(i),'_',nadName);
    movefile(nadName,NnadName); % give label for keeping track purposes
    movefile(NnadName,'Experiments') % move to experiments
end 
top = dir(expdir); % redo name list
top = natsortfiles(top);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'}));
expName = {explist.name};

%% create Position_X and Images folders in ACDC folder
for i = 1:numFolders
    positionName = sprintf('Position_%d',i);
    positionPath = fullfile(acdcdir,positionName);
    mkdir(positionPath);
end 

sub = dir(acdcdir); % right now this section is redundant, but may be needed if two planes to replace numFolders above
sub = sub([sub.isdir]);
poslist = sub(~ismember({sub(:).name},{'.','..'}));
numPos = length(poslist);
cd(acdcdir)

for i = 1:numPos
    posname = {poslist.name};
    posdir = append(acdcdir,s,string(posname(i))); % get to correct Position_X
    cd(posdir)
    mkdir Images
    cd(acdcdir)
end 

%% copy over tiffs to ACDC Images, grab reference and make a copy of it
cd(expdir)
for i = 1:numFolders
    naddir = append(expdir,s,string(expName(i))); % go into each gonad folder
    cd(naddir)
    nadstruct = dir(fullfile(naddir,'*tif*'));
    positionName = sprintf('Position_%d',i);
    imagesdir = append(acdcdir,s,positionName,s,'Images');
    if numel(nadstruct) == 0 % check if tiffs exist
    else 
        copyfile('Add_planes*.tif*',imagesdir) % right now, need to run macro first to get right file names
        cd(imagesdir)
        % copies tiff to make reference - this is an absolute pain, but works
        imageslist = dir(imagesdir);
        images = imageslist(~ismember({imageslist(:).name},{'.','..'}));
        imagesNames = {images.name};
        numImages = length(images);
        for j = 1:numImages
            match = ".t" + wildcardPattern + "f"; % to allow for both tif and tiff
            % match = ".ti*";
            iName = string(imagesNames(j));
            % byebye = append('_add_channels',match);
            byebye = '_add_channels.t' + wildcardPattern + 'f';
            if contains(iName,'add_channels')
                ref = erase(iName, byebye);
            else 
                ref = erase(iName, match);
            end 
            ref = append(ref,'_ref.tif');
            copyfile(iName,ref); 
        end 
    end 
    cd(expdir)
end 
end 

