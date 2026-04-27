%% This function filters tracks generated from uTrack based on if they are in the SC or not
% !!! This requires chromosomes masks from Cell-ACDC (Cellpose/SpotMAX) !!!
% "In the SC" means at least one loc from a track overlaps with a mask in
% the previous, current, or next cycle ("time wiggle") - i.e., a cycle 2
% track overlaps with a mask in cycle 1 or cycle 3. 
% Automatically includes the correct Vutara offset (reference image doesn't
% exactly align with particle localization -- see Registration Analysis)
% Optionally, can also include a "space wiggle" so that tracks don't
% exactly have to overlap with mask, just be close enough.

function REAL_trackFiltering(nm2px,minLocs,maxBlink,w,small,filter)
s = filesep;
% User inputs
if nargin == 0
    warning("No parameters input. Using default values")
nm2px = 99; % conversion (nm per px)
minLocs = 10;
maxBlink = 0.50;
w = 0; % wiggle room, in pixels
small = 3;
filter = 'SC+Nuc'; % options: 'none','SConly','SCandNuc', 'SC+Nuc'
end 
%if ~exist(w,'var') % first input to exist must be a string scalar or
%character vector
    %w = 0;
%end 
%if ~exist(small,'var')
  %  small = 0;
%end 
vutaraOffset = 0; % = 2290: use in dire circumstances, now replaced with tform in Tracking

%% Step 0: Get masks from Cell-ACDC

%% Step 1: File management (as always)
rootdir = uigetdir(pwd,'Select folder containing single microscopy day');
expdir = append(rootdir,s,'Experiments');
top = dir(expdir);
top = natsortfiles(top);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'})); % only experimental gonad folders
numFolders = length(explist); % gonads
expName = {explist.name};

cd(expdir)
for f = 1:numFolders % may need to reinitalize variables here, but this is a sketch
    naddir = append(expdir,s,string(expName(f))); % go into each gonad folder
    cd(naddir)
    trackStruct = dir(fullfile(naddir,'*tracksOrg.mat'));
    tracksOrg = load(trackStruct.name); % load in correct files
    maskStruct = dir(fullfile(naddir,'*mask.mat'));
    arr_0 = load(maskStruct.name); 
%% Step 2: Prefilter tracks based on locs and blinking
tracksOrg = tracksOrg.tracksOrg; % weird way to load in mat file, but it works!
arr_0 = arr_0.arr_0;
numCycles = size(arr_0,1);
tracks = struct;
% adjustments
nTracks_raw = length(tracksOrg);
for i = 1:nTracks_raw
    tracks(i).xCoord = ([tracksOrg(i).xLoc]+vutaraOffset)/nm2px; %in px is /99
    tracks(i).yCoord = ([tracksOrg(i).yLoc]+vutaraOffset)/nm2px;
    tracks(i).frame = tracksOrg(i).frame;
    tracks(i).cycle = tracksOrg(i).cycle;
    tracks(i).track = tracksOrg(i).track;
end 
rawTracks = tracks; % debug purposes

% prefilter based on loc time 
for i = 1:nTracks_raw
    % too short of tracks or missing too many locs
    if length(tracks(i).xCoord) <= minLocs || sum(isnan(tracks(i).xCoord))/length(tracks(i).xCoord) >= maxBlink
        tracks(i).xCoord = [];
    end 
end 
idx = zeros(nTracks_raw,1);
for i = 1:nTracks_raw
    idx(i) = ~isempty(tracks(i).xCoord);
end 
idx = logical(idx);
tracks = tracks(idx);
nTracks_prefilter = length(tracks);

% rounding locs to nearest pixel -- should this instead be just chopping off decimals?
for i = 1:nTracks_prefilter
    for j = 1:length(tracks(i).frame)
        Rtracks(i).xCoord(j) = round(tracks(i).xCoord(j));
        Rtracks(i).yCoord(j) = round(tracks(i).yCoord(j));
        Rtracks(i).cycle = tracks(i).cycle;
        Rtracks(i).track = tracks(i).track;
        Rtracks(i).frame = tracks(i).frame;
    end 
end 


%% Step 3: Import masks and filter tracks 

% Try "time wiggle" and splitting by cycle
BW = imbinarize(arr_0);
BW = bwareaopen(BW,small); % removes <=small px mask bits 
sctracks = struct([]);

for c = 1:numCycles
    % grab correct tracks
    Rcycle = Rtracks;
    for i = 1:nTracks_prefilter
    if Rtracks(i).cycle ~= c 
        Rcycle(i).xCoord = [];
    end 
    end 
    idx = zeros(nTracks_prefilter,1);
    for i = 1:nTracks_prefilter
        idx(i) = ~isempty(Rcycle(i).xCoord);
    end 
    idx = logical(idx);
    Rcycle = Rcycle(idx);
    nTracks_cycle = length(Rcycle);

    % grab correct masks - one before and one after
    % BWm = current mask, BWb = mask before, BWa = mask after
    if ndims(arr_0) > 2 % check if need to squeeze down
        BWm = squeeze(BW(c,:,:));
    if c == 1 && ndims(arr_0) % edge case
        BWa = squeeze(BW(c+1,:,:));
        BWb = logical(zeros(488)); % blank
    elseif c == numCycles % edge case
        BWa = logical(zeros(488));
        BWb = squeeze(BW(c-1,:,:));
    else 
        BWa = squeeze(BW(c+1,:,:));
        BWb = squeeze(BW(c-1,:,:));
    end 
    else % super special case when only 1 cycle
        BWm = BW; BWa = BW; BWb = BW;
    end

% look to see if y-x pair = 1 in binary image
for i = 1:nTracks_cycle
    for j = 1:length(Rcycle(i).frame)
        x = Rcycle(i).xCoord(j);
        y = Rcycle(i).yCoord(j);
        % see if in mask or not
        if isnan(x) || isnan(y) % missing locs
            Rcycle(i).SC(j) = 12; % THIS IS IMPORTANT FOR FILTERING LATER TO MAKE IT LESS CONFUSING 
        elseif sum(sum(BWm(y-w:y+w,x-w:x+w)))>0 || ...
               sum(sum(BWa(y-w:y+w,x-w:x+w)))>0 || ...
               sum(sum(BWb(y-w:y+w,x-w:x+w)))>0 % check the surrounding cycles for any white pixels
            Rcycle(i).SC(j) = 1; 
        else
            Rcycle(i).SC(j) = 0;
        end 
    end 
    Rcycle(i).SC = (Rcycle(i).SC)';
    Rcycle(i).frame = (Rcycle(i).frame)';
end 

% keep only tracks with at least some time in SC - TO UPDATE: AT LEAST x 10 continuous locs in SC
switch filter % get id for each filter type
 %% CASE: NO FILTERING
    case 'none'
        id = ones(nTracks_cycle,1);
        % do filtering based on cycle and filter type
    id = logical(id);
    ctracks = tracks(idx); % cycle filter
    names = {Rcycle.SC}; % copy over in sc data by cycle
    [ctracks.sc] = names{:};
    SCTracks = ctracks(id); % SC filter
    sctracks = horzcat(sctracks,SCTracks);
%% CASE: SC ONLY
    case 'SConly' 
subs = struct([]);
nTrack = length(Rcycle);
for n = 1:nTrack
    subsequences = struct([]);
    if isempty(find(Rcycle(n).SC==1, 1)) % nothing in SC
    else 
    startIdx = find(Rcycle(n).SC == 1);
    endIdx   = find(Rcycle(n).SC == 0);
    if isempty(endIdx) % entirely in SC
        endIdx = startIdx(end); % grab last 1
    else 
        endIdx = vertcat(find(Rcycle(n).SC==0),startIdx(end)); %startIdx; % otherwise, hm.... 
    end 
    
    lastEnd = 0; % Track last subsequence end index

    % Loop through start indices
    for i = 1:length(startIdx)
        if startIdx(i) <= lastEnd
            continue; % Skip if inside previous subsequence
        end

        % Find the first end index after this start
        nextEnd = endIdx(find(endIdx >= startIdx(i), 1, 'first'));
        if ~isempty(find(Rcycle(n).SC(startIdx(i):nextEnd)==0, 1))
            nextEnd = nextEnd - 1;
        end 

        if ~isempty(nextEnd)
            subsequences(end+1).seqs = Rcycle(n).SC(startIdx(i):nextEnd);
            subsequences(end).idx = startIdx(i):nextEnd;
            subsequences(end).track = Rcycle(n).track;
            lastEnd = nextEnd; % Update last end to avoid overlaps
        end
    end 
    end
    subs = horzcat(subs,subsequences);
end

% cleanup: kick out trailing 12s (because I am not inclined to figure it
% out in the above loop)

nSeqs = length(subs);
for i = 1:nSeqs
    if subs(i).seqs(end) == 12 % check if has trailing 12s
        lastOne = find(subs(i).seqs == 1, 1, 'last' );
        subs(i).seqs = [subs(i).seqs(1:lastOne)];
    end 
end 

% final filtering
ID = zeros(nSeqs,1);
for i = 1:nSeqs
    inSC = length(find(subs(i).seqs==1));
    Nans = length(find(subs(i).seqs==12));
    percSC = inSC/(inSC+Nans);
    if length(subs(i).seqs) >= minLocs && percSC >= maxBlink
        ID(i) = 1;
    end 
end 
ID = logical(ID);
subs = subs(ID);

% get xLoc, yLoc, frame
    ctracks = tracks(idx); % cycle filter
    if ~isempty(Rcycle) % check to make sure stuff is in there
    names = {Rcycle.SC}; % copy over in sc data by cycle
    [ctracks.sc] = names{:};
nSeqs = length(subs);
for i = 1:nSeqs
    id = (subs(i).idx)';
    trackN = subs(i).track;
    subTracks = ctracks([ctracks(:).track] == trackN);
    subs(i).xCoord = subTracks.xCoord(id);
    subs(i).yCoord = subTracks.yCoord(id);
    subs(i).frame = subTracks.frame(id);
    subs(i).cycle = subTracks.cycle;
    subs(i).sc = subTracks.sc(id);
end 
SCTracks = subs; 
if isempty(SCTracks)
else 
sctracks = horzcat(sctracks,SCTracks);
end
    end

%% CASE: SC AND NUC - mix of SC, Nuc, and SC+Nuc
    case 'SCandNuc'
        id = zeros(nTracks_cycle,1);
        for i = 1:nTracks_cycle
            if any(Rcycle(i).SC == 1) % at least one loc in SC
                id(i) = 1;
            else 
                id(i) = 0;
            end 
        end 
    id = logical(id);
    ctracks = tracks(idx); % cycle filter
    if ~isempty(Rcycle) % make sure tracks exist
    names = {Rcycle.SC}; % copy over in sc data by cycle
    [ctracks.sc] = names{:};
    SCTracks = ctracks(id); % SC filter
    sctracks = horzcat(sctracks,SCTracks);
    end
    %% CASE: SC BUT ALSO NUC - just SC+Nuc (i.e., no "pure" tracks of SC or Nuc)
    case 'SC+Nuc'
        id = zeros(nTracks_cycle,1);
        for i = 1:nTracks_cycle
            if any(Rcycle(i).SC == 1) && any(Rcycle(i).SC == 0) % at least one loc in SC and one in Nuc
                id(i) = 1;
            else 
                id(i) = 0;
            end 
        end 
    id = logical(id);
    ctracks = tracks(idx); % cycle filter
    if ~isempty(Rcycle) % check to make sure not empty
        names = {Rcycle.SC}; % copy over in sc data by cycle
    [ctracks.sc] = names{:};
    SCTracks = ctracks(id); % SC+Nuc filter
    sctracks = horzcat(sctracks,SCTracks);
    end
end
end 


%% Step 4: Visualization - optional

% rawTracks for entirely unfiltered
% tracks for prefiltered
% SCTracks for prefiltered and in SC 

%% Step 5: Save SC tracks in correct format for analysis
nTracks_SC = length(sctracks);
swift = [];

% Loop to populate swift table
for i = 1:nTracks_SC
    dur = length(sctracks(i).xCoord); % length (# of frames)
    % ID and time
    t = (sctracks(i).frame)';
    id = i*ones(dur,1); % track/seg id
    if isfield(sctracks,'track')
        track_id = sctracks(i).track*ones(dur,1);
    else 
        track_id = id;
    end 
    % x loc & error
    x = (sctracks(i).xCoord*99)-vutaraOffset;
    precisionx = zeros(dur,1); 
    % y loc & error
    y = (sctracks(i).yCoord*99)-vutaraOffset;
    precisiony = zeros(dur,1); 
    % cycles (for diagnostic purposes)
    cycle = (sctracks(i).cycle)*ones(dur,1);
    % time in SC (for analysis purposes)
    inSC = sctracks(i).sc; 
    % combining everything
    swi = horzcat(x',y',precisionx,precisiony,track_id,id,t,id,cycle,inSC);
    swift = vertcat(swift,swi);
end 

% labeling
colNames = {'x','y','precisionx','precisiony','track_id','seg_id','t','id','cycle','inSC'};
if ~isempty(swift)
swiftTable = array2table(swift,'VariableNames',colNames);
toDelete = isnan(swiftTable.x);
swiftTable(toDelete,:) = [];
% export
switch filter
    case 'none'
    writetable(swiftTable, append(num2str(f),'SCRawTracks.csv'));
    case 'SConly'
    writetable(swiftTable, append(num2str(f),'SCOnlyTracks.csv'));
    case 'SCandNuc'
    writetable(swiftTable, append(num2str(f),'SCandNucTracks.csv'));
    case 'SC+Nuc'
    writetable(swiftTable, append(num2str(f),'SC+NucTracks.csv'));
end 
else 
end 

%% TESTING
%{
% Time in SC (using time wiggle technique)
for i = 1:nTracks_SC
    time = sctracks(i).SC;
    in = sum(time(:)==1);
    out = sum(time(:)==0);
    total = in + out; % this excludes NaNs
    sctracks(i).percSC = in/total*100; 
end 

save("sc_label_lone_after","sctracks");
figure; hist([sctracks(:).percSC])
%}

%% Plotting
%{
BW = imbinarize(squeeze(arr_0(1,:,:)));
figure; hold on
imshow(BW) % right now, arbitrary cycle
for i = 1:nTracks_raw
    plot(tracks(i).xCoord,tracks(i).yCoord)
end 
%}
end
end 

%{
    case 'SConly' 
        id = zeros(nTracks_cycle,1);
        max_count = 1;
        count = 1;
        j = 2;
            for i = 1:nTracks_cycle
                if isempty(find([Rcycle(i).SC] == 1, 1)) % nothing in SC 
                    max_count = 0;
                else 
                while j <= length(Rcycle(i).SC)
                if (Rcycle(i).SC(j) ~= 0) && (Rcycle(i).SC(j-1) ~= 0) % NaNs (12) okay, just not 0
                    % UPDATE: condition for NaNs
                    count = count + 1;
                else 
                    %lastInt = find(Rcycle(i).SC==1,1,"last");
                    if count > max_count %&& lastInt  % make sure last seen integer is 1 (not 0 or NaN (12))   
                        max_count = count;
                    end
                    count = 1;
                end 
                j = j + 1;
                end 
                if count > max_count % checks if the last sequence is the longest
                    max_count = count;
                end
                end
            j = 2;
            count = 1;
            Rcycle(i).SCmax = max_count;
            if Rcycle(i).SCmax >=10 
                id(i) = 1;
            else 
                id(i) = 0;
            end 
            max_count = 1;
            end 
%}