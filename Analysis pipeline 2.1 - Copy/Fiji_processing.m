%% Fiji through Matlab

% Software requirements: Fiji (latest version is best), Image-J-MATLAB plugin (though update site)
%{
addpath("C:\Users\Victoria\Downloads\fiji-latest-win64-jdk\Fiji\scripts") % where Miji.m is stored
javaaddpath("C:\Program Files\MATLAB\R2025b\java\mij.jar")
javaaddpath("C:\Program Files\MATLAB\R2025b\java\ij.jar")


Miji; % to start
MIJ.exit % to end session

MIJ.start("C:\Users\Victoria\Downloads\fiji-latest-win64-jdk\Fiji\fiji-windows-x64.exe") % alternative ways to start
MIJ.start

ij.IJ.open(imagePath) % open images

% running a macro
fijiPath = "C:\Users\Victoria\Downloads\fiji-latest-win64-jdk\Fiji\fiji-windows-x64.exe";
macroFile = fullpath(fijiPath,'macros','Name.ijm');
IJ.runMacroFile(macroFile)

% test

macroCode = fileread("C:\Users\Victoria\Documents\Analysis pipeline\Add_planes.ijm");
MIJ.runMacro(macroCode)
MIJ.run('Macro...',['code=[' macroCode ']']);

IJ.runMacroFile("C:\Users\Victoria\Documents\Analysis pipeline\Add_planes.ijm")

macroFile = "C:\Users\Victoria\Documents\Analysis pipeline\Add_planes.ijm";
ij.IJ.runMacroFile(macroFile) % <-- THIS ONE
%}

%% ACTUALLY USING MACRO - alternatives commented out but kept in case of breakage

% Set up
function Fiji_processing(fijipath,mijpath,ijpath)
addpath(fijipath) % where Miji.m is stored
javaaddpath(mijpath)
if  ijpath ~= "" % optional to use ijpath 
    javaaddpath(ijpath)
end 

Miji % open ImageJ through Matlab
% MIJ.start

% running macro
macroFile = "Add_planes_add_channels.ijm";
ij.IJ.runMacroFile(macroFile)

MIJ.exit % end session