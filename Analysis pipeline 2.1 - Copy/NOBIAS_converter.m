%%% Converts between crusty NOBIAS "data" variable and "tracksToUse" (and vice versa)
% See NOBIAS manual for further details: https://github.com/BiteenMatlab/NOBIAS/blob/main/NOBIAS%20Quick%20Start%20Guide.pdf
% Inputs: tracksToUse 
% Outputs: data 

%% tracksToUse (track_analysis_main) to AllTracks (for NOBIAS)

function NOBIAS_converter

% Zeroth step: get oriented to file structure
rootdir = uigetdir(pwd,'Select folder containing single microscopy day');
s = filesep;
expdir = append(rootdir,s,'Experiments');
top = dir(expdir);
top = natsortfiles(top);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'})); % only experimental gonad folders
explist = folderlist(~startsWith({folderlist(:).name},'.')); % update to get rid of any extraneous files
numFolders = length(explist); % gonads
expName = {explist.name};

cd(expdir)
for f = 1:numFolders % may need to reinitalize variables here, but this is a sketch
    naddir = append(expdir,s,string(expName(f))); % go into each gonad folder
    cd(naddir)
    trackStruct = dir(fullfile(naddir,'*tracksToUse.mat'));
    tracksToUse = open(trackStruct.name);
    tracksToUse = tracksToUse.tracksToUse;
%% run without setting anything up
f = 1;
% First step: trackToUse to AllTracks
nTrack = size(tracksToUse, 2);
AllTracks = {};
for i = 1:nTrack
    nFrame = length(tracksToUse(i).frame); % number of frames in each track
    AllTracks{i,1}(1:nFrame,1) = 12; % placeholder
    AllTracks{i,1}(1:nFrame,2) = tracksToUse(i).frame + 1;  % frame number (split by track #)
    AllTracks{i,1}(1:nFrame,3) = tracksToUse(i).yLoc; % y coord
    AllTracks{i,1}(1:nFrame,4) = tracksToUse(i).xLoc; % x coord  
    AllTracks{i,1} = rmmissing(AllTracks{i,1}); % remove rows where there is no localization
end 

% Second step: AllTracks to data and reference (used later for tracksToUse labelling)
% Nearly identical to NOBIAS_preparedata
TrID=[];
All_steps={};
All_corrstep={};
min_length=3;
for i=1:length(AllTracks)
    temptr=AllTracks{i};
    fixedTrack = nan(max(temptr(:,2)),size(temptr,2));
    fixedTrack(temptr(:,2),:) = temptr;
    fixedTrack(1:find(all(isnan(fixedTrack),2)==0,1,'first')-1,:)=[];
    tempstep=fixedTrack(2:end,[4,3])-fixedTrack(1:end-1,[4,3]); % nans for sliding window of 2
    tempcorrstep=[tempstep(1:end-1,:).*tempstep(2:end,:); nan, nan];
    gapsID=(~isnan(tempstep(:,1)))&(~isnan(tempstep(:,2)));
    tempstep=tempstep(~isnan(tempstep(:,1)),:);
    tempstep=tempstep(~isnan(tempstep(:,2)),:);
    tempcorrstep=tempcorrstep(gapsID,:);
    reference(i).gaps = fixedTrack(:,2);
    if size(tempstep,1)>min_length
        All_steps{end+1}=tempstep;
        All_corrstep{end+1}=tempcorrstep;
    end
end
for i=1:length(All_steps)
    TrID=[TrID, ones(1,size(All_steps{i},1))*i];
end
data.obs=cat(1,All_steps{:})';
data.TrID=TrID;
data.obs_corr=cat(1,All_corrstep{:})'; % not needed if motion blur correction not wanted

% Third step: save
save(append(num2str(f),"NOBIAS_data"),"data")
save(append(num2str(f),"NOBIAS_reference"),"reference") % reference if want to go back to tracksToUse format later (i.e., for visualization)
end
end