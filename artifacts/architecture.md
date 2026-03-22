# planned architeture overview

This project is concerned with comparison testing of simulation implementations of the extended phase graph (EPG) formalism.
The goal is to produce golden data in a structured reference format.

The Python `jax`-based implementation is external to this repostory.
The Python implementation is functional-style and produces operators and base state matrices.


The MATLAB implementation is internal to this repository -> functions are extracted into the `matlab` directory.
The MATLAB implementation is in-place mutating and produces mutated state matrices.

We would like to compare the golden data with the Python output in the other repository as part of the testing process.

We need some kind of intermediate comparison test specification format to specify the input - output pairs for the two implementations.

Option Flow 1:

Generate inputs here:

 -> input state matrix omega + inputs to EPG function
 -> compute output matrix omega' in MATLAB
 -> save input and output in a structured format (e.g. JSON, HDF5, etc.) with tags and metadata (git commit hash from matlab code) as tagged golden data
 -> load the input and output in the Python repository
 -> compute output matrix omega' in Python in other repository
 -> compare the Python output with the MATLAB output in other repository as part of the testing process in the other repository
