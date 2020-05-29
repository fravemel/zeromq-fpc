//  Lazy Pirate client

program lpclient;

{$MODE objfpc}{$H+}

uses
  zmq,
  zmq_utils,
  SysUtils;

const
  REQUEST_TIMEOUT = 2500;
  REQUEST_RETRIES = 3;
  SERVER_ENDPOINT = 'tcp://localhost:5555';

var
  context, client, poller: Pointer;
  i: integer;
  Request, Reply: Utf8String;// string; // ansistring
  sequence: integer;
  retries_left: integer;
  expect_reply: integer;
  items: zmq_pollitem_t;
  rc: integer;
  linger: integer = 0;

begin
  WriteLn('Connecting to Echo server...');
  context := zmq_ctx_new;
  client := zmq_socket(context, ZMQ_REQ);
  zmq_setsockopt(client, ZMQ_LINGER, @linger, SIZEOF(linger));
  zmq_connect(client, SERVER_ENDPOINT);


  sequence := 0;
  retries_left := REQUEST_RETRIES;

  WriteLn('Entering while loop');
  while (retries_left > 0) do
  begin
    Inc(sequence);
    Request := IntToStr(sequence);
    WriteLn('Sending ' + Request + '...');
    zmq_send_string(client, Request);

    expect_reply := 1;
    while (expect_reply > 0) do
    begin
      items.socket := client;
      items.fd := 0;
      items.events := ZMQ_POLLIN;
      items.revents := 0;

      rc := zmq_poll(@items, 1, REQUEST_TIMEOUT);

      if (rc = -1) then
        break;
      // Here we process a server reply and exit our loop if the
      // reply is valid. If we didn't get a reply we close the
      // client socket, open it again and resend the request. We
      // try a number times before finally abandoning:

      if (items.revents and ZMQ_POLLIN = ZMQ_POLLIN) then
      begin
        // We got a reply from the server, must match sequence
        reply := zmq_recv_string(client);
        if StrToInt(Reply) = sequence then
        begin
          Writeln(Format('I: server replied OK (%s)', [reply]));
          retries_left := REQUEST_RETRIES;
          expect_reply := 0;
        end
        else
          Writeln(Format('E: malformed reply from server: %s', [reply]));
      end
      else
      begin
        Dec(retries_left);

        if retries_left = 0 then
        begin
          Writeln('E: server seems to be offline, abandoning');
          break;
        end
        else
        begin
          Writeln('W: no response from server, retrying...');
          zmq_close(client);
          Writeln('I: reconnecting to server...');
          client := zmq_socket(context, ZMQ_REQ);
          zmq_connect(client, SERVER_ENDPOINT);
          zmq_send_string(client, Request);
        end;
      end;
    end;

  end;
  zmq_close(client);
  zmq_ctx_destroy(context);
end.
