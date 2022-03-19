module geofence (clk,reset,X,Y,valid,is_inside);
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

  parameter IDLE = 3'd0;
  parameter RD_DATA = 3'd1;
  parameter POSITION_CAL= 3'd2;
  parameter DET_INSIDE = 3'd3;
  parameter DONE = 3'd4;

  reg [2:0] counter_reg;
  reg [19:0] postion_reg;

  wire rd_data_done_flag;
  wire rd_data;
  assign rd_data_done_flag = (counter_reg == 3'd7);
  assign rd_data = (current_state == RD_DATA);

  always @(posedge clk or posedge reset)
  begin
    if(reset)
      counter_reg <= 3'd0;
    else if(!reset)
      counter_reg <= rd_data_done_flag ? 3'd0 : counter_reg + 3'd1;
  end

  /*----------FSM-----------*/
  always @(posedge clk or posedge reset)
  begin
    current_state <= (reset) ? IDLE : next_state;
  end

  always @(*)
  begin
    case (current_state)
      IDLE:
        next_state = (!reset) ? RD_DATA : IDLE;
      RD_DATA:
        next_state = (rd_data_done_flag) ? POSITION_CAL : RD_DATA;
      POSITION_CAL:
        next_state = (counter_reg == 3'd5) ? DET_INSIDE : POSITION_CAL;
      DET_INSIDE:
        next_state = (counter_reg == 3'd5) ? DET_INSIDE : DONE;
      DONE:
        next_state = IDLE;
      default:
        next_state = IDLE;
    endcase
  end

  /*----------RD_DATA----------*/
  always @(posedge clk or posedge reset)
  begin
    if(reset)
      postion_reg <= 20'd0;
    else if(!reset)
      postion_reg [counter_reg] <= {X,Y};
  end



endmodule

