# LZSS-VHDL
An implementation of the [LZSS](https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Storer%E2%80%93Szymanski) lossless data compression algorithm in VHDL. The implementation adheres to the [Intel Avalon Streaming Interface](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/manual/mnl_avalon_spec.pdf#_OPENTOPIC_TOC_PROCESSING_d116e9815) and is meant to be used as an accelerator for the [Configurable Network Protocol Accelerator](https://ieeexplore.ieee.org/document/9280342) framework.


## Configuration
The implementation can be configured in the ```lzss.vdh``` file in the ```packages``` directory. Aside from the size of the sliding window, the process of finding matches in the processed data can be configured. The sliding window can either be scanned at once, or in multiple pipelined iterations.


## Compression
For compression, the contents of the ```tx_acc``` folder are required. The top level component, ```tx_acc_top```, is a state machine, which uses the ```match_finder``` component for finding matches. Depending on the amount of iterations specified in the ```lzss.vhd``` file, either the ```match_finder_single``` or ```match_finder_piped``` implementation is instantiated.


## Decompression
The decompression algorithm is implemented by the ```rx_acc_top``` component in the ```rx_acc``` directory. This component also implements a state machine, which is very similar to the one used for compression.


## Compilation
The repository contains a makefile for compilation, which uses the VHDL analizer, compiler and simulator ```ghdl```. The only two targets required for compilation of the compression and decompression implementations are ```tx_acc``` and ```rx_acc``` respectively.


## Testing
In the ```testbenches``` directory, two testbenches can be found, testing either the compression or decompression implementation. The ```tx_acc_top_tb``` testbench reads the file at ```testbenches/testdata/original```, feeds it to the ```tx_acc_top``` component and stores its output in the file at ```testbenches/testdata/encoded```. The ```rx_acc_top_tb``` testbench feeds the decompression algorithm with the ```testbenches/testdata/encoded``` file, storing the output in ```testbenches/testdata/decoded```.

The simulation of the testbenches with ```ghdl``` can be invoked by adding ```sim=tx_acc``` or ```sim=rx_acc``` to the make command.
