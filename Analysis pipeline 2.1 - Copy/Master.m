%%% This script is a "one-stop shop" for any data analysis. Right now, it
%%% is merely a way to keep track (ha, pun) of analysis steps and important
%%% scripts. 

%% 0. FILE MANAGEMENT 
addpath(genpath("LVD Matlab"))
addpath(genpath("NOBIAS"))
addpath(genpath("uTrack"))
addpath(genpath("Analysis pipeline"))

%% 1. TRACKING
% Software requirements: uTrack
% Input: ExportedParticles-001.csv
% Output: tracksOrg


% Set up
path_to_main_code = 'C:\Users\Victoria\Documents\uTrack\u-track3D-master'; % master folder that contains uTrack code
saveFolder = 'C:\Users\Victoria\Documents\uTrack\u-track-save'; % temp folder (FILES GET DELETED!)

% Parameters

Tracking

%% . MASKS
% Software requirements: anaconda, Cell-ACDC

%% . FILTERING
TrackFiltering

%% . ANALYSIS

% Convert tracksOrg to data for NOBIAS
NOBIAS_converter

%% . VISUALIZATION