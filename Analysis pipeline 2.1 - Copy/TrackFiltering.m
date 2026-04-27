%%% Got masks and are looking to filter tracks? 


%% Step 0: Get masks from Cell-ACDC

%% Step 1: Import files

% Convert .npz masks to .mat masks 
cd(tempdir)
pyrun(["from scipy.io import savemat", ...
    "import numpy as np", ...
    "import glob", ...
    "import os", ...
    "npzFiles = glob.glob('*.npz')", ...
    "for f in npzFiles:", ...
    "   fm = os.path.splitext(f)[0]+'.mat'", ...
    "   d = np.load(f)", ...
    "   savemat(fm,d)"])

%% Step 2: Combine cycles

slice = arr_0(i,:,:); % per cycle
slice = squeeze(slice);

% optional plotting to manually check masks
%{ 
imagesc(slice)
slice_blur = imgaussfilt(slice,0.75);
set(gca, 'Visible','off') % invisible axes
set(gca, 'XTick', [])
set(gca, 'XTickLabel', [])
set(gca, 'YTick',[])
set(gca, 'YTickLabel', [])
%} 

%% combining masks testing (figure hold on doesn't work, sadly)
figure; imshow(BW) % first binary image
figure; imshow(BW1) % second binary image
BW2 = imfuse(BW,BW1); % combo (but in color), uint8
figure; imshow(BW2)
BW3 = rgb2gray(BW2);
figure; imshow(BW3)
BW4 = imbinarize(BW3);
figure; imshow(BW4)

% 1) binary images, 2) fuse binaries (into RBG), 3) convert RGB to
% grayscale since can't directly binarize, and 4) convert grayscale back to binary

% user input  
numCycles = 3;
planes = 1;
slices = numCycles * planes;
BW = logical(zeros(488)); % blank 488x488 for concatenation purposes

%% loop to smush together masks

slices = 3; 
for i = 1:slices
    slice = arr_0(i,:,:); 
    slice = squeeze(slice);
    bw = imbinarize(slice); 
    bw = bwareaopen(bw,10);
    BW = imfuse(BW,bw);
end 
imshow(BW) % should see green and magenta for overlaps

% binarizing masks 
BW = rgb2gray(BW);
BW = imbinarize(BW);
imshow(BW) % should just see black and white
%}

%% make mask very simple (white for chromsomes, everything else black)
%figure
%hold on
slice = arr_0;
BW = imbinarize(slice); % adapative for trackmate
BW = bwareaopen(BW,10); % remove "SC" smaller than 10 pixels
% imshow(BW)
% get centroid from each slice --> track how this moves over time and apply
% this translation to tracks? 
% s = regionprops(slice,'centroid');
% centroids = cat(1,s.Centroid);
% meanVal = mean(arr_0,"all");
%binaryImage = arr_0 >= meanVal;
%imshow(binaryImage) % now 1 = SC, 0 = not SC

%% plotting tracks over mask

% grabbing only relevant things from tracksOrg + unit conversion and offset
% (later add in NOBIAS annotation)
tracks = struct;
nTracks = length(tracksOrg);
for i = 1:nTracks
    tracks(i).xCoord = ([tracksOrg(i).xLoc]+2290)/99; %in px is /99
    tracks(i).yCoord = ([tracksOrg(i).yLoc]+2290)/99;
    tracks(i).frame = tracksOrg(i).frame;
    % tracks(i).cycle = tracksOrg(i).cycle;
    % tracks(i).track = tracksOrg(i).track;
end 
rawTracks = tracks;

% prefilter based on loc time 
for i = 1:nTracks
    % too short of tracks or missing too many locs
    if length(tracks(i).xCoord) < 10 || sum(isnan(tracks(i).xCoord))/length(tracks(i).xCoord) > 0.50
        tracks(i).xCoord = [];
    end 
end 
idx = zeros(nTracks,1);
for i = 1:nTracks
    idx(i) = ~isempty(tracks(i).xCoord);
end 
idx = logical(idx);
tracks = tracks(idx);
nTracks = length(tracks);
%% CYCLE TESTING
cycle1 = tracks;

% cycle 1 (0)
for i = 1:nTracks
    if any(tracks(i).cycle ~= 1) 
        cycle1(i).xCoord = [];
    end 
end 

idx = zeros(nTracks,1);
for i = 1:nTracks
    idx(i) = ~isempty(cycle1(i).xCoord);
end 
idx = logical(idx);
cycle1 = cycle1(idx);
nTracks = length(cycle1);
tracks = cycle1;
save("cycle1tracks","tracks");


%% prefilter based on if "in" SC or not at any point
% round locs to nearest int in order to deal with resolution of image
for i = 1:nTracks
    for j = 1:length(tracks(i).frame)
        Rtracks(i).xCoord(j) = round(tracks(i).xCoord(j));
        Rtracks(i).yCoord(j) = round(tracks(i).yCoord(j));
    end 
end 

% look to see if y-x pair = 1 in binary image
w = 3; % wiggle room, in pixels
for i = 1:nTracks
    for j = 1:length(tracks(i).frame)
        x = Rtracks(i).xCoord(j);
        y = Rtracks(i).yCoord(j);
        % see if in mask or not
        if isnan(x) || isnan(y)
            tracks(i).SC(j) = NaN; 
        elseif sum(sum(BW(y-w:y+w,x-w:x+w)))>0 % check the surrounding region for any white pixels
            tracks(i).SC(j) = 1; 
        else
            tracks(i).SC(j) = 0;
        end 
    end 
    tracks(i).SC = (tracks(i).SC)';
    %tracks(i).states = states(i).trackLabelEdit; % for NOBIAS if have annotation 
end 

% keep only tracks with at least some time in SC
id = zeros(nTracks,1);
for i = 1:nTracks
    if any(tracks(i).SC == 1)
        id(i) = 1;
    else 
        id(i) = 0;
    end 
end 
bad = sum(id)/nTracks; % percent bad tracks
id = logical(id);
SCTracks = tracks(id);
nTracks = length(SCTracks);
% save("SC_cycle2","SCTracks")
%% cursed reconstruction based on what gets filtered in track analysis
%{
for i = 1:length(tracksToUse2)
    j = 1;
    while abs(tracksToUse2(i).xLoc(1) - ((SCTracks(j).xCoord(1)*99)-2290)) > 1 * 10^-11
        j = j + 1;
    end
    tracksToUse2(i).SClabel = SCTracks(j).SC;
end 
save("tracksToUse2_label","tracksToUse2")
%}

%% plotting >:)
nTracks = length(tracksToUse);
figure; hold on
imshow(imbinarize(squeeze(arr_0(1,:,:))))
for i = 1:nTracks
    plot((tracksToUse(i).xLoc)/99,(tracksToUse(i).yLoc)/99)
end


figure; 
hist([tracksToUse(:).fitD]*1000)
%{
% with original BG image
figure 
hold on
BG = imread("D:\LvD008_15C_SPT\20251107\Gonad1\Early_Pach_S1G1R1\Processed images\BG_mat.png");
imshow(BG)
for i = 1:nTracks
    plot(SCTracks(i).xCoord,SCTracks(i).yCoord)
end

% compare to prefilter
figure 
hold on
imshow(BG)
nTracks = length(tracksOrg);
for i = 1:nTracks
    plot(rawTracks(i).xCoord,rawTracks(i).yCoord)
end
%}

%% save filtered SC tracks in Swift format --> then can run track analysis main
% Set up
nTracks = length(SCTracks);
swift = [];

% Loop to populate swift table
for i = 1:nTracks
    dur = length(SCTracks(i).xCoord); % length (# of frames)
    % ID and time
    t = (SCTracks(i).frame)';
    id = i*ones(dur,1); % track/seg id
    % x loc & error
    x = (SCTracks(i).xCoord*99)-2290;
    precisionx = zeros(dur,1); % precisionx = Errors(i).precisionx;
    % y loc & error
    y = (SCTracks(i).yCoord*99)-2290;
    precisiony = zeros(dur,1); % precisiony = Errors(i).precisiony; 
    % combining everything
    swi = horzcat(x',y',precisionx,precisiony,id,id,t,id);
    swift = vertcat(swift,swi);
end 

% labeling
colNames = {'x','y','precisionx','precisiony','track_id','seg_id','t','id'};
swiftTable = array2table(swift,'VariableNames',colNames);
toDelete = isnan(swiftTable.x);
swiftTable(toDelete,:) = [];
% export
writetable(swiftTable, 'SCtracks.csv');



%% TESTING: Track cycles and masks cycles

% (All tracks for testing have >10 locs and <50% blinky)

% SCTracks1 is cycle 1 tracks that are "in the SC" of the cycle 1 mask
% SCTracks2 is cycle 1 tracks that are "in the SC" of the cycle 2 mask

% FP is a cycle 1 track that is in the cycle 2 mask, but not the cycle 1 mask
% FN is a cycle 1 track that is in the cycle 1 mask, but not the cycle 2 mask

FP = 0;
FN = 0;

tracks1 = [SCTracks1(:).track];
tracks2 = [SCTracks2(:).track];

% FP
for i = 1:length(tracks2)
    if any(tracks1==tracks2(i)) % check if c1m2 track exists in c1c1
    else
        FP = FP + 1;
    end 
end 

% FN
for i = 1:length(tracks1)
    if any(tracks2==tracks1(i))
    else 
        FN = FN + 1;
    end 
end 