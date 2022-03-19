module geofence (clk,
                   reset,
                   X,
                   Y,
                   valid,
                   is_inside);
  input clk;
  input reset;
  input [9:0] X;
  input [9:0] Y;
  output valid;
  output is_inside;
  //reg valid;
  //reg is_inside;
  reg [2:0] next_state ;
  reg [2:0] current_state ;

  integer i              = 0;
  parameter IDLE         = 3'd0;
  parameter RD_DATA      = 3'd1;
  parameter POSITION_CAL = 3'd2;
  parameter DET_INSIDE   = 3'd3;
  parameter DONE         = 3'd4;
  /*-----------CROSS_PRODUCT_DECLARE-------*/
  wire [9:0]cross_product_in_ref_point_x;
  wire [9:0]cross_product_in_ref_point_y;

  wire [9:0]cross_product_in_input_point_1_x;
  wire [9:0]cross_product_in_input_point_1_y;

  wire[9:0] cross_product_in_input_point_2_x;
  wire[9:0] cross_product_in_input_point_2_y;

  reg [19:0]cross_product_in_ref_point ;
  reg [19:0]cross_product_in_input_point_1;
  reg [19:0]cross_product_in_input_point_2;
  wire signed [19:0]cross_result;
  wire cross_out;

  //Registers
  reg [2:0] counter_reg;
  reg [2:0] pointer_reg;
  reg [19:0] position_reg[0:5];
  reg [19:0] test_point_reg;
  reg is_inside_flag_reg;

  wire [2:0] counter_wire;

  //Flags
  wire rd_data_done_flag;
  wire position_cal_done_flag;
  wire det_inside_done_flag;
  wire iteration_clear;

  wire state_IDLE;
  wire state_RD_DATA;
  wire state_POSITION_CAL;
  wire state_DET_INSIDE;
  wire state_DONE;


  assign counter_wire = !state_POSITION_CAL ? 3'd0 : iteration_clear ? counter_reg + 3'd1 : counter_reg;

  assign rd_data_done_flag      = (counter_reg == 3'd5);
  assign position_cal_done_flag = (counter_reg == 3'd4 && state_POSITION_CAL);
  assign iteration_clear        = (pointer_reg == 3'd5);
  assign det_inside_done_flag   = (counter_reg == 3'd5 && state_DET_INSIDE);

  assign state_IDLE         = (current_state == IDLE)  ;
  assign state_RD_DATA      = (current_state == RD_DATA);
  assign state_POSITION_CAL = (current_state == POSITION_CAL);
  assign state_DET_INSIDE   = (current_state == DET_INSIDE);
  assign state_DONE         = (current_state == DONE);


  //counter_reg
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      counter_reg <= 3'd0;
    else if (state_DET_INSIDE)
      counter_reg <= det_inside_done_flag ? 3'd0 : counter_reg + 3'd1;
    else if (iteration_clear)
      counter_reg <= position_cal_done_flag ? 3'd0 : counter_wire;
    else if (state_RD_DATA)
      counter_reg <= rd_data_done_flag ? 3'd1 : counter_reg + 3'd1;
    else if (state_IDLE)
      counter_reg <= 3'd0;
    else
      counter_reg <= counter_reg;
  end

  //pointer_reg
  always @(posedge clk or posedge reset)
  begin
    if (reset)
      pointer_reg <= 3'd2;
    else if (state_POSITION_CAL)
      pointer_reg <= (iteration_clear) ? counter_wire + 3'd1 : pointer_reg + 3'd1;
    else
      pointer_reg <= 3'd2;
  end

  always @(posedge clk or posedge reset)
  begin
    current_state <= (reset) ? IDLE : next_state ;
  end

  always @(*)
  begin
    case (current_state)
      IDLE:
        next_state = (!reset) ? RD_DATA : IDLE;
      RD_DATA:
        next_state = (rd_data_done_flag) ? POSITION_CAL : RD_DATA;
      POSITION_CAL:
        next_state = (counter_reg == 3'd4) ? DET_INSIDE : POSITION_CAL;
      DET_INSIDE:
        next_state = !cross_out & state_DET_INSIDE ? DONE: (counter_reg == 'd5) ? DONE : DET_INSIDE;
      DONE:
        next_state = IDLE;
      default:
        next_state = IDLE;
    endcase
  end

  /*----------RD_DATA----------*/
  wire[9:0] test_x,test_y;

  always @(posedge clk or posedge reset)
  begin
    if (reset)
    begin
      for(i = 0;i<6;i = i+1)
      begin
        position_reg[i] <= 20'd0;
      end
      test_point_reg <= 20'd0;
    end
    else if (state_IDLE)
      test_point_reg <= {X,Y};
    else
      test_point_reg <= test_point_reg;
  end

  assign {test_x,test_y} = test_point_reg;

  //position_reg
  always @(posedge clk)
  begin
    if (reset)
    begin
      for(i = 0;i<6;i = i+1)
      begin
        position_reg[i] <= 20'd0;
      end
    end
    else if (state_IDLE)
    begin
      for(i = 0;i<6;i = i+1)
      begin
        position_reg[i] <= 20'd0;
      end
    end
    else if (state_RD_DATA)
      position_reg [counter_reg] <= {X,Y};
    else
    begin
      if (state_POSITION_CAL)
      begin //SWAPPING
        position_reg[counter_reg] <= cross_out ? position_reg[pointer_reg] : position_reg[counter_reg];
        position_reg[pointer_reg] <= cross_out ? position_reg[counter_reg] : position_reg[pointer_reg];
      end
      else
      begin
        for(i = 0;i<6;i = i+1)
        begin
          position_reg[i] <= position_reg[i];
        end
      end
    end
  end

  //test_point_reg
  always @(posedge clk or posedge reset)
  begin
    test_point_reg <= reset ? 20'd0 : state_IDLE ? {X,Y} : test_point_reg;
  end

  wire [9:0] temp_x[0:5];
  wire [9:0] temp_y[0:5];

  genvar j;
  generate
    for(j = 0 ; j<6 ; j = j+1)
    begin
      assign {temp_x[j],temp_y[j]} = position_reg[j];
    end
  endgenerate

  //is_inside_flag
  always @(posedge clk or posedge reset)
  begin
    is_inside_flag_reg <= reset ? 0 : state_IDLE ? 0 : cross_out & det_inside_done_flag ? 1 : is_inside_flag_reg;
  end

  /*--------CROSS_PRODUCT INPUTS---------*/
  always @(*)
  begin
    case(current_state)
      POSITION_CAL:
      begin
        cross_product_in_input_point_1 = position_reg[counter_reg];
        cross_product_in_input_point_2 = position_reg[pointer_reg];
        cross_product_in_ref_point     = position_reg[0];
      end
      DET_INSIDE:
      begin
        cross_product_in_input_point_1 = test_point_reg;
        cross_product_in_input_point_2 = (counter_reg == 5) ? position_reg[0]: position_reg[counter_reg+1];
        cross_product_in_ref_point     = position_reg[counter_reg];
      end

      default:
      begin
        cross_product_in_input_point_1 = 0;
        cross_product_in_input_point_2 = 0;
        cross_product_in_ref_point     = 0;
      end
    endcase
  end


  /*------------CROSS PRODUCT----------*/
  assign {cross_product_in_input_point_1_x,cross_product_in_input_point_1_y} = cross_product_in_input_point_1;
  assign {cross_product_in_input_point_2_x,cross_product_in_input_point_2_y} = cross_product_in_input_point_2;
  assign {cross_product_in_ref_point_x,cross_product_in_ref_point_y}         = cross_product_in_ref_point;


  assign cross_result = (cross_product_in_input_point_1_x - cross_product_in_ref_point_x)
         *(cross_product_in_input_point_2_y-cross_product_in_ref_point_y)
         - (cross_product_in_input_point_2_x-cross_product_in_ref_point_x)
         *(cross_product_in_input_point_1_y - cross_product_in_ref_point_y);

  assign cross_out = cross_result > 0;



  /*------------DONE----------------*/
  assign valid     = (state_DONE) ? 1 : 0;
  assign is_inside = (state_DONE) ? (is_inside_flag_reg ? 1 : 0) : 0;

endmodule
