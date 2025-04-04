# fir_filter
This is a FIR (Finite Impulse Response) filter written in Verilog. It takes in data, filters it using fixed values (called coefficients), and gives the filtered result. It uses AXI Stream to connect with other blocks.

It stores the last 8 input numbers.

Multiplies each with a fixed value (coefficient).

Adds them all together to make the output.

After the last input, it keeps outputting results by pretending zeros came in, until it’s done.

Input Stream
     (AXI)
       |
       v
+------------------+
|  FIR Filter Block|
|  (with 8 taps)   |
+------------------+
       |
       v
   Output Stream
     (AXI)
