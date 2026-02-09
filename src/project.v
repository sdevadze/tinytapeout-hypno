/*
 * Hypnotic concentric rings effect
 * ui_in[0] = speed (0=slow, 1=fast)
 * ui_in[1] = direction (0=outward, 1=inward)
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_hypno_rings (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals from sync generator
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    // Instantiate the sync generator
    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos),
        .vpos(vpos)
    );

    // Frame counter for animation
    reg [9:0] frame;

    // Control inputs
    wire speed = ui_in[0];      // 0=slow, 1=fast
    wire direction = ui_in[1];  // 0=outward, 1=inward
    wire[1:0] speed_factor = ui_in[3:2];  // accel or slow factor

    // hpos/vpos modification
    wire[9:0] hpos_mod = (ui_in[4] ? hpos[9:0] >> ui_in[5] : hpos[9:0] << ui_in[5]);
    wire[9:0] vpos_mod = (ui_in[6] ? vpos[9:0] >> ui_in[7] : vpos[9:0] << ui_in[7]);


    // Centered coordinates (signed)
    wire signed [10:0] cx = $signed({1'b0, hpos_mod}) - 11'sd320;
    wire signed [10:0] cy = $signed({1'b0, vpos_mod}) - 11'sd240;

    // Absolute values
    wire [9:0] abs_x = cx[10] ? (~cx[9:0] + 1'b1) : cx[9:0];
    wire [9:0] abs_y = cy[10] ? (~cy[9:0] + 1'b1) : cy[9:0];

    // Distance approximation (max + min/2)
    wire [9:0] max_d = (abs_x > abs_y) ? abs_x : abs_y;
    wire [9:0] min_d = (abs_x < abs_y) ? abs_x : abs_y;
    wire [9:0] radius = max_d + {1'b0, min_d[9:1]};

    // Animated radius for concentric rings with direction control
    wire [7:0] anim_offset_orig = frame[6:0] + frame[6:0];
    // accelerate
    wire [7:0] anim_offset = (speed ? (anim_offset_orig << speed_factor) : (anim_offset_orig >> speed_factor));
    wire [7:0] anim_radius = direction ? (radius[7:0] - anim_offset) : (radius[7:0] + anim_offset);

    // Final color outputs (hypnotic concentric rings)
    wire [1:0] r_out = anim_radius[5:4] & {2{display_on}};
    wire [1:0] g_out = anim_radius[6:5] & {2{display_on}};
    wire [1:0] b_out = anim_radius[7:6] & {2{display_on}};

    // VGA output mapping (RGB222 on Tiny VGA PMOD)
    assign uo_out[0] = r_out[1];  // R1
    assign uo_out[4] = r_out[0];  // R0
    assign uo_out[1] = g_out[1];  // G1
    assign uo_out[5] = g_out[0];  // G0
    assign uo_out[2] = b_out[1];  // B1
    assign uo_out[6] = b_out[0];  // B0
    assign uo_out[3] = vsync;    // VSYNC
    assign uo_out[7] = hsync;    // HSYNC

    // Bidirectional pins unused
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Frame counter for animation with variable speed
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame <= 0;
        end else begin
            if (hpos == 0 && vpos == 0)
                frame <= frame + (speed ? 10'd2 : 10'd1);
        end
    end

    // Unused inputs
//    wire _unused = &{ena, uio_in, ui_in[7:2], radius[9:8], frame[9:7], min_d[0], anim_radius[3:0], 1'b0};
    wire _unused = &{ena, uio_in, radius[9:8], frame[9:7], min_d[0], anim_radius[3:0], 1'b0};

endmodule
