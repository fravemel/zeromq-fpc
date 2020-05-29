
//  Lazy Pirate server
//  Binds REQ socket to tcp://*:5555
//  Like hwserver except:
//   - echoes request as-is
//   - randomly runs slowly, or exits to simulate a crash.

program lpserver;

{$MODE objfpc}{$H+}

uses SysUtils, zmq, zmq_utils;

var
  context, responder: Pointer;
  rc : integer = 0;
  request : string; // ansistring
  cycles : Integer;
begin
  Randomize;
  //  Socket to talk to clients
  context := zmq_ctx_new;
  responder := zmq_socket(context, ZMQ_REP);
  rc := zmq_bind(responder, 'tcp://*:5555');
  Assert(rc = 0);
  WriteLn('Echo server initialized...');

  cycles := 0;
  while True do
    begin

      request:= zmq_recv_string(responder);
      Writeln('Received ', request);

      inc( cycles );
      //  Simulate various problems, after a few cycles
      if ( cycles > 10 ) and ( random(3) = 0) then
      begin
        Writeln( 'I: simulating a crash' );
        break;
      end else
      if ( cycles > 3 ) and ( random(3) = 0 ) then
      begin
        Writeln( 'I: simulating CPU overload' );
        sleep(2000);
      end;

      Writeln( Format( 'I: normal request (%s)', [request] ) );
      sleep (1000);              //  Do some heavy work

      WriteLn('Sending '+request+'...');
      zmq_send_string(responder, request);
    end;
end.
