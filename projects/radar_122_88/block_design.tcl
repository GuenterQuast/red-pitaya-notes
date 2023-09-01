# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 122.88
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 122.88
  CLKOUT2_USED true
  CLKOUT2_REQUESTED_OUT_FREQ 245.76
  CLKOUT2_REQUESTED_PHASE 157.5
  CLKOUT3_USED true
  CLKOUT3_REQUESTED_OUT_FREQ 245.76
  CLKOUT3_REQUESTED_PHASE 202.5
  USE_RESET false
} {
  clk_in1_p adc_clk_p_i
  clk_in1_n adc_clk_n_i
}

# Create processing_system7
cell xilinx.com:ip:processing_system7 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/red_pitaya.xml
  PCW_USE_S_AXI_HP0 1
  PCW_USE_S_AXI_ACP 1
  PCW_USE_DEFAULT_ACP_USER_VAL 1
} {
  M_AXI_GP0_ACLK pll_0/clk_out1
  S_AXI_HP0_ACLK pll_0/clk_out1
  S_AXI_ACP_ACLK pll_0/clk_out1
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master Disable
  Slave Disable
} [get_bd_cells ps_0]

# Create xlconstant
cell xilinx.com:ip:xlconstant const_0

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
  dcm_locked pll_0/locked
  slowest_sync_clk pll_0/clk_out1
}

# ADC

# Create axis_red_pitaya_adc
cell pavel-demin:user:axis_red_pitaya_adc adc_0 {
  ADC_DATA_WIDTH 16
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# DAC

# Create axis_red_pitaya_dac
cell pavel-demin:user:axis_red_pitaya_dac dac_0 {
  DAC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  wrt_clk pll_0/clk_out3
  locked pll_0/locked
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
  s_axis_tvalid const_0/dout
}

# HUB

# Create axi_hub
cell pavel-demin:user:axi_hub hub_0 {
  CFG_DATA_WIDTH 224
  STS_DATA_WIDTH 32
} {
  S_AXI ps_0/M_AXI_GP0
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_0 {
  DIN_WIDTH 224 DIN_FROM 0 DIN_TO 0
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_1 {
  DIN_WIDTH 224 DIN_FROM 1 DIN_TO 1
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_2 {
  DIN_WIDTH 224 DIN_FROM 31 DIN_TO 16
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_3 {
  DIN_WIDTH 224 DIN_FROM 63 DIN_TO 32
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_4 {
  DIN_WIDTH 224 DIN_FROM 95 DIN_TO 64
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_5 {
  DIN_WIDTH 224 DIN_FROM 127 DIN_TO 96
} {
  din hub_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_6 {
  DIN_WIDTH 224 DIN_FROM 159 DIN_TO 128
} {
  din hub_0/cfg_data
}

# DDS

# Create axis_constant
cell pavel-demin:user:axis_constant phase_0 {
  AXIS_TDATA_WIDTH 32
} {
  cfg_data slice_3/dout
  aclk pll_0/clk_out1
}

# Create dds_compiler
cell xilinx.com:ip:dds_compiler dds_0 {
  DDS_CLOCK_RATE 122.88
  SPURIOUS_FREE_DYNAMIC_RANGE 138
  FREQUENCY_RESOLUTION 0.2
  PHASE_INCREMENT Streaming
  HAS_ARESETN true
  HAS_PHASE_OUT false
  PHASE_WIDTH 30
  OUTPUT_WIDTH 24
  NEGATIVE_SINE true
} {
  S_AXIS_PHASE phase_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create axis_constant
cell pavel-demin:user:axis_constant phase_1 {
  AXIS_TDATA_WIDTH 32
} {
  cfg_data slice_3/dout
  aclk pll_0/clk_out1
}

# Create dds_compiler
cell xilinx.com:ip:dds_compiler dds_1 {
  DDS_CLOCK_RATE 122.88
  SPURIOUS_FREE_DYNAMIC_RANGE 138
  FREQUENCY_RESOLUTION 0.2
  PHASE_INCREMENT Streaming
  HAS_ARESETN true
  HAS_PHASE_OUT false
  PHASE_WIDTH 30
  OUTPUT_WIDTH 24
} {
  S_AXIS_PHASE phase_1/M_AXIS
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# RX

for {set i 0} {$i <= 3} {incr i} {

  # Create port_slicer
  cell pavel-demin:user:port_slicer adc_slice_$i {
    DIN_WIDTH 32 DIN_FROM [expr 16 * ($i / 2) + 15] DIN_TO [expr 16 * ($i / 2)]
  } {
    din adc_0/m_axis_tdata
  }

  # Create port_slicer
  cell pavel-demin:user:port_slicer dds_slice_$i {
    DIN_WIDTH 48 DIN_FROM [expr 24 * ($i % 2) + 23] DIN_TO [expr 24 * ($i % 2)]
  } {
    din dds_0/m_axis_data_tdata
  }

  # Create dsp48
  cell pavel-demin:user:dsp48 mult_$i {
    A_WIDTH 24
    B_WIDTH 16
    P_WIDTH 32
  } {
    A dds_slice_$i/dout
    B adc_slice_$i/dout
    CLK pll_0/clk_out1
  }

  # Create axis_variable
  cell pavel-demin:user:axis_variable rate_$i {
    AXIS_TDATA_WIDTH 16
  } {
    cfg_data slice_2/dout
    aclk pll_0/clk_out1
    aresetn slice_0/dout
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Programmable
    MINIMUM_RATE 15
    MAXIMUM_RATE 128
    FIXED_OR_INITIAL_RATE 15
    INPUT_SAMPLE_FREQUENCY 122.88
    CLOCK_FREQUENCY 122.88
    INPUT_DATA_WIDTH 32
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 32
    USE_XTREME_DSP_SLICE false
    HAS_ARESETN true
  } {
    s_axis_data_tdata mult_$i/P
    s_axis_data_tvalid const_0/dout
    S_AXIS_CONFIG rate_$i/M_AXIS
    aclk pll_0/clk_out1
    aresetn slice_0/dout
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 4
  NUM_SI 4
} {
  S00_AXIS cic_0/M_AXIS_DATA
  S01_AXIS cic_1/M_AXIS_DATA
  S02_AXIS cic_2/M_AXIS_DATA
  S03_AXIS cic_3/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler fir_0 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-1.6464825947e-08, -4.7195976111e-08, -7.3969804484e-10, 3.0853352366e-08, 1.8498593382e-08, 3.2656750741e-08, -6.1649151740e-09, -1.5186359978e-07, -8.2998227949e-08, 3.1367247777e-07, 3.0506547939e-07, -4.7285124488e-07, -7.1195495904e-07, 5.4574063368e-07, 1.3315637659e-06, -4.1279086810e-07, -2.1454374378e-06, -6.8006467034e-08, 3.0680922271e-06, 1.0350061814e-06, -3.9348163084e-06, -2.5861732352e-06, 4.5043801477e-06, 4.7368854080e-06, -4.4818639402e-06, -7.3809002981e-06, 3.5634212218e-06, 1.0265218064e-05, -1.5001488430e-06, -1.2990035406e-05, -1.8275617390e-06, 1.5042551805e-05, 6.3390555256e-06, -1.5868450698e-05, -1.1703786442e-05, 1.4976501776e-05, 1.7329688105e-05, -1.2067661980e-05, -2.2412557348e-05, 7.1558960033e-06, 2.6040808077e-05, -6.6646754452e-07, -2.7364748541e-05, -6.5293624239e-06, 2.5805288929e-05, 1.3166326537e-05, -2.1271192497e-05, -1.7740820138e-05, 1.4340042306e-05, 1.8768601134e-05, -6.3536432210e-06, -1.5121844942e-05, -6.1877612146e-07, 6.3989038268e-06, 3.9813307175e-06, 6.7389375010e-06, -9.8442411601e-07, -2.2342032814e-05, -1.0755761346e-05, 3.7131546955e-05, 3.2640177258e-05, -4.6730366627e-05, -6.4512587947e-05, 4.6126753723e-05, 1.0416220372e-04, -3.0441665130e-05, -1.4710905617e-04, -4.1371283181e-06, 1.8673702455e-04, 5.9355901934e-05, -2.1485366461e-04, -1.3400377336e-04, 2.2268096992e-04, 2.2331862792e-04, -2.0220604546e-04, -3.1887357105e-04, 1.4773483964e-04, 4.0908095860e-04, -5.7420621507e-05, -4.8037477817e-04, -6.5512890967e-05, 5.1902296864e-04, 2.1214083246e-04, -5.1341486705e-04, -3.6810202252e-04, 4.5641734447e-04, 5.1471658785e-04, -3.4771137860e-04, -6.3135079407e-04, 1.9527526251e-04, 6.9851418741e-04, -1.5881772975e-05, -7.0155314101e-04, -1.6583570468e-04, 6.3439541243e-04, 3.1990840994e-04, -5.0273271063e-04, -4.1510447677e-04, 3.2597807034e-04, 4.2423975078e-04, -1.3739242147e-04, -3.3016185479e-04, -1.8073582550e-05, 1.3161167164e-04, 8.8416722351e-05, 1.5198058943e-04, -2.1565665594e-05, -4.7779980293e-04, -2.2600285691e-04, 7.7945487056e-04, 6.7905866853e-04, -9.7113751046e-04, -1.3345139575e-03, 9.5475506884e-04, 2.1532627719e-03, -6.3102825990e-04, -3.0551461729e-03, -8.6604616445e-05, 3.9180606746e-03, 1.2563990530e-03, -4.5820834718e-03, -2.8925781035e-03, 4.8589738379e-03, 4.9512096090e-03, -4.5468027787e-03, -7.3194064982e-03, 3.4488023429e-03, 9.8092626542e-03, -1.3949220396e-03, -1.2157318368e-02, -1.7358744924e-03, 1.4029168032e-02, 5.9935985332e-03, -1.5030511349e-02, -1.1342163366e-02, 1.4714818733e-02, 1.7644095012e-02, -1.2591250884e-02, -2.4653562939e-02, 8.1160219161e-03, 3.2010292493e-02, -6.5039690493e-04, -3.9225966756e-02, -1.0657243778e-02, 4.5635088540e-02, 2.7172231004e-02, -5.0218838727e-02, -5.1576985838e-02, 5.0936557069e-02, 9.0343433132e-02, -4.1600399368e-02, -1.6339651194e-01, -1.0531231406e-02, 3.5615645419e-01, 5.5428707645e-01, 3.5615645419e-01, -1.0531231406e-02, -1.6339651194e-01, -4.1600399368e-02, 9.0343433132e-02, 5.0936557069e-02, -5.1576985838e-02, -5.0218838727e-02, 2.7172231004e-02, 4.5635088540e-02, -1.0657243778e-02, -3.9225966756e-02, -6.5039690493e-04, 3.2010292493e-02, 8.1160219161e-03, -2.4653562939e-02, -1.2591250884e-02, 1.7644095012e-02, 1.4714818733e-02, -1.1342163366e-02, -1.5030511349e-02, 5.9935985332e-03, 1.4029168032e-02, -1.7358744924e-03, -1.2157318368e-02, -1.3949220396e-03, 9.8092626542e-03, 3.4488023429e-03, -7.3194064982e-03, -4.5468027787e-03, 4.9512096090e-03, 4.8589738379e-03, -2.8925781035e-03, -4.5820834718e-03, 1.2563990530e-03, 3.9180606746e-03, -8.6604616445e-05, -3.0551461729e-03, -6.3102825990e-04, 2.1532627719e-03, 9.5475506884e-04, -1.3345139575e-03, -9.7113751046e-04, 6.7905866853e-04, 7.7945487056e-04, -2.2600285691e-04, -4.7779980293e-04, -2.1565665594e-05, 1.5198058943e-04, 8.8416722351e-05, 1.3161167164e-04, -1.8073582550e-05, -3.3016185479e-04, -1.3739242147e-04, 4.2423975078e-04, 3.2597807034e-04, -4.1510447677e-04, -5.0273271063e-04, 3.1990840994e-04, 6.3439541243e-04, -1.6583570468e-04, -7.0155314101e-04, -1.5881772975e-05, 6.9851418741e-04, 1.9527526251e-04, -6.3135079407e-04, -3.4771137860e-04, 5.1471658785e-04, 4.5641734447e-04, -3.6810202252e-04, -5.1341486705e-04, 2.1214083246e-04, 5.1902296864e-04, -6.5512890967e-05, -4.8037477817e-04, -5.7420621507e-05, 4.0908095860e-04, 1.4773483964e-04, -3.1887357105e-04, -2.0220604546e-04, 2.2331862792e-04, 2.2268096992e-04, -1.3400377336e-04, -2.1485366461e-04, 5.9355901934e-05, 1.8673702455e-04, -4.1371283181e-06, -1.4710905617e-04, -3.0441665130e-05, 1.0416220372e-04, 4.6126753723e-05, -6.4512587947e-05, -4.6730366627e-05, 3.2640177258e-05, 3.7131546955e-05, -1.0755761346e-05, -2.2342032814e-05, -9.8442411601e-07, 6.7389375010e-06, 3.9813307175e-06, 6.3989038268e-06, -6.1877612146e-07, -1.5121844942e-05, -6.3536432210e-06, 1.8768601134e-05, 1.4340042306e-05, -1.7740820138e-05, -2.1271192497e-05, 1.3166326537e-05, 2.5805288929e-05, -6.5293624239e-06, -2.7364748541e-05, -6.6646754452e-07, 2.6040808077e-05, 7.1558960033e-06, -2.2412557348e-05, -1.2067661980e-05, 1.7329688105e-05, 1.4976501776e-05, -1.1703786442e-05, -1.5868450698e-05, 6.3390555256e-06, 1.5042551805e-05, -1.8275617390e-06, -1.2990035406e-05, -1.5001488430e-06, 1.0265218064e-05, 3.5634212218e-06, -7.3809002981e-06, -4.4818639402e-06, 4.7368854080e-06, 4.5043801477e-06, -2.5861732352e-06, -3.9348163084e-06, 1.0350061814e-06, 3.0680922271e-06, -6.8006467034e-08, -2.1454374378e-06, -4.1279086810e-07, 1.3315637659e-06, 5.4574063368e-07, -7.1195495904e-07, -4.7285124488e-07, 3.0506547939e-07, 3.1367247777e-07, -8.2998227949e-08, -1.5186359978e-07, -6.1649151740e-09, 3.2656750741e-08, 1.8498593382e-08, 3.0853352366e-08, -7.3969804484e-10, -4.7195976111e-08, -1.6464825947e-08}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Quantize_Only
  BESTPRECISION true
  FILTER_TYPE Decimation
  DECIMATION_RATE 2
  NUMBER_CHANNELS 1
  NUMBER_PATHS 4
  SAMPLE_FREQUENCY 8.192
  CLOCK_FREQUENCY 122.88
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 34
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA comb_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 20
  M_TDATA_NUM_BYTES 16
  TDATA_REMAP {tdata[151:120],tdata[111:80],tdata[71:40],tdata[31:0]}
} {
  S_AXIS fir_0/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# DMA

# Create axis_ram_reader
cell pavel-demin:user:axis_ram_reader reader_0 {
  ADDR_WIDTH 16
  AXI_ID_WIDTH 3
  AXIS_TDATA_WIDTH 128
  FIFO_WRITE_DEPTH 512
} {
  M_AXI ps_0/S_AXI_HP0
  min_addr slice_4/dout
  cfg_data slice_5/dout
  aclk pll_0/clk_out1
  aresetn slice_1/dout
}

# Create xlconstant
cell xilinx.com:ip:xlconstant const_1 {
  CONST_WIDTH 12
  CONST_VAL 4095
}

# Create axis_ram_writer
cell pavel-demin:user:axis_ram_writer writer_0 {
  ADDR_WIDTH 12
  AXI_ID_WIDTH 3
  AXIS_TDATA_WIDTH 128
  FIFO_WRITE_DEPTH 512
} {
  S_AXIS subset_0/M_AXIS
  M_AXI ps_0/S_AXI_ACP
  min_addr slice_6/dout
  cfg_data const_1/dout
  aclk pll_0/clk_out1
  aresetn slice_1/dout
}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 2
  IN0_WIDTH 16
  IN1_WIDTH 16
} {
  In0 reader_0/sts_data
  In1 writer_0/sts_data
  dout hub_0/sts_data
}

# TX

# Create fir_compiler
cell xilinx.com:ip:fir_compiler fir_1 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-1.6464825947e-08, -4.7195976111e-08, -7.3969804484e-10, 3.0853352366e-08, 1.8498593382e-08, 3.2656750741e-08, -6.1649151740e-09, -1.5186359978e-07, -8.2998227949e-08, 3.1367247777e-07, 3.0506547939e-07, -4.7285124488e-07, -7.1195495904e-07, 5.4574063368e-07, 1.3315637659e-06, -4.1279086810e-07, -2.1454374378e-06, -6.8006467034e-08, 3.0680922271e-06, 1.0350061814e-06, -3.9348163084e-06, -2.5861732352e-06, 4.5043801477e-06, 4.7368854080e-06, -4.4818639402e-06, -7.3809002981e-06, 3.5634212218e-06, 1.0265218064e-05, -1.5001488430e-06, -1.2990035406e-05, -1.8275617390e-06, 1.5042551805e-05, 6.3390555256e-06, -1.5868450698e-05, -1.1703786442e-05, 1.4976501776e-05, 1.7329688105e-05, -1.2067661980e-05, -2.2412557348e-05, 7.1558960033e-06, 2.6040808077e-05, -6.6646754452e-07, -2.7364748541e-05, -6.5293624239e-06, 2.5805288929e-05, 1.3166326537e-05, -2.1271192497e-05, -1.7740820138e-05, 1.4340042306e-05, 1.8768601134e-05, -6.3536432210e-06, -1.5121844942e-05, -6.1877612146e-07, 6.3989038268e-06, 3.9813307175e-06, 6.7389375010e-06, -9.8442411601e-07, -2.2342032814e-05, -1.0755761346e-05, 3.7131546955e-05, 3.2640177258e-05, -4.6730366627e-05, -6.4512587947e-05, 4.6126753723e-05, 1.0416220372e-04, -3.0441665130e-05, -1.4710905617e-04, -4.1371283181e-06, 1.8673702455e-04, 5.9355901934e-05, -2.1485366461e-04, -1.3400377336e-04, 2.2268096992e-04, 2.2331862792e-04, -2.0220604546e-04, -3.1887357105e-04, 1.4773483964e-04, 4.0908095860e-04, -5.7420621507e-05, -4.8037477817e-04, -6.5512890967e-05, 5.1902296864e-04, 2.1214083246e-04, -5.1341486705e-04, -3.6810202252e-04, 4.5641734447e-04, 5.1471658785e-04, -3.4771137860e-04, -6.3135079407e-04, 1.9527526251e-04, 6.9851418741e-04, -1.5881772975e-05, -7.0155314101e-04, -1.6583570468e-04, 6.3439541243e-04, 3.1990840994e-04, -5.0273271063e-04, -4.1510447677e-04, 3.2597807034e-04, 4.2423975078e-04, -1.3739242147e-04, -3.3016185479e-04, -1.8073582550e-05, 1.3161167164e-04, 8.8416722351e-05, 1.5198058943e-04, -2.1565665594e-05, -4.7779980293e-04, -2.2600285691e-04, 7.7945487056e-04, 6.7905866853e-04, -9.7113751046e-04, -1.3345139575e-03, 9.5475506884e-04, 2.1532627719e-03, -6.3102825990e-04, -3.0551461729e-03, -8.6604616445e-05, 3.9180606746e-03, 1.2563990530e-03, -4.5820834718e-03, -2.8925781035e-03, 4.8589738379e-03, 4.9512096090e-03, -4.5468027787e-03, -7.3194064982e-03, 3.4488023429e-03, 9.8092626542e-03, -1.3949220396e-03, -1.2157318368e-02, -1.7358744924e-03, 1.4029168032e-02, 5.9935985332e-03, -1.5030511349e-02, -1.1342163366e-02, 1.4714818733e-02, 1.7644095012e-02, -1.2591250884e-02, -2.4653562939e-02, 8.1160219161e-03, 3.2010292493e-02, -6.5039690493e-04, -3.9225966756e-02, -1.0657243778e-02, 4.5635088540e-02, 2.7172231004e-02, -5.0218838727e-02, -5.1576985838e-02, 5.0936557069e-02, 9.0343433132e-02, -4.1600399368e-02, -1.6339651194e-01, -1.0531231406e-02, 3.5615645419e-01, 5.5428707645e-01, 3.5615645419e-01, -1.0531231406e-02, -1.6339651194e-01, -4.1600399368e-02, 9.0343433132e-02, 5.0936557069e-02, -5.1576985838e-02, -5.0218838727e-02, 2.7172231004e-02, 4.5635088540e-02, -1.0657243778e-02, -3.9225966756e-02, -6.5039690493e-04, 3.2010292493e-02, 8.1160219161e-03, -2.4653562939e-02, -1.2591250884e-02, 1.7644095012e-02, 1.4714818733e-02, -1.1342163366e-02, -1.5030511349e-02, 5.9935985332e-03, 1.4029168032e-02, -1.7358744924e-03, -1.2157318368e-02, -1.3949220396e-03, 9.8092626542e-03, 3.4488023429e-03, -7.3194064982e-03, -4.5468027787e-03, 4.9512096090e-03, 4.8589738379e-03, -2.8925781035e-03, -4.5820834718e-03, 1.2563990530e-03, 3.9180606746e-03, -8.6604616445e-05, -3.0551461729e-03, -6.3102825990e-04, 2.1532627719e-03, 9.5475506884e-04, -1.3345139575e-03, -9.7113751046e-04, 6.7905866853e-04, 7.7945487056e-04, -2.2600285691e-04, -4.7779980293e-04, -2.1565665594e-05, 1.5198058943e-04, 8.8416722351e-05, 1.3161167164e-04, -1.8073582550e-05, -3.3016185479e-04, -1.3739242147e-04, 4.2423975078e-04, 3.2597807034e-04, -4.1510447677e-04, -5.0273271063e-04, 3.1990840994e-04, 6.3439541243e-04, -1.6583570468e-04, -7.0155314101e-04, -1.5881772975e-05, 6.9851418741e-04, 1.9527526251e-04, -6.3135079407e-04, -3.4771137860e-04, 5.1471658785e-04, 4.5641734447e-04, -3.6810202252e-04, -5.1341486705e-04, 2.1214083246e-04, 5.1902296864e-04, -6.5512890967e-05, -4.8037477817e-04, -5.7420621507e-05, 4.0908095860e-04, 1.4773483964e-04, -3.1887357105e-04, -2.0220604546e-04, 2.2331862792e-04, 2.2268096992e-04, -1.3400377336e-04, -2.1485366461e-04, 5.9355901934e-05, 1.8673702455e-04, -4.1371283181e-06, -1.4710905617e-04, -3.0441665130e-05, 1.0416220372e-04, 4.6126753723e-05, -6.4512587947e-05, -4.6730366627e-05, 3.2640177258e-05, 3.7131546955e-05, -1.0755761346e-05, -2.2342032814e-05, -9.8442411601e-07, 6.7389375010e-06, 3.9813307175e-06, 6.3989038268e-06, -6.1877612146e-07, -1.5121844942e-05, -6.3536432210e-06, 1.8768601134e-05, 1.4340042306e-05, -1.7740820138e-05, -2.1271192497e-05, 1.3166326537e-05, 2.5805288929e-05, -6.5293624239e-06, -2.7364748541e-05, -6.6646754452e-07, 2.6040808077e-05, 7.1558960033e-06, -2.2412557348e-05, -1.2067661980e-05, 1.7329688105e-05, 1.4976501776e-05, -1.1703786442e-05, -1.5868450698e-05, 6.3390555256e-06, 1.5042551805e-05, -1.8275617390e-06, -1.2990035406e-05, -1.5001488430e-06, 1.0265218064e-05, 3.5634212218e-06, -7.3809002981e-06, -4.4818639402e-06, 4.7368854080e-06, 4.5043801477e-06, -2.5861732352e-06, -3.9348163084e-06, 1.0350061814e-06, 3.0680922271e-06, -6.8006467034e-08, -2.1454374378e-06, -4.1279086810e-07, 1.3315637659e-06, 5.4574063368e-07, -7.1195495904e-07, -4.7285124488e-07, 3.0506547939e-07, 3.1367247777e-07, -8.2998227949e-08, -1.5186359978e-07, -6.1649151740e-09, 3.2656750741e-08, 1.8498593382e-08, 3.0853352366e-08, -7.3969804484e-10, -4.7195976111e-08, -1.6464825947e-08}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Quantize_Only
  BESTPRECISION true
  FILTER_TYPE Interpolation
  INTERPOLATION_RATE 2
  NUMBER_CHANNELS 1
  NUMBER_PATHS 4
  SAMPLE_FREQUENCY 4.096
  CLOCK_FREQUENCY 122.88
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 34
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA reader_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster bcast_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 20
  M_TDATA_NUM_BYTES 4
  NUM_MI 4
  M00_TDATA_REMAP {tdata[31:0]}
  M01_TDATA_REMAP {tdata[71:40]}
  M02_TDATA_REMAP {tdata[111:80]}
  M03_TDATA_REMAP {tdata[151:120]}
} {
  S_AXIS fir_1/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

for {set i 0} {$i <= 3} {incr i} {

  # Create axis_variable
  cell pavel-demin:user:axis_variable rate_[expr $i + 4] {
    AXIS_TDATA_WIDTH 16
  } {
    cfg_data slice_2/dout
    aclk pll_0/clk_out1
    aresetn slice_0/dout
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler cic_[expr $i + 4] {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Interpolation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Programmable
    MINIMUM_RATE 15
    MAXIMUM_RATE 128
    FIXED_OR_INITIAL_RATE 15
    INPUT_SAMPLE_FREQUENCY 8.192
    CLOCK_FREQUENCY 122.88
    INPUT_DATA_WIDTH 32
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 32
    USE_XTREME_DSP_SLICE false
    HAS_ARESETN true
  } {
    S_AXIS_DATA bcast_0/M0${i}_AXIS
    S_AXIS_CONFIG rate_[expr $i + 4]/M_AXIS
    aclk pll_0/clk_out1
    aresetn slice_0/dout
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner comb_1 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 4
  NUM_SI 2
} {
  S00_AXIS cic_4/M_AXIS_DATA
  S01_AXIS cic_5/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner comb_2 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 4
  NUM_SI 2
} {
  S00_AXIS cic_6/M_AXIS_DATA
  S01_AXIS cic_7/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

for {set i 0} {$i <= 1} {incr i} {

  # Create axis_lfsr
  cell pavel-demin:user:axis_lfsr lfsr_$i {} {
    aclk pll_0/clk_out1
    aresetn rst_0/peripheral_aresetn
  }

  # Create cmpy
  cell xilinx.com:ip:cmpy mult_[expr $i + 4] {
    APORTWIDTH.VALUE_SRC USER
    BPORTWIDTH.VALUE_SRC USER
    APORTWIDTH 32
    BPORTWIDTH 24
    ROUNDMODE Random_Rounding
    OUTPUTWIDTH 17
  } {
    S_AXIS_A comb_[expr $i + 1]/M_AXIS
    s_axis_b_tdata dds_1/m_axis_data_tdata
    s_axis_b_tvalid dds_1/m_axis_data_tvalid
    S_AXIS_CTRL lfsr_$i/M_AXIS
    aclk pll_0/clk_out1
  }

}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_1 {
  NUM_PORTS 2
  IN0_WIDTH 16
  IN1_WIDTH 16
} {
  In0 mult_4/m_axis_dout_tdata
  In1 mult_5/m_axis_dout_tdata
  dout dac_0/s_axis_tdata
}
