# naherinlied
lied script for seamstress & supercollider

this is the script I usually use for performance – it's very similar to SuperLied but offloads some duties from SuperCollider to Seamstress and has a slightly more fun GUI. Unlike SuperLied, it requires a monome grid. But also unlike SuperLied, you can bring your own midi device to it quite easily, thanks to Seamstress's params paradigm, which, like params on monome norns, makes midi mapping very easy.

This script will take some setup to work correctly. You'll want to put the stuff in the "seamstress-stuff" folder inside your seamstress folder and then alter line 851 of `naherinlied.scd` to point to that location. Once that's done, you can either execute `naherinlied.scd` from SCIDE or from a terminal, and it'll open seamstress for you and run the `naherinlied.lua` file that provides the GUI, midi functionality, etc. for the script.
